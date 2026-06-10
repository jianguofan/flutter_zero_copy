## ADDED Requirements

### Requirement: ZeroCopyWidget displays external GPU texture

The system SHALL provide a `ZeroCopyWidget` Flutter widget that displays GPU-rendered content from an external C++ OpenGL process via zero-copy IOSurface texture sharing.

#### Scenario: Widget initialization creates IOSurface and launches renderer
- **WHEN** `ZeroCopyWidget` is inserted into the widget tree with `width`, `height`, `left`, `top` parameters
- **THEN** the system creates an IOSurface of the specified dimensions via the native plugin
- **AND** wraps it in a CVPixelBuffer registered with Flutter TextureRegistry
- **AND** launches the `cube_renderer` child process with the surfaceID as a command-line argument

#### Scenario: Zero-copy texture display
- **WHEN** the C++ child process renders a frame to the shared IOSurface
- **THEN** Flutter's Texture widget displays the rendered content without any pixel data copy between processes
- **AND** the IOSurface GPU VRAM is the single source of truth for both Metal and OpenGL

### Requirement: Configurable widget position and size

The system SHALL allow `ZeroCopyWidget` to be positioned and sized via `width`, `height`, `left`, `top` constructor parameters.

#### Scenario: Widget positioned at specified coordinates
- **WHEN** `ZeroCopyWidget` is created with `left: 100, top: 80`
- **THEN** the Texture widget is rendered at a 100px horizontal and 80px vertical offset from its parent

#### Scenario: Widget sized to specified dimensions
- **WHEN** `ZeroCopyWidget` is created with `width: 800, height: 600`
- **THEN** the IOSurface is allocated at 800×600 pixels
- **AND** the Texture widget occupies 800×600 logical pixels

### Requirement: Flutter overlay compositing

The system SHALL allow Flutter widgets to be rendered on top of the zero-copy texture content.

#### Scenario: Text overlay on 3D content
- **WHEN** a Flutter `Text` widget is placed in the widget tree above `ZeroCopyWidget`
- **THEN** the text is visible on top of the 3D rendered content
- **AND** no visual artifacts occur at the overlay boundary

### Requirement: C++ child process lifecycle

The system SHALL manage the C++ renderer process lifecycle.

#### Scenario: Process started with correct arguments
- **WHEN** `ZeroCopyWidget.initState()` is called
- **THEN** the `cube_renderer` executable is launched via `Process.start`
- **AND** it receives the surfaceID, width, and height as command-line arguments

#### Scenario: Process terminated on widget disposal
- **WHEN** `ZeroCopyWidget.dispose()` is called
- **THEN** the child process is sent SIGTERM
- **AND** the IOSurface is released
- **AND** the texture is unregistered from Flutter TextureRegistry

### Requirement: Frame rate performance

The system SHALL achieve 55+ FPS at 800×600 resolution on Apple Silicon Macs.

#### Scenario: Rendering performance
- **WHEN** the cube renderer is running at 800×600 resolution
- **THEN** the Flutter app maintains 55+ FPS measured by Flutter DevTools
- **AND** Activity Monitor confirms `cube_renderer` runs as an independent process
