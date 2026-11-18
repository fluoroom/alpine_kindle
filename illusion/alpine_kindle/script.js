/*
 * Alpine Linux for Kindle - Illusion app.
 * Runs on Mesquite's WebKit (approx. Safari 5 / WebKit 533), so this file is
 * intentionally ES5 and avoids fetch(), Promise, flexbox-only assumptions, etc.
 */

var APP_ID = "com.fluoroom.alpinekindle";
var APP_VERSION = "2.2.0";
var APP_DIR = "/mnt/us/documents/alpine_kindle";
var STATUS_URL = "file:///mnt/us/alpine/illusion/status.txt";
var LOG_URL = "file:///mnt/us/alpine/illusion/action.log";
var POLL_MS = 2000;

var state = {
    initialized: false,
    missing: true,
    busy: false,
    action: "",
    message: "",
    progress: 0,
    alpine: false,
    home: false,
    running: false,
    kterm: false,
    kpm: false,
    utild: false,
    kual: false,
    updated: false,
    appVersion: "",
    freeMb: "",
    lastProbe: ""
};

var pollInFlight = false;
var optimisticUntil = 0;
var lastLaunch = 0;
var toastTimer = null;
var confirmCallback = null;
var updateClearRequested = false;

/* ------------------------------------------------------------------ */
/* Small helpers                                                       */
/* ------------------------------------------------------------------ */

function byId(id) {
    return document.getElementById(id);
}

function show(el) {
    if (el && el.style.display !== "block") {
        el.style.display = "block";
    }
}

function hide(el) {
    if (el && el.style.display !== "none") {
        el.style.display = "none";
    }
}

function setText(id, value) {
    var el = byId(id);
    var text = String(value);
    if (el && el.textContent !== text) {
        el.textContent = text;
    }
}

function trim(value) {
    return String(value).replace(/^\s+|\s+$/g, "");
}

function parseStatus(raw) {
    var result = {};
    var lines = String(raw).replace(/\r/g, "").split("\n");
    var i;
    var pos;
    for (i = 0; i < lines.length; i++) {
        pos = lines[i].indexOf("=");
        if (pos > 0) {
            result[lines[i].substring(0, pos)] = lines[i].substring(pos + 1);
        }
    }
    return result;
}

function kindleObject() {
    try {
        if (window.kindle) {
            return window.kindle;
        }
        if (window.top && window.top.kindle) {
            return window.top.kindle;
        }
    } catch (e) {
        return null;
    }
    return null;
}

function timeString() {
    var d = new Date();
    var h = d.getHours();
    var m = d.getMinutes();
    var s = d.getSeconds();
    h = h < 10 ? "0" + h : "" + h;
    m = m < 10 ? "0" + m : "" + m;
    s = s < 10 ? "0" + s : "" + s;
    return h + ":" + m + ":" + s;
}

function toast(message) {
    var el = byId("toast");
    if (!el) {
        return;
    }
    el.textContent = message;
    show(el);
    if (toastTimer) {
        window.clearTimeout(toastTimer);
    }
    toastTimer = window.setTimeout(function () {
        hide(el);
        toastTimer = null;
    }, 3200);
}

/* ------------------------------------------------------------------ */
/* File reading (iframe trick used by other Illusion apps)             */
/* ------------------------------------------------------------------ */

