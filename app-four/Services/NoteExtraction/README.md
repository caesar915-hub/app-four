# NoteExtraction (from nl-calssifier)

These files are copied from the standalone `nl-calssifier` Swift package:
`/Users/caesargrey/Projects/nl-calssifier`

**Integration note:** To consume this as a proper SPM dependency instead of inline sources:
1. Delete this folder (`Services/NoteExtraction/`)
2. In Xcode, add a package dependency:
   - Local path: `../nl-calssifier` (during development)
   - Or GitHub URL: `https://github.com/caesar915-hub/nl-calssifier` (after push)
3. Link the `NoteExtraction` product to the `app-four` target.
4. Add `import NoteExtraction` to `NLSummarizationService.swift`.
