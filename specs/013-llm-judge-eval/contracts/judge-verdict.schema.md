# Contract: Judge structured-output verdict

The judge MUST return JSON conforming to this schema (enforced via Anthropic `output_config.format` / pydantic). One call judges one post — all four signals + all four richer fields. `reason` precedes the verdict in the emitted object order (FR-003).

```json
{
  "type": "object",
  "additionalProperties": false,
  "required": ["id", "signals", "fields"],
  "properties": {
    "id": { "type": "string" },
    "signals": {
      "type": "object",
      "additionalProperties": false,
      "required": ["mood", "energy", "focus", "sleep"],
      "properties": {
        "mood":   { "$ref": "#/$defs/signalVerdict" },
        "energy": { "$ref": "#/$defs/signalVerdict" },
        "focus":  { "$ref": "#/$defs/signalVerdict" },
        "sleep":  { "$ref": "#/$defs/signalVerdict" }
      }
    },
    "fields": {
      "type": "object",
      "additionalProperties": false,
      "required": ["feelings", "activities", "sleep", "sideEffect"],
      "properties": {
        "feelings":   { "$ref": "#/$defs/fieldVerdict" },
        "activities": { "$ref": "#/$defs/fieldVerdict" },
        "sleep":      { "$ref": "#/$defs/fieldVerdict" },
        "sideEffect": { "$ref": "#/$defs/fieldVerdict" }
      }
    }
  },
  "$defs": {
    "signalVerdict": {
      "type": "object",
      "additionalProperties": false,
      "required": ["reason", "label", "partial"],
      "properties": {
        "reason":  { "type": "string", "minLength": 1 },
        "label":   { "type": "string", "enum": ["TP", "FP", "FN", "TN"] },
        "partial": { "type": "boolean" }
      }
    },
    "fieldVerdict": {
      "type": "object",
      "additionalProperties": false,
      "required": ["reason", "correct_items", "spurious_items", "missed_items"],
      "properties": {
        "reason":         { "type": "string", "minLength": 1 },
        "correct_items":  { "type": "array", "items": { "type": "string" } },
        "spurious_items": { "type": "array", "items": { "type": "string" } },
        "missed_items":   { "type": "array", "items": { "type": "string" } }
      }
    }
  }
}
```

**Prompt contract** (inputs the judge receives): `clean_text`, the extractor's per-signal values, and the extractor's richer-field item lists. The judge is instructed adversarially (assume over-extraction) and applies the 7 span-level exclusion criteria; a signal is TP/FN only under first-person-present attribution (FR-002, FR-009).

**Failure handling**: a response that fails this schema is retried once, then quarantined (R6 / FR-014). Results are matched to posts by `id`, never by position (FR-014).
