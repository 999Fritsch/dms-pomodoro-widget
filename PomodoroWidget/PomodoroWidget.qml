import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property var popoutService: null

    // ── Config (with safe defaults) ──────────────────────────────────────
    readonly property int workSecs:        (pluginData.workDuration        ?? 25) * 60
    readonly property int shortBreakSecs:  (pluginData.shortBreakDuration  ??  5) * 60
    readonly property int longBreakSecs:   (pluginData.longBreakDuration   ?? 15) * 60
    readonly property int pomosUntilLong:   pluginData.pomodorosUntilLongBreak ?? 4
    readonly property bool autoStartBreak:  pluginData.autoStartBreak === true
    readonly property bool soundEnabled:    pluginData.enableSound === true
    readonly property string soundFilePath: pluginData.soundFile ?? ""

    // ── Timer state ───────────────────────────────────────────────────────
    // mode: 0 = idle | 1 = work | 2 = short break | 3 = long break
    property int  mode:          0
    property bool running:       false
    property bool paused:        false
    property int  remainingSecs: 0
    property int  pomodorosDone: 0
    property bool _breakPending: false

    readonly property bool isIdle:  mode === 0
    readonly property bool isWork:  mode === 1
    readonly property bool isBreak: mode === 2 || mode === 3

    readonly property int totalSecs: {
        if (mode === 1) return workSecs
        if (mode === 2) return shortBreakSecs
        if (mode === 3) return longBreakSecs
        return 0
    }

    // Work: fills 0→1 (CW).  Break: empties 1→0 (leading edge retreats CCW).
    readonly property real arcProgress: {
        if (isIdle || totalSecs === 0) return 0
        if (isWork) return (totalSecs - remainingSecs) / totalSecs
        return remainingSecs / totalSecs
    }

    // ── Popup state ───────────────────────────────────────────────────────
    property bool showPopup:    false
    property real popupTargetX: 0

    // ── Notification / sound helpers ──────────────────────────────────────
    property string _notifyTitle: ""
    property string _notifyBody:  ""
    property bool   _doNotify:    false
    property bool   _doSound:     false

    // ── Utilities ─────────────────────────────────────────────────────────
    function pad2(n) { return String(n).padStart(2, "0") }
    function fmtTime(s) { return pad2(Math.floor(s / 60)) + ":" + pad2(s % 60) }

    function startWork() {
        mode = 1; remainingSecs = workSecs; running = true; paused = false
    }

    function startBreak() {
        _breakPending = false
        var isLongBreak = pomosUntilLong > 0 && (pomodorosDone % pomosUntilLong === 0)
        mode = isLongBreak ? 3 : 2
        remainingSecs = isLongBreak ? longBreakSecs : shortBreakSecs
        running = true; paused = false
    }

    function togglePause() {
        if (!isIdle) paused = !paused
    }

    function resetTimer() {
        running = false; paused = false; mode = 0; remainingSecs = 0; _breakPending = false
    }

    function resetSession() {
        pomodorosDone = 0; resetTimer()
    }

    function skipCurrent() {
        if (isWork) {
            pomodorosDone++
            _notify("Pomodoro Complete!", "Time for a break.")
            if (autoStartBreak) {
                startBreak()
            } else {
                resetTimer()
                _breakPending = true
            }
        } else if (isBreak) {
            _notify("Break Over", "Time to focus!")
            resetTimer()
        }
    }

    function _notify(title, body) {
        _notifyTitle = title
        _notifyBody  = body
        _doNotify    = true
        if (soundEnabled && soundFilePath !== "") _doSound = true
    }

    // ── Countdown ─────────────────────────────────────────────────────────
    Timer {
        interval: 1000
        repeat:   true
        running:  root.running && !root.paused
        onTriggered: {
            if (root.remainingSecs > 0) {
                root.remainingSecs--
            } else {
                root.running = false
                if (root.isWork) {
                    root.pomodorosDone++
                    root._notify("Pomodoro Complete!", "Time for a break.")
                    if (root.autoStartBreak) {
                        root.startBreak()
                    } else {
                        root.mode = 0
                        root._breakPending = true
                    }
                } else if (root.isBreak) {
                    root._notify("Break Over", "Time to focus!")
                    root.mode = 0
                }
            }
        }
    }

    // ── Notification process ──────────────────────────────────────────────
    Process {
        command: ["notify-send", "-a", "Pomodoro", root._notifyTitle, root._notifyBody]
        running: root._doNotify
        onExited: root._doNotify = false
    }

    // ── Sound process (only when explicitly configured) ───────────────────
    Process {
        command: root.soundFilePath !== "" ? ["paplay", root.soundFilePath] : ["true"]
        running: root._doSound && root.soundEnabled && root.soundFilePath !== ""
        onExited: root._doSound = false
    }

    // ── Bar pill ──────────────────────────────────────────────────────────
    horizontalBarPill: Component {
        Item {
            id: pill

            readonly property real fsz:     Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
            readonly property real arcSz:   Math.round(root.barThickness * 0.72)
            readonly property real spacing: 5

            implicitWidth:  root.isIdle
                            ? idleIcon.implicitWidth
                            : arcSz + spacing + countTxt.implicitWidth
            implicitHeight: root.barThickness

            // ── Idle: themed timer icon ──────────────────────────────────
            DankIcon {
                id: idleIcon
                anchors.centerIn: parent
                visible: root.isIdle
                name:  "timer"
                size:  Math.round(pill.fsz * 1.15)
                color: Theme.primary
            }

            // ── Running/Paused/Break: arc + count ────────────────────────
            Row {
                anchors.centerIn: parent
                visible: !root.isIdle
                spacing: pill.spacing

                Canvas {
                    id: pillArc
                    width:  pill.arcSz
                    height: pill.arcSz
                    anchors.verticalCenter: parent.verticalCenter

                    property real  progress: root.arcProgress
                    property color arcColor: Theme.primary
                    onProgressChanged: requestPaint()
                    onArcColorChanged: requestPaint()

                    SequentialAnimation on opacity {
                        running: root.paused && !root.isIdle
                        loops:   Animation.Infinite
                        NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0;  duration: 700; easing.type: Easing.InOutSine }
                        onStopped: pillArc.opacity = 1.0
                    }

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        var cx = width / 2, cy = height / 2
                        var sw = Math.max(2, Math.round(width * 0.14))
                        var r  = (Math.min(width, height) - sw) / 2

                        ctx.beginPath()
                        ctx.arc(cx, cy, r, 0, 2 * Math.PI, false)
                        ctx.strokeStyle = Qt.rgba(arcColor.r, arcColor.g, arcColor.b, 0.18)
                        ctx.lineWidth   = sw
                        ctx.stroke()

                        if (progress > 0.005) {
                            var start = -Math.PI / 2
                            ctx.beginPath()
                            ctx.arc(cx, cy, r, start, start + progress * 2 * Math.PI, false)
                            ctx.strokeStyle = String(arcColor)
                            ctx.lineWidth   = sw
                            ctx.lineCap     = "round"
                            ctx.stroke()
                        }
                    }
                }

                StyledText {
                    id: countTxt
                    anchors.verticalCenter: parent.verticalCenter
                    text:  String(root.pomodorosDone)
                    color: Theme.primary
                    font.pixelSize: Math.round(pill.fsz * 0.85)
                    font.weight: Font.Bold
                }
            }
        }
    }

    verticalBarPill: Component {
        Item {
            readonly property real fsz:   Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
            readonly property real arcSz: Math.round(root.barThickness * 0.72)
            implicitWidth:  root.barThickness
            implicitHeight: root.isIdle ? Math.round(fsz * 1.4) : arcSz + 20

            DankIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                visible: root.isIdle
                name:  "timer"
                size:  Math.round(fsz * 1.15)
                color: Theme.primary
            }
        }
    }

    pillClickAction: function(x, y, width, section, screen) {
        root.popupTargetX = x + width / 2
        popupWin.visible = !popupWin.visible
        root.showPopup = popupWin.visible
    }

    // ── Popup window ──────────────────────────────────────────────────────
    Window {
        id: popupWin
        flags:  Qt.Popup | Qt.FramelessWindowHint
        width:  268
        height: rootCol.implicitHeight + 32
        color:  "transparent"

        x: Math.max(0, Math.round(root.popupTargetX - width / 2))
        y: root.barThickness + 4

        onVisibleChanged: if (!visible) root.showPopup = false

        Rectangle {
            anchors.fill: parent
            radius: 14
            color:  Theme.surface
            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.55)
            border.width: 1

            Column {
                id: rootCol
                anchors {
                    top:   parent.top
                    left:  parent.left
                    right: parent.right
                    margins: 16
                }
                topPadding:    16
                bottomPadding: 16
                spacing: 14

                // ── Mode label ───────────────────────────────────────────
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: {
                        if (root.isIdle && root._breakPending) return "Break Ready"
                        if (root.isIdle)     return "Pomodoro Timer"
                        if (root.isWork)     return "Work"
                        if (root.mode === 3) return "Long Break"
                        return "Short Break"
                    }
                    color: Theme.primary
                    font.pixelSize: 15
                    font.weight: Font.Bold
                }

                // ── Big arc + time ───────────────────────────────────────
                Item {
                    width: parent.width
                    height: 136

                    Canvas {
                        id: bigArc
                        width:  128
                        height: 128
                        anchors.centerIn: parent

                        property real  progress:    root.arcProgress
                        property color arcColor:    Theme.primary
                        property bool  nearHandle:  false
                        property bool  active:      !root.isIdle
                        onProgressChanged:   requestPaint()
                        onArcColorChanged:   requestPaint()
                        onNearHandleChanged: requestPaint()
                        onActiveChanged:     requestPaint()

                        SequentialAnimation on opacity {
                            running: root.paused && !root.isIdle
                            loops:   Animation.Infinite
                            NumberAnimation { to: 0.4; duration: 700; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                            onStopped: bigArc.opacity = 1.0
                        }

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cx = width / 2, cy = height / 2
                            var sw = 9
                            var r  = (Math.min(width, height) - sw) / 2

                            ctx.beginPath()
                            ctx.arc(cx, cy, r, 0, 2 * Math.PI, false)
                            ctx.strokeStyle = Qt.rgba(arcColor.r, arcColor.g, arcColor.b, 0.13)
                            ctx.lineWidth   = sw
                            ctx.stroke()

                            var start = -Math.PI / 2
                            if (progress > 0.005) {
                                ctx.beginPath()
                                ctx.arc(cx, cy, r, start, start + progress * 2 * Math.PI, false)
                                ctx.strokeStyle = String(arcColor)
                                ctx.lineWidth   = sw
                                ctx.lineCap     = "round"
                                ctx.stroke()
                            }

                            // Drag handle knob — visible from the first tick
                            if (active) {
                                var tipAngle = start + progress * 2 * Math.PI
                                var kx = cx + r * Math.cos(tipAngle)
                                var ky = cy + r * Math.sin(tipAngle)
                                var knobR = nearHandle ? 7 : 5
                                ctx.beginPath()
                                ctx.arc(kx, ky, knobR, 0, 2 * Math.PI, false)
                                ctx.fillStyle = String(arcColor)
                                ctx.fill()
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text:  root.isIdle ? "--:--" : root.fmtTime(root.remainingSecs)
                            color: Theme.surfaceText
                            font.pixelSize: 22
                            font.weight: Font.Bold
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            property bool isDragging: false
                            cursorShape: isDragging        ? Qt.ClosedHandCursor
                                       : bigArc.nearHandle ? Qt.OpenHandCursor
                                       : Qt.ArrowCursor

                            function arcR() {
                                return (Math.min(bigArc.width, bigArc.height) - 9) / 2
                            }
                            function knobCenter() {
                                var cx = bigArc.width / 2
                                var cy = bigArc.height / 2
                                var a  = -Math.PI / 2 + root.arcProgress * 2 * Math.PI
                                return { x: cx + arcR() * Math.cos(a), y: cy + arcR() * Math.sin(a) }
                            }
                            function distToKnob(mx, my) {
                                var k = knobCenter()
                                return Math.sqrt(Math.pow(mx - k.x, 2) + Math.pow(my - k.y, 2))
                            }
                            function angleToRemaining(mx, my) {
                                var cx = bigArc.width / 2
                                var cy = bigArc.height / 2
                                var angle = Math.atan2(my - cy, mx - cx)
                                var prog = (angle + Math.PI / 2) / (2 * Math.PI)
                                if (prog < 0) prog += 1
                                prog = Math.max(0.01, Math.min(0.99, prog))
                                var secs = root.isWork
                                           ? (1 - prog) * root.totalSecs
                                           : prog * root.totalSecs
                                secs = Math.round(secs / 60) * 60
                                return Math.max(60, Math.min(root.totalSecs, secs))
                            }

                            onPressed: {
                                if (root.isIdle) return
                                if (distToKnob(mouseX, mouseY) < 18) isDragging = true
                            }
                            onPositionChanged: {
                                if (!root.isIdle)
                                    bigArc.nearHandle = distToKnob(mouseX, mouseY) < 18
                                if (isDragging)
                                    root.remainingSecs = angleToRemaining(mouseX, mouseY)
                            }
                            onReleased: isDragging = false
                            onExited:   bigArc.nearHandle = false
                        }
                    }
                }

                // ── Session dots ─────────────────────────────────────────
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 7

                    Repeater {
                        model: root.pomosUntilLong
                        delegate: Rectangle {
                            width: 9; height: 9; radius: 5
                            color: index < (root.pomodorosDone % root.pomosUntilLong)
                                   ? Theme.primary
                                   : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                        }
                    }
                }

                // ── Primary controls ─────────────────────────────────────
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10

                    // Play / Pause / Start
                    Rectangle {
                        width: 46; height: 46; radius: 23
                        color:        Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.13)
                        border.color: Theme.primary
                        border.width: 1

                        DankIcon {
                            anchors.centerIn: parent
                            name:  (root.isIdle || root.paused) ? "play_arrow" : "pause"
                            size:  22
                            color: Theme.primary
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.isIdle) {
                                    if (root._breakPending) root.startBreak()
                                    else root.startWork()
                                } else {
                                    root.togglePause()
                                }
                            }
                        }
                    }

                    // Reset current timer
                    Rectangle {
                        width: 46; height: 46; radius: 23
                        color:        Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.45)
                        border.width: 1

                        DankIcon {
                            anchors.centerIn: parent
                            name:  "replay"
                            size:  22
                            color: Theme.primary
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.resetTimer()
                        }
                    }

                    // Skip (hidden when idle)
                    Rectangle {
                        width: 46; height: 46; radius: 23
                        visible:      !root.isIdle
                        color:        Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.45)
                        border.width: 1

                        DankIcon {
                            anchors.centerIn: parent
                            name:  "skip_next"
                            size:  22
                            color: Theme.primary
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.skipCurrent()
                        }
                    }
                }

                // ── Reset session ─────────────────────────────────────────
                Rectangle {
                    width: parent.width
                    height: 36
                    radius: 8
                    color:        Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.07)
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.28)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text:  "Reset Session  (" + root.pomodorosDone + " done)"
                        color: Theme.primary
                        font.pixelSize: 12
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.resetSession()
                    }
                }
            }
        }
    }
}
