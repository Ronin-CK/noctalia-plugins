import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root
    property var pluginApi: null

    spacing: Style.marginM

    // Properties
    property real iconScale: pluginApi?.pluginSettings?.iconScale || 1.0
    property string displayMode: pluginApi?.pluginSettings?.displayMode || "icon-text"
    property string deviceNativePath: pluginApi?.pluginSettings?.deviceNativePath || "__default__"
    property bool hideIfIdle: pluginApi?.pluginSettings?.hideIfIdle !== undefined ? pluginApi.pluginSettings.hideIfIdle : false
    property bool hideIfNotDetected: pluginApi?.pluginSettings?.hideIfNotDetected !== undefined ? pluginApi.pluginSettings.hideIfNotDetected : true

    // Title
    NLabel {
        label: pluginApi?.tr("settings.title") ?? "Battery Icon Settings"
        description: pluginApi?.tr("settings.description") ?? "Customize the appearance and behavior of the battery icon."
        Layout.fillWidth: true
    }

    // Display Mode
    NValueSelector {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.display_mode_label") ?? "Display Mode"
        description: pluginApi?.tr("settings.display_mode_desc") ?? "How to show the battery information."
        model: [
            { "label": pluginApi?.tr("settings.mode_icon_text") ?? "Icon + Percentage", "value": "icon-text" },
            { "label": pluginApi?.tr("settings.mode_always_show") ?? "Always Show Pill", "value": "alwaysShow" },
            { "label": pluginApi?.tr("settings.mode_icon_only") ?? "Icon Only", "value": "icon-only" }
        ]
        value: root.displayMode
        onSelected: value => {
            root.displayMode = value;
            root.saveSettings();
        }
    }

    // Device Selection
    NValueSelector {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.device_label") ?? "Battery Device"
        description: pluginApi?.tr("settings.device_desc") ?? "Select which device to monitor."
        model: BatteryService.deviceModel.map(d => ({ "label": d.name, "value": d.key }))
        value: root.deviceNativePath
        onSelected: value => {
            root.deviceNativePath = value;
            root.saveSettings();
        }
    }

    // Visibility Toggles
    NValueSwitch {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.hide_idle_label") ?? "Hide if Idle"
        description: pluginApi?.tr("settings.hide_idle_desc") ?? "Hide the icon when fully charged and plugged in."
        checked: root.hideIfIdle
        onToggled: {
            root.hideIfIdle = checked;
            root.saveSettings();
        }
    }

    NValueSwitch {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.hide_missing_label") ?? "Hide if Not Detected"
        description: pluginApi?.tr("settings.hide_missing_desc") ?? "Hide the icon if no battery device is found."
        checked: root.hideIfNotDetected
        onToggled: {
            root.hideIfNotDetected = checked;
            root.saveSettings();
        }
    }

    // Scale Slider
    NValueSlider {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.scale_label") ?? "Icon Scale"
        description: pluginApi?.tr("settings.scale_desc") ?? "Adjust the size of the battery icon relative to the pill."
        from: 0.5
        to: 1.5
        stepSize: 0.05
        value: root.iconScale
        defaultValue: 1.0
        text: Math.round(value * 100) + "%"
        
        onMoved: value => {
             root.iconScale = value;
             root.saveSettings();
        }
    }

    function saveSettings() {
        if (root.pluginApi) {
            root.pluginApi.pluginSettings.iconScale = root.iconScale;
            root.pluginApi.pluginSettings.displayMode = root.displayMode;
            root.pluginApi.pluginSettings.deviceNativePath = root.deviceNativePath;
            root.pluginApi.pluginSettings.hideIfIdle = root.hideIfIdle;
            root.pluginApi.pluginSettings.hideIfNotDetected = root.hideIfNotDetected;
            root.pluginApi.saveSettings();
        }
    }

    Connections {
        target: root.pluginApi
        function onPluginSettingsChanged() {
            root.iconScale = root.pluginApi?.pluginSettings?.iconScale || 1.0;
            root.displayMode = root.pluginApi?.pluginSettings?.displayMode || "icon-text";
            root.deviceNativePath = root.pluginApi?.pluginSettings?.deviceNativePath || "__default__";
            root.hideIfIdle = root.pluginApi?.pluginSettings?.hideIfIdle !== undefined ? root.pluginApi.pluginSettings.hideIfIdle : false;
            root.hideIfNotDetected = root.pluginApi?.pluginSettings?.hideIfNotDetected !== undefined ? root.pluginApi.pluginSettings.hideIfNotDetected : true;
        }
    }
}
