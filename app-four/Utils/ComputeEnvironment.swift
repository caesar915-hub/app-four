import Foundation
import CoreML

/// Chooses CoreML compute units based on the runtime environment.
///
/// The Apple Neural Engine compiler service (`ANECompilerService`) can't be reached
/// from processes launched through the developer tunnel — Xcode runs *and*
/// `devicectl` launches, with or without a debugger attached. Models that request
/// `.cpuAndNeuralEngine` then fail to compile with
/// "MILCompilerForANE error: ... Couldn't communicate with a helper application",
/// and either hang or fall back to very slow CPU — which is why on-device Whisper
/// timed out even on a plain `devicectl` launch (no debugger, so the old
/// `isDebuggerAttached` heuristic still picked the ANE and transcription hung
/// until the 90 s timeout).
///
/// The GPU (Metal) path needs no such helper, so we use `.cpuAndGPU` for every
/// development-signed build (the ones that launch through the tunnel) and keep the
/// fast `.cpuAndNeuralEngine` path for distribution signing (TestFlight/App Store,
/// launched normally).
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

    /// True when the app carries an embedded provisioning profile, i.e. a
    /// development/ad-hoc build. Those are the builds launched through the
    /// Xcode/devicectl developer tunnel, where the ANE compiler is unreachable;
    /// TestFlight/App Store installs have no embedded profile and launch normally,
    /// so they can use the ANE.
    static var isDevelopmentSigned: Bool {
        Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision") != nil
    }

    /// ANE when available (fast). GPU for development-signed builds (developer
    /// tunnel ⇒ ANE compiler unreachable) or on the Simulator, which has no Neural
    /// Engine at all — an ANE-targeted model there hangs at compile or crawls on
    /// the CPU fallback, stalling transcription on "Transcribing with Whisper…"
    /// indefinitely.
    static var preferredUnits: MLComputeUnits {
        #if targetEnvironment(simulator)
        let units: MLComputeUnits = .cpuAndGPU
        let reason = "simulator (no ANE)"
        #else
        let units: MLComputeUnits = isDevelopmentSigned ? .cpuAndGPU : .cpuAndNeuralEngine
        let reason = "developmentSigned=\(isDevelopmentSigned)"
        #endif
        AppLogger.log("ComputeEnvironment: \(reason) → \(units == .cpuAndGPU ? "cpuAndGPU" : "cpuAndNeuralEngine")")
        return units
    }
}