function readTextFile(url, callback) {
    var iframe = document.createElement("iframe");
    var finished = false;
    var timer = null;

    function cleanup() {
        if (timer) {
            window.clearTimeout(timer);
            timer = null;
        }
        if (iframe.parentNode) {
            iframe.parentNode.removeChild(iframe);
        }
    }

    function finish(text) {
        if (finished) {
            return;
        }
        finished = true;
        cleanup();
        callback(text);
    }

    iframe.style.position = "absolute";
    iframe.style.left = "-9999px";
    iframe.style.top = "0";
    iframe.style.width = "10px";
    iframe.style.height = "10px";
    iframe.style.border = "0";

    iframe.onload = function () {
        var doc = null;
        var text = "";
        try {
            doc = iframe.contentDocument || iframe.contentWindow.document;
            if (doc && doc.body) {
                text = doc.body.textContent || doc.body.innerText || "";
                if (!text && doc.body.innerHTML) {
                    text = doc.body.innerHTML
                        .replace(/<[^>]+>/g, "")
                        .replace(/&lt;/g, "<")
                        .replace(/&gt;/g, ">")
                        .replace(/&amp;/g, "&");
                }
            }
        } catch (e) {
            text = "";
        }
        if (text && text.indexOf("ERR_FILE_NOT_FOUND") !== -1) {
            text = "";
        }
        finish(text);
    };

    iframe.onerror = function () {
        finish("");
    };

    try {
        // A fragment makes the load unique so WebKit does not serve a cached
        // copy of the status/log file. Fragments are not part of the path.
        iframe.src = url + "#" + new Date().getTime();
    } catch (e) {
        finish("");
        return;
    }

    document.body.appendChild(iframe);

    // A missing file does not always fire onload; don't block the UI.
    timer = window.setTimeout(function () {
        finish("");
    }, 2500);
}

/* ------------------------------------------------------------------ */
/* Status polling                                                      */
/* ------------------------------------------------------------------ */

function pollStatus() {
    if (pollInFlight) {
        return;
    }
    pollInFlight = true;

    readTextFile(STATUS_URL, function (statusText) {
        readTextFile(LOG_URL, function (logText) {
            pollInFlight = false;
            applyStatus(statusText);
            applyLog(logText);
        });
    });
}

function applyStatus(raw) {
    var data = parseStatus(raw);
    var now = new Date().getTime();

    if (!data.app_version && !data.last_probe && !data.app_installed) {
        state.missing = true;
        state.busy = false;
        state.action = "";
        state.message = "";
        state.alpine = false;
        state.home = false;
        state.running = false;
        state.kterm = false;
        state.kpm = false;
        state.utild = false;
        state.kual = false;
        state.updated = false;
        state.freeMb = "";
        state.initialized = true;
        render();
        return;
    }

    state.initialized = true;
    state.missing = false;
    state.busy = data.busy === "1";
    state.action = data.action || "";
    state.message = data.message || "";
    state.progress = parseInt(data.progress, 10);
    if (isNaN(state.progress)) {
        state.progress = 0;
    }
    state.alpine = data.alpine === "1";
    state.home = data.home === "1";
    state.running = data.running === "1";
    state.kterm = data.kterm === "1";
    state.kpm = data.kpm === "1";
    state.utild = data.utild === "1";
    state.kual = data.kual === "1";
    state.updated = data.updated === "1";
    state.appVersion = data.app_version || "";
    state.freeMb = data.free_mb || "";
    state.lastProbe = data.last_probe || "";

    // Keep the optimistic lock for a few seconds while Utild picks up the
    // command; otherwise the buttons flash back to enabled.
    if (!state.busy && now < optimisticUntil) {
        state.busy = true;
        state.progress = Math.max(state.progress, 5);
    }

    // The update flag survives the reload (it lives in the status file), so
    // acknowledge it once the running JS version matches the new app.
    if (state.updated && !state.busy && !versionMismatch() && !updateClearRequested) {
        updateClearRequested = true;
        sendCommand("probe.sh --clear-updated");
    }

    render();
}

function applyLog(raw) {
    var el = byId("log");
    var text;
    if (!el || !raw) {
        return;
    }
    text = String(raw).replace(/\r/g, "");
    if (trim(text) === "") {
        return;
    }
    if (text.length > 7000) {
        text = text.substring(text.length - 7000);
    }
    if (el.textContent !== text) {
        el.textContent = text;
        el.scrollTop = el.scrollHeight;
    }
    setText("log-time", timeString());
}

/* ------------------------------------------------------------------ */
/* Rendering                                                           */
/* ------------------------------------------------------------------ */

