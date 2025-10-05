// HDM-X Welcome Page Script
class WelcomePage {
    constructor() {
        this.extensionVersion = '2.0.0';
        this.clientVersion = 'Unknown';
        this.isConnected = false;
        // Download count removed as not needed
        
        this.init();
    }

    async init() {
        await this.loadExtensionData();
        this.updateUI();
        this.setupEventListeners();
        this.startStatusCheck();
        this.animateElements();
    }

    async loadExtensionData() {
        try {
            // Get extension version from manifest
            if (typeof chrome !== 'undefined' && chrome.runtime) {
                this.extensionVersion = chrome.runtime.getManifest().version;
            }

            // Load stored data
            if (typeof chrome !== 'undefined' && chrome.storage) {
                const result = await chrome.storage.local.get([
                    'clientVersion',
                    'isConnected'
                ]);

                this.clientVersion = result.clientVersion || 'Unknown';
                this.isConnected = result.isConnected || false;
            }
        } catch (error) {
            console.error('Failed to load extension data:', error);
        }
    }

    updateUI() {
        // Update version information
        const extensionVersionEl = document.getElementById('extension-version');
        if (extensionVersionEl) {
            extensionVersionEl.textContent = `v${this.extensionVersion}`;
        }

        const clientVersionEl = document.getElementById('client-version');
        if (clientVersionEl) {
            clientVersionEl.textContent = this.clientVersion !== 'Unknown' 
                ? `v${this.clientVersion}` 
                : '未检测到';
        }

        // Download count display removed

        // Update connection status
        this.updateConnectionStatus();
    }

    updateConnectionStatus() {
        const statusEl = document.getElementById('connection-status');
        if (!statusEl) return;

        const statusDot = statusEl.querySelector('.status-dot');
        const statusText = statusEl.querySelector('.status-text');

        if (this.isConnected) {
            statusDot.style.background = 'var(--success-color)';
            statusText.textContent = '已连接';
            statusText.style.color = 'var(--success-color)';
        } else {
            statusDot.style.background = 'var(--error-color)';
            statusDot.style.animation = 'none';
            statusText.textContent = '未连接';
            statusText.style.color = 'var(--error-color)';
        }
    }

    setupEventListeners() {
        // Listen for storage changes
        if (typeof chrome !== 'undefined' && chrome.storage) {
            chrome.storage.onChanged.addListener((changes, areaName) => {
                if (areaName === 'local') {
                    this.handleStorageChange(changes);
                }
            });
        }

        // Setup theme toggle
        this.setupThemeToggle();
        
        // Setup scroll animations
        this.setupScrollAnimations();
    }

    handleStorageChange(changes) {
        let shouldUpdate = false;

        if (changes.clientVersion) {
            this.clientVersion = changes.clientVersion.newValue;
            shouldUpdate = true;
        }

        if (changes.isConnected) {
            this.isConnected = changes.isConnected.newValue;
            shouldUpdate = true;
        }

        // Download count tracking removed

        if (shouldUpdate) {
            this.updateUI();
        }
    }

    setupThemeToggle() {
        // Detect system theme preference
        const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
        
        const updateTheme = (e) => {
            document.body.classList.toggle('dark-theme', e.matches);
        };

        mediaQuery.addListener(updateTheme);
        updateTheme(mediaQuery);
    }

    setupScrollAnimations() {
        // Intersection Observer for scroll animations
        const observerOptions = {
            threshold: 0.1,
            rootMargin: '0px 0px -50px 0px'
        };

        const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    entry.target.classList.add('animate-in');
                }
            });
        }, observerOptions);

        // Observe elements for animation
        const animateElements = document.querySelectorAll(
            '.feature-card, .step-item, .status-card'
        );
        
        animateElements.forEach(el => {
            observer.observe(el);
        });
    }

    animateElements() {
        // Add staggered animation to feature cards
        const featureCards = document.querySelectorAll('.feature-card');
        featureCards.forEach((card, index) => {
            card.style.animationDelay = `${index * 0.1}s`;
        });

        // Add entrance animation to hero elements
        const heroElements = document.querySelectorAll(
            '.logo-container, .hero-description, .version-badge'
        );
        
        heroElements.forEach((el, index) => {
            el.style.opacity = '0';
            el.style.transform = 'translateY(30px)';
            el.style.transition = 'all 0.8s ease';
            
            setTimeout(() => {
                el.style.opacity = '1';
                el.style.transform = 'translateY(0)';
            }, index * 200 + 300);
        });
    }

    startStatusCheck() {
        // Check connection status periodically
        setInterval(async () => {
            try {
                if (typeof chrome !== 'undefined' && chrome.runtime) {
                    const response = await chrome.runtime.sendMessage({
                        action: 'getStats'
                    });

                    if (response) {
                        this.isConnected = response.isConnected;
                        this.updateUI();
                    }
                }
            } catch (error) {
                // Extension context might be invalid, ignore
            }
        }, 5000);
    }

    showNotification(message, type = 'info') {
        const notification = document.createElement('div');
        notification.className = `notification ${type}`;
        notification.textContent = message;
        
        Object.assign(notification.style, {
            position: 'fixed',
            top: '20px',
            right: '20px',
            padding: '16px 20px',
            borderRadius: 'var(--radius-md)',
            color: 'white',
            fontSize: '14px',
            fontWeight: '500',
            zIndex: '10000',
            opacity: '0',
            transform: 'translateX(100%)',
            transition: 'all 0.3s ease',
            boxShadow: 'var(--shadow-lg)'
        });

        const colors = {
            success: 'var(--success-color)',
            error: 'var(--error-color)',
            warning: 'var(--warning-color)',
            info: 'var(--primary-color)'
        };
        notification.style.backgroundColor = colors[type] || colors.info;

        document.body.appendChild(notification);

        setTimeout(() => {
            notification.style.opacity = '1';
            notification.style.transform = 'translateX(0)';
        }, 10);

        setTimeout(() => {
            notification.style.opacity = '0';
            notification.style.transform = 'translateX(100%)';
            setTimeout(() => {
                if (notification.parentNode) {
                    document.body.removeChild(notification);
                }
            }, 300);
        }, 4000);
    }
}

