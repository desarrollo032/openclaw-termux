cmake_minimum_required(VERSION 3.22.1)

project(openclaw_pty VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(openclaw_pty SHARED
    openclaw_pty.cpp
    openclaw_pty.h
)

find_library(log-lib log)

target_link_libraries(openclaw_pty
    ${log-lib}
    android
)

target_include_directories(openclaw_pty PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
