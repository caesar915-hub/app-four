---
description: Regenerate the WORKLOG.md top block from git/gh primary sources. Replaces the current top block if it exists; otherwise prepends a new one.
---

Regenerate `docs/WORKLOG.md` by running the generator and replacing the top session block
(the first `## YYYY-MM-DD` block) with a freshly derived one. Use this after any merge or
PR action to keep the worklog current. Accepts an optional since-ref argument.

```bash
# Generate fresh block
NEW_BLOCK=$(bash scripts/worklog.sh $ARGUMENTS)

# Separate the file into: invariant header | top block | rest of blocks
HEADER=$(awk '/^## /{exit} {print}' docs/WORKLOG.md)
# Drop the current top block (everything from first ## to second ##, exclusive)
REST=$(awk 'BEGIN{found=0; count=0} /^## /{count++; if(count==2){found=1}} found{print}' docs/WORKLOG.md)

printf '%s\n%s\n\n%s\n' "$HEADER" "$NEW_BLOCK" "$REST" > docs/WORKLOG.md
```

After running, show the user:
1. The new top block that was written
2. One line noting what changed vs the previous top block (if anything — e.g. "added 3 commits, 2 PRs updated")

If `$ARGUMENTS` is provided, pass it as the since-ref to `scripts/worklog.sh`.
With no arguments the script auto-detects the range from the first commit hash in the current top block.
