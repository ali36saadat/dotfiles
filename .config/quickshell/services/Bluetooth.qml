pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

QtObject {
    id: bluetooth

    property bool polling: false
    property bool available: false
    property bool powered: false
    property bool scanning: false
    property bool _actionBusy: false
    property string message: ""
    property var devices: []
    property var _knownDevices: []
    property var _pairedAddresses: []
    property var _connectedAddresses: []
    property var _batteryByAddress: ({})
    property var _notifiedLowBattery: []
    property var _notificationQueue: []

    readonly property bool busy: _actionBusy || scanning
    readonly property int connectedCount: {
        var count = 0;
        for (var i = 0; i < devices.length; i++)
            if (devices[i].connected)
                count++;
        return count;
    }
    readonly property string summary: !available ? "Unavailable" : !powered ? "Off" : connectedCount ? connectedCount + " connected" : "On"

    function _parseDevices(output) {
        var result = [];
        var cleanOutput = ("" + output).replace(/\u001b\[[0-9;]*m/g, "");
        var lines = cleanOutput.split("\n");
        for (var i = 0; i < lines.length; i++) {
            var match = lines[i].match(/^Device\s+([0-9A-F:]+)\s+(.+)$/i);
            if (match)
                result.push({ address: match[1], name: match[2] });
        }
        return result;
    }

    function _containsAddress(addresses, address) {
        return addresses.indexOf(address) !== -1;
    }

    function _section(output, marker, nextMarker) {
        var start = output.indexOf(marker);
        if (start < 0)
            return "";
        start += marker.length;
        var end = nextMarker ? output.indexOf(nextMarker, start) : -1;
        return output.substring(start, end < 0 ? output.length : end);
    }

    function _batteryFor(address) {
        return _batteryByAddress.hasOwnProperty(address) ? _batteryByAddress[address] : null;
    }

    function _rebuildDevices() {
        var merged = {};
        for (var i = 0; i < _knownDevices.length; i++) {
            var known = _knownDevices[i];
            merged[known.address] = {
                address: known.address,
                name: known.name,
                paired: _containsAddress(_pairedAddresses, known.address),
                connected: _containsAddress(_connectedAddresses, known.address),
                battery: _batteryFor(known.address)
            };
        }
        for (var p = 0; p < _pairedAddresses.length; p++) {
            var pairedAddress = _pairedAddresses[p];
            if (!merged[pairedAddress])
                merged[pairedAddress] = { address: pairedAddress, name: pairedAddress, paired: true, connected: false, battery: _batteryFor(pairedAddress) };
        }
        for (var c = 0; c < _connectedAddresses.length; c++) {
            var connectedAddress = _connectedAddresses[c];
            if (!merged[connectedAddress])
                merged[connectedAddress] = { address: connectedAddress, name: connectedAddress, paired: false, connected: true, battery: _batteryFor(connectedAddress) };
            else
                merged[connectedAddress].connected = true;
        }
        var result = [];
        for (var address in merged)
            result.push(merged[address]);
        result.sort(function (a, b) {
            return a.name.localeCompare(b.name);
        });
        devices = result;
    }

    function _refreshBatteries() {
        if (_batteryProbe.running)
            return;
        var addresses = [];
        var candidates = _knownDevices.concat(_pairedAddresses.map(function (address) { return { address: address }; }), _connectedAddresses.map(function (address) { return { address: address }; }));
        for (var i = 0; i < candidates.length; i++) {
            if (!_containsAddress(addresses, candidates[i].address))
                addresses.push(candidates[i].address);
        }
        if (addresses.length === 0) {
            _batteryByAddress = ({});
            _rebuildDevices();
            _checkLowBattery();
            return;
        }
        var command = ["sh", "-c", "for address do printf '\\n--QS-BATTERY:%s--\\n' \"$address\"; bluetoothctl info \"$address\"; done", "qs"];
        for (var j = 0; j < addresses.length; j++)
            command.push(addresses[j]);
        _batteryProbe.command = command;
        _batteryProbe.running = true;
    }

    function _checkLowBattery() {
        var connectedLow = [];
        for (var previous = 0; previous < _notifiedLowBattery.length; previous++) {
            var previousAddress = _notifiedLowBattery[previous];
            var previousBattery = _batteryFor(previousAddress);
            if (_containsAddress(_connectedAddresses, previousAddress) && (previousBattery === null || previousBattery < 15))
                connectedLow.push(previousAddress);
        }
        for (var i = 0; i < _connectedAddresses.length; i++) {
            var address = _connectedAddresses[i];
            var battery = _batteryFor(address);
            if (battery !== null && battery < 15) {
                if (!_containsAddress(_notifiedLowBattery, address)) {
                    var device = null;
                    for (var d = 0; d < devices.length; d++)
                        if (devices[d].address === address)
                            device = devices[d];
                    _queueLowBatteryNotification(device ? device.name : address, battery);
                }
                if (!_containsAddress(connectedLow, address))
                    connectedLow.push(address);
            }
        }
        _notifiedLowBattery = connectedLow;
    }

    function _queueLowBatteryNotification(name, battery) {
        _notificationQueue.push({ name: name, battery: battery });
        _sendNextNotification();
    }

    function _sendNextNotification() {
        if (_notifier.running || _notificationQueue.length === 0)
            return;
        var item = _notificationQueue.shift();
        _notifier.command = ["notify-send", "-u", "critical", "-a", "Bluetooth", "Low battery: " + item.name, item.battery + "% remaining"];
        _notifier.running = true;
    }

    function _applyBatteryOutput(output) {
        var lines = ("" + output).replace(/\u001b\[[0-9;]*m/g, "").split("\n");
        var batteryByAddress = {};
        var currentAddress = "";
        for (var i = 0; i < lines.length; i++) {
            var marker = lines[i].match(/^--QS-BATTERY:([0-9A-F:]+)--$/i);
            if (marker) {
                currentAddress = marker[1];
                continue;
            }
            var batteryMatch = lines[i].match(/Battery Percentage:\s+(?:0x[0-9a-f]+\s+)?\((\d+)\)/i) || lines[i].match(/Battery Percentage:\s+(\d+)%?/i);
            if (currentAddress && batteryMatch)
                batteryByAddress[currentAddress] = parseInt(batteryMatch[1], 10);
        }
        _batteryByAddress = batteryByAddress;
        _rebuildDevices();
        _checkLowBattery();
    }

    function refresh() {
        if (!_deviceProbe.running)
            _deviceProbe.running = true;
    }

    function setPower(on) {
        if (!available || busy || powered === on)
            return;
        _runAction(["bluetoothctl", "power", on ? "on" : "off"]);
    }

    function togglePower() {
        setPower(!powered);
    }

    function startScan() {
        if (!available || !powered || busy)
            return;
        message = "";
        _scan.running = true;
    }

    function toggleDevice(device) {
        if (!device || !powered || busy)
            return;
        if (device.connected) {
            _runAction(["bluetoothctl", "disconnect", device.address]);
        } else if (device.paired) {
            _runAction(["bluetoothctl", "connect", device.address]);
        } else {
            _runAction(["bluetoothctl", "--agent", "NoInputNoOutput", "--timeout", "25", "pair", device.address]);
        }
    }

    function _runAction(command) {
        if (_actionBusy)
            return;
        message = "";
        _actionBusy = true;
        _action.command = command;
        _action.running = true;
    }

    property Process _deviceProbe: Process {
        command: ["sh", "-c", "bluetoothctl show; printf '\\n--QS-KNOWN--\\n'; bluetoothctl devices; printf '\\n--QS-PAIRED--\\n'; bluetoothctl devices Paired; printf '\\n--QS-CONNECTED--\\n'; bluetoothctl devices Connected"]
        stdout: StdioCollector {
            onStreamFinished: {
                var output = "" + text;
                var knownMarker = "--QS-KNOWN--";
                var pairedMarker = "--QS-PAIRED--";
                var connectedMarker = "--QS-CONNECTED--";
                var stateEnd = output.indexOf(knownMarker);
                var stateOutput = stateEnd < 0 ? output : output.substring(0, stateEnd);
                var knownOutput = bluetooth._section(output, knownMarker, pairedMarker);
                var pairedOutput = bluetooth._section(output, pairedMarker, connectedMarker);
                var connectedOutput = bluetooth._section(output, connectedMarker, "");
                var pairedRows = bluetooth._parseDevices(pairedOutput);
                var connectedRows = bluetooth._parseDevices(connectedOutput);

                bluetooth.available = stateOutput.indexOf("Controller ") !== -1;
                bluetooth.powered = /Powered:\s+yes/i.test(stateOutput);
                bluetooth._knownDevices = bluetooth._parseDevices(knownOutput);
                bluetooth._pairedAddresses = pairedRows.map(function (device) { return device.address; });
                bluetooth._connectedAddresses = connectedRows.map(function (device) { return device.address; });
                bluetooth._rebuildDevices();
                bluetooth._refreshBatteries();
            }
        }
    }

    property Process _batteryProbe: Process {
        stdout: StdioCollector {
            onStreamFinished: bluetooth._applyBatteryOutput(text)
        }
    }

    property Process _notifier: Process {
        onExited: bluetooth._sendNextNotification()
    }

    property Process _action: Process {
        onExited: code => {
            bluetooth._actionBusy = false;
            bluetooth.message = code === 0 ? "" : "Bluetooth action failed. Check pairing prompts and adapter status.";
            if (code !== 0)
                bluetooth._messageTimer.restart();
            bluetooth._settle.restart();
        }
    }

    property Process _scan: Process {
        command: ["bluetoothctl", "--timeout", "15", "scan", "on"]
        onExited: {
            bluetooth.scanning = false;
            bluetooth._settle.restart();
        }
        onRunningChanged: bluetooth.scanning = running
    }

    property Timer _scanPoll: Timer {
        interval: 1200
        repeat: true
        running: bluetooth.scanning
        onTriggered: bluetooth.refresh()
    }

    property Timer _settle: Timer {
        interval: 800
        onTriggered: bluetooth.refresh()
    }

    property Timer _messageTimer: Timer {
        interval: 6000
        onTriggered: bluetooth.message = ""
    }

    property Timer _tick: Timer {
        interval: 15000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: bluetooth.refresh()
    }

    Component.onCompleted: refresh()
}