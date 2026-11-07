cmake_minimum_required(VERSION 3.18)
project(face_ncnn)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Prefer prebuilt NCNN via NCNN_DIR, else FetchContent
set(NCNN_DIR "" CACHE PATH "Path to ncnn install (lib/cmake/ncnn)")

if(NCNN_DIR)
  list(APPEND CMAKE_PREFIX_PATH ${NCNN_DIR})
  find_package(ncnn REQUIRED)
else()
  include(FetchContent)
  FetchContent_Declare(
    ncnn
    GIT_REPOSITORY https://github.com/Tencent/ncnn.git
    GIT_TAG 20250916
    GIT_SHALLOW TRUE
  )
  set(NCNN_BUILD_TOOLS OFF CACHE BOOL "" FORCE)
  set(NCNN_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
  set(NCNN_BUILD_BENCHMARK OFF CACHE BOOL "" FORCE)
  set(NCNN_BUILD_TESTS OFF CACHE BOOL "" FORCE)
  set(NCNN_VULKAN OFF CACHE BOOL "" FORCE)
  set(NCNN_SHARED_LIB ON CACHE BOOL "" FORCE)
  FetchContent_MakeAvailable(ncnn)
endif()

add_library(face_ncnn SHARED
  src/face_engine.cpp
)
target_include_directories(face_ncnn PUBLIC include)
target_link_libraries(face_ncnn PUBLIC ncnn)

if(ANDROID)
  target_link_libraries(face_ncnn PUBLIC log android)
endif()
