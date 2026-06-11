# app/core/model_registry.py
#
# ModelRegistry loads ONNX models from disk at startup.
# Each model is wrapped in an OnnxModel that exposes a predict() method.
# The registry is shared across all batch engine workers.

import os
import logging
import numpy as np
from pathlib import Path
from typing import Dict, Optional

import onnxruntime as ort

from app.core.config import settings

logger = logging.getLogger(__name__)


class OnnxModel:
    """Wraps an ONNX Runtime InferenceSession with metadata."""

    def __init__(self, name: str, path: str):
        self.name = name
        self.path = path

        # GraphOptimizationLevel.ORT_ENABLE_ALL gives maximum performance
        opts = ort.SessionOptions()
        opts.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
        opts.intra_op_num_threads = os.cpu_count() or 2

        self.session = ort.InferenceSession(
            path,
            sess_options=opts,
            providers=["CPUExecutionProvider"],  # add CUDAExecutionProvider for GPU
        )

        # Cache input/output metadata for validation
        self.input_name   = self.session.get_inputs()[0].name
        self.input_shape  = self.session.get_inputs()[0].shape
        self.output_name  = self.session.get_outputs()[0].name
        self.output_shape = self.session.get_outputs()[0].shape

        logger.info(
            "Loaded model '%s' | input: %s %s | output: %s %s",
            name, self.input_name, self.input_shape,
            self.output_name, self.output_shape,
        )

    def predict(self, inputs: np.ndarray) -> np.ndarray:
        """Run inference. inputs shape: (batch_size, *feature_dims)"""
        outputs = self.session.run(
            [self.output_name],
            {self.input_name: inputs.astype(np.float32)},
        )
        return outputs[0]

    def info(self) -> dict:
        return {
            "name":         self.name,
            "input_name":   self.input_name,
            "input_shape":  self.input_shape,
            "output_name":  self.output_name,
            "output_shape": self.output_shape,
        }


class ModelRegistry:
    """Discovers and loads all .onnx files from the models directory."""

    def __init__(self):
        self._models: Dict[str, OnnxModel] = {}

    async def load_all(self):
        models_dir = Path(settings.models_dir)
        if not models_dir.exists():
            logger.warning("Models dir %s does not exist — creating with demo model", models_dir)
            models_dir.mkdir(parents=True, exist_ok=True)
            self._create_demo_model(models_dir)

        for path in models_dir.glob("*.onnx"):
            name = path.stem
            try:
                self._models[name] = OnnxModel(name, str(path))
            except Exception as e:
                logger.error("Failed to load model %s: %s", name, e)

        logger.info("Loaded %d model(s): %s", len(self._models), list(self._models.keys()))

    def get(self, name: str) -> Optional[OnnxModel]:
        return self._models.get(name)

    def list_models(self) -> list[dict]:
        return [m.info() for m in self._models.values()]

    def default_model(self) -> Optional[OnnxModel]:
        """Return the first model — used when no model_name is specified."""
        return next(iter(self._models.values()), None)

    def _create_demo_model(self, models_dir: Path):
        """
        Creates a tiny demo ONNX model (linear regression) at startup
        so the service works out of the box without external model files.
        In production you'd mount a PVC with your real model files.
        """
        try:
            from sklearn.linear_model import LinearRegression
            from skl2onnx import convert_sklearn
            from skl2onnx.common.data_types import FloatTensorType
            import numpy as np

            # Train a trivial model: output ≈ sum of inputs
            X = np.random.randn(100, 4).astype(np.float32)
            y = X.sum(axis=1)
            model = LinearRegression().fit(X, y)

            # Convert to ONNX
            initial_type = [("float_input", FloatTensorType([None, 4]))]
            onnx_model = convert_sklearn(model, initial_types=initial_type)

            output_path = models_dir / "demo-linear.onnx"
            with open(output_path, "wb") as f:
                f.write(onnx_model.SerializeToString())

            logger.info("Created demo ONNX model at %s", output_path)
        except Exception as e:
            logger.warning("Could not create demo model (sklearn/skl2onnx not installed): %s", e)
