"""JudgeBackend seam (spec 013, research R1).

The live judge is Claude Code (no API key): the orchestrator writes verdict JSON
that the harness validates and ingests. FixtureBackend lets the calibration,
scoring, and gating logic be unit-tested without any live judging.
"""
from abc import ABC, abstractmethod

from judge.schema import parse_verdict, PostVerdict


class JudgeBackend(ABC):
    @abstractmethod
    def judge_batch(self, items) -> list[PostVerdict]:
        """Judge a batch of joined items ({id, text, gold, extraction})."""


class FixtureBackend(JudgeBackend):
    """Returns pre-recorded verdicts keyed by id (for tests / replay)."""

    def __init__(self, raw_by_id: dict):
        self._raw = raw_by_id

    def judge_batch(self, items) -> list[PostVerdict]:
        return [parse_verdict(self._raw[it["id"]]) for it in items]
