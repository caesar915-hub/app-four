#!/usr/bin/env python3
"""
Stage 2 — Convert FLAN-T5-Base to Core ML FP16.

Produces two .mlpackage files:
  FlanT5BaseEncoder.mlpackage  — run once per transcript
  FlanT5BaseDecoder.mlpackage  — run once per output token (greedy loop)

Decoder returns only the last token's logits [1, vocab_size] to keep
the output shape fixed regardless of sequence position.

Fixed encoder input: 128 tokens (pad/truncate in 04_benchmark.py).
Flexible decoder input: grows 1→max_output_tokens each step.
On macOS this runs on GPU/CPU. On iOS this means CPU-only for the
decoder (flexible shapes). Fixed-shape optimization is a later task.

Run: python 02_convert.py
Time: 10-20 min
Disk: ~3GB (FP16 models)
"""

import torch
import numpy as np
import coremltools as ct
from transformers import T5ForConditionalGeneration, AutoTokenizer
from pathlib import Path

MODEL_NAME   = "google/flan-t5-base"
ENCODER_LEN  = 128   # fixed encoder input length
MAX_OUT_TOKENS = 80  # max decoder steps
OUT_DIR      = Path(__file__).parent


class EncoderWrapper(torch.nn.Module):
    def __init__(self, encoder):
        super().__init__()
        self.encoder = encoder

    def forward(self, input_ids: torch.Tensor, attention_mask: torch.Tensor) -> torch.Tensor:
        return self.encoder(
            input_ids=input_ids,
            attention_mask=attention_mask,
        ).last_hidden_state  # [1, seq_len, 1024]


class DecoderStepWrapper(torch.nn.Module):
    """
    Wraps T5 decoder + lm_head for one greedy step.
    Returns logits for the LAST token only → [1, vocab_size].
    This keeps output shape fixed regardless of decoder sequence length.
    """
    def __init__(self, model: T5ForConditionalGeneration):
        super().__init__()
        self.decoder   = model.decoder
        self.lm_head   = model.lm_head
        self.embed     = model.shared
        self.model_dim = model.model_dim
        # FLAN-T5 (v1.1 arch) has tie_word_embeddings=False → NO output rescale.
        # Original t5-base has it True → rescale. Gate on the actual config.
        self.tie_word_embeddings = model.config.tie_word_embeddings

    def forward(
        self,
        decoder_input_ids:      torch.Tensor,  # [1, step]
        encoder_hidden_states:  torch.Tensor,  # [1, ENCODER_LEN, 768]
        encoder_attention_mask: torch.Tensor,  # [1, ENCODER_LEN]
    ) -> torch.Tensor:
        # T5 does NOT scale decoder INPUT embeddings — pass straight through.
        decoder_embeds = self.embed(decoder_input_ids)
        decoder_out = self.decoder(
            inputs_embeds=decoder_embeds,
            encoder_hidden_states=encoder_hidden_states,
            encoder_attention_mask=encoder_attention_mask,
            use_cache=False,
        )
        hidden = decoder_out.last_hidden_state          # [1, step, 768]
        # Only the last position drives the next token — slice BEFORE lm_head
        # so the 32128-wide projection runs once per step, not step× per step.
        last_hidden = hidden[:, -1:, :]                 # [1, 1, 768]
        if self.tie_word_embeddings:                    # False for flan-t5 → skipped
            last_hidden = last_hidden * (self.model_dim ** -0.5)
        logits = self.lm_head(last_hidden)              # [1, 1, 32128]
        return logits[:, -1, :]                         # [1, 32128]


def convert_encoder(model, out_dir: Path):
    print("\n── Encoder ──────────────────────────────────")
    wrapper = EncoderWrapper(model.get_encoder())
    wrapper.eval()

    dummy_ids  = torch.zeros((1, ENCODER_LEN), dtype=torch.int32)
    dummy_mask = torch.ones((1, ENCODER_LEN),  dtype=torch.int32)

    with torch.no_grad():
        traced = torch.jit.trace(wrapper, (dummy_ids, dummy_mask))

    cml = ct.convert(
        traced,
        inputs=[
            ct.TensorType(name="input_ids",      shape=(1, ENCODER_LEN), dtype=np.int32),
            ct.TensorType(name="attention_mask",  shape=(1, ENCODER_LEN), dtype=np.int32),
        ],
        outputs=[ct.TensorType(name="encoder_hidden_states")],
        convert_to="mlprogram",                          # required for INT8 weight quant (03)
        minimum_deployment_target=ct.target.macOS13,     # iOS path: use ct.target.iOS16
        compute_units=ct.ComputeUnit.ALL,
    )
    path = out_dir / "FlanT5BaseEncoder.mlpackage"
    cml.save(str(path))
    print(f"Saved: {path}")
    return path


def convert_decoder(model, out_dir: Path):
    print("\n── Decoder ──────────────────────────────────")
    wrapper = DecoderStepWrapper(model)
    wrapper.eval()

    # Trace with step=1 (will use flexible shape for actual steps 1..N)
    dummy_dec_ids = torch.zeros((1, 1),          dtype=torch.int32)
    dummy_enc_hs  = torch.zeros((1, ENCODER_LEN, 768), dtype=torch.float32)
    dummy_enc_msk = torch.ones((1, ENCODER_LEN), dtype=torch.int32)

    with torch.no_grad():
        traced = torch.jit.trace(wrapper, (dummy_dec_ids, dummy_enc_hs, dummy_enc_msk))

    # Flexible decoder seq length: 1 → MAX_OUT_TOKENS
    dec_seq_dim = ct.RangeDim(lower_bound=1, upper_bound=MAX_OUT_TOKENS, default=1)

    cml = ct.convert(
        traced,
        inputs=[
            ct.TensorType(name="decoder_input_ids",      shape=(1, dec_seq_dim), dtype=np.int32),
            ct.TensorType(name="encoder_hidden_states",  shape=(1, ENCODER_LEN, 768)),
            ct.TensorType(name="encoder_attention_mask", shape=(1, ENCODER_LEN), dtype=np.int32),
        ],
        outputs=[ct.TensorType(name="logits")],
        convert_to="mlprogram",                          # required for INT8 weight quant (03)
        minimum_deployment_target=ct.target.macOS13,     # iOS path: use ct.target.iOS16
        compute_units=ct.ComputeUnit.CPU_AND_GPU,  # flexible shapes → no ANE
    )
    path = out_dir / "FlanT5BaseDecoder.mlpackage"
    cml.save(str(path))
    print(f"Saved: {path}")
    return path


def main():
    print(f"Loading {MODEL_NAME}...")
    model = T5ForConditionalGeneration.from_pretrained(MODEL_NAME, torch_dtype=torch.float32)
    model.eval()
    print("Loaded.\n")

    convert_encoder(model, OUT_DIR)
    convert_decoder(model, OUT_DIR)

    print("\n✓ Conversion complete. Run 03_quantize.py next.")


if __name__ == "__main__":
    main()
