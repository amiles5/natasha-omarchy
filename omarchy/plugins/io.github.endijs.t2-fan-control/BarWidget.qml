import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.endijs.t2-fan-control"
  ipcTarget: "io.github.endijs.t2-fan-control"

  property int temperature: 0
  property int rpm: 0
  property int minRpm: 0
  property int maxRpm: 0
  property var fans: []
  property bool daemonRunning: false
  property int lowTemp: 55
  property int highTemp: 75
  property string curve: "linear"
  property bool fullSpeed: false
  property bool originalSaved: false
  property bool dirty: false
  property bool saving: false
  property bool helperInstalled: false
  property bool restoreConfirm: false
  property string message: ""
  property string statusOutput: ""
  property string applyOutput: ""
  property string applyError: ""

  readonly property string helperPath: Qt.resolvedUrl("t2fan-control").toString().replace(/^file:\/\//, "")
  readonly property string privilegedHelperPath: "/usr/local/libexec/omarchy-t2-fan-control"
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color accent: Color.accent
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function refresh() {
    if (statusProc.running) return
    statusOutput = ""
    statusProc.running = true
  }

  function consumeStatus(raw) {
    try {
      var value = JSON.parse(String(raw || "{}"))
      temperature = Number(value.temperature || 0)
      fans = value.fans instanceof Array ? value.fans : []
      var primary = fans.length > 0 ? fans[0] : value
      rpm = Number(primary.rpm || 0)
      minRpm = Number(primary.minRpm || 0)
      maxRpm = Number(primary.maxRpm || 0)
      daemonRunning = value.running === true
      originalSaved = value.originalSaved === true
      helperInstalled = value.helperInstalled === true
      if (!dirty && !saving) {
        lowTemp = Number(value.lowTemp || 55)
        highTemp = Number(value.highTemp || 75)
        curve = String(value.curve || "linear")
        fullSpeed = value.fullSpeed === true
      }
    } catch (error) {
      message = "Could not read fan status"
    }
  }

  function save() {
    if (saving) return
    if (!helperInstalled) {
      message = "Install the privileged helper before saving"
      return
    }
    if (highTemp < lowTemp + 5) {
      message = "High temperature must be at least 5°C above low"
      return
    }
    saving = true
    restoreConfirm = false
    message = "Waiting for administrator authorization…"
    applyOutput = ""
    applyError = ""
    applyProc.command = ["pkexec", privilegedHelperPath, "apply", String(lowTemp), String(highTemp), curve, fullSpeed ? "true" : "false"]
    applyProc.running = true
  }

  function restoreOriginal() {
    if (saving || !originalSaved) return
    if (!helperInstalled) {
      message = "Install the privileged helper before restoring"
      return
    }
    if (!restoreConfirm) {
      restoreConfirm = true
      message = "Click Restore again to replace the current curve"
      return
    }
    saving = true
    restoreConfirm = false
    message = "Waiting for administrator authorization…"
    applyOutput = ""
    applyError = ""
    applyProc.command = ["pkexec", privilegedHelperPath, "restore"]
    applyProc.running = true
  }

  function resetEditor() {
    dirty = false
    restoreConfirm = false
    message = ""
    refresh()
  }

  function open() {
    controller.show()
    refresh()
  }

  function fanTooltip() {
    if (fans.length <= 1) return temperature + "°C  ·  " + rpm + " RPM"
    var parts = []
    for (var i = 0; i < fans.length; i++)
      parts.push("Fan " + fans[i].index + ": " + fans[i].rpm + " RPM")
    return temperature + "°C  ·  " + parts.join("  ·  ")
  }

  visible: rpm > 0
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Component.onCompleted: refresh()

  Process {
    id: statusProc
    command: [root.helperPath, "status"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.statusOutput = text }
    onExited: function(exitCode) {
      if (exitCode === 0) root.consumeStatus(root.statusOutput)
    }
  }

  Process {
    id: applyProc
    command: []
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.applyOutput = text }
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: root.applyError = text }
    onExited: function(exitCode) {
      root.saving = false
      if (exitCode === 0) {
        root.dirty = false
        root.message = String(root.applyOutput).trim() || "Saved"
        root.refresh()
      } else {
        var detail = String(root.applyError).replace(/\s+/g, " ").trim()
        root.message = detail || "Save cancelled or failed"
      }
    }
  }

  Timer {
    interval: 2000
    running: root.opened
    repeat: true
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰈐"
    active: root.opened
    tooltipText: root.fanTooltip()
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: popup
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: fittedContentWidth(Style.space(430))
    contentHeight: fittedContentHeight(content.implicitHeight)

    Column {
      id: content
      // The default-property alias keeps this item's QML parent as the panel,
      // even though it is rendered inside KeyboardPanel's inset holder. Derive
      // the actual inner width explicitly so rows and separators stop at the
      // visible card border.
      width: popup.contentWidth
        - popup.padding * 2
        - Border.left(popup.borderSpec)
        - Border.right(popup.borderSpec)
      spacing: Style.space(14)

      Row {
        width: parent.width
        spacing: Style.space(18)

        Column {
          width: (parent.width - parent.spacing) / 2
          spacing: Style.space(2)
          Text {
            text: root.temperature + "°C"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
            font.bold: true
          }
          Text {
            text: "Hottest CPU core"
            color: Qt.darker(root.foreground, 1.45)
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

        Column {
          width: (parent.width - parent.spacing) / 2
          spacing: Style.space(2)
          Text {
            text: root.rpm + " RPM"
            color: root.daemonRunning ? root.foreground : root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
            font.bold: true
          }
          Text {
            width: parent.width
            text: root.daemonRunning ? (root.minRpm + "–" + root.maxRpm + " RPM · running") : "t2fanrd is not running"
            elide: Text.ElideRight
            color: Qt.darker(root.foreground, 1.45)
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }
      }

      Column {
        width: parent.width
        spacing: Style.space(4)
        visible: root.fans.length > 1

        Repeater {
          model: root.fans
          delegate: Row {
            required property var modelData
            width: parent.width
            Text {
              width: parent.width / 2
              text: "Fan " + modelData.index
              color: Qt.darker(root.foreground, 1.35)
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
            Text {
              width: parent.width / 2
              horizontalAlignment: Text.AlignRight
              text: modelData.rpm + " RPM  ·  " + modelData.minRpm + "–" + modelData.maxRpm
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
        }
      }

      Rectangle { width: parent.width; height: 1; color: Qt.darker(root.foreground, 1.8) }

      Text {
        text: "FAN CURVE"
        color: Qt.darker(root.foreground, 1.35)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      Row {
        spacing: Style.space(18)
        NumberField {
          label: "Start ramping (°C)"
          value: root.lowTemp
          from: 35
          to: 80
          foreground: root.foreground
          accent: root.accent
          onModified: function(value) { root.lowTemp = value; root.dirty = true; root.restoreConfirm = false; root.message = "" }
        }
        NumberField {
          label: "Maximum speed (°C)"
          value: root.highTemp
          from: 45
          to: 100
          foreground: root.foreground
          accent: root.accent
          onModified: function(value) { root.highTemp = value; root.dirty = true; root.restoreConfirm = false; root.message = "" }
        }
      }

      Column {
        spacing: Style.space(6)
        Text {
          text: "Curve"
          color: Qt.darker(root.foreground, 1.4)
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
        ButtonGroup {
          options: [
            { value: "linear", label: "Linear" },
            { value: "exponential", label: "Exponential" },
            { value: "logarithmic", label: "Logarithmic" }
          ]
          value: root.curve
          foreground: root.foreground
          accent: root.accent
          fontFamily: root.fontFamily
          onChanged: function(value) { root.curve = value; root.dirty = true; root.restoreConfirm = false; root.message = "" }
        }
      }

      Row {
        width: parent.width
        spacing: Style.space(10)
        Text {
          width: parent.width - fullSwitch.width - parent.spacing
          anchors.verticalCenter: parent.verticalCenter
          text: "Always run at maximum speed"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }
        ToggleSwitch {
          id: fullSwitch
          anchors.verticalCenter: parent.verticalCenter
          checked: root.fullSpeed
          busy: root.saving
          foreground: root.foreground
          accent: root.accent
          onToggled: { root.fullSpeed = !root.fullSpeed; root.dirty = true; root.restoreConfirm = false; root.message = "" }
        }
      }

      Text {
        visible: root.message !== ""
        width: parent.width
        wrapMode: Text.WordWrap
        text: root.message
        color: root.message.indexOf("failed") >= 0 || root.message.indexOf("must") >= 0 ? root.urgent : root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
      }

      Row {
        spacing: Style.space(8)
        Button {
          text: root.saving ? "Saving…" : "Save curve"
          iconText: "󰆓"
          enabled: root.dirty && !root.saving
          bordered: true
          foreground: root.foreground
          accent: root.accent
          onClicked: root.save()
        }
        Button {
          text: "Discard"
          enabled: root.dirty && !root.saving
          bordered: true
          foreground: root.foreground
          accent: root.accent
          onClicked: root.resetEditor()
        }
      }

      Button {
        visible: root.originalSaved
        text: root.restoreConfirm ? "Confirm restore" : "Restore original configuration"
        enabled: !root.saving
        bordered: true
        foreground: root.restoreConfirm ? root.urgent : root.foreground
        accent: root.accent
        onClicked: root.restoreOriginal()
      }
    }
  }
}
