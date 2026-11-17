// CarMedia Broadcast — MIT © 2026 CarMedia contributors (see LICENSE).
//
// ReplayKit Broadcast Upload Extension — screen-cast PoC (stage 4).
//
// Pipeline (all public APIs, zero files persisted):
//   RPSampleBufferType.video
//     -> VTCompressionSession (H.264)
//     -> AVCC samples converted to Annex-B NAL streams
//     -> TCP (NWConnection) to the LAN test receiver.
//
// Why not AVAssetWriter: it writes files; our rules forbid persisting
// recordings without explicit authorization, and there is no public
// AVAssetWriter sink for sockets. Why not "just AirPlay it": no public API
// exists to push ReplayKit buffers to an AirPlay *video* receiver or to the
// CarPlay screen from an app — see docs/MIRRORING.md. Audio is received but
// intentionally not forwarded yet (sync work; documented limitation).
// Protected (DRM) content arrives as blank frames from ReplayKit — the
// system already blocks it; we cannot and do not try to bypass that.

import Network
import ReplayKit
import VideoToolbox

public final class SampleHandler: RPBroadcastSampleHandler {
    private var connection: NWConnection?
    private var encoder: VTCompressionSession?
    private var frameCount = 0
    private var lastHeartbeat: TimeInterval = 0
    private var readyToSend = false

    private let shared = UserDefaults(suiteName: "group.dev.carmedia.app")

    /// Single active handler; the VT output callback is a C function pointer
    /// so it reaches the instance through this weak ref instead of a refcon.
    private static weak var active: SampleHandler?

    // MARK: - Lifecycle

    override public func broadcastStarted(withPublishingConfiguration publishingConfiguration: RPBroadcastConfiguration,
                                          completionHandler: @escaping (NSError?) -> Void) {
        let host = shared?.string(forKey: "mirror.receiverHost") ?? ""
        let port = shared?.integer(forKey: "mirror.receiverPort") ?? 0
        guard !host.isEmpty, port > 0, port < 65536 else {
            setStatus("error", "defina o receptor no app CarMedia antes de iniciar")
            completionHandler(NSError(domain: "CarMediaBroadcast", code: 1,
                              userInfo: [NSLocalizedDescriptionKey:
                                "Defina IP e porta do receptor no app CarMedia antes de iniciar a transmissão."]))
            return
        }
        setStatus("starting", "conectando à porta \(port)")
        startTCP(host: host, port: port)
        completionHandler(nil)
    }

    override public func broadcastFinished() {
        readyToSend = false
        connection?.cancel()
        connection = nil
        if let encoder {
            VTCompressionSessionCompleteFrames(encoder, untilPresentationTimeStamp: .invalid)
            VTCompressionSessionInvalidate(encoder)
        }
        encoder = nil
        SampleHandler.active = nil
        setStatus("idle", "")
    }

    // MARK: - Samples

