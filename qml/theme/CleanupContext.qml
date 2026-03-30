pragma Singleton
import QtQuick 2.15

QtObject {
    id: ctx

    property bool isScanning: false
    property int elapsedMs: 0
    property int totalFiles: 0
    property real totalSize: 0

    // 分类数据: [{ id, name, files: [...], size, selected }]
    property var categories: []

    function formatSize(bytes) {
        var b = Number(bytes) || 0
        if (b >= 1024 * 1024 * 1024 * 1024)
            return (b / (1024 * 1024 * 1024 * 1024)).toFixed(1) + " TB"
        if (b >= 1024 * 1024 * 1024)
            return (b / (1024 * 1024 * 1024)).toFixed(1) + " GB"
        if (b >= 1024 * 1024)
            return (b / (1024 * 1024)).toFixed(1) + " MB"
        if (b >= 1024)
            return (b / 1024).toFixed(1) + " KB"
        return Math.round(b) + " B"
    }

    function updateCategory(categoryId, name, files, totalSize) {
        var list = categories.slice()
        var found = -1
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === categoryId) {
                found = i
                break
            }
        }
        var cat = found >= 0 ? list[found] : { id: categoryId, name: name, files: [], size: 0, selected: true }
        cat.name = name
        cat.files = files || []
        cat.size = totalSize || 0
        if (found >= 0)
            list[found] = cat
        else
            list.push(cat)
        categories = list
    }

    function setCategorySelected(categoryId, selected) {
        var list = categories.slice()
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === categoryId) {
                var c = list[i]
                if (c.selected === selected)
                    return
                c.selected = selected
                list[i] = c
                categories = list
                return
            }
        }
    }

    function getSelectedFiles() {
        var paths = []
        for (var i = 0; i < categories.length; i++) {
            var c = categories[i]
            if (c.selected && c.files) {
                for (var j = 0; j < c.files.length; j++) {
                    var p = c.files[j].path
                    if (p) paths.push(p)
                }
            }
        }
        return paths
    }

    function getSelectedSize() {
        var sz = 0
        for (var i = 0; i < categories.length; i++) {
            var c = categories[i]
            if (c.selected && c.files) {
                for (var j = 0; j < c.files.length; j++) {
                    sz += c.files[j].size || 0
                }
            }
        }
        return sz
    }

    function reset() {
        categories = []
        totalFiles = 0
        totalSize = 0
    }
}
