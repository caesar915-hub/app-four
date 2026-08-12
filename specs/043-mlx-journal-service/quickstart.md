# Quickstart: 043-mlx-journal-service

To get started with the `043-mlx-journal-service` feature in development:

## 1. Local Package Setup
The `SquirlLLM` package will be located at `packages/SquirlLLM`. 
When running the main `app-four` target in Xcode, you must ensure that this local Swift Package is linked in the `app-four` target's Frameworks, Libraries, and Embedded Content.

## 2. Model Download
The Llama 3.2 1B (4-bit) model is downloaded from Hugging Face on the first run. For development, you may want to pre-download the model to avoid waiting on every clean build. MLX-Swift caches the model in the app's standard Cache directory.

## 3. Simulating Low Memory
To test the `os_proc_available_memory() < 200MB` fallback, you can either:
- Use an older device (e.g., iPhone 12 Pro) and open several memory-heavy apps.
- Temporarily mock the `MemoryMonitor` to return `< 200MB` in development to ensure the UI alert and graceful fallback works without crashing.

## 4. Background Task Expiration
To test the background task expiration handler:
1. Start an extraction in the app.
2. Immediately background the app.
3. In Xcode, simulate a background task expiration (Debug > Simulate Background Fetch or by using Instruments). 
4. Ensure the UI shows "Processing..." and the extraction correctly resumes/retries on the next launch.
