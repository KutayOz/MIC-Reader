# CMakeLists.txt for native OpenCV integration

cmake_minimum_required(VERSION 3.18.1)

project("native_opencv")

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find OpenCV
# OpenCV should be extracted to android/app/src/main/cpp/opencv
set(OpenCV_DIR ${CMAKE_SOURCE_DIR}/opencv/sdk/native/jni)
find_package(OpenCV REQUIRED)

message(STATUS "OpenCV found: ${OpenCV_VERSION}")
message(STATUS "OpenCV include dirs: ${OpenCV_INCLUDE_DIRS}")
message(STATUS "OpenCV libs: ${OpenCV_LIBS}")

# Create shared library
add_library(
    native_opencv
    SHARED
    native_opencv.cpp
)

# Include OpenCV headers
target_include_directories(native_opencv PRIVATE ${OpenCV_INCLUDE_DIRS})

# Link OpenCV libraries
target_link_libraries(
    native_opencv
    ${OpenCV_LIBS}
    log
)
