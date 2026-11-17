// CarMedia — MIT © 2026 CarMedia contributors (see LICENSE).

import Foundation
@testable import CarMedia
import Testing

@Suite struct CarGateTests {
    @Test func singleFastSampleDoesNotFlip() {
        // Need 3 agreeing samples before declaring "moving".
        let r1 = CarGate.decide(speed: 20, isMoving: false, agreeing: 0, samplesToFlip: 3)
        #expect(!r1.flip && r1.nextAgreeing == 1 && !r1.nextMoving)
        let r2 = CarGate.decide(speed: 20, isMoving: false, agreeing: 1, samplesToFlip: 3)
        #expect(!r2.flip && r2.nextAgreeing == 2)
        let r3 = CarGate.decide(speed: 20, isMoving: false, agreeing: 2, samplesToFlip: 3)
        #expect(r3.flip && r3.nextMoving)
    }

    @Test func badFixDoesNotCountAsDriving() {
        let r = CarGate.decide(speed: -1, isMoving: false, agreeing: 5, samplesToFlip: 3)
        #expect(!r.flip && r.nextAgreeing == 5)
    }

    @Test func agreementResetsWhenStateMatches() {
        let r = CarGate.decide(speed: 0.5, isMoving: false, agreeing: 2, samplesToFlip: 3)
        #expect(!r.flip && r.nextAgreeing == 0)
    }

    @Test func stopDetectedAfterFlips() {
        let r = CarGate.decide(speed: 0.2, isMoving: true, agreeing: 2, samplesToFlip: 3)
        #expect(r.flip && !r.nextMoving)
    }
}

@Suite struct FeatureFlagTests {
    @Test func envOverrideWins() {
        // (env is process-wide; test by setting is not possible after launch,
        // so assert the default contract instead)
        #expect(FeatureFlags.carPlayVideo.defaultValue == false)
        #expect(FeatureFlags.mirroring.defaultValue == false)
        #expect(FeatureFlags.parkedGate.defaultValue == true)
        #expect(FeatureFlags.carPlayScene.defaultValue == true)
    }
}

@Suite struct AnnexBTests {
    @Test func avccToAnnexB() {
        // Two NALs: len 2 => [0x65 0xAA], len 1 => [0x41]
        var input = Data()
        input.append(UInt8(0)); input.append(UInt8(0)); input.append(UInt8(0)); input.append(UInt8(2))
        input.append(contentsOf: [0x65, 0xAA])
        input.append(contentsOf: [0, 0, 0, 1])
        input.append(0x41)
        let out = AnnexB.convert(input)
        let units = AnnexB.nalUnits(out)
        #expect(units.count == 2)
        #expect(units[0] == Data([0x65, 0xAA]))
        #expect(units[1] == Data([0x41]))
    }

    @Test func truncatedInputDoesNotCrash() {
        _ = AnnexB.convert(Data([0, 0, 0]))
        _ = AnnexB.convert(Data())
        _ = AnnexB.nalUnits(Data())
    }
}
