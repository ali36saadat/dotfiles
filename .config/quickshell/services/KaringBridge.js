const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const servicePath = path.join(os.homedir(), ".local/share/com.nebula.karing/service.json");
const subscriptionPath = path.join(os.homedir(), ".local/share/com.nebula.karing/karing_subscribe.json");
const selectionPath = path.join(os.homedir(), ".config/quickshell/karing-selection.json");

function runBusctl(args) {
    const result = spawnSync("/usr/bin/busctl", ["--user", ...args], {
        encoding: "utf8",
        timeout: 3000
    });
    if (result.status !== 0)
        throw new Error("Karing tray interface is unavailable");
    return result.stdout;
}

function findTray() {
    const services = runBusctl(["list", "--no-pager"]);
    const ownerLine = services.split("\n").find(line => /\bkaring\b/i.test(line));
    if (!ownerLine)
        throw new Error("Karing is not running");
    const owner = ownerLine.trim().split(/\s+/)[0];
    const tree = runBusctl(["tree", owner]);
    const menuLine = tree.split("\n").find(line => /\/org\/ayatana\/NotificationItem\/[^\s]+\/Menu/.test(line));
    if (!menuLine)
        throw new Error("Karing tray menu is unavailable");
    const menuPath = menuLine.trim().split(/\s+/).pop();
    const layout = runBusctl(["call", owner, menuPath, "com.canonical.dbusmenu", "GetLayout", "iias", "0", "8", "0"]);
    const items = [];
    const labelPattern = /(\d+)\s+\d+\s+"label"\s+s\s+"([^"]*)"/g;
    let match;
    while ((match = labelPattern.exec(layout)) !== null) {
        const label = match[2].trim();
        if (label)
            items.push({ id: Number(match[1]), label });
    }
    const connectItem = items.find(item => /^connect$/i.test(item.label));
    const disconnectItem = items.find(item => /^disconnect$/i.test(item.label));
    return {
        owner,
        menuPath,
        connected: Boolean(disconnectItem),
        action: disconnectItem || connectItem
    };
}

function controlConfig() {
    const config = JSON.parse(fs.readFileSync(servicePath, "utf8"));
    if (!Number.isInteger(config.control_port) || !config.secret)
        throw new Error("Karing controller is not configured");
    return { port: config.control_port, token: config.secret };
}

async function requestController(method, endpoint, body, timeout = 4000) {
    const config = controlConfig();
    const response = await fetch(`http://127.0.0.1:${config.port}${endpoint}`, {
        method,
        headers: {
            Authorization: `Bearer ${config.token}`,
            ...(body === undefined ? {} : { "Content-Type": "application/json" })
        },
        body: body === undefined ? undefined : JSON.stringify(body),
        signal: AbortSignal.timeout(timeout)
    });
    if (!response.ok)
        throw new Error(`Karing controller returned ${response.status}`);
    if (response.status === 204)
        return null;
    return response.json();
}

async function readGroups() {
    const result = await requestController("GET", "/proxies");
    const groups = [];
    for (const [name, proxy] of Object.entries(result.proxies || {})) {
        if (!Array.isArray(proxy.all) || !["Selector", "Fallback", "LoadBalance"].includes(proxy.type))
            continue;
        groups.push({ name, type: proxy.type, selected: proxy.now || "", options: proxy.all });
    }
    return groups;
}

function readLocalProfiles() {
    const data = JSON.parse(fs.readFileSync(subscriptionPath, "utf8"));
    return (data.items || [])
        .filter(profile => profile.enable && Array.isArray(profile.servers) && profile.servers.length > 0)
        .map(profile => ({
            id: profile.groupid,
            name: profile.remark || "Profile",
            options: profile.servers.map(server => ({
                name: server.tag,
                latency: server.latency || ""
            }))
        }));
}

function readSavedSelection() {
    try {
        return JSON.parse(fs.readFileSync(selectionPath, "utf8"));
    } catch (_) {
        return null;
    }
}

