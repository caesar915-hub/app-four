#!/usr/bin/env bash
# sync-tuning.sh — Syncs on-device journal MLX tuning payload from macOS harness to iOS repo.
#
# Usage:
#   ./scripts/sync-tuning.sh [MACOS_REPO_PATH]
#   ./scripts/sync-tuning.sh --check [MACOS_REPO_PATH]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"

CHECK_MODE=0
MACOS_REPO="/Users/caesargrey/Projects/app-four-macos"

for arg in "$@"; do
    if [[ "$arg" == "--check" ]]; then
        CHECK_MODE=1
    elif [[ "$arg" != -* ]]; then
        MACOS_REPO="$arg"
    fi
done

if [[ ! -d "$MACOS_REPO" ]]; then
    echo "Error: macOS tuning repository not found at '$MACOS_REPO'" >&2
    exit 1
fi

MACOS_SRC_DIR="$MACOS_REPO/Sources/SquirlJournal"
if [[ ! -d "$MACOS_SRC_DIR" ]]; then
    echo "Error: SquirlJournal source directory not found at '$MACOS_SRC_DIR'" >&2
    exit 1
fi

# Exact 10-file mapping: macOS relative path -> iOS relative path
FILE_PAIRS=(
    "Resources/Prompts.yaml:app-four/Resources/Prompts.yaml"
    "Resources/lexicon.json:app-four/Resources/lexicon.json"
    "PromptLoader.swift:app-four/Services/PromptLoader.swift"
    "SummaryPromptBuilder.swift:app-four/Services/SummaryPromptBuilder.swift"
    "SignalPromptBuilder.swift:app-four/Services/SignalPromptBuilder.swift"
    "NoteExtraction/ExtractionValidator.swift:app-four/Services/NoteExtraction/ExtractionValidator.swift"
    "NoteExtraction/UnifiedExtraction.swift:app-four/Services/NoteExtraction/UnifiedExtraction.swift"
    "NoteExtraction/Lexicon.swift:app-four/Services/NoteExtraction/Lexicon.swift"
    "NoteExtraction/LexiconData.swift:app-four/Services/NoteExtraction/LexiconData.swift"
    "NoteExtraction/NoteExtraction.swift:app-four/Services/NoteExtraction/NoteExtraction.swift"
)

apply_adaptations() {
    local target_file="$1"
    local base_name
    base_name="$(basename "$target_file")"

    case "$base_name" in
        "PromptLoader.swift")
            sed -i '' 's/Bundle\.module\.url(/Bundle.main.url(/g' "$target_file"
            sed -i '' 's/print("PromptLoader warning:/AppLogger.log("PromptLoader warning:/g' "$target_file"
            sed -i '' 's/prints warning/logs a warning/g' "$target_file"
            sed -i '' 's/prints a warning/logs a warning/g' "$target_file"
            ;;
        "LexiconData.swift")
            sed -i '' 's/Bundle\.module\.url(/Bundle.main.url(/g' "$target_file"
            ;;
        "ExtractionValidator.swift")
            sed -i '' 's/print("ExtractionValidator:/AppLogger.log("ExtractionValidator:/g' "$target_file"
            ;;
        "NoteExtraction.swift")
            sed -i '' '/^import SquirlSignals$/d' "$target_file"
            ;;
    esac
}

if [[ "$CHECK_MODE" -eq 1 ]]; then
    echo "Running tuning parity check (macOS -> iOS)..."
    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TMP_DIR"' EXIT

    DRIFT_COUNT=0
    for pair in "${FILE_PAIRS[@]}"; do
        src_rel="${pair%%:*}"
        dst_rel="${pair##*:}"

        src_full="$MACOS_SRC_DIR/$src_rel"
        dst_full="$IOS_REPO/$dst_rel"

        if [[ ! -f "$src_full" ]]; then
            echo "❌ Missing source file on macOS: $src_rel" >&2
            DRIFT_COUNT=$((DRIFT_COUNT + 1))
            continue
        fi

        if [[ ! -f "$dst_full" ]]; then
            echo "❌ Missing destination file on iOS: $dst_rel" >&2
            DRIFT_COUNT=$((DRIFT_COUNT + 1))
            continue
        fi

        tmp_file="$TMP_DIR/$(basename "$src_rel")"
        cp "$src_full" "$tmp_file"
        apply_adaptations "$tmp_file"

        if ! diff -u "$tmp_file" "$dst_full" > /dev/null 2>&1; then
            echo "❌ Parity drift detected in $dst_rel:" >&2
            diff -u "$tmp_file" "$dst_full" >&2 || true
            DRIFT_COUNT=$((DRIFT_COUNT + 1))
        else
            echo "  ✓ $dst_rel in sync"
        fi
    done

    if [[ "$DRIFT_COUNT" -gt 0 ]]; then
        echo "" >&2
        echo "Tuning parity check FAILED with $DRIFT_COUNT drifted file(s)." >&2
        exit 1
    fi

    VERSION_STAMP="$(grep '^# tuning-version:' "$IOS_REPO/app-four/Resources/Prompts.yaml" || echo "unknown")"
    echo ""
    echo "✅ Parity check PASSED. All 10 tuning files match ($VERSION_STAMP)."
    exit 0
fi

echo "═══════════════════════════════════════════════════════════════════════"
echo "Syncing MLX Journal Tuning Payload: macOS -> iOS"
echo "Source: $MACOS_SRC_DIR"
echo "Destination: $IOS_REPO"
echo "═══════════════════════════════════════════════════════════════════════"

SYNCED_COUNT=0
for pair in "${FILE_PAIRS[@]}"; do
    src_rel="${pair%%:*}"
    dst_rel="${pair##*:}"

    src_full="$MACOS_SRC_DIR/$src_rel"
    dst_full="$IOS_REPO/$dst_rel"

    if [[ ! -f "$src_full" ]]; then
        echo "Error: Source file does not exist: $src_full" >&2
        exit 1
    fi

    mkdir -p "$(dirname "$dst_full")"
    cp "$src_full" "$dst_full"
    apply_adaptations "$dst_full"

    echo "  → [SYNCED] $src_rel -> $dst_rel"
    SYNCED_COUNT=$((SYNCED_COUNT + 1))
done

VERSION_STAMP="$(grep '^# tuning-version:' "$IOS_REPO/app-four/Resources/Prompts.yaml" || echo "unknown")"
echo "═══════════════════════════════════════════════════════════════════════"
echo "Sync complete: $SYNCED_COUNT files synced."
echo "Active Version: $VERSION_STAMP"
echo "═══════════════════════════════════════════════════════════════════════"
