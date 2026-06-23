"""Verdict schema + validation (spec 013, contracts/judge-verdict.schema.md).

The judge (Claude Code) decides, per signal, whether it is PRESENT (first-person,
present-tense, author's own — the corrected gold). The TP/FP/FN/TN confusion label
is DERIVED downstream from (gold presence x extractor presence), not judged here.
Richer fields are judged as item sets (correct/spurious/missed).

parse_verdict() raises VerdictError on any malformed output so the batch runner can
retry once then quarantine (FR-014, research R6) rather than miscount.
"""
import json

from pydantic import BaseModel, ConfigDict, StrictBool, ValidationError, field_validator

_SIGNAL_KEYS = {"mood", "energy", "focus", "sleep"}
_FIELD_KEYS = {"feelings", "activities", "sleep", "sideEffect"}


class VerdictError(ValueError):
    """Raised when judge output does not conform to the verdict schema."""


class SignalVerdict(BaseModel):
    model_config = ConfigDict(extra="forbid")
    reason: str
    present: StrictBool

    @field_validator("reason")
    @classmethod
    def _reason_nonempty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("reason must be non-empty")
        return v


class FieldVerdict(BaseModel):
    model_config = ConfigDict(extra="forbid")
    reason: str
    correct_items: list[str]
    spurious_items: list[str]
    missed_items: list[str]

    @field_validator("reason")
    @classmethod
    def _reason_nonempty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("reason must be non-empty")
        return v


class PostVerdict(BaseModel):
    model_config = ConfigDict(extra="forbid")
    id: str
    signals: dict[str, SignalVerdict]
    fields: dict[str, FieldVerdict]

    @field_validator("signals")
    @classmethod
    def _signal_keys(cls, v):
        if set(v) != _SIGNAL_KEYS:
            raise ValueError(f"signals keys must be exactly {sorted(_SIGNAL_KEYS)}")
        return v

    @field_validator("fields")
    @classmethod
    def _field_keys(cls, v):
        if set(v) != _FIELD_KEYS:
            raise ValueError(f"fields keys must be exactly {sorted(_FIELD_KEYS)}")
        return v


def parse_verdict(raw) -> PostVerdict:
    """Validate raw judge output (dict or JSON string) into a PostVerdict."""
    if isinstance(raw, str):
        try:
            raw = json.loads(raw)
        except (json.JSONDecodeError, ValueError) as e:
            raise VerdictError(f"not valid JSON: {e}") from e
    try:
        return PostVerdict.model_validate(raw)
    except ValidationError as e:
        raise VerdictError(str(e)) from e
