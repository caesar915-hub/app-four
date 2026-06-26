---
description: Generate a new WORKLOG session block from git/gh and prepend it to docs/WORKLOG.md.
---

Run the worklog generator and prepend the new block into docs/WORKLOG.md (newest-on-top).

```bash
# Split WORKLOG at the first session block (first "## " line), insert new block between the file header and the existing blocks.
HEADER=$(awk '/^## /{exit} {print}' docs/WORKLOG.md)
EXISTING=$(awk '/^## /{found=1} found{print}' docs/WORKLOG.md)
NEW_BLOCK=$(bash scripts/worklog.sh $ARGUMENTS)
printf '%s\n%s\n\n%s\n' "$HEADER" "$NEW_BLOCK" "$EXISTING" > docs/WORKLOG.md
```

After the command runs, show the user the new block that was prepended and confirm the file was updated. If `$ARGUMENTS` is provided, it's passed as the since-ref to `scripts/worklog.sh` (e.g. `main`, a commit hash, or an `a..b` range). With no arguments the script auto-detects the range from the first commit hash in the current top block.
