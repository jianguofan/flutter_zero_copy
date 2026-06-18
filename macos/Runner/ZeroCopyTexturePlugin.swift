import Cocoa
import FlutterMacOS
import CoreVideo
import IOSurface

/// Flutter plugin for zero-copy GPU texture sharing via IOSurface.
///
/// Creates an IOSurface → wraps in CVPixelBuffer → registers with Flutter TextureRegistry.
/// A CVDisplayLink drives frame updates at vsync rate (60fps), notifying Flutter
/// to re-sample the texture on every display refresh.
class ZeroCopyTexturePlugin: NSObject, FlutterPlugin, FlutterTexture {

    // MARK: - State

    private var textureRegistry: FlutterTextureRegistry?
    private var textureId: Int64 = 0
    private var surfaceRef: IOSurfaceRef?
    private var pixelBuffer: CVPixelBuffer?
    private var currentSurfaceID: UInt32 = 0
    private var displayLink: CVDisplayLink?

    // MARK: - FlutterPlugin

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.snapmaker.zero_copy/texture",
            binaryMessenger: registrar.messenger
        )
        let instance = ZeroCopyTexturePlugin()
        instance.textureRegistry = registrar.textures
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "createSurface":
            guard let args = call.arguments as? [String: Any],
                  let width = args["width"] as? Int,
                  let height = args["height"] as? Int else {
                result(FlutterError(code: "INVALID_ARGS",
                                    message: "Expected {width: Int, height: Int}",
                                    details: nil))
                return
            }
            if let surfaceInfo = createSurface(width: width, height: height) {
                result(surfaceInfo)
            } else {
                result(FlutterError(code: "CREATE_FAILED",
                                    message: "Failed to create IOSurface",
                                    details: nil))
            }

        case "dispose":
            disposeSurface()
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Surface lifecycle

    private func createSurface(width: Int, height: Int) -> [String: Any]? {
        disposeSurface()

        let bytesPerPixel = 4

        // Use CVPixelBufferCreate to create both the IOSurface backing and the
        // Metal-compatible pixel buffer in one call.  CoreVideo internally
        // configures the IOSurface with proper alignment and properties so that
        // Metal (used by Flutter's texture widget) can create textures from it.
        //
        // kIOSurfaceIsGlobal is included so the engine process can look up the
        // surface by ID via IOSurfaceLookup.
        var cvPixelBufferOut: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey as String: [
                kIOSurfacePixelFormat as String: kCVPixelFormatType_32BGRA,
                kIOSurfaceIsGlobal as String: true,
            ] as [String: Any],
            kCVPixelBufferMetalCompatibilityKey as String: true,
        ]

        let cvRet = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &cvPixelBufferOut
        )

        guard cvRet == kCVReturnSuccess, let cvOut = cvPixelBufferOut else {
            NSLog("[ZeroCopyPlugin] CVPixelBufferCreate failed: %d (w=%d, h=%d)", cvRet, width, height)
            return nil
        }
        pixelBuffer = cvOut

        // Extract the underlying IOSurface from the pixel buffer (zero-copy —
        // the pixel buffer retains it, we just hold an unretained reference).
        guard let surface = CVPixelBufferGetIOSurface(pixelBuffer!) else {
            NSLog("[ZeroCopyPlugin] CVPixelBufferGetIOSurface returned nil")
            pixelBuffer = nil
            return nil
        }
        surfaceRef = surface.takeUnretainedValue()

        let surfaceID = IOSurfaceGetID(surfaceRef!)
        currentSurfaceID = surfaceID
        let actualBPR = IOSurfaceGetBytesPerRow(surfaceRef!)
        NSLog("[ZeroCopyPlugin] Created Metal-compatible IOSurface: id=%u, %dx%d, bpr=%d", surfaceID, width, height, actualBPR)

        // Fill with a bright test color so we can verify texture display immediately
        IOSurfaceLock(surfaceRef!, [], nil)
        let base = IOSurfaceGetBaseAddress(surfaceRef!)
        // Use actual bytes-per-row for row addressing (may be > width*4 due to alignment)
        let actualBPR32 = actualBPR / bytesPerPixel
        let ptr = base.bindMemory(to: UInt32.self, capacity: actualBPR32 * height)
        // Fill row by row to respect stride
        for row in 0..<height {
            let rowStart = row * actualBPR32
            for col in 0..<width {
                ptr[rowStart + col] = 0xFF00FFFF  // BGRA magenta
            }
        }
        IOSurfaceUnlock(surfaceRef!, [], nil)
        NSLog("[ZeroCopyPlugin] Filled IOSurface with test color (magenta)")

        // Register with Flutter TextureRegistry
        textureId = textureRegistry!.register(self)
        NSLog("[ZeroCopyPlugin] Registered texture: id=%lld", textureId)

        // Start CVDisplayLink to drive frame updates at vsync
        startDisplayLink()

        // Immediately notify first frame
        textureRegistry?.textureFrameAvailable(textureId)

        return [
            "surfaceID": Int(surfaceID),
            "textureId": textureId,
            "width": width,
            "height": height,
        ]
    }

    private func disposeSurface() {
        stopDisplayLink()

        if textureId != 0 {
            textureRegistry?.unregisterTexture(textureId)
        }
        textureId = 0
        pixelBuffer = nil
        surfaceRef = nil
        currentSurfaceID = 0
        NSLog("[ZeroCopyPlugin] Surface disposed")
    }

    // MARK: - CVDisplayLink (vsync-driven frame updates)

    private func startDisplayLink() {
        let callback: CVDisplayLinkOutputCallback = { (displayLink, _, _, _, _, ctx) -> CVReturn in
            guard let ctx = ctx else { return kCVReturnError }
            let plugin = Unmanaged<ZeroCopyTexturePlugin>.fromOpaque(ctx).takeUnretainedValue()
            plugin.onDisplayLink()
            return kCVReturnSuccess
        }

        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let link = displayLink else {
            NSLog("[ZeroCopyPlugin] Failed to create CVDisplayLink")
            return
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(link, callback, selfPtr)
        CVDisplayLinkStart(link)
        NSLog("[ZeroCopyPlugin] CVDisplayLink started")
    }

    private func stopDisplayLink() {
        if let link = displayLink {
            CVDisplayLinkStop(link)
            displayLink = nil
            NSLog("[ZeroCopyPlugin] CVDisplayLink stopped")
        }
    }

    private func onDisplayLink() {
        // Notify Flutter on every vsync that new content is available.
        // Even without active rendering, this keeps the Texture widget live.
        if textureId != 0 {
            textureRegistry?.textureFrameAvailable(textureId)
        }
    }

    // MARK: - FlutterTexture

    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        guard let pb = pixelBuffer else {
            NSLog("[ZeroCopyPlugin] copyPixelBuffer: nil!")
            return nil
        }
        return Unmanaged.passRetained(pb)
    }
}
