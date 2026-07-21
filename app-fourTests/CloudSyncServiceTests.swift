import Testing
import Foundation
import CloudKit
@testable import app_four

// MARK: - Pure mapping: CKAccountStatus → SyncAccountStatus

@Suite struct SyncAccountStatusMappingTests {
    @Test func mapsEveryCKAccountStatus() {
        #expect(SyncAccountStatus(from: .available) == .available)
        #expect(SyncAccountStatus(from: .noAccount) == .noAccount)
        #expect(SyncAccountStatus(from: .restricted) == .restricted)
        #expect(SyncAccountStatus(from: .temporarilyUnavailable) == .temporarilyUnavailable)
        #expect(SyncAccountStatus(from: .couldNotDetermine) == .couldNotDetermine)
    }
}

// MARK: - Pure mapping: CKError → SyncFailure

@Suite struct SyncFailureMappingTests {
    private func ckError(_ code: CKError.Code, userInfo: [String: Any] = [:]) -> Error {
        NSError(domain: CKErrorDomain, code: code.rawValue, userInfo: userInfo)
    }

    @Test func mapsQuotaExceeded() {
        #expect(SyncFailure(from: ckError(.quotaExceeded)) == .quotaExceeded)
    }

    @Test func mapsNetworkCases() {
        #expect(SyncFailure(from: ckError(.networkUnavailable)) == .network)
        #expect(SyncFailure(from: ckError(.networkFailure)) == .network)
    }

    @Test func mapsNotAuthenticated() {
        #expect(SyncFailure(from: ckError(.notAuthenticated)) == .notAuthenticated)
    }

    @Test func mapsRateLimitedWithRetryAfter() {
        let mapped = SyncFailure(from: ckError(.requestRateLimited, userInfo: [CKErrorRetryAfterKey: 5.0]))
        #expect(mapped == .rateLimited(retryAfterSeconds: 5.0))
    }

    @Test func mapsRateLimitedWithoutRetryAfter() {
        #expect(SyncFailure(from: ckError(.zoneBusy)) == .rateLimited(retryAfterSeconds: nil))
    }

    @Test func mapsUnknownCKErrorToOther() {
        // A CKError code we don't special-case still classifies as .other, not a crash.
        if case .other = SyncFailure(from: ckError(.internalError)) {
            // ok
        } else {
            Issue.record("Expected .other for an unmapped CKError code")
        }
    }

    @Test func mapsNonCKErrorToOther() {
        struct Boom: Error {}
        if case .other = SyncFailure(from: Boom()) {
            // ok — content-free type name only
        } else {
            Issue.record("Expected .other for a non-CKError")
        }
    }
}

// MARK: - Opt-in gating (mock)

@MainActor
@Suite struct CloudSyncOptInGatingTests {
    @Test func isOffByDefault() async {
        let sut = MockCloudSyncService(accountStatus: .available)
        #expect(await sut.isSyncEnabled == false)
    }

    @Test func enablingRequiresAvailableAccount() async {
        let sut = MockCloudSyncService(accountStatus: .noAccount)
        await #expect(throws: SyncFailure.notAuthenticated) {
            try await sut.setSyncEnabled(true)
        }
        #expect(await sut.isSyncEnabled == false)
    }

    @Test func enableThenDisablePersistsFlag() async throws {
        let sut = MockCloudSyncService(accountStatus: .available)
        try await sut.setSyncEnabled(true)
        #expect(await sut.isSyncEnabled == true)
        try await sut.setSyncEnabled(false)
        #expect(await sut.isSyncEnabled == false)
    }

    @Test func removeFromICloudDisablesAndFlagsCall() async throws {
        let sut = MockCloudSyncService(accountStatus: .available, startEnabled: true)
        try await sut.removeFromICloud()
        #expect(sut.removeFromICloudCalled)
        #expect(await sut.isSyncEnabled == false)
    }
}
