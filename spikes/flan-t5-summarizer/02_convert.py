#!/usr/bin/env python3
"""
Stage 2 — Convert a T5/FLAN-T5 model to Core ML FP16.

Model selected via --model (see models.py). Produces two .mlpackage files:
  {Prefix}Encoder.mlpackage  — run once per transcript
  {Prefix}Decoder.mlpackage  — run once per output token (greedy loop)

d_model is read from the live model.config — never hardcoded — so encoder/
decoder Core ML shapes can never drift from the actual weights.

Decoder returns only the last token's logits [1, vocab_size] to keep the
output shape fixed regardless of sequence position.

Run: python 02_convert.py --model flan-small
Time: 10-20 min (large is slower)
"""

import argparse
import numpy as np
import torch
import coremltools as ct
from transformers import T5ForConditionalGeneration
from pathlib import Path

from models import add_model_arg, resolve

OUT_DIR = Path(__file__).parent


class EncoderWrapper(torch.nn.Module):
    def __init__(self, encoder):
        super().__init__()
        self.encoder = encoder

    def forward(self, input_ids: torch.Tensor, attention_mask: torch.Tensor) -> torch.Tensor:
        return self.encoder(
            input_ids=input_ids,
            attention_mask=attention_mask,
        ).last_hidden_state  # [1, seq_len, d_model]


class DecoderStepWrapper(torch.nn.Module):
    """
    Wraps T5 decoder + lm_head for one greedy step.
    Returns logits for the LAST token only → [1, vocab_size].
    """
    def __init__(self, model: T5ForConditionalGeneration):
        super().__init__()
        self.decoder   = model.decoder
        self.lm_head   = model.lm_head
        self.embed     = model.shared
        self.model_dim = model.model_dim
        # FLAN-T5 (v1.1): tie_word_embeddings=False → NO output rescale.
        # Plain t5 (the medical models): default True → rescale + tied lm_head.
        # Gate on the resolved config so both paths are correct.
        self.tie_word_embeddings = model.config.tie_word_embeddings

    def forward(
        self,
        decoder_input_ids:      torch.Tensor,  # [1, step]
        encoder_hidden_states:  torch.Tensor,  # [1, ENCODER_LEN, d_model]
        encoder_attention_mask: torch.Tensor,  # [1, ENCODER_LEN]
    ) -> torch.Tensor:
        decoder_embeds = self.embed(decoder_input_ids)
        decoder_out = self.decoder(
            inputs_embeds=decoder_embeds,
            encoder_hidden_states=encoder_hidden_states,
            encoder_attention_mask=encoder_attention_mask,
            use_cache=False,
        )
        hidden = decoder_out.last_hidden_state          # [1, step, d_model]
        last_hidden = hidden[:, -1:, :]                 # [1, 1, d_model]
        if self.tie_word_embeddings:                    # True for plain t5
            last_hidden = last_hidden * (self.model_dim ** -0.5)
        logits = self.lm_head(last_hidden)              # [1, 1, vocab]
        return logits[:, -1, :]                         # [1, vocab]


def convert_encoder(model, prefix, encoder_len, out_dir: Path):
    print("\n── Encoder ──────────────────────────────────")
    wrapper = EncoderWrapper(model.get_encoder())
    wrapper.eval()

    dummy_ids  = torch.zeros((1, encoder_len), dtype=torch.int32)
    dummy_mask = torch.ones((1, encoder_len),  dtype=torch.int32)

    with torch.no_grad():
        traced = torch.jit.trace(wrapper, (dummy_ids, dummy_mask))

    cml = ct.convert(
        traced,
        inputs=[
            ct.TensorType(name="input_ids",      shape=(1, encoder_len), dtype=np.int32),
            ct.TensorType(name="attention_mask", shape=(1, encoder_len), dtype=np.int32),
        ],
        outputs=[ct.TensorType(name="encoder_hidden_states")],
        convert_to="mlprogram",
        minimum_deployment_target=ct.target.macOS13,     # iOS path: ct.target.iOS16
        compute_units=ct.ComputeUnit.ALL,
    )
    path = out_dir / f"{prefix}Encoder.mlpackage"
    cml.save(str(path))
    print(f"Saved: {path}")
    return path


def convert_decoder(model, prefix, encoder_len, d_model, max_out, out_dir: Path):
    print("\n── Decoder ──────────────────────────────────")
    wrapper = DecoderStepWrapper(model)
    wrapper.eval()

    dummy_dec_ids = torch.zeros((1, 1),                   dtype=torch.int32)
    dummy_enc_hs  = torch.zeros((1, encoder_len, d_model), dtype=torch.float32)
    dummy_enc_msk = torch.ones((1, encoder_len),          dtype=torch.int32)

    with torch.no_grad():
        traced = torch.jit.trace(wrapper, (dummy_dec_ids, dummy_enc_hs, dummy_enc_msk))

    dec_seq_dim = ct.RangeDim(lower_bound=1, upper_bound=max_out, default=1)

    cml = ct.convert(
        traced,
        inputs=[
            ct.TensorType(name="decoder_input_ids",      shape=(1, dec_seq_dim), dtype=np.int32),
            ct.TensorType(name="encoder_hidden_states",  shape=(1, encoder_len, d_model)),
            ct.TensorType(name="encoder_attention_mask", shape=(1, encoder_len), dtype=np.int32),
        ],
        outputs=[ct.TensorType(name="logits")],
        convert_to="mlprogram",
        minimum_deployment_target=ct.target.macOS13,     # iOS path: ct.target.iOS16
        compute_units=ct.ComputeUnit.CPU_AND_GPU,         # flexible shapes → no ANE
    )
    path = out_dir / f"{prefix}Decoder.mlpackage"
    cml.save(str(path))
    print(f"Saved: {path}")
    return path


def main():
    parser = argparse.ArgumentParser()
    add_model_arg(parser)
    args = parser.parse_args()
    spec = resolve(args)

    print(f"Loading {spec['hf']} ...")
    model = T5ForConditionalGeneration.from_pretrained(spec["hf"], torch_dtype=torch.float32)
    model.eval()
    d_model = model.config.d_model
    print(f"Loaded. d_model={d_model}, encoder_len={spec['encoder_len']}, "
          f"tie_word_embeddings={model.config.tie_word_embeddings}\n")

    convert_encoder(model, spec["prefix"], spec["encoder_len"], OUT_DIR)
    convert_decoder(model, spec["prefix"], spec["encoder_len"], d_model,
                    spec["max_new_tokens"], OUT_DIR)

    print(f"\n✓ Conversion complete. Next: python 03_quantize.py --model {spec['key']}")


if __name__ == "__main__":
    main()