function saveSelection(selection) {
    fs.mkdirSync(path.dirname(selectionPath), { recursive: true, mode: 0o700 });
    fs.writeFileSync(selectionPath, JSON.stringify(selection), { mode: 0o600 });
}

async function applySelection(selection, liveGroups) {
    if (!selection)
        return false;
    const match = liveGroups.find(group => group.options.includes(selection.option));
    if (!match || match.selected === selection.option)
        return false;
    await requestController("PUT", `/proxies/${encodeURIComponent(match.name)}`, { name: selection.option });
    return true;
}

async function pingOption(option) {
    const query = new URLSearchParams({
        timeout: "5000",
        url: "https://www.gstatic.com/generate_204"
    });
    const result = await requestController("GET", `/proxies/${encodeURIComponent(option)}/delay?${query}`, undefined, 6500);
    return Number(result.delay);
}

async function pingProfile(profileId) {
    const profile = readLocalProfiles().find(item => item.id === profileId);
    if (!profile)
        throw new Error("Profile was not found");

    const results = new Array(profile.options.length);
    let next = 0;
    async function worker() {
        while (next < profile.options.length) {
            const index = next++;
            const option = profile.options[index].name;
            try {
                results[index] = { option, delay: await pingOption(option), error: "" };
            } catch (_) {
                results[index] = { option, delay: null, error: "Failed" };
            }
        }
    }

    await Promise.all(Array.from({ length: Math.min(12, profile.options.length) }, worker));
    return results;
}

async function main() {
    const [operation, ...args] = process.argv.slice(2);

    if (operation === "status") {
        let tray;
        try {
            tray = findTray();
        } catch (error) {
            tray = { connected: false, error: error.message };
        }
        let liveGroups = [];
        let apiAvailable = false;
        try {
            liveGroups = await readGroups();
            apiAvailable = true;
        } catch (_) {}
        const pendingSelection = readSavedSelection();
        if (apiAvailable && pendingSelection) {
            try {
                const applied = await applySelection(pendingSelection, liveGroups);
                if (applied)
                    liveGroups = await readGroups();
            } catch (_) {}
        }
        const profiles = readLocalProfiles();
        const globalGroup = liveGroups.find(group => group.name === "GLOBAL") || liveGroups[0];
        for (const profile of profiles) {
            for (const option of profile.options) {
                option.selected = pendingSelection
                    ? pendingSelection.option === option.name
                    : Boolean(globalGroup && globalGroup.selected === option.name);
            }
        }
        console.log(JSON.stringify({
            available: !tray.error,
            connected: tray.connected,
            apiAvailable,
            profiles
        }));
        return;
    }

    if (operation === "toggle") {
        const tray = findTray();
        if (!tray.action)
            throw new Error("Karing connection action is unavailable");
        runBusctl([
            "call", tray.owner, tray.menuPath, "com.canonical.dbusmenu", "Event",
            "isvu", String(tray.action.id), "clicked", "s", "", "0"
        ]);
        console.log(JSON.stringify({ ok: true }));
        return;
    }

    if (operation === "select") {
        const group = args[0];
        const option = args[1];
        if (!group || !option)
            throw new Error("Missing profile or server");
        const selection = { profile: group, option };
        saveSelection(selection);
        let applied = false;
        try {
            applied = await applySelection(selection, await readGroups());
        } catch (_) {}
        console.log(JSON.stringify({ ok: true, pending: !applied }));
        return;
    }

    if (operation === "ping") {
        const option = args[0];
        if (!option)
            throw new Error("Missing server");
        const delay = await pingOption(option);
        console.log(JSON.stringify({ ok: true, option, delay }));
        return;
    }

    if (operation === "ping-all") {
        const profileId = args[0];
        if (!profileId)
            throw new Error("Missing profile");
        const results = await pingProfile(profileId);
        console.log(JSON.stringify({ ok: true, results }));
        return;
    }

    throw new Error("Unknown Karing operation");
}

main().catch(error => {
    console.log(JSON.stringify({ ok: false, error: error.message }));
    process.exitCode = 1;
});