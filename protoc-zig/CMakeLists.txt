project(zigpb CXX)

cmake_minimum_required(VERSION 3.10)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra -Wpedantic")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(PkgConfig REQUIRED)
pkg_check_modules(PROTOBUF REQUIRED protobuf)

set(SOURCES src/main.cpp src/formatter.cpp src/codeGenerator.cpp)
add_executable(${CMAKE_PROJECT_NAME} ${SOURCES})

target_link_libraries(${CMAKE_PROJECT_NAME} ${PROTOBUF_STATIC_LIBRARIES} protoc)

target_include_directories(${CMAKE_PROJECT_NAME} PUBLIC ${PROTOBUF_INCLUDE_DIRS})
target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE "inc")

