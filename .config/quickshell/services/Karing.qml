pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

QtObject {
    id: karing

    property bool polling: false
    property bool available: false
    property bool connected: false
    property bool apiAvailable: false
    property bool busy: false
    property string message: ""
    property string _operation: ""
    property var profiles: []
    property var pingResults: ({})

    readonly property string summary: !available ? "Not running" : connected ? "Connected" : "Disconnected"
    readonly property bool pinging: busy && (_operation === "ping" || _operation === "ping-all")
    readonly property string activeProfile: {
        for (var i = 0; i < profiles.length; i++)
            for (var j = 0; j < profiles[i].options.length; j++)
                if (profiles[i].options[j].selected)
                    return profiles[i].options[j].name;
        return "";
    }

    readonly property string _bridgePath: Qt.resolvedUrl("KaringBridge.js").toString().replace(/^file:\/\//, "")

    function refresh() {
        if (busy)
            return;
        _run("status", []);
    }

    function toggle() {
        if (!available || busy)
            return;
        message = "";
        _run("toggle", []);
    }

    function selectProfile(group, profile) {
        if (busy || !group || !profile)
            return;
        message = "";
        _run("select", [group, profile]);
    }

    function pingProfile(profile) {
        if (!apiAvailable || busy || !profile)
            return;
        message = "";
        _run("ping", [profile]);
    }

    function pingAll(profileId) {
        if (!apiAvailable || busy || !profileId)
            return;
        message = "";
        _run("ping-all", [profileId]);
    }

    function _run(operation, args) {
        if (busy || _runner.running)
            return;
        _operation = operation;
        busy = operation !== "status";
        var command = ["/usr/bin/node", _bridgePath, operation];
        for (var i = 0; i < args.length; i++)
            command.push(args[i]);
        _runner.command = command;
        _runner.running = true;
    }

    function _handleOutput(output) {
        var result;
        try {
            result = JSON.parse("" + output);
        } catch (e) {
            message = "Could not read Karing response.";
            return;
        }
        if (!result.ok && _operation !== "status") {
            message = result.error || "Karing action failed.";
            return;
        }
        if (_operation === "status") {
            if (available !== result.available)
                available = result.available;
            if (connected !== result.connected)
                connected = result.connected;
            if (apiAvailable !== result.apiAvailable)
                apiAvailable = result.apiAvailable;
            var nextProfiles = result.profiles || [];
            if (JSON.stringify(profiles) !== JSON.stringify(nextProfiles))
                profiles = nextProfiles;
        } else if (_operation === "ping" && result.ok) {
            var updatedResults = Object.assign({}, pingResults);
            updatedResults[result.option] = result.delay;
            pingResults = updatedResults;
        } else if (_operation === "ping-all" && result.ok) {
            var allResults = Object.assign({}, pingResults);
            for (var i = 0; i < result.results.length; i++)
                allResults[result.results[i].option] = result.results[i].delay === null ? result.results[i].error : result.results[i].delay;
            pingResults = allResults;
        }
    }

    property Process _runner: Process {
        stdout: StdioCollector {
            onStreamFinished: karing._handleOutput(text)
        }
        onExited: code => {
            var operation = karing._operation;
            if (operation !== "status")
                karing.busy = false;
            if (code !== 0 && operation !== "status" && !karing.message.length)
                karing.message = "Karing action failed.";
            if (operation !== "status")
                karing._settle.restart();
        }
    }

    property Timer _settle: Timer {
        interval: 700
        onTriggered: karing.refresh()
    }

    property Timer _tick: Timer {
        interval: 8000
        repeat: true
        running: karing.polling
        triggeredOnStart: true
        onTriggered: karing.refresh()
    }

    Component.onCompleted: refresh()
}