pragma Singleton
import QtQuick 2.15

QtObject {
    id: ctx

    // 对话记录列表，每项: { role: "user"|"ai", content: string, timestamp: string }
    property var history: [
        { role: "user", content: "帮我找出 6 个月内没有访问过的大视频文件，给清理建议", timestamp: "" },
        { role: "ai", content: "正在扫描文件访问记录…已找到符合条件的文件：符合条件文件 5 个，可释放空间 89.1 GB。建议将 Interstellar.4K.mkv 等 3 个文件移至冷存储，预计节省 81.6 GB。", timestamp: "" },
        { role: "user", content: "好的，帮我执行删除但先预览一下", timestamp: "" },
        { role: "ai", content: "正在执行 dry-run 预览… delete_files(paths=[3 个文件], dry_run=true)", timestamp: "" }
    ]

    function addUserMessage(text) {
        if (!text || text.trim().length === 0) return
        var item = {
            role: "user",
            content: text.trim(),
            timestamp: Qt.formatDateTime(new Date(), "yyyy-MM-dd hh:mm")
        }
        history = history.concat([item])
    }

    function addAiMessage(text) {
        var item = {
            role: "ai",
            content: text || "",
            timestamp: Qt.formatDateTime(new Date(), "yyyy-MM-dd hh:mm")
        }
        history = history.concat([item])
    }

    function addToolExecution(name, status, result) {
        var n = name || ""
        var st = status || ""
        var r = result || ""
        var line = "「" + n + "」" + st + (r.length ? " — " + r : "")
        var item = {
            role: "tool",
            content: line,
            timestamp: Qt.formatDateTime(new Date(), "yyyy-MM-dd hh:mm")
        }
        history = history.concat([item])
    }

    function addConversation(userText, aiText) {
        addUserMessage(userText)
        addAiMessage(aiText)
    }

    function clearHistory() {
        history = []
    }

    function getConversationGroups() {
        // 将连续的 user+ai 分组为一次对话
        var groups = []
        var current = null
        for (var i = 0; i < history.length; i++) {
            var item = history[i]
            if (item.role === "user") {
                current = { user: item.content, ai: "", timestamp: item.timestamp }
                groups.push(current)
            } else if (item.role === "ai" && current) {
                current.ai = item.content
            }
        }
        return groups
    }
}
