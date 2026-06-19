#!/usr/bin/env python3
"""
Stage 3 — Quantize FP16 Core ML models to INT8.

Model selected via --model (see models.py). Reads/writes:
  {Prefix}Encoder.mlpackage  → {Prefix}Encoder_INT8.mlpackage
  {Prefix}Decoder.mlpackage  → {Prefix}Decoder_INT8.mlpackage

linear_symmetric INT8: per-channel scales, no zero-points.
Weight-only quant — halves size; speed gain on CPU/GPU is modest (no ANE here).
Typically <1% accuracy degradation on T5-class models.

Run: python 03_quantize.py --model flan-small
"""

import argparse
from pathlib import Path

import coremltools as ct
from coremltools.optimize.coreml import (
    OpLinearQuantizerConfig,
    OptimizationConfig,
    linear_quantize_weights,
)

from models import add_model_arg, resolve

OUT_DIR = Path(__file__).parent


def quantize(src: Path, dst: Path):
    print(f"\n── Quantizing {src.name} ──")
    model = ct.models.MLModel(str(src))

    config = OptimizationConfig(
        global_config=OpLinearQuantizerConfig(
            mode="linear_symmetric",
            dtype="int8",
        )
    )

    quantized = linear_quantize_weights(model, config=config)
    quantized.save(str(dst))

    src_mb = sum(f.stat().st_size for f in src.rglob("*") if f.is_file()) / 1e6
    dst_mb = sum(f.stat().st_size for f in dst.rglob("*") if f.is_file()) / 1e6
    print(f"  {src_mb:.0f} MB → {dst_mb:.0f} MB  ({dst_mb/src_mb*100:.0f}% of original)")
    print(f"  Saved: {dst}")


def main():
    parser = argparse.ArgumentParser()
    add_model_arg(parser)
    args = parser.parse_args()
    spec = resolve(args)
    prefix = spec["prefix"]

    pairs = [
        (f"{prefix}Encoder.mlpackage", f"{prefix}Encoder_INT8.mlpackage"),
        (f"{prefix}Decoder.mlpackage", f"{prefix}Decoder_INT8.mlpackage"),
    ]

    for src_name, dst_name in pairs:
        src = OUT_DIR / src_name
        dst = OUT_DIR / dst_name
        if not src.exists():
            print(f"MISSING: {src} — run 02_convert.py --model {spec['key']} first")
            continue
        quantize(src, dst)

    print(f"\n✓ Quantization complete. Next: python 04_benchmark.py --model {spec['key']} --int8")


if __name__ == "__main__":
    main()
