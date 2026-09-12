// Live GPU power draw + adjustable power cap on the bar, read/written via
// the AMD dGPU's hwmon "power1_input"/"power1_cap" sysfs files. The hwmon
// number isn't guaranteed stable across reboots, so both the poll and the
// write resolve the path fresh each time by scanning /sys/class/drm/card*
// /device for vendor 0x1002 (AMD) with a hwmon child, rather than
// hardcoding a card/hwmon path.
//
// Cap changes are deliberately NOT persisted across reboots (plain sysfs
// write, resets to hardware default on boot) - see natasha-omarchy README.
// Scroll on the bar icon = +/-1W. Right-click = popup with a slider for
// coarser adjustment.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "milesj.gpupower"

  // Floor enforced here, not by the hardware (power1_cap_min reports 0).
  // Below idle draw (~12W) the GPU may throttle hard or become unstable
  // under any real load - kept user-adjustable for deliberate testing.
  readonly property real minCapWatts: 5

  property real watts: 0
  property real capWatts: 0
  property real capMaxWatts: 40
  property bool available: false
  property bool popupOpen: false

  readonly property string resolveHwmon: "hm=\"\"; for c in /sys/class/drm/card*/device; do v=$(cat \"$c/vendor\" 2>/dev/null); if [ \"$v\" = \"0x1002\" ]; then hm=$(ls -d \"$c\"/hwmon/hwmon*/ 2>/dev/null | head -1); [ -n \"$hm\" ] && break; fi; done;"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function setCap(watts) {
    var clamped = Math.max(minCapWatts, Math.min(capMaxWatts, Math.round(watts)))
    var microwatts = clamped * 1000000
    writeProc.command = ["bash", "-c", resolveHwmon + " [ -n \"$hm\" ] && echo " + microwatts + " | sudo -n tee \"${hm}power1_cap\" >/dev/null"]
    writeProc.running = true
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.available ? ("⚡ " + root.watts.toFixed(1) + "W") : "⚡ …"
    tooltipText: root.available
      ? ("AMD GPU power draw (cap: " + root.capWatts.toFixed(0) + "W" + (root.capWatts < root.capMaxWatts - 1 ? ", lowered - scroll or right-click to adjust" : ", scroll or right-click to adjust") + ")")
      : "AMD GPU power draw"

    onPressed: function(b) {
      if (b === Qt.RightButton) root.popupOpen = !root.popupOpen
    }
    onWheelMoved: function(delta) {
      if (!root.available) return
      root.setCap(root.capWatts + (delta > 0 ? 1 : -1))
    }
  }

  Process {
    id: powerProc
    command: ["bash", "-c", root.resolveHwmon + " [ -n \"$hm\" ] && cat \"${hm}power1_input\" \"${hm}power1_cap\" \"${hm}power1_cap_max\""]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var lines = String(text || "").trim().split("\n")
        var microwatts = parseFloat(lines[0])
        var capMicrowatts = lines.length > 1 ? parseFloat(lines[1]) : NaN
        var capMaxMicrowatts = lines.length > 2 ? parseFloat(lines[2]) : NaN
        if (isFinite(microwatts) && microwatts > 0) {
          root.watts = microwatts / 1000000
          root.capWatts = isFinite(capMicrowatts) ? capMicrowatts / 1000000 : 0
          if (isFinite(capMaxMicrowatts) && capMaxMicrowatts > 0) root.capMaxWatts = capMaxMicrowatts / 1000000
          root.available = true
        } else {
          root.available = false
        }
      }
    }
  }

  Process {
    id: writeProc
    onExited: pollTimer.triggered()
  }

  Timer {
    id: pollTimer
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!powerProc.running) powerProc.running = true
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(260))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(10)

      Text {
        textFormat: Text.PlainText
        text: "AMD GPU Power Cap"
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.subtitle
        font.bold: true
      }

      Text {
        textFormat: Text.PlainText
        text: "Live only - resets to " + root.capMaxWatts.toFixed(0) + "W default on reboot."
        color: Qt.darker(root.bar.foreground, 1.4)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
        width: parent.width
      }

      Row {
        width: parent.width
        spacing: Style.space(10)

        PanelSlider {
          id: capSlider
          bar: root.bar
          width: parent.width - Style.space(60)
          anchors.verticalCenter: parent.verticalCenter
          minimum: root.minCapWatts
          maximum: root.capMaxWatts
          step: 1
          value: root.capWatts
          onMoved: function(v) { root.setCap(v) }
        }

        Text {
          textFormat: Text.PlainText
          anchors.verticalCenter: parent.verticalCenter
          text: root.capWatts.toFixed(0) + "W"
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }
    }
  }
}
