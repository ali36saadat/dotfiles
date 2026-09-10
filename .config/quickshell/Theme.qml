pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: theme

    property string _home: Quickshell.env("HOME") || ""

    property string _themeName: "night"
    property var _colors: ({})

    // --------------------------------------------------
    // Current theme selector
    // ~/.local/share/themes/current/current
    // --------------------------------------------------

    property FileView _currentFile: FileView {
        path: theme._home + "/.local/share/themes/current/current"
        watchChanges: true

        onLoaded: {
            theme._loadThemeName()
        }

        onFileChanged: {
            reload()
        }
    }

    // --------------------------------------------------
    // Selected theme colors
    // ~/.local/share/themes/colors/<theme>/colors.conf
    // --------------------------------------------------

    property FileView _colorsFile: FileView {
        path: theme._home +
              "/.local/share/themes/colors/" +
              theme._themeName +
              "/colors.conf"

        watchChanges: true

        onLoaded: {
            theme._parseColors()
        }

        onFileChanged: {
            reload()
        }
    }

    Component.onCompleted: {
        _currentFile.reload()
    }

    // --------------------------------------------------
    // Read selected theme
    // --------------------------------------------------

    function _loadThemeName() {
        var lines = _currentFile.text().split("\n")
        var name = "night"

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()

            if (line.startsWith("theme=")) {
                name = line.substring(6).trim()
                break
            }
        }

        if (!name)
            name = "night"

        theme._themeName = name

        _colorsFile.path =
            theme._home +
            "/.local/share/themes/colors/" +
            name +
            "/colors.conf"

        _colorsFile.reload()
    }

    // --------------------------------------------------
    // Parse colors.conf
    // --------------------------------------------------

    function _parseColors() {
        var result = {}
        var lines = _colorsFile.text().split("\n")

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()

            if (!line || line.startsWith("#"))
                continue

            var index = line.indexOf("=")

            if (index === -1)
                continue

            var key = line.substring(0, index).trim()
            var value = line.substring(index + 1).trim()

            result[key] = value
        }

        theme._colors = result
    }

    // --------------------------------------------------
    // Color lookup
    // --------------------------------------------------

    function _col(key, fallback) {
        if (theme._colors[key] !== undefined &&
            theme._colors[key] !== "")
            return theme._colors[key]

        return fallback
    }

    // --------------------------------------------------
    // Helpers
    // --------------------------------------------------

    function _lum(c) {
        var q = Qt.color(c)

        return 0.2126 * q.r +
               0.7152 * q.g +
               0.0722 * q.b
    }

    function _alpha(c, a) {
        var q = Qt.color(c)

        return Qt.rgba(
            q.r,
            q.g,
            q.b,
            a
        )
    }

    function blend(a, b, t) {
        var x = Qt.color(a)
        var y = Qt.color(b)

        return Qt.rgba(
            x.r + (y.r - x.r) * t,
            x.g + (y.g - x.g) * t,
            x.b + (y.b - x.b) * t,
            x.a + (y.a - x.a) * t
        )
    }

    // --------------------------------------------------
    // Base colors
    // --------------------------------------------------

    readonly property color background:
        _col("background", "#0D1117")

    readonly property color surface:
        _col("surface", "#161B22")

    readonly property color text:
        _col("text", "#F0F6FC")

    readonly property color accent:
        _col("accent", "#58A6FF")

    readonly property color secondary:
        _col("secondary", "#79C0FF")

    readonly property color border:
        _col("border", "#30363D")

    // --------------------------------------------------
    // Derived colors
    // --------------------------------------------------

    readonly property bool isLight:
        _lum(background) > 0.62

    readonly property color notchFill:
        surface

    readonly property color panel:
        surface

    readonly property color surfaceHover:
        blend(
            surface,
            text,
            isLight ? 0.04 : 0.08
        )

    readonly property color surfaceActive:
        blend(
            surface,
            text,
            isLight ? 0.07 : 0.12
        )

    readonly property color raised:
        blend(
            surface,
            text,
            isLight ? 0.12 : 0.07
        )

    readonly property color sunken:
        blend(
            surface,
            "#000000",
            isLight ? 0.10 : 0.42
        )

    readonly property color separator:
        border

    readonly property color textPrimary:
        text

    readonly property color textSecondary:
        secondary

    readonly property color textMuted:
        _alpha(text, 0.50)

    readonly property color textFaint:
        _alpha(text, 0.26)

    readonly property color accentText:
        _lum(accent) > 0.55
            ? "#141317"
            : "#F7F7FA"

    readonly property color scrim:
        _alpha(
            "#000000",
            isLight ? 0.16 : 0.38
        )

    readonly property color negative:
        blend(
            "#E06C75",
            text,
            0.10
        )

    // --------------------------------------------------
    // Fonts
    // --------------------------------------------------

    readonly property string fontSans:
        "Inter, Roboto, -apple-system, Sans-Serif"

    readonly property string fontMono:
        "JetBrains Mono, monospace"

    readonly property string fontIcon:
        "JetBrainsMono Nerd Font"
}
