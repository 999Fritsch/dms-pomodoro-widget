import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

// NOTE: This settings UI uses DMS built-in setting components.
// SliderSetting and TextSetting are assumed available alongside ToggleSetting.
// If they are not registered in your DMS version, the widget still works via
// plugin_settings.json — edit that file directly to configure the timer.

PluginSettings {
    id: root
    pluginId: "pomodoroWidget"

    StyledText {
        width: parent.width
        text: "Pomodoro Timer"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Timer durations"
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.Medium
        color: Theme.surfaceVariantText
        topPadding: 8
    }

    SliderSetting {
        settingKey:   "workDuration"
        label:        "Work duration (min)"
        description:  "Length of each focus session."
        defaultValue: 25
        from: 5; to: 90; stepSize: 5
    }

    SliderSetting {
        settingKey:   "shortBreakDuration"
        label:        "Short break (min)"
        description:  "Rest between focus sessions."
        defaultValue: 5
        from: 1; to: 30; stepSize: 1
    }

    SliderSetting {
        settingKey:   "longBreakDuration"
        label:        "Long break (min)"
        description:  "Extended rest after completing a full cycle."
        defaultValue: 15
        from: 5; to: 60; stepSize: 5
    }

    SliderSetting {
        settingKey:   "pomodorosUntilLongBreak"
        label:        "Sessions per cycle"
        description:  "Number of work sessions before a long break."
        defaultValue: 4
        from: 2; to: 8; stepSize: 1
    }

    StyledText {
        width: parent.width
        text: "Behaviour"
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.Medium
        color: Theme.surfaceVariantText
        topPadding: 8
    }

    ToggleSetting {
        settingKey:   "autoStartBreak"
        label:        "Auto-start break"
        description:  "Automatically begin the break timer when a work session ends. Off by default — gives you time to make notes before the break starts."
        defaultValue: false
    }

    StyledText {
        width: parent.width
        text: "Sound"
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.Medium
        color: Theme.surfaceVariantText
        topPadding: 8
    }

    ToggleSetting {
        settingKey:   "enableSound"
        label:        "Enable sound"
        description:  "Play an audio file when a session ends. Off by default."
        defaultValue: false
    }

    TextSetting {
        settingKey:   "soundFile"
        label:        "Sound file path"
        description:  "Absolute path to an audio file (e.g. /home/you/sounds/bell.ogg). Played via paplay."
        defaultValue: ""
        visible:      pluginData.enableSound === true
    }
}
