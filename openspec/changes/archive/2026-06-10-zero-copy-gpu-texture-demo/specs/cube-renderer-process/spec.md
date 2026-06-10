## ADDED Requirements

### Requirement: Headless OpenGL rendering context

The C++ renderer SHALL create a headless OpenGL Core Profile 3.3 context without a window.

#### Scenario: Context creation
- **WHEN** `cube_renderer` starts with a valid surfaceID
- **THEN** a CGL context is created with `CGLCreateContext(pix, NULL, &ctx)`
- **AND** the context supports OpenGL 3.2 Core or higher
- **AND** hardware acceleration is used (not software rendering)

### Requirement: IOSurface binding to OpenGL texture

The C++ renderer SHALL bind the shared IOSurface to an OpenGL texture via `CGLTexImageIOSurface2D`.

#### Scenario: Surface lookup and binding
- **WHEN** `cube_renderer` receives a valid surfaceID
- **THEN** `IOSurfaceLookup(surfaceID)` returns the shared IOSurface
- **AND** `CGLTexImageIOSurface2D` binds it to a GL texture without copying data
- **AND** an FBO is created with the IOSurface texture as color attachment 0

#### Scenario: Invalid surface ID
- **WHEN** `cube_renderer` receives a non-existent surfaceID
- **THEN** the process exits with a non-zero exit code
- **AND** an error message is written to stderr

### Requirement: Rotating cube rendering

The C++ renderer SHALL render a rotating colored cube at approximately 60fps.

#### Scenario: Cube geometry and coloring
- **WHEN** the render loop is active
- **THEN** a cube with 6 distinctly colored faces is rendered (red, green, blue, yellow, cyan, magenta)
- **AND** each face is composed of 2 triangles (12 triangles total, 36 vertices)

#### Scenario: Rotation animation
- **WHEN** each frame is rendered
- **THEN** the cube rotates around the Y-axis
- **AND** a perspective projection matrix (45° FOV) is applied
- **AND** the camera is positioned at (0, 0, 3) looking at the origin

#### Scenario: Frame timing
- **WHEN** the render loop is active
- **THEN** `usleep(16667)` provides approximately 60 frames per second
- **AND** `glFlush()` is called after each frame to update the IOSurface

### Requirement: Clean shutdown

The C++ renderer SHALL clean up all OpenGL resources on termination.

#### Scenario: SIGTERM handling
- **WHEN** the process receives SIGTERM or SIGINT
- **THEN** the render loop exits gracefully
- **AND** the FBO, texture, renderbuffer, VAO, VBO, and shader program are deleted
- **AND** the IOSurface reference is released
- **AND** the CGL context is destroyed
