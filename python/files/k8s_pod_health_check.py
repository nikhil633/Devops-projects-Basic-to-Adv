#!/usr/bin/env python3
"""
k8s_pod_health_check.py

Scan pods across namespaces (or one namespace) for crash-loops, high
restart counts, and non-Running phases. Uses the official kubernetes
Python client and whatever kubeconfig/context is currently active
(works fine against AKS via `az aks get-credentials` first).

Install:
    pip install kubernetes --break-system-packages

Usage:
    python k8s_pod_health_check.py                     # all namespaces
    python k8s_pod_health_check.py -n platform          # one namespace
    python k8s_pod_health_check.py --min-restarts 5
"""

import argparse
from kubernetes import client, config


def load_kube():
    try:
        config.load_kube_config()
    except Exception:
        config.load_incluster_config()  # fallback if run from inside a pod


def check_pods(v1: client.CoreV1Api, namespace: str | None, min_restarts: int):
    pods = (
        v1.list_namespaced_pod(namespace) if namespace else v1.list_pod_for_all_namespaces()
    ).items

    problems = []
    for pod in pods:
        ns, name = pod.metadata.namespace, pod.metadata.name
        phase = pod.status.phase
        statuses = pod.status.container_statuses or []

        max_restarts = max((s.restart_count for s in statuses), default=0)
        waiting_reasons = [
            s.state.waiting.reason for s in statuses if s.state and s.state.waiting
        ]

        flags = []
        if phase not in ("Running", "Succeeded"):
            flags.append(f"phase={phase}")
        if max_restarts >= min_restarts:
            flags.append(f"restarts={max_restarts}")
        if any(r in ("CrashLoopBackOff", "ImagePullBackOff", "ErrImagePull") for r in waiting_reasons):
            flags.append(f"waiting={waiting_reasons}")

        if flags:
            problems.append((ns, name, ", ".join(flags)))

    return problems


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-n", "--namespace", default=None)
    ap.add_argument("--min-restarts", type=int, default=5)
    args = ap.parse_args()

    load_kube()
    v1 = client.CoreV1Api()

    problems = check_pods(v1, args.namespace, args.min_restarts)
    if not problems:
        print("No problem pods found.")
        return

    width_ns = max(len(p[0]) for p in problems)
    width_name = max(len(p[1]) for p in problems)
    for ns, name, flags in sorted(problems):
        print(f"{ns:<{width_ns}}  {name:<{width_name}}  {flags}")


if __name__ == "__main__":
    main()
