// Thin bar widget: no direct speaker calls, just reflects Service.qml's
// state. Click = play/pause the active room, scroll = volume, right-click
// opens a popup to switch rooms. Auto-duck (pausing the active room when
// other host audio plays) runs entirely in the service, independent of
// whether this widget is open.

import QtQuick
import Quickshell
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "milesj.sonos"

  readonly property var sonosService: bar?.shell?.serviceFor("milesj.sonos")
  readonly property var rooms: sonosService ? sonosService.rooms : ({})
  readonly property string activeRoom: sonosService ? sonosService.activeRoom : ""
  readonly property var activeState: rooms[activeRoom] || ({})

  readonly property bool isPlaying: activeState.transport === "PLAYING"
  readonly property string statusText: {
    if (activeState.title) return activeState.title
    if (activeState.transport === "PLAYING") return "Playing"
    if (activeState.transport === "PAUSED_PLAYBACK") return "Paused"
    if (!activeState.transport) return "..."
    return "Idle"
  }
  readonly property string displayText: activeRoom + ": " + statusText
  readonly property string playIcon: isPlaying ? "󰏤" : "󰐊"

  property bool popupOpen: false

  visible: true
  implicitWidth: row.implicitWidth + Style.space(14)
  implicitHeight: barSize

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Style.space(6)

    Text {
      textFormat: Text.PlainText
      anchors.verticalCenter: parent.verticalCenter
      text: root.playIcon
      color: root.isPlaying ? root.bar.barForeground : Qt.darker(root.bar.barForeground, 1.5)
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.body
      Behavior on color {
        enabled: !root.bar || root.bar.foregroundAnimationEnabled
        ColorAnimation { duration: 160 }
      }
    }

    Text {
      textFormat: Text.PlainText
      anchors.verticalCenter: parent.verticalCenter
      visible: !root.bar.vertical
      text: root.displayText
      color: root.bar.barForeground
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
      width: Math.min(implicitWidth, Style.space(200))
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: function(mouse) {
      if (!root.sonosService) return
      if (mouse.button === Qt.RightButton) {
        root.popupOpen = !root.popupOpen
      } else {
        root.sonosService.toggleActive(root.activeRoom)
      }
    }
    onWheel: function(wheel) {
      if (!root.sonosService) return
      var steps = wheel.angleDelta.y > 0 ? 1 : -1
      root.sonosService.setVolume(root.activeRoom, steps * 2, null)
    }
    onEntered: if (root.bar) root.bar.showTooltip(root, root.displayText + (root.activeState.volume !== undefined && root.activeState.volume !== null ? "  " + root.activeState.volume + "%" : ""))
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(280))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(10)

      Text {
        textFormat: Text.PlainText
        text: "Sonos"
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.subtitle
        font.bold: true
      }

      Column {
        id: roomList
        width: parent.width
        spacing: Style.space(4)

        Repeater {
          model: root.sonosService ? root.sonosService.roomDefs : []

          Button {
            id: roomButton
            required property var modelData
            readonly property string roomName: modelData.name
            readonly property var st: root.rooms[roomName] || ({})

            width: roomList.width
            text: roomName + (st.title ? "  ·  " + st.title : (st.transport === "PLAYING" ? "  ·  Playing" : ""))
            fontSize: Style.font.bodySmall
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            horizontalPadding: Style.spacing.controlPaddingX
            verticalPadding: Style.spacing.controlPaddingY
            bordered: true
            selected: roomName === root.activeRoom

            onClicked: if (root.sonosService) root.sonosService.setActiveRoom(roomName)
          }
        }
      }

      PanelSeparator {
        foreground: root.bar.foreground
      }

      Row {
        width: parent.width
        spacing: Style.space(10)

        Button {
          iconText: root.playIcon
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.panelGap
          verticalPadding: Style.spacing.controlPaddingY
          iconSize: Style.font.iconLarge
          onClicked: if (root.sonosService) root.sonosService.toggleActive(root.activeRoom)
        }

        PanelSlider {
          id: volumeSlider
          bar: root.bar
          width: parent.width - Style.space(120)
          anchors.verticalCenter: parent.verticalCenter
          minimum: 0
          maximum: 100
          step: 1
          value: root.activeState.volume || 0
          onMoved: function(v) { if (root.sonosService) root.sonosService.setVolume(root.activeRoom, null, Math.round(v)) }
        }

        Text {
          textFormat: Text.PlainText
          anchors.verticalCenter: parent.verticalCenter
          text: (root.activeState.volume || 0) + "%"
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }
    }
  }
}