function setDisabled(id, disabled) {
    var el = byId(id);
    var value = !!disabled;
    if (el && el.disabled !== value) {
        el.disabled = value;
    }
}

function formatFree(value) {
    var n = parseInt(value, 10);
    if (isNaN(n)) {
        return "\u2014";
    }
    if (n >= 1024) {
        return (Math.round((n / 1024) * 10) / 10) + " GB";
    }
    return n + " MB";
}

function versionMismatch() {
    return state.appVersion !== "" &&
        state.appVersion !== "unknown" &&
        state.appVersion !== APP_VERSION;
}

function bannerText() {
    var parts = [];

    if (!state.initialized) {
        return "";
    }

    if (state.missing) {
        parts.push("Setup incomplete. Close this app and tap the Alpine item in your Library.");
        return parts.join(" ");
    }

    if (!state.utild) {
        parts.push("Terminal runtime offline. Connect Wi-Fi, close this app, then tap the Alpine item in your Library.");
    }

    if (!state.kterm) {
        if (state.kpm) {
            parts.push("kterm is not installed; tap Install kterm below.");
        } else {
            parts.push("kterm is not installed and KPM was not found; install one of them to use the terminal.");
        }
    }

    if (state.updated || versionMismatch()) {
        parts.push("Update installed \u2014 tap Reload to apply it.");
    }

    return parts.join(" ");
}

function render() {
    var busy = state.busy;
    var canRun = state.utild && !busy;
    var title = "Checking\u2026";
    var detail = state.message || "";
    var dot = "dot dot-unknown";
    var banner = bannerText();

    setText("version", "v" + APP_VERSION);
    setText("footer-version", "v" + APP_VERSION);

    if (!state.initialized) {
        title = "Checking\u2026";
        detail = "Reading device state\u2026";
        dot = "dot dot-unknown";
    } else if (state.missing) {
        title = "Setup needed";
        detail = "Tap \"Alpine Linux\" in your Library to finish setup.";
        dot = "dot dot-off";
    } else if (!state.utild) {
        title = "Runtime offline";
        detail = state.message || "Utild is not running.";
        dot = "dot dot-off";
    } else if (busy) {
        title = state.action || "Working\u2026";
        dot = "dot dot-busy";
    } else if (state.running) {
        title = "Alpine is running";
        dot = "dot dot-ok";
    } else if (state.alpine) {
        title = "Ready";
        dot = "dot dot-ok";
    } else {
        title = "Alpine is not installed";
        dot = "dot dot-off";
    }

    if (!detail) {
        if (state.alpine) {
            detail = "Installed" + (state.home ? " with home data" : " without home data") + ".";
        } else {
            detail = "Deploy an image to get started.";
        }
    }

    setText("state-title", title);
    setText("state-detail", detail);
    var dotEl = byId("state-dot");
    if (dotEl && dotEl.className !== dot) {
        dotEl.className = dot;
    }
    setText("free", formatFree(state.freeMb));

    var bannerEl = byId("banner");
    if (banner) {
        setText("banner-text", banner);
        show(bannerEl);
    } else {
        hide(bannerEl);
    }

    var progressWrap = byId("progress-wrap");
    if (busy) {
        var pct = state.progress;
        if (isNaN(pct) || pct < 0) {
            pct = 0;
        }
        if (pct > 100) {
            pct = 100;
        }
        if (pct < 4) {
            pct = 4;
        }
        show(progressWrap);
        var width = pct + "%";
        if (byId("progress-bar").style.width !== width) {
            byId("progress-bar").style.width = width;
        }
    } else {
        hide(progressWrap);
    }

    setDisabled("btn-deploy-release", !canRun || state.alpine);
    setDisabled("btn-deploy-nightly", !canRun || state.alpine);
    setDisabled("btn-shell", !canRun || !state.alpine || !state.kterm);
    setDisabled("btn-xfce", !canRun || !state.alpine || !state.kterm);
    setDisabled("btn-fluxbox", !canRun || !state.alpine || !state.kterm);
    setDisabled("btn-installer", !canRun || !state.alpine || !state.kterm);
    setDisabled("btn-stop", !canRun);
    setDisabled("btn-delete-root", !canRun || !state.alpine);
    setDisabled("btn-delete-home", !canRun || !state.home);
    setDisabled("btn-update", !canRun);
    setDisabled("btn-install-kterm", !canRun || !state.kpm);
    setDisabled("btn-fish", !canRun || !state.alpine || state.running);
    setDisabled("btn-remove-kual", !canRun || !state.kual);
    setDisabled("btn-refresh", !state.utild || busy);

    if (state.kterm) {
        hide(byId("btn-install-kterm"));
    } else {
        show(byId("btn-install-kterm"));
        setText("kterm-desc", state.kpm ? "Install kterm through KPM" : "KPM not found; install kterm manually");
    }

    if (!state.alpine) {
        setText("fish-desc", "Deploy Alpine first");
    } else if (state.running) {
        setText("fish-desc", "Stop Alpine before installing fish");
    } else {
        setText("fish-desc", "Make fish the default shell");
    }

    if (state.kual) {
        show(byId("btn-remove-kual"));
    } else {
        hide(byId("btn-remove-kual"));
    }

    if (state.updated || versionMismatch()) {
        show(byId("btn-reload"));
    } else {
        hide(byId("btn-reload"));
    }
}

