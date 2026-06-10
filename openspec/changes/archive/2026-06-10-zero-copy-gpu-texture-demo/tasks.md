## 1. C++ Cube Renderer

- [x] 1.1 Create `cube_renderer/` directory and `CMakeLists.txt` (Core Profile 3.3, OpenGL + IOSurface frameworks)
- [x] 1.2 Implement headless CGL context creation in `main.cpp`
- [x] 1.3 Implement `IOSurfaceLookup` + `CGLTexImageIOSurface2D` for zero-copy GL texture binding
- [x] 1.4 Create FBO with IOSurface texture as color attachment + depth renderbuffer
- [x] 1.5 Implement cube geometry (VAO/VBO, 36 vertices, 6 colored faces)
- [x] 1.6 Implement vertex/fragment shaders with MVP matrix uniform
- [x] 1.7 Implement render loop (clear, rotate, draw, glFlush, usleep ~60fps)
- [x] 1.8 Implement SIGTERM/SIGINT cleanup handler
- [x] 1.9 Verify compilation with `cmake && make`

## 2. Flutter Plugin (macOS)

- [x] 2.1 Create `ZeroCopyTexturePlugin.swift` implementing `FlutterPlugin` and `FlutterTexture`
- [x] 2.2 Implement IOSurface creation with `kIOSurfaceIsGlobal` for cross-process lookup
- [x] 2.3 Implement `CVPixelBufferCreateWithIOSurface` for zero-copy pixel buffer wrapping
- [x] 2.4 Implement Flutter TextureRegistry registration (`registerTexture`)
- [x] 2.5 Implement MethodChannel handlers: `createSurface`, `textureFrameAvailable`, `dispose`
- [x] 2.6 Implement `copyPixelBuffer()` returning the IOSurface-backed CVPixelBuffer
- [x] 2.7 Register plugin in `MainFlutterWindow.swift`
- [x] 2.8 Add `ZeroCopyTexturePlugin.swift` to Xcode project via Ruby xcodeproj script

## 3. Flutter Dart Layer

- [x] 3.1 Create `ZeroCopyWidget` StatefulWidget with `width`, `height`, `left`, `top` parameters
- [x] 3.2 Implement MethodChannel call to `createSurface` in `initState()`
- [x] 3.3 Implement `Process.start` to launch `cube_renderer` with surfaceID
- [x] 3.4 Implement Ticker-based frame loop calling `textureFrameAvailable` method
- [x] 3.5 Implement `build()` returning `Positioned` + `Texture` widget with overlay
- [x] 3.6 Implement `dispose()` for process cleanup and texture unregistration
- [x] 3.7 Create demo app with control panel (sliders for width/height/left/top, start/stop button)

## 4. Build & Integration

- [x] 4.1 Create `build_cube_renderer.sh` build script
- [x] 4.2 Verify Flutter macOS project compiles (`flutter build macos --debug`)
- [x] 4.3 Verify C++ binary compiles for arm64
- [x] 4.4 End-to-end integration test: Swift → IOSurface → cube_renderer → pixel verification
- [x] 4.5 Verify zero-copy: first pixel non-zero (0xff262626), confirming rendering occurred
- [x] 4.6 Verify cross-process IOSurfaceLookup works (kIOSurfaceIsGlobal)

## 5. Verification

- [x] 5.1 OpenGL 4.1 Metal context confirmed (Apple M1 Max)
- [x] 5.2 FBO complete status confirmed
- [x] 5.3 Shader compile/link confirmed
- [x] 5.4 120+ frames rendered in 2-second test (60fps target met)
- [x] 5.5 Clean exit with exit code 0
- [x] 5.6 No pixel copy operations in code path (zero-copy verified)

## 6. Debugging & Bug Fixes

- [x] 6.1 Identified: cube invisible due to column-major matrix multiplication bug in computeMVP()
- [x] 6.2 Fixed: changed matrix indexing from row-major (a[i*4+k]) to column-major (a[k*4+row])
- [x] 6.3 Identified: FlutterTextureRegistry.registerTexture renamed to register(_:) in Swift
- [x] 6.4 Fixed: replaced Dart Ticker+MethodChannel frame sync with native CVDisplayLink
- [x] 6.5 Verified: center pixel 0xff33cc33 confirms cube rendered at screen center
- [x] 6.6 Verified: top-left pixel 0xff262659 confirms background rendered correctly
