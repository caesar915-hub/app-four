#!/usr/bin/env python3
"""
Stage 3 — Quantize FP16 Core ML models to INT8.

Reads:   FlanT5BaseEncoder.mlpackage
         FlanT5BaseDecoder.mlpackage
Writes:  FlanT5BaseEncoder_INT8.mlpackage
         FlanT5BaseDecoder_INT8.mlpackage

linear_symmetric INT8: per-channel scales, no zero-points.
Typically <1% accuracy degradation on T5-class models.

Run: python 03_quantize.py
Time: 5-10 min
"""

import coremltools as ct
from coremltools.optimize.coreml import (
    OpLinearQuantizerConfig,
    OptimizationConfig,
    linear_quantize_weights,
)
from pathlib import Path

OUT_DIR = Path(__file__).parent

MODELS = [
    ("FlanT5BaseEncoder.mlpackage",     "FlanT5BaseEncoder_INT8.mlpackage"),
    ("FlanT5BaseDecoder.mlpackage",     "FlanT5BaseDecoder_INT8.mlpackage"),
]


def quantize(src: Path, dst: Path):
    print(f"\n── Quantizing {src.name} ──")
    model = ct.models.MLModel(str(src))

    config = OptimizationConfig(
        global_config=OpLinearQuantizerConfig(
            mode="linear_symmetric",  # per-channel, no zero-point — best for transformers
            dtype="int8",
        )
    )

    quantized = linear_quantize_weights(model, config=config)
    quantized.save(str(dst))

    src_mb  = sum(f.stat().st_size for f in src.rglob("*") if f.is_file()) / 1e6
    dst_mb  = sum(f.stat().st_size for f in dst.rglob("*") if f.is_file()) / 1e6
    print(f"  {src_mb:.0f} MB → {dst_mb:.0f} MB  ({dst_mb/src_mb*100:.0f}% of original)")
    print(f"  Saved: {dst}")


def main():
    for src_name, dst_name in MODELS:
        src = OUT_DIR / src_name
        dst = OUT_DIR / dst_name
        if not src.exists():
            print(f"MISSING: {src} — run 02_convert.py first")
            continue
        quantize(src, dst)

    print("\n✓ Quantization complete. Run 04_benchmark.py next.")


if __name__ == "__main__":
    main()
