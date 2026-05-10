cmake_minimum_required(VERSION 3.20)
project(osx-overlay LANGUAGES Swift)

add_executable(${PROJECT_NAME}
    src/Ansi.swift
    src/Color.swift
    src/Config.swift
    src/DrawCmd.swift
    src/FileWatcher.swift
    src/Gui.swift
    src/IntPair.swift
    src/Line.swift
    src/OverlayCanvas.swift
    src/OverlayWindow.swift
    src/main.swift
)

set_target_properties(${PROJECT_NAME} PROPERTIES
    MACOSX_BUNDLE FALSE
    MACOSX_BUNDLE_GUI_IDENTIFIER "com.example.osx-overlay"
    MACOSX_BUNDLE_BUNDLE_NAME "OSX Overlay"
)