// Global functions for button actions
function downloadClient() {
    const welcomePage = window.welcomePageInstance;
    
    // Try to open download page
    const downloadUrl = 'https://github.com/your-repo/hdm-x/releases/latest';
    window.open(downloadUrl, '_blank');
    
    if (welcomePage) {
        welcomePage.showNotification('正在打开下载页面...', 'info');
    }
}

function openSettings() {
    const welcomePage = window.welcomePageInstance;
    
    try {
        if (typeof chrome !== 'undefined' && chrome.runtime) {
            chrome.runtime.openOptionsPage();
        } else {
            // Fallback: open extension popup
            window.open(chrome.runtime.getURL('popup.html'), '_blank');
        }
        
        if (welcomePage) {
            welcomePage.showNotification('正在打开设置页面...', 'info');
        }
    } catch (error) {
        if (welcomePage) {
            welcomePage.showNotification('无法打开设置页面', 'error');
        }
    }
}

function testExtension() {
    const welcomePage = window.welcomePageInstance;
    
    try {
        if (typeof chrome !== 'undefined' && chrome.tabs) {
            // Open a test page
            chrome.tabs.create({ 
                url: 'https://www.example.com',
                active: true 
            });
            
            if (welcomePage) {
                welcomePage.showNotification('已打开测试页面，请尝试使用扩展功能', 'success');
            }
        } else {
            if (welcomePage) {
                welcomePage.showNotification('请在浏览器中测试扩展功能', 'info');
            }
        }
    } catch (error) {
        if (welcomePage) {
            welcomePage.showNotification('无法打开测试页面', 'error');
        }
    }
}

function openHelp() {
    const welcomePage = window.welcomePageInstance;
    
    const helpUrl = 'https://github.com/your-repo/hdm-x/wiki';
    window.open(helpUrl, '_blank');
    
    if (welcomePage) {
        welcomePage.showNotification('正在打开帮助文档...', 'info');
    }
}

function openFeedback() {
    const welcomePage = window.welcomePageInstance;
    
    const feedbackUrl = 'https://github.com/your-repo/hdm-x/issues';
    window.open(feedbackUrl, '_blank');
    
    if (welcomePage) {
        welcomePage.showNotification('正在打开反馈页面...', 'info');
    }
}

function openAbout() {
    const welcomePage = window.welcomePageInstance;
    
    const aboutUrl = 'https://github.com/your-repo/hdm-x';
    window.open(aboutUrl, '_blank');
    
    if (welcomePage) {
        welcomePage.showNotification('正在打开项目主页...', 'info');
    }
}

// Initialize welcome page when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.welcomePageInstance = new WelcomePage();
});

// Handle page visibility changes
document.addEventListener('visibilitychange', () => {
    if (!document.hidden && window.welcomePageInstance) {
        // Refresh data when page becomes visible
        window.welcomePageInstance.loadExtensionData().then(() => {
            window.welcomePageInstance.updateUI();
        });
    }
});

// Add CSS for scroll animations
const style = document.createElement('style');
style.textContent = `
    .animate-in {
        animation: slideInUp 0.6s ease-out forwards;
    }
    
    @keyframes slideInUp {
        from {
            opacity: 0;
            transform: translateY(30px);
        }
        to {
            opacity: 1;
            transform: translateY(0);
        }
    }
    
    .notification {
        animation: slideInRight 0.3s ease-out;
    }
    
    @keyframes slideInRight {
        from {
            opacity: 0;
            transform: translateX(100%);
        }
        to {
            opacity: 1;
            transform: translateX(0);
        }
    }
`;
document.head.appendChild(style);