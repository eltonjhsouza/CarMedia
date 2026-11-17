// CarMedia — MIT © 2026 CarMedia contributors (see LICENSE).
// Compiled into BOTH the app and the broadcast extension (see project.yml),
// so it is unit-tested from the app's test target.

import Foundation
import UIKit

/// AVCC (length-prefixed NAL units, as produced by VideoToolbox with the
/// default MP4-style packetization) -> Annex-B (4-byte start codes), the
/// equivalent of FFmpeg's h264_mp4toannexb bitstream filter.
public enum AnnexB {
    public static let startCode: [UInt8] = [0, 0, 0, 1]

    public static func convert(_ data: Data, naluLengthSize: Int = 4) -> Data {
        let input = Data(data)   // normalize slice offsets to zero-based
        var out = Data(capacity: input.count + 32)
        var pos = 0
        while pos + naluLengthSize <= input.count {
            var nalLen = 0
            for k in 0..<naluLengthSize {
                nalLen = (nalLen << 8) | Int(input[pos + k])
            }
            let start = pos + naluLengthSize
            let end = min(start + nalLen, input.count)
            guard nalLen > 0, end > start else { break }
            out.append(contentsOf: startCode)
            out.append(input[start..<end])
            pos = end
        }
        return out
    }

    /// Splits an Annex-B stream back into NAL units (used by tests and by
    /// the receiver reference).
    public static func nalUnits(_ annexB: Data) -> [Data] {
        let b = [UInt8](annexB)
        func isStart(_ p: Int) -> Bool {
            p + 2 < b.count && b[p] == 0 && b[p + 1] == 0 &&
                (b[p + 2] == 1 || (p + 3 < b.count && b[p + 2] == 0 && b[p + 3] == 1))
        }
        var units: [Data] = []
        var i = 0
        while i < b.count {
            guard isStart(i) { i += 1; continue }
            var j = i + 3
            if b[i + 2] == 0 { j = i + 4 }        // 4-byte start code
            var k = j
            while k < b.count, !isStart(k) { k += 1 }
            // Skip emulation-prevention zeros kept just before a start code.
            var end = k
            while end > j, b[end - 1] == 0 { end -= 1 }
            if end > j { units.append(Data(b[j..<end])) }
            i = k
        }
        return units
    }
}
