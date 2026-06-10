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
        let bytesPerRow = width * bytesPerPixel

        let props: [String: Any] = [
            kIOSurfaceWidth as String: width,
            kIOSurfaceHeight as String: height,
            kIOSurfaceBytesPerElement as String: bytesPerPixel,
            kIOSurfaceBytesPerRow as String: bytesPerRow,
            kIOSurfacePixelFormat as String: kCVPixelFormatType_32BGRA,
            kIOSurfaceIsGlobal as String: true,
        ]

        guard let surface = IOSurfaceCreate(props as CFDictionary) else {
            NSLog("[ZeroCopyPlugin] IOSurfaceCreate failed")
            return nil
        }
        surfaceRef = surface

        let surfaceID = IOSurfaceGetID(surface)
        currentSurfaceID = surfaceID
        NSLog("[ZeroCopyPlugin] Created IOSurface: id=%u, %dx%d", surfaceID, width, height)

        // Fill with a bright test color so we can verify texture display immediately
        IOSurfaceLock(surface, [], nil)
        let base = IOSurfaceGetBaseAddress(surface)
        let totalPixels = width * height
        let ptr = base.bindMemory(to: UInt32.self, capacity: totalPixels)
        for i in 0..<totalPixels {
            ptr[i] = 0xFF00FFFF  // BGRA magenta
        }
        IOSurfaceUnlock(surface, [], nil)
        NSLog("[ZeroCopyPlugin] Filled IOSurface with test color (magenta)")

        // Create CVPixelBuffer backed by IOSurface (zero-copy)
        var cvPixelBufferOut: Unmanaged<CVPixelBuffer>?
        let cvRet = CVPixelBufferCreateWithIOSurface(
            kCFAllocatorDefault,
            surface,
            nil,
            &cvPixelBufferOut
        )

        guard cvRet == kCVReturnSuccess, let cvOut = cvPixelBufferOut else {
            NSLog("[ZeroCopyPlugin] CVPixelBufferCreateWithIOSurface failed: %d", cvRet)
            return nil
        }
        pixelBuffer = cvOut.takeRetainedValue()
        NSLog("[ZeroCopyPlugin] CVPixelBuffer created: %dx%d", width, height)

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