    override public func processSampleBuffer(_ sampleBuffer: CMSampleBuffer,
                                             with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video: handleVideo(sampleBuffer)
        case .audioApp, .audioMic: break // not forwarded in this PoC (documented)
        @unknown default: break
        }
    }

    private func handleVideo(_ sampleBuffer: CMSampleBuffer) {
        guard readyToSend, let pixel = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        ensureEncoder(for: pixel)
        guard let encoder else { return }

        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        frameCount += 1
        let now = Date().timeIntervalSince1970
        if now - lastHeartbeat > 1 {
            shared?.set(now, forKey: "mirror.heartbeat")
            shared?.set(frameCount, forKey: "mirror.frames")
            lastHeartbeat = now
        }

        VTCompressionSessionEncodeFrame(
            encoder,
            imageBuffer: pixel,
            presentationTimeStamp: pts,
            duration: .invalid,
            frameProperties: nil,
            sourceFrameRefCon: nil,
            infoFlagsOut: nil
        )
    }

    // MARK: - Encoder

    private func ensureEncoder(for pixel: CVImageBuffer) {
        guard encoder == nil else { return }
        let w = Int32(CVPixelBufferGetWidth(pixel))
        let h = Int32(CVPixelBufferGetHeight(pixel))
        var session: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: w, height: h,
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: [kVTVideoEncoderSpecification_EnableHardwareAcceleratedVideoEncoding: true] as CFDictionary,
            imageBufferAttributes: nil,
            compressedVideoOutputAttributes: nil,
            outputCallback: SampleHandler.compressedOutput,
            sourceFrameRefCon: nil,
            compressionSessionOut: &session
        )
        guard status == noErr, let session else {
            setStatus("error", "encoder indisponível (\(status))")
            return
        }
        VTCompressionSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate,
                                        value: NSNumber(value: 2_000_000))
        VTCompressionSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyframeInterval,
                                        value: NSNumber(value: 2.0))
        VTCompressionSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowTemporalCompression,
                                        value: kCFBooleanFalse)
        VTCompressionSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate,
                                        value: NSNumber(value: 30))
        encoder = session
        VTCompressionSessionPrepareToEncodeFrames(session)
    }

    private static let compressedOutput: VTCompressionOutputCallback = { _, _, status, _, sampleBuffer in
        guard status == noErr, let sampleBuffer else { return }
        SampleHandler.active?.receiveEncoded(sampleBuffer)
    }

    // MARK: - Encoded sample -> Annex-B -> TCP

    fileprivate func receiveEncoded(_ sampleBuffer: CMSampleBuffer) {
        guard readyToSend, let connection, connection.state == .ready,
              let block = CMSampleBufferGetDataBuffer(sampleBuffer),
              let format = CMSampleBufferGetFormatDescription(sampleBuffer)
        else { return }

        var out = Data()
        if isKeyframe(sampleBuffer) {
            // Prepend SPS + PPS in-band so the receiver can decode without
            // out-of-band parameter sets.
            for i in 0...1 {
                var ptr: UnsafePointer<UInt8>?
                var len: CFIndex = 0
                var complete: Int8 = 0
                var nalLength: CFIndex = 0
                let st = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
                    format, parameterSetIndex: i,
                    parameterSetPointerOut: &ptr, parameterSetSizeOut: &len,
                    parameterSetCompleteOut: &complete, nalLengthSizeOut: &nalLength)
                if st == noErr, let ptr {
                    out.append(contentsOf: [0, 0, 0, 1])
                    out.append(contentsOf: UnsafeBufferPointer(start: ptr, count: len))
                }
            }
        }

        var offsetLen = 0
        var totalLen = 0
        var pointer: UnsafeMutablePointer<Int8>?
        let st = CMBlockBufferGetDataPointer(block, atOffset: 0, lengthAtOffsetOut: &offsetLen,
                                             totalLengthOut: &totalLen, dataPointerOut: &pointer)
        guard st == noErr, totalLen > 0, let pointer else { return }
        let avcc = Data(bytes: pointer, count: totalLen)
        out.append(AnnexB.convert(avcc))

        connection.send(content: out, completion: .contentProcessed { [weak self] err in
            if let err { self?.setStatus("error", "tcp: \(err.localizedDescription)") }
        })
    }

    private func isKeyframe(_ sb: CMSampleBuffer) -> Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sb, createIfNecessary: false)
                as? [[String: Any]],
              let first = attachments.first,
              let notSync = first[kCMSampleAttachmentKey_NotSync as String] as? Bool
        else { return true }
        return !notSync
    }

    /// AVCC -> Annex-B lives in CarMedia/Core/AnnexB.swift (shared file,
    /// unit-tested from the app target).
    // MARK: - TCP

    private func startTCP(host: String, port: Int) {
        SampleHandler.active = self
        guard let p = NWEndpoint.Port(rawValue: UInt16(port)) else {
            setStatus("error", "porta inválida"); return
        }
        let conn = NWConnection(host: NWEndpoint.Host(host), port: p, using: .tcp)
        conn.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.readyToSend = true
                self?.setStatus("streaming", "conectado")
            case .waiting:
                self?.setStatus("starting", "aguardando receptor")
            case .failed(let e):
                self?.readyToSend = false
                self?.setStatus("error", "tcp: \(e.localizedDescription)")
            case .cancelled:
                self?.readyToSend = false
            default:
                break
            }
        }
        conn.start(queue: .main)
        connection = conn
    }

    private func setStatus(_ s: String, _ detail: String) {
        shared?.set(s, forKey: "mirror.status")
        shared?.set(detail, forKey: "mirror.statusDetail")
    }
}
