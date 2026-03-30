cmake_minimum_required(VERSION 3.16)
project(FileSearch LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_AUTOMOC ON)

# Qt 安装目录
set(CMAKE_PREFIX_PATH "/home/mobtgzhang/Qt/6.10.2/gcc_64" CACHE PATH "Qt installation path")

find_package(Qt6 REQUIRED COMPONENTS
    Core
    Gui
    Quick
    QuickControls2
    Qml
    WebEngineQuick
    WebChannel
    QuickDialogs2
    Concurrent
    Network
)

# 源文件
set(SOURCES
    src/main.cpp
    src/AppSettings.cpp
    src/PathProvider.cpp
    src/StatusContext.cpp
    src/engine/SearchEngine.cpp
    src/engine/IndexEngine.cpp
    src/engine/ScanEngine.cpp
    src/engine/ScanWorker.cpp
    src/engine/DuplicateEngine.cpp
    src/engine/DuplicateWorker.cpp
    src/engine/CleanupEngine.cpp
    src/engine/CleanupWorker.cpp
    src/model/FileItemModel.cpp
    src/agent/AIBridge.cpp
    src/agent/ChatBridge.cpp
    src/agent/ToolExecutor.cpp
    src/agent/ContextBuilder.cpp
    src/agent/tools/SearchFilesTool.cpp
    src/agent/tools/DeleteFilesTool.cpp
    src/agent/tools/MoveFilesTool.cpp
    src/agent/tools/ShellTool.cpp
    src/agent/tools/ReadFileTool.cpp
    src/agent/tools/WriteFileTool.cpp
    src/agent/tools/WebFetchTool.cpp
    src/agent/AgentOrchestrator.cpp
    src/agent/AgentSandbox.cpp
    src/agent/CacheManager.cpp
    src/agent/PromptLoader.cpp
    src/agent/PromptFallbacks.cpp
    src/service/FileOperationService.cpp
)

add_executable(FileSearch ${SOURCES}
    src/AppSettings.h
    src/PathProvider.h
    src/StatusContext.h
    src/model/FileItemModel.h
    src/model/UnifiedFileRecord.h
    src/engine/SearchEngine.h
    src/engine/IndexEngine.h
    src/engine/ScanEngine.h
    src/engine/ScanWorker.h
    src/engine/DuplicateEngine.h
    src/engine/DuplicateWorker.h
    src/engine/CleanupEngine.h
    src/engine/CleanupWorker.h
    src/agent/AIBridge.h
    src/agent/ChatBridge.h
    src/agent/ToolExecutor.h
    src/agent/ContextBuilder.h
    src/agent/AgentOrchestrator.h
    src/agent/AgentSandbox.h
    src/agent/CacheManager.h
    src/agent/PromptLoader.h
    src/agent/PromptFallbacks.h
    src/service/FileOperationService.h
)

target_include_directories(FileSearch PRIVATE
    ${CMAKE_SOURCE_DIR}
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/src/engine
    ${CMAKE_SOURCE_DIR}/src/model
    ${CMAKE_SOURCE_DIR}/src/agent
    ${CMAKE_SOURCE_DIR}/src/agent/tools
    ${CMAKE_SOURCE_DIR}/src/service
)

add_custom_command(TARGET FileSearch POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        ${CMAKE_SOURCE_DIR}/src/agent/prompts
        $<TARGET_FILE_DIR:FileSearch>/prompts
    COMMENT "Copying agent prompts beside executable"
)

target_link_libraries(FileSearch PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Qml
    Qt6::WebEngineQuick
    Qt6::WebChannel
    Qt6::QuickDialogs2
    Qt6::Concurrent
    Qt6::Network
)
