// Icon button on the bar that opens Omarchy's existing system menu
// (Screensaver / Lock / Suspend / Hibernate / Logout / Reboot / Shutdown) -
// the same menu SUPER+ESCAPE opens, just always visible on the bar.
import QtQuick
import qs.Ui

BarWidget {
  id: root
  moduleName: "milesj.powermenu"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰐥"
    horizontalMargin: 7.5
    tooltipText: "Power"
    onPressed: function(button) {
      if (!root.bar) return
      root.bar.run("omarchy-menu toggle system")
    }
  }
}
