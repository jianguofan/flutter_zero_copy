cmake_minimum_required(VERSION 3.16)
project(cube_renderer LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O2")

add_executable(cube_renderer main.cpp)

target_link_libraries(cube_renderer
    "-framework OpenGL"
    "-framework IOSurface"
    "-framework CoreVideo"
    "-framework CoreFoundation"
)
