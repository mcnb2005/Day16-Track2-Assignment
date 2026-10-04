#!/usr/bin/env python3
"""Train and benchmark a LightGBM fraud detector for Lab 16."""

from __future__ import annotations

import argparse
import json
import platform
import statistics
import time
from datetime import datetime, timezone
from pathlib import Path

import lightgbm as lgb
import numpy as np
import pandas as pd
import sklearn
from lightgbm import LGBMClassifier
from sklearn.metrics import (
    accuracy_score,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
)
from sklearn.model_selection import train_test_split


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Train and benchmark LightGBM on the credit-card fraud dataset."
    )
    parser.add_argument(
        "--data",
        type=Path,
        default=Path.home() / "ml-benchmark" / "creditcard.csv",
        help="Path to creditcard.csv.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path.home() / "ml-benchmark" / "benchmark_result.json",
        help="Where to write the JSON results.",
    )
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument(
        "--latency-runs",
        type=int,
        default=200,
        help="Number of single-row predictions used for latency statistics.",
    )
    parser.add_argument(
        "--throughput-runs",
        type=int,
        default=10,
        help="Number of 1,000-row batches used for throughput statistics.",
    )
    return parser.parse_args()


def measure_inference(
    model: LGBMClassifier,
    x_test: pd.DataFrame,
    latency_runs: int,
    throughput_runs: int,
) -> dict[str, float | int]:
    single_row = x_test.iloc[[0]]
    batch_size = min(1000, len(x_test))
    batch = x_test.iloc[:batch_size]

    # Warm both prediction paths before recording timings.
    model.predict_proba(single_row)
    model.predict_proba(batch)

    latency_samples_ms = []
    for _ in range(latency_runs):
        started = time.perf_counter()
        model.predict_proba(single_row)
        latency_samples_ms.append((time.perf_counter() - started) * 1000)

    batch_samples_s = []
    for _ in range(throughput_runs):
        started = time.perf_counter()
        model.predict_proba(batch)
        batch_samples_s.append(time.perf_counter() - started)

    mean_batch_seconds = statistics.mean(batch_samples_s)
    return {
        "single_row_runs": latency_runs,
        "single_row_latency_mean_ms": statistics.mean(latency_samples_ms),
        "single_row_latency_median_ms": statistics.median(latency_samples_ms),
        "single_row_latency_p95_ms": float(np.percentile(latency_samples_ms, 95)),
        "batch_rows": batch_size,
        "batch_runs": throughput_runs,
        "batch_mean_seconds": mean_batch_seconds,
        "throughput_rows_per_second": batch_size / mean_batch_seconds,
    }


def print_summary(results: dict) -> None:
    metrics = results["metrics"]
    timings = results["timings_seconds"]
    inference = results["inference"]
    rows = [
        ("Data load time", f"{timings['data_load']:.4f} s"),
        ("Training time", f"{timings['training']:.4f} s"),
        ("Best iteration", str(results["model"]["best_iteration"])),
        ("AUC-ROC", f"{metrics['auc_roc']:.6f}"),
        ("Accuracy", f"{metrics['accuracy']:.6f}"),
        ("F1-score", f"{metrics['f1_score']:.6f}"),
        ("Precision", f"{metrics['precision']:.6f}"),
        ("Recall", f"{metrics['recall']:.6f}"),
        (
            "Inference latency (1 row, median)",
            f"{inference['single_row_latency_median_ms']:.4f} ms",
        ),
        (
            f"Inference throughput ({inference['batch_rows']} rows)",
            f"{inference['throughput_rows_per_second']:.2f} rows/s",
        ),
    ]
    width = max(len(label) for label, _ in rows)
    print("\nLightGBM benchmark results")
    print("=" * (width + 27))
    for label, value in rows:
        print(f"{label:<{width}} : {value}")
    print("=" * (width + 27))


def main() -> None:
    args = parse_args()
    if not args.data.is_file():
        raise SystemExit(
            f"Dataset not found: {args.data}\n"
            "Download it first with:\n"
            "  kaggle datasets download -d mlg-ulb/creditcardfraud "
            "--unzip -p ~/ml-benchmark/"
        )
    if args.latency_runs < 1 or args.throughput_runs < 1:
        raise SystemExit("--latency-runs and --throughput-runs must be positive")

    total_started = time.perf_counter()
    load_started = time.perf_counter()
    data = pd.read_csv(args.data)
    load_seconds = time.perf_counter() - load_started

    if "Class" not in data.columns:
        raise SystemExit("Dataset must contain the target column named 'Class'.")

    x = data.drop(columns="Class")
    target = data["Class"]
    if not pd.api.types.is_numeric_dtype(target):
        # OpenML's CSV representation wraps the binary labels as "'0'"/"'1'".
        target = target.astype(str).str.strip().str.strip("'\"")
    y = pd.to_numeric(target, errors="raise").astype(int)
    x_train, x_test, y_train, y_test = train_test_split(
        x,
        y,
        test_size=0.2,
        random_state=args.seed,
        stratify=y,
    )

    model = LGBMClassifier(
        objective="binary",
        n_estimators=1000,
        learning_rate=0.05,
        num_leaves=31,
        class_weight="balanced",
        random_state=args.seed,
        n_jobs=-1,
        verbosity=-1,
    )

    training_started = time.perf_counter()
    model.fit(
        x_train,
        y_train,
        eval_X=x_test,
        eval_y=y_test,
        eval_metric="auc",
        callbacks=[
            lgb.early_stopping(stopping_rounds=50, verbose=False),
            lgb.log_evaluation(period=0),
        ],
    )
    training_seconds = time.perf_counter() - training_started

    probabilities = model.predict_proba(x_test)[:, 1]
    predictions = (probabilities >= 0.5).astype(int)
    inference = measure_inference(
        model,
        x_test,
        latency_runs=args.latency_runs,
        throughput_runs=args.throughput_runs,
    )

    results = {
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "dataset": {
            "path": str(args.data.resolve()),
            "rows": int(len(data)),
            "features": int(x.shape[1]),
            "fraud_rows": int(y.sum()),
            "train_rows": int(len(x_train)),
            "test_rows": int(len(x_test)),
        },
        "timings_seconds": {
            "data_load": load_seconds,
            "training": training_seconds,
            "total": time.perf_counter() - total_started,
        },
        "model": {
            "name": "LGBMClassifier",
            "best_iteration": int(model.best_iteration_ or model.n_estimators),
            "classification_threshold": 0.5,
            "parameters": model.get_params(),
        },
        "metrics": {
            "auc_roc": roc_auc_score(y_test, probabilities),
            "accuracy": accuracy_score(y_test, predictions),
            "f1_score": f1_score(y_test, predictions, zero_division=0),
            "precision": precision_score(y_test, predictions, zero_division=0),
            "recall": recall_score(y_test, predictions, zero_division=0),
        },
        "inference": inference,
        "environment": {
            "python": platform.python_version(),
            "platform": platform.platform(),
            "lightgbm": lgb.__version__,
            "scikit_learn": sklearn.__version__,
            "pandas": pd.__version__,
            "numpy": np.__version__,
        },
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(results, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    print_summary(results)
    print(f"\nFull JSON written to: {args.output}")


if __name__ == "__main__":
    main()