/* ------------------------------------------------------------------ */
/* Commands                                                            */
/* ------------------------------------------------------------------ */

function sendCommand(command) {
    var k = kindleObject();
    var full = "sh " + APP_DIR + "/bin/" + command;

    if (!k || !k.messaging || !k.messaging.sendStringMessage) {
        toast("Kindle bridge unavailable. Open the app from your Library.");
        return false;
    }

    try {
        k.messaging.sendStringMessage("com.kindlemodding.utild", "runCMD", full);
        return true;
    } catch (e) {
        toast("Could not send command to Utild.");
        return false;
    }
}

function runAction(command, label) {
    if (state.busy) {
        return;
    }
    if (!sendCommand(command)) {
        return;
    }

    state.busy = true;
    state.action = label;
    state.message = "Starting\u2026";
    state.progress = 5;
    optimisticUntil = new Date().getTime() + 4000;
    render();

    window.setTimeout(pollStatus, 800);
}

function launchSession(command, message) {
    var now = new Date().getTime();
    if (now - lastLaunch < 4000) {
        return;
    }
    lastLaunch = now;
    if (!sendCommand(command)) {
        return;
    }
    toast(message);
    window.setTimeout(pollStatus, 1200);
}

/* ------------------------------------------------------------------ */
/* Confirmation dialog                                                 */
/* ------------------------------------------------------------------ */

function closeConfirm() {
    hide(byId("overlay"));
    confirmCallback = null;
}

function askConfirm(title, message, callback) {
    setText("confirm-title", title);
    setText("confirm-text", message);
    confirmCallback = callback;
    show(byId("overlay"));
}

/* ------------------------------------------------------------------ */
/* Event wiring                                                        */
/* ------------------------------------------------------------------ */

function goHome() {
    var k = kindleObject();
    if (k && k.appmgr && k.appmgr.start) {
        try {
            k.appmgr.start("com.lab126.booklet.home");
            return;
        } catch (e) {
            /* fall through */
        }
    }
    toast("Use the Library/Home control to leave the app.");
}

