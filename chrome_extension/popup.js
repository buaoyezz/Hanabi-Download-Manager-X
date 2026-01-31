const statusText = document.getElementById("status-text");
const statusDot = document.getElementById("status-dot");
const extStatus = document.getElementById("ext-status");
const toggleButton = document.getElementById("toggle-button");
const extVersion = document.getElementById("ext-version");

let isExtensionEnabled = true;

async function updateUI() {
    return new Promise((resolve) => {
        chrome.storage.local.get(["isConnected", "shouldDisableExtension"], (data) => {
            console.log("Storage data:", data);
            
            const connected = data.isConnected === true;
            const disabled = data.shouldDisableExtension === true;
            
            isExtensionEnabled = !disabled;
            
            console.log("UI Update - Connected:", connected, "Enabled:", isExtensionEnabled);
            
            if (connected) {
                statusText.textContent = "Connected";
                statusDot.classList.remove("disconnected");
                statusDot.classList.add("connected");
            } else {
                statusText.textContent = "Disconnected";
                statusDot.classList.remove("connected");
                statusDot.classList.add("disconnected");
            }
            
            if (isExtensionEnabled) {
                extStatus.textContent = "Enabled";
                toggleButton.textContent = "Disable Extension";
                toggleButton.className = "button button-enabled";
            } else {
                extStatus.textContent = "Disabled";
                toggleButton.textContent = "Enable Extension";
                toggleButton.className = "button button-disabled";
            }
            
            resolve();
        });
    });
}

function forceCheckConnection() {
    chrome.runtime.sendMessage({ action: 'checkConnection' }, () => {
        console.log("Forced connection check");
    });
}

toggleButton.addEventListener("click", () => {
    const newState = !isExtensionEnabled;
    chrome.storage.local.set({ shouldDisableExtension: !newState }, () => {
        console.log(`Extension ${newState ? "enabled" : "disabled"}`);
        updateUI();
    });
});

chrome.storage.onChanged.addListener((changes, areaName) => {
    console.log("Storage changed:", changes, areaName);
    if (areaName === 'local' && changes.isConnected) {
        console.log("Connection status changed to:", changes.isConnected.newValue);
        updateUI();
    }
});

async function init() {
    const version = chrome.runtime.getManifest().version;
    extVersion.textContent = `v${version}`;
    
    if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
        document.body.classList.add('dark-mode');
    }
    
    console.log("Popup initialized");
    
    await updateUI();
    
    forceCheckConnection();
    
    setTimeout(async () => {
        console.log("Delayed update");
        await updateUI();
    }, 300);
}

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
} else {
    init();
}

window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (event) => {
    document.body.classList.toggle('dark-mode', event.matches);
});
