cmake_minimum_required(VERSION 3.20)
project(osx-overlay LANGUAGES Swift)

add_executable(${PROJECT_NAME}
    src/main.swift
    src/Color.swift
)

set_target_properties(${PROJECT_NAME} PROPERTIES
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_GUI_IDENTIFIER "com.example.osx-overlay"
    MACOSX_BUNDLE_BUNDLE_NAME "OSX Overlay"
)
