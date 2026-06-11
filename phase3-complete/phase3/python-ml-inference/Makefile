run:
	uvicorn app.main:app --reload --port 8100

test:
	pytest tests/ -v

up:
	docker-compose up --build

# Test single prediction
predict:
	curl -s -X POST http://localhost:8100/predict \
	  -H "Content-Type: application/json" \
	  -d '{"inputs":[1.0,2.0,3.0,4.0]}' | jq .

# Test batch prediction
predict-batch:
	curl -s -X POST http://localhost:8100/predict/batch \
	  -H "Content-Type: application/json" \
	  -d '{"inputs":[[1,2,3,4],[5,6,7,8],[9,10,11,12]]}' | jq .

# List loaded models
models:
	curl -s http://localhost:8100/models | jq .
