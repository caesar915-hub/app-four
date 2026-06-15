import Foundation
import CoreML

/// Chooses CoreML compute units based on the runtime environment.
///
/// The Apple Neural Engine compiler service (`ANECompilerService`) can't be reached
/// from a process attached to the Xcode debugger. Models that request
/// `.cpuAndNeuralEngine` then fail to compile with
/// "MILCompilerForANE error: ... Couldn't communicate with a helper application",
/// and either hang or fall back to very slow CPU — which is why on-device Whisper
/// times out when run from Xcode.
///
/// The GPU (Metal) path needs no such helper, so we prefer `.cpuAndGPU` while a
/// debugger is attached and the fast `.cpuAndNeuralEngine` path otherwise
/// (standalone launch, TestFlight, App Store).
enum ComputeEnvironment {

    /// True when this process is being traced by a debugger (e.g. launched from Xcode).
    /// Detected via the `P_TRACED` flag on the process info from `sysctl`.
    static var isDebuggerAttached: Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        guard result == 0 else { return false }
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }

    /// ANE when available (fast). GPU when a debugger is attached (the ANE compiler
    /// is unreachable then) or on the Simulator, which has no Neural Engine at all —
    /// an ANE-targeted model there hangs at compile or crawls on the CPU fallback,
    /// stalling transcription on "Transcribing with Whisper…" indefinitely.
    static var preferredUnits: MLComputeUnits {
        #if targetEnvironment(simulator)
        let units: MLComputeUnits = .cpuAndGPU
        let reason = "simulator (no ANE)"
        #else
        let units: MLComputeUnits = isDebuggerAttached ? .cpuAndGPU : .cpuAndNeuralEngine
        let reason = "debuggerAttached=\(isDebuggerAttached)"
        #endif
        AppLogger.log("ComputeEnvironment: \(reason) → \(units == .cpuAndGPU ? "cpuAndGPU" : "cpuAndNeuralEngine")")
        return units
    }
}
