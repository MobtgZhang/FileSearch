pragma Singleton
import QtQuick 2.15

QtObject {
    id: theme

    // 从 appSettings 读取主题（context property 注入）
    property string _mode: (typeof appSettings !== "undefined" && appSettings) ? appSettings.themeMode : "dark"

    // Dark 模式色彩（参考 ai-file-manager-ui.html）
    readonly property color _darkBg:       "#0a0c10"
    readonly property color _darkSurface:  "#10141c"
    readonly property color _darkPanel:     "#141820"
    readonly property color _darkBorder:   "#1e2430"
    readonly property color _darkAccent:   "#4af0b4"
    readonly property color _darkAccent2:  "#7b6ff0"
    readonly property color _darkAccent3:  "#f07b6f"
    readonly property color _darkAccent4:  "#f0c46f"
    readonly property color _darkText:     "#c8d4e8"
    readonly property color _darkMuted:    "#4a5568"
    readonly property color _darkBright:   "#e8f0ff"

    // Light 模式色彩
    readonly property color _lightBg:       "#f5f6f8"
    readonly property color _lightSurface:   "#ffffff"
    readonly property color _lightPanel:    "#eef0f4"
    readonly property color _lightBorder:   "#d1d5db"
    readonly property color _lightAccent:   "#0d9488"
    readonly property color _lightAccent2:  "#6366f1"
    readonly property color _lightAccent3:  "#dc2626"
    readonly property color _lightAccent4:  "#d97706"
    readonly property color _lightText:     "#374151"
    readonly property color _lightMuted:    "#6b7280"
    readonly property color _lightBright:   "#111827"

    // 动态色彩（根据主题切换）
    readonly property color bg:       _mode === "light" ? _lightBg : _darkBg
    readonly property color surface:  _mode === "light" ? _lightSurface : _darkSurface
    readonly property color panel:    _mode === "light" ? _lightPanel : _darkPanel
    readonly property color border:   _mode === "light" ? _lightBorder : _darkBorder
    readonly property color accent:   _mode === "light" ? _lightAccent : _darkAccent
    readonly property color accent2:  _mode === "light" ? _lightAccent2 : _darkAccent2
    readonly property color accent3:  _mode === "light" ? _lightAccent3 : _darkAccent3
    readonly property color accent4:  _mode === "light" ? _lightAccent4 : _darkAccent4
    readonly property color text:     _mode === "light" ? _lightText : _darkText
    readonly property color muted:    _mode === "light" ? _lightMuted : _darkMuted
    readonly property color bright:   _mode === "light" ? _lightBright : _darkBright

    // 字体
    readonly property string fontFamily: "JetBrains Mono, Consolas, monospace"
    readonly property string fontDisplay: "Syne, Segoe UI, sans-serif"

    // 尺寸
    readonly property int titleBarHeight: 38
    readonly property int searchBarHeight: 60
    readonly property int sidebarWidth: 48
    readonly property int vizPanelWidth: 320
    readonly property int aiPanelWidth: 280
    readonly property int statusBarHeight: 40
    readonly property int actionBarHeight: 44
    readonly property int fileRowHeight: 32
    readonly property int colHeaderHeight: 32

}
