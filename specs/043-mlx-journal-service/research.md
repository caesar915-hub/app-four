# Phase 0: Research (043-mlx-journal-service)

## 1. MLX-Swift Integration and Constraints
Apple's MLX framework for machine learning operates natively on Apple Silicon. For `app-four`, we use MLX-Swift (https://github.com/ml-explore/mlx-swift), which provides Swift bindings around the core C++ MLX library.

**Research findings**:
- **C++ Bridging Isolation**: MLX-Swift brings in substantial C++ headers. If imported directly into `app-four`, it drastically affects build times and module boundaries. The optimal approach is to isolate it into a separate Swift Package (`SquirlLLM`).
- **Memory Pressure (`os_proc_available_memory`)**: MLX inference on iOS unified memory devices causes heavy pressure. Before initializing the model weights, we must query the OS using `os_proc_available_memory()`. If available RAM is less than 200 MB, we must safely abort to prevent an OOM crash.
- **HuggingFace Hub**: MLX-Swift includes a downloader integration (`hub-swift`) for fetching weights from the Hugging Face Hub (e.g., `mlx-community/Llama-3.2-1B-Instruct-4bit`). The model downloads once to the app's cache and is reused on subsequent inferences.

## 2. Background Task Lifecycle
Because LLM inference can take 5-15 seconds and users frequently background apps while a task runs, we must properly handle background lifecycle.
- **Research findings**: 
  - `UIApplication.shared.beginBackgroundTask(expirationHandler:)` allows requesting up to ~30 seconds of background execution time.
  - In the expiration handler, we must synchronously flag the MLX-Swift generation task to abort, so that the main app isn't killed. 
  - The pending transcription architecture (via `PendingTranscriptionServiceImpl`) already handles picking up aborted tasks on the next launch, meaning the fallback behavior is natively supported if we abort cleanly.

## 3. Data Validation Strategy
The legacy NLP system (`CueMatcher`) produced highly structured, statically typed results. The new LLM produces raw JSON strings.
- **Research findings**: 
  - JSON output can be partial, malformed, or hallucinate properties.
  - The `UnifiedExtraction` parsing layer will use standard `JSONDecoder`. However, it must cross-reference arrays against the `lexicon.json` schema. For example, if the LLM hallucinates an emotion not in the lexicon, it must be discarded.
  - Partial decoding is crucial: if `medications` array fails to parse due to a syntax error, the parser should discard just that field, but keep `topics`, `mood`, etc. (using a custom `init(from decoder:)` strategy with try? fallback).
