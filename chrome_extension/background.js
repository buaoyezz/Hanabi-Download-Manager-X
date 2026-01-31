let isConnected = false;
let shouldDisableExtension = false;
let heartbeatInterval = null;
const API_BASE_URL = "http://127.0.0.1:9710";

function checkConnection() {
    fetch(`${API_BASE_URL}/health`)
        .then(response => response.json())
        .then(data => {
            if (data.status === "ok") {
                updateConnectionStatus(true);
            } else {
                updateConnectionStatus(false);
            }
        })
        .catch(error => {
            console.log("Connection check failed:", error);
            updateConnectionStatus(false);
        });
}

function updateConnectionStatus(connected) {
    isConnected = connected;
    updateBadge(connected ? "connected" : "disconnected");
    updateStatus(connected);
}

function updateBadge(status) {
    const badgeColor = (status === "connected") ? "green" : "pink";
    const badgeText = (status === "connected") ? "√" : "×";
    chrome.action.setBadgeBackgroundColor({ color: badgeColor });
    chrome.action.setBadgeText({ text: badgeText });
}

function updateStatus(connected) {
    chrome.storage.local.set({ isConnected: connected }, () => {
        console.log(`Status updated: ${connected ? "Connected" : "Disconnected"}`);
    });
}

function startHeartbeat() {
    if (!heartbeatInterval) {
        heartbeatInterval = setInterval(() => {
            checkConnection();
        }, 5000);
    }
}

function stopHeartbeat() {
    if (heartbeatInterval) {
        clearInterval(heartbeatInterval);
        heartbeatInterval = null;
    }
}

let requestHeadersMap = new Map();

chrome.webRequest.onBeforeSendHeaders.addListener(
    (details) => {
        const requestHeadersDict = details.requestHeaders.reduce((acc, header) => {
            acc[header.name.toLowerCase()] = header.value;
            return acc;
        }, {});

        requestHeadersMap.set(details.url, requestHeadersDict);
    },
    {
        urls: ["<all_urls>"],
        types: ["main_frame", "sub_frame", "xmlhttprequest", "other"],
    },
    ["requestHeaders", "extraHeaders"]
);

chrome.downloads.onDeterminingFilename.addListener((downloadItem) => {
    if (downloadItem.state === "in_progress") {
        chrome.storage.local.get(["shouldDisableExtension"], (result) => {
            if (!result.shouldDisableExtension && isConnected) {
                console.log("Download started:", downloadItem);
                if (downloadItem.finalUrl.startsWith("http")) {
                    chrome.downloads.cancel(downloadItem.id);

                    const requestHeaders = requestHeadersMap.get(downloadItem.finalUrl) || {};

                    const downloadData = {
                        url: downloadItem.finalUrl,
                        filename: downloadItem.filename,
                        referer: downloadItem.referrer || requestHeaders['referer'] || "",
                        user_agent: requestHeaders['user-agent'] || "",
                        cookies: requestHeaders['cookie'] || "",
                        headers: requestHeaders,
                        from_browser: true
                    };

                    console.log("Sending download to Hanabi:", downloadData);

                    sendDownloadToHanabi(downloadData);

                    requestHeadersMap.clear();
                }
            }
        });
    }
});

function sendDownloadToHanabi(downloadData) {
    if (isConnected) {
        fetch(`${API_BASE_URL}/download/add`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(downloadData)
        })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                console.log("Download added successfully:", data.data);
                if (chrome.notifications && chrome.notifications.create) {
                    chrome.notifications.create({
                        type: 'basic',
                        iconUrl: 'icon128.png',
                        title: 'Hanabi Download ManagerX',
                        message: 'Download task added successfully!'
                    });
                }
            } else {
                console.error("Failed to add download:", data.error);
            }
        })
        .catch(error => {
            console.error("Error sending download:", error);
        });
    } else {
        console.error("Not connected to Hanabi Download ManagerX");
    }
}

chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (request.action === 'checkConnection') {
        checkConnection();
        sendResponse({ status: 'checking' });
    }
    return true;
});

checkConnection();
startHeartbeat();

chrome.storage.local.get(["shouldDisableExtension"], (result) => {
    shouldDisableExtension = result.shouldDisableExtension || false;
    console.log("Extension disable status:", shouldDisableExtension);
});
