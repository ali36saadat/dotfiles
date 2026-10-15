pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import ".."

// Default sink / source volume and mute, plus the list of real (non-stream)
// devices so the Audio page can switch outputs and inputs.
QtObject {
    id: audio

    readonly property var _sink: Pipewire.defaultAudioSink
    readonly property var _source: Pipewire.defaultAudioSource
    readonly property var _allNodes: Pipewire.nodes ? Pipewire.nodes.values : []

    // Real devices only — application streams are nodes too, but they are
    // not something you'd pick as a system output.
    readonly property var sinks: {
        var out = [];
        for (var i = 0; i < _allNodes.length; i++) {
            var n = _allNodes[i];
            if (n.isSink && !n.isStream && n.audio)
                out.push(n);
        }
        return out;
    }
    readonly property var sources: {
        var out = [];
        for (var i = 0; i < _allNodes.length; i++) {
            var n = _allNodes[i];
            if (!n.isSink && !n.isStream && n.audio)
                out.push(n);
        }
        return out;
    }
    property var appStreams: []
    property var _appVolumes: ({})

    function _refreshAppStreams() {
        var nodes = Pipewire.nodes ? Pipewire.nodes.values : [];
        var streams = [];
        var ids = [];
        for (var i = 0; i < nodes.length; i++) {
            var node = nodes[i];
            if (PwNodeType.toString(node.type) === "AudioOutStream") {
                streams.push(node);
                ids.push(node.id);
            }
        }
        var currentIds = [];
        for (var j = 0; j < appStreams.length; j++)
            currentIds.push(appStreams[j].id);
        if (ids.length !== currentIds.length || ids.some(function (id, index) { return id !== currentIds[index]; })) {
            appStreams = streams;
            var retained = {};
            for (var k = 0; k < streams.length; k++) {
                var key = "" + streams[k].id;
                if (_appVolumes.hasOwnProperty(key))
                    retained[key] = _appVolumes[key];
            }
            _appVolumes = retained;
        }
        _rememberNewAppVolumes();
    }

    function _rememberNewAppVolumes() {
        var levels = Object.assign({}, _appVolumes);
        var changed = false;
        for (var i = 0; i < appStreams.length; i++) {
            var stream = appStreams[i];
            if (!stream.ready || !stream.audio)
                continue;
            var key = "" + stream.id;
            if (levels.hasOwnProperty(key))
                continue;
            levels[key] = volume <= 0 || muted ? 1 : stream.audio.volume;
            changed = true;
        }
        if (!changed)
            return;
        _appVolumes = levels;
        _applyAppVolumes(volume, muted);
        _setSinkLevels(volume, muted);
    }

    // Volume reads need the node bound, so track the defaults plus anything
    // the device lists expose.
    property PwObjectTracker _tracker: PwObjectTracker {
        objects: {
            var o = [];
            if (audio._sink)
                o.push(audio._sink);
            if (audio._source)
                o.push(audio._source);
            for (var i = 0; i < audio.sinks.length; i++)
                o.push(audio.sinks[i]);
            for (var j = 0; j < audio.sources.length; j++)
                o.push(audio.sources[j]);
            for (var k = 0; k < audio.appStreams.length; k++)
                o.push(audio.appStreams[k]);
            return o;
        }
    }

    // Public handles on the current defaults, so pages don't reach for the
    // underscore-prefixed internals.
    readonly property var currentSink: _sink
    readonly property var currentSource: _source

    function nodeLabel(n) {
        if (!n)
            return "";
        return n.nickname || n.description || n.name || "";
    }

    function appLabel(n) {
        if (!n)
            return "";
        var props = n.properties || {};
        return props["application.name"] || props["media.name"] || nodeLabel(n);
    }

    // ── output ──────────────────────────────────────────────────
    readonly property bool ready: _sink && _sink.ready && _sink.audio
    readonly property real volume: ready ? _sink.audio.volume : 0
    readonly property bool muted: ready ? _sink.audio.muted : false
    readonly property int volumePercent: Math.round(volume * 100)
    readonly property string sinkLabel: nodeLabel(_sink)

    // ── input ───────────────────────────────────────────────────
    readonly property bool micReady: _source && _source.ready && _source.audio
    readonly property real micVolume: micReady ? _source.audio.volume : 0
    readonly property bool micMuted: micReady ? _source.audio.muted : false
    readonly property int micPercent: Math.round(micVolume * 100)
    readonly property string sourceLabel: nodeLabel(_source)

    // Fired whenever the sink volume/mute changes for any reason — the notch
    // uses this as the system volume OSD.
    signal changed(bool userDriven)
    property bool _selfChange: false

    function setVolume(v) {
        if (!ready)
            return;
        var next = Config.clamp(v, 0, 1);
        _selfChange = true;
        _applyAppVolumes(next, muted);
        _setSinkLevels(next, muted);
    }
    function toggleMute() {
        if (!ready)
            return;
        _selfChange = true;
        var next = !_sink.audio.muted;
        _applyAppVolumes(volume, next);
        _setSinkLevels(volume, next);
    }

    function _setSinkLevels(nextVolume, nextMuted) {
        if (!_sink || !_sink.ready || !_sink.audio)
            return;
        _sink.audio.volume = nextVolume;
        _sink.audio.muted = nextMuted;
    }

    function setMicVolume(v) {
        if (!micReady)
            return;
        _source.audio.volume = Config.clamp(v, 0, 1);
    }
    function toggleMicMute() {
        if (!micReady)
            return;
        _source.audio.muted = !_source.audio.muted;
    }

    function setAppVolume(node, v) {
        if (!node || !node.ready || !node.audio)
            return;
        var key = "" + node.id;
        var levels = Object.assign({}, _appVolumes);
        levels[key] = Config.clamp(v, 0, 1);
        _appVolumes = levels;
        _applyAppVolumes(volume, muted);
        _setSinkLevels(volume, muted);
    }

    function appVolume(node) {
        if (!node)
            return 0;
        var key = "" + node.id;
        if (_appVolumes.hasOwnProperty(key))
            return _appVolumes[key];
        return node.audio ? node.audio.volume : 0;
    }

    function _applyAppVolumes(masterVolume, masterMuted) {
        var levels = Object.assign({}, _appVolumes);
        var changed = false;
        for (var i = 0; i < appStreams.length; i++) {
            var stream = appStreams[i];
            if (!stream.ready || !stream.audio)
                continue;
            var key = "" + stream.id;
            if (!levels.hasOwnProperty(key)) {
                levels[key] = stream.audio.volume;
                changed = true;
            }
            stream.audio.volume = masterMuted || masterVolume <= 0 ? 0 : levels[key];
        }
        if (changed)
            _appVolumes = levels;
    }

    function setSink(node) {
        if (node)
            Pipewire.preferredDefaultAudioSink = node;
    }
    function setSource(node) {
        if (node)
            Pipewire.preferredDefaultAudioSource = node;
    }

    property Connections _sinkConn: Connections {
        target: audio.ready ? audio._sink.audio : null
        function onVolumeChanged() {
            audio.changed(audio._selfChange);
            audio._selfChange = false;
        }
        function onMutedChanged() {
            audio.changed(audio._selfChange);
            audio._selfChange = false;
        }
    }

    property Timer _streamPoll: Timer {
        interval: 1500
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: audio._refreshAppStreams()
    }

}
