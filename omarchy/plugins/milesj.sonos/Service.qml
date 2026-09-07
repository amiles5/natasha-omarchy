// Headless Sonos service: polls all rooms every 5s over direct UPnP/SOAP
// (no cloud, no app), tracks per-room transport/title/volume/coordinator,
// and auto-ducks (pauses/resumes) the active room when other audio starts
// or stops playing on this host. BarWidget.qml only ever reads state from
// here and writes back through the action functions below - it never talks
// to the speakers directly.
//
// Ported from milesj/ayana-cachyos's Noctalia/Luau "sonos-control" plugin
// (.local/share/noctalia/plugins/sonos-control) to Omarchy/QML. Rooms are
// the same physical Sonos system, so the IP/RINCON table is carried over
// as-is. Grouping and Favourites from that plugin aren't ported yet.

import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var shell: null

  readonly property var roomDefs: [
    { name: "Bedroom",     ip: "192.168.1.181", rincon: "RINCON_7828CAE285F801400" },
    { name: "Dining",      ip: "192.168.1.194", rincon: "RINCON_7828CAE6B2EA01400" },
    { name: "Kitchen",     ip: "192.168.1.204", rincon: "RINCON_347E5C35CDB801400" },
    { name: "Living Room", ip: "192.168.1.227", rincon: "RINCON_38420B9B1FEE01400" }
  ]

  property string activeRoom: "Dining"
  property var rooms: ({})
  property bool togglePending: false

  // Duck state: only resumes a room this service itself paused, and only if
  // nothing else changed its transport while the host was making noise.
  property bool hostAudioActive: false
  property string autoPausedRoom: ""

  function findRoom(name) {
    for (var i = 0; i < roomDefs.length; i++) if (roomDefs[i].name === name) return roomDefs[i]
    return null
  }

  function findByRincon(id) {
    for (var i = 0; i < roomDefs.length; i++) if (roomDefs[i].rincon === id) return roomDefs[i]
    return null
  }

  function coordIpFor(name) {
    var st = rooms[name]
    var coordRincon = st ? st.coordRincon : null
    var coordRoom = (coordRincon && findByRincon(coordRincon)) || findRoom(name)
    return coordRoom ? coordRoom.ip : null
  }

  function setRoomState(name, patch) {
    var next = {}
    for (var k in root.rooms) next[k] = root.rooms[k]
    var merged = {}
    var existing = next[name] || {}
    for (var ek in existing) merged[ek] = existing[ek]
    for (var pk in patch) merged[pk] = patch[pk]
    next[name] = merged
    root.rooms = next
  }

  // ---------------------------------------------------------------- SOAP
  property var soapQueue: []
  property bool soapBusy: false
  property var currentSoapJob: null

  function soapEnvelope(service, action, body) {
    return '<?xml version="1.0" encoding="utf-8"?>' +
      '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">' +
      '<s:Body><u:' + action + ' xmlns:u="urn:schemas-upnp-org:service:' + service + ':1">' +
      body +
      '</u:' + action + '></s:Body></s:Envelope>'
  }

  function soap(ip, path, service, action, body, cb) {
    soapQueue.push({ ip: ip, path: path, service: service, action: action, body: body, cb: cb })
    pumpSoap()
  }

  function pumpSoap() {
    if (soapBusy || soapQueue.length === 0) return
    soapBusy = true
    currentSoapJob = soapQueue.shift()
    var job = currentSoapJob
    soapProc.command = ["curl", "-fsS", "--max-time", "4", "-X", "POST",
      "-H", "Content-Type: text/xml; charset=\"utf-8\"",
      "-H", "SOAPAction: \"urn:schemas-upnp-org:service:" + job.service + ":1#" + job.action + "\"",
      "--data-binary", soapEnvelope(job.service, job.action, job.body),
      "http://" + job.ip + ":1400" + job.path]
    soapProc.running = true
  }

  function finishSoap(rawText) {
    var job = currentSoapJob
    currentSoapJob = null
    soapBusy = false
    var text = String(rawText || "")
    if (job && job.cb) job.cb({ ok: text.length > 0, body: text })
    pumpSoap()
  }

  Process {
    id: soapProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.finishSoap(text)
    }
  }

  // ----------------------------------------------------------------- XML
  function decodeEntities(s) {
    return String(s || "")
      .replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">")
      .replace(/&quot;/g, "\"")
      .replace(/&apos;/g, "'")
      .replace(/&amp;/g, "&")
  }

  function tagValue(body, tag) {
    var re = new RegExp("<" + tag + ">([\\s\\S]*?)</" + tag + ">")
    var m = String(body || "").match(re)
    return m ? m[1] : null
  }

  // ------------------------------------------------------------ room poll
  property int pollIndex: 0

  function pollRoom(room, cb) {
    soap(room.ip, "/MediaRenderer/AVTransport/Control", "AVTransport", "GetPositionInfo",
      "<InstanceID>0</InstanceID>", function(res) {
        var coordRincon = room.rincon
        var title = ""
        if (res.ok) {
          var uri = tagValue(res.body, "TrackURI")
          var rid = (uri && uri.indexOf("x-rincon:") === 0) ? uri.substring(9) : null
          if (rid) {
            coordRincon = rid
          } else {
            var meta = tagValue(res.body, "TrackMetaData")
            if (meta && meta !== "NOT_IMPLEMENTED") {
              meta = decodeEntities(meta)
              title = tagValue(meta, "dc:title") || ""
            }
          }
        }
        soap(room.ip, "/MediaRenderer/AVTransport/Control", "AVTransport", "GetTransportInfo",
          "<InstanceID>0</InstanceID>", function(res2) {
            var transport = (res2.ok && tagValue(res2.body, "CurrentTransportState")) || "?"
            soap(room.ip, "/MediaRenderer/RenderingControl/Control", "RenderingControl", "GetVolume",
              "<InstanceID>0</InstanceID><Channel>Master</Channel>", function(res3) {
                var volRaw = res3.ok ? tagValue(res3.body, "CurrentVolume") : null
                var volume = (volRaw !== null && volRaw !== undefined) ? parseInt(volRaw, 10) : null
                root.setRoomState(room.name, { transport: transport, title: title, volume: volume, coordRincon: coordRincon })
                cb()
              })
          })
      })
  }

  function pollNext() {
    if (pollIndex >= roomDefs.length) {
      pollIndex = 0
      return
    }
    var room = roomDefs[pollIndex]
    pollIndex++
    pollRoom(room, pollNext)
  }

  // ---------------------------------------------------------- host audio
  function onHostAudioStart() {
    var st = rooms[activeRoom]
    if (st && st.transport === "PLAYING") {
      autoPausedRoom = activeRoom
      var ip = coordIpFor(activeRoom)
      if (!ip) return
      soap(ip, "/MediaRenderer/AVTransport/Control", "AVTransport", "Pause",
        "<InstanceID>0</InstanceID>", function(res) {})
    }
  }

  function onHostAudioStop() {
    if (!autoPausedRoom) return
    var roomName = autoPausedRoom
    autoPausedRoom = ""
    var st = rooms[roomName]
    // Pausing a live stream (radio, etc.) often reports STOPPED rather than
    // PAUSED_PLAYBACK, so both count as "we paused it, safe to resume".
    if (st && (st.transport === "PAUSED_PLAYBACK" || st.transport === "STOPPED")) {
      var ip = coordIpFor(roomName)
      if (!ip) return
      soap(ip, "/MediaRenderer/AVTransport/Control", "AVTransport", "Play",
        "<InstanceID>0</InstanceID><Speed>1</Speed>", function(res) {})
    }
  }

  function checkHostAudioOutput(text) {
    var isRunning = String(text || "").indexOf("RUNNING") !== -1
    if (isRunning && !hostAudioActive) {
      hostAudioActive = true
      onHostAudioStart()
    } else if (!isRunning && hostAudioActive) {
      hostAudioActive = false
      onHostAudioStop()
    }
  }

  Process {
    id: hostAudioProc
    command: ["pactl", "list", "sinks", "short"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.checkHostAudioOutput(text)
    }
  }

  Timer {
    id: pollTimer
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!hostAudioProc.running) hostAudioProc.running = true
      pollIndex = 0
      pollNext()
    }
  }

  // -------------------------------------------------------------- actions
  function toggleActive(roomName) {
    if (togglePending) return
    var ip = coordIpFor(roomName)
    if (!ip) return
    var st = rooms[roomName]
    var playing = st && st.transport === "PLAYING"
    var action = playing ? "Pause" : "Play"
    var body = "<InstanceID>0</InstanceID>" + (action === "Play" ? "<Speed>1</Speed>" : "")
    togglePending = true
    soap(ip, "/MediaRenderer/AVTransport/Control", "AVTransport", action, body, function(res) {
      togglePending = false
      pollIndex = 0
      pollNext()
    })
  }

  function setVolume(roomName, delta, absolute) {
    var r = findRoom(roomName)
    if (!r) return
    var st = rooms[roomName]
    var current = (st && st.volume !== null && st.volume !== undefined) ? st.volume : 20
    var newVol = (absolute !== undefined && absolute !== null) ? absolute : Math.max(0, Math.min(100, current + delta))
    soap(r.ip, "/MediaRenderer/RenderingControl/Control", "RenderingControl", "SetVolume",
      "<InstanceID>0</InstanceID><Channel>Master</Channel><DesiredVolume>" + newVol + "</DesiredVolume>",
      function(res) {
        root.setRoomState(roomName, { volume: newVol })
      })
  }

  function setActiveRoom(roomName) {
    if (!findRoom(roomName)) return
    activeRoom = roomName
  }
}