function wireEvents() {
    byId("btn-home").onclick = goHome;

    byId("btn-deploy-release").onclick = function () {
        askConfirm(
            "Deploy Alpine",
            "Download and install the latest Alpine release?\n\n" +
            "This creates the root filesystem in /mnt/us/alpine. Your home data is not touched. " +
            "Wi-Fi is required and the download can take a while.",
            function () {
                var fish = byId("opt-fish").checked ? " --fish" : "";
                runAction("get.sh --release --yes" + fish, "Deploy Alpine");
            }
        );
    };

    byId("btn-deploy-nightly").onclick = function () {
        askConfirm(
            "Deploy nightly build",
            "Download and install the latest NIGHTLY Alpine build?\n\n" +
            "Nightly builds are untested and may be unstable. Wi-Fi is required.",
            function () {
                var fish = byId("opt-fish").checked ? " --fish" : "";
                runAction("get.sh --nightly --yes" + fish, "Deploy Alpine (nightly)");
            }
        );
    };

    byId("btn-shell").onclick = function () {
        launchSession("launch_kterm.sh start.sh", "Opening Alpine shell\u2026");
    };

    byId("btn-xfce").onclick = function () {
        launchSession("launch_kterm.sh xfce.sh", "Opening XFCE desktop\u2026");
    };

    byId("btn-fluxbox").onclick = function () {
        launchSession("launch_kterm.sh fluxbox.sh", "Opening Fluxbox desktop\u2026");
    };

    byId("btn-installer").onclick = function () {
        launchSession("launch_kterm.sh gui_installer.sh", "Opening GUI installer\u2026");
    };

    byId("btn-install-kterm").onclick = function () {
        runAction("install_kterm.sh", "Install kterm");
    };

    byId("btn-fish").onclick = function () {
        askConfirm(
            "Install fish shell",
            "Install fish in Alpine and make it the default shell for root and the alpine user?\n\n" +
            "Alpine must be stopped. Wi-Fi is required inside Alpine for apk.",
            function () {
                runAction("fish.sh --yes", "Install fish shell");
            }
        );
    };

    byId("btn-stop").onclick = function () {
        runAction("stop.sh", "Stop Alpine");
    };

    byId("btn-delete-root").onclick = function () {
        askConfirm(
            "Delete Alpine root",
            "Delete the Alpine root filesystem?\n\n" +
            "Your home.ext4 (user data and settings) is kept. You can deploy a new image afterwards.",
            function () {
                runAction("delete.sh --yes", "Delete Alpine root");
            }
        );
    };

    byId("btn-delete-home").onclick = function () {
        askConfirm(
            "Delete home data",
            "Delete the Alpine home filesystem?\n\n" +
            "All files, settings and installed desktop packages in home.ext4 will be lost. " +
            "This cannot be undone.",
            function () {
                runAction("deletehome.sh --yes", "Delete Alpine home");
            }
        );
    };

    byId("btn-update").onclick = function () {
        askConfirm(
            "Update this app",
            "Download and install the latest version of Alpine Manager?\n\n" +
            "Your Alpine images are not touched. Wi-Fi is required.",
            function () {
                runAction("update.sh", "Update app");
            }
        );
    };

    byId("btn-remove-kual").onclick = function () {
        askConfirm(
            "Remove old KUAL extension",
            "Remove the old KUAL extension and its library shortcut?\n\n" +
            "Alpine data in /mnt/us/alpine is kept.",
            function () {
                runAction("remove_kual.sh", "Remove KUAL extension");
            }
        );
    };

    byId("btn-reload").onclick = function () {
        window.location.reload();
    };

    byId("btn-refresh").onclick = function () {
        if (!sendCommand("probe.sh")) {
            return;
        }
        toast("Refreshing status\u2026");
        window.setTimeout(pollStatus, 500);
    };

    byId("confirm-cancel").onclick = closeConfirm;

    byId("confirm-ok").onclick = function () {
        var cb = confirmCallback;
        closeConfirm();
        if (cb) {
            cb();
        }
    };
}

/* ------------------------------------------------------------------ */
/* Boot                                                                */
/* ------------------------------------------------------------------ */

function hookAppResume() {
    var k = kindleObject();
    if (k && k.appmgr) {
        try {
            k.appmgr.ongo = function () {
                pollStatus();
            };
        } catch (e) {
            /* not supported on this firmware */
        }
    }
}

function init() {
    wireEvents();
    hookAppResume();
    render();
    pollStatus();
    window.setInterval(pollStatus, POLL_MS);
}

if (document.addEventListener) {
    document.addEventListener("DOMContentLoaded", init, false);
} else {
    window.onload = init;
}
