cmake_minimum_required(VERSION 3.20)
project(osx-overlay LANGUAGES CXX Swift)

add_executable(${PROJECT_NAME}
    src/main.swift
    src/Color.cpp
)

target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_compile_options(${PROJECT_NAME} PRIVATE
    $<$<COMPILE_LANGUAGE:CXX>:-Wall -Wextra -Werror>
    $<$<COMPILE_LANGUAGE:Swift>:-warnings-as-errors>
)

set_target_properties(${PROJECT_NAME} PROPERTIES
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_GUI_IDENTIFIER "com.example.osx-overlay"
    MACOSX_BUNDLE_BUNDLE_NAME "OSX Overlay"
)
