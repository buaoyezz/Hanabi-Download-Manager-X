import { browser } from 'wxt/browser';
import { getBrowserLabel, isFirefoxBrowser } from '@/lib/browser';
import {
  DEFAULT_DESKTOP_SERVICE_PORT,
  getHanabiDesktopServiceHost,
} from '@/lib/extension-meta';
import {
  getFallbackPopupLocale,
  getPopupMessages,
  normalizePopupLocale,
} from '@/lib/i18n';
import {
  type BrowserDownloadHandlingMode,
  type PortMode,
  normalizeBrowserDownloadHandlingMode,
  readPopupStorageState,
  STORAGE_KEYS,
} from '@/lib/storage';
import './style.css';

type PopupState = {
  isConnected: boolean;
  isEnabled: boolean;
  enableAutomaticHandoff: boolean;
  enableContextMenus: boolean;
  showNotifications: boolean;
  showConnectionBadge: boolean;
  desktopServicePort: number;
  portMode: PortMode;
  locale: string;
  browserDownloadHandlingMode: BrowserDownloadHandlingMode;
  browserDownloadSmallFileThreshold: number;
  refreshing: boolean;
};

type PopupView = 'main' | 'settings';

type ConnectionCheckResponse = {
  status?: 'connected' | 'disconnected';
  apiPort?: number;
  locale?: string;
  browserDownloadHandlingMode?: string;
  browserDownloadSmallFileThreshold?: number;
};

type Child = Node | string | null | undefined;

const rootCandidate = document.getElementById('root');

if (!(rootCandidate instanceof HTMLElement)) {
  throw new Error('Popup root element was not found.');
}

const rootElement: HTMLElement = rootCandidate;

const browserLabel = getBrowserLabel();
const firefox = isFirefoxBrowser();

let view: PopupView = 'main';
let portInputValue = String(DEFAULT_DESKTOP_SERVICE_PORT);
let state: PopupState = {
  isConnected: false,
  isEnabled: true,
  enableAutomaticHandoff: true,
  enableContextMenus: true,
  showNotifications: true,
  showConnectionBadge: true,
  desktopServicePort: DEFAULT_DESKTOP_SERVICE_PORT,
  portMode: 'auto',
  locale: getFallbackPopupLocale(),
  browserDownloadHandlingMode: 'smart',
  browserDownloadSmallFileThreshold: 8 * 1024 * 1024,
  refreshing: false,
};

function classNames(...tokens: Array<string | false | null | undefined>) {
  return tokens.filter(Boolean).join(' ');
}

function appendChildren(parent: Node, children: Child[]) {
  for (const child of children) {
    if (child === null || child === undefined) {
      continue;
    }

    parent.appendChild(
      typeof child === 'string' ? document.createTextNode(child) : child,
    );
  }

  return parent;
}

function createElement<K extends keyof HTMLElementTagNameMap>(
  tagName: K,
  className?: string,
  children: Child[] = [],
) {
  const element = document.createElement(tagName);
  if (className) {
    element.className = className;
  }

  appendChildren(element, children);
  return element;
}

function createText(tagName: 'p' | 'h1' | 'span' | 'button', className: string, text: string) {
  const element = createElement(tagName, className);
  element.textContent = text;
  return element;
}

function createSymbol(text: string, className: string, color?: string) {
  const element = createElement('span', className);
  element.setAttribute('aria-hidden', 'true');
  element.textContent = text;

  if (color) {
    element.style.color = color;
  }

  return element;
}

function createButton({
  className,
  disabled,
  icon,
  label,
  onClick,
}: {
  className: string;
  disabled?: boolean;
  icon?: Node;
  label: string;
  onClick?: () => void;
}) {
  const button = document.createElement('button');
  button.className = className;
  button.disabled = disabled === true;
  button.type = 'button';

  if (onClick) {
    button.addEventListener('click', onClick);
  }

  if (icon) {
    button.appendChild(icon);
  }

  button.appendChild(createText('span', '', label));
  return button;
}

function createToggle({
  checked,
  label,
  onChange,
}: {
  checked: boolean;
  label: string;
  onChange: (checked: boolean) => void;
}) {
  const wrapper = createElement('label', 'popup-toggle');
  const input = document.createElement('input');
  const track = createElement('span', 'popup-toggle__track');
  const thumb = createElement('span', 'popup-toggle__thumb');

  input.checked = checked;
  input.className = 'popup-toggle__input';
  input.type = 'checkbox';
  input.setAttribute('aria-label', label);
  input.addEventListener('change', () => {
    onChange(input.checked);
  });

  track.setAttribute('aria-hidden', 'true');
  track.appendChild(thumb);
  wrapper.append(input, track);

  return wrapper;
}

function createDivider() {
  return createElement('div', 'popup-divider');
}

function createStatCard(label: string, value: string) {
  return createElement('div', 'popup-stat', [
    createText('p', 'popup-stat__label', label),
    createText('p', 'popup-stat__value', value),
  ]);
}

function createHeaderTitle(title: string, alignRight = false) {
  return createElement(
    'div',
    alignRight ? 'popup-header__title' : undefined,
    [
      createText('p', 'popup-eyebrow', 'Hanabi Browser Bridge'),
      createText('h1', 'popup-title', title),
    ],
  );
}

function createLeadingIcon(symbol: string, color: string, subtle = false) {
  return createElement(
    'span',
    classNames('popup-leading-icon', subtle && 'popup-leading-icon--subtle'),
    [
      createSymbol(
        symbol,
        classNames('popup-symbol', subtle ? 'popup-symbol--small' : 'popup-symbol--large'),
        color,
      ),
    ],
  );
}

function createControlState(text: string) {
  return createText('span', 'popup-control__state', text);
}

function getMessages() {
  return getPopupMessages(normalizePopupLocale(state.locale));
}

function formatThreshold(bytes: number) {
  const mb = bytes / 1024 / 1024;
  return `${Number.isInteger(mb) ? mb.toFixed(0) : mb.toFixed(1)} MB`;
}

function getHandlingModeLabel() {
  const zh = normalizePopupLocale(state.locale) === 'zh';
  switch (state.browserDownloadHandlingMode) {
    case 'always_ask':
      return zh ? '\u603b\u662f\u8be2\u95ee' : 'Always ask';
    case 'silent_takeover':
      return zh ? '\u9759\u9ed8\u63a5\u7ba1' : 'Silent';
    case 'small_files_to_browser':
      return zh ? '\u5c0f\u6587\u4ef6\u6d4f\u89c8\u5668' : 'Small files browser';
    default:
      return zh
        ? `\u667a\u80fd < ${formatThreshold(state.browserDownloadSmallFileThreshold)}`
        : `Smart < ${formatThreshold(state.browserDownloadSmallFileThreshold)}`;
  }
}

function setView(nextView: PopupView) {
  view = nextView;
  render();
}

function setState(nextState: PopupState) {
  state = nextState;
  render();
}

function patchState(patch: Partial<PopupState>) {
  state = {
    ...state,
    ...patch,
  };
  render();
}

async function syncState() {
  const values = await readPopupStorageState();
  portInputValue = String(values.desktopServicePort);

  setState({
    ...state,
    isConnected: values.isConnected,
    isEnabled: !values.shouldDisableExtension,
    enableAutomaticHandoff: values.enableAutomaticHandoff,
    enableContextMenus: values.enableContextMenus,
    showNotifications: values.showNotifications,
    showConnectionBadge: values.showConnectionBadge,
    desktopServicePort: values.desktopServicePort,
    portMode: values.portMode,
    locale: values.popupLocale,
  });
}

async function refreshConnection() {
  patchState({ refreshing: true });

  try {
    const response = (await browser.runtime.sendMessage({
      action: 'checkConnection',
    })) as ConnectionCheckResponse | undefined;

    if (response) {
      setState({
        ...state,
        isConnected: response.status === 'connected',
        desktopServicePort:
          typeof response.apiPort === 'number'
            ? response.apiPort
            : state.desktopServicePort,
        locale: response.locale ?? state.locale,
        browserDownloadHandlingMode: normalizeBrowserDownloadHandlingMode(
          response.browserDownloadHandlingMode,
        ),
        browserDownloadSmallFileThreshold:
          typeof response.browserDownloadSmallFileThreshold === 'number'
            ? response.browserDownloadSmallFileThreshold
            : state.browserDownloadSmallFileThreshold,
      });
    }

    await syncState();
  } finally {
    patchState({ refreshing: false });
  }
}

async function toggleExtension(enabled: boolean) {
  await browser.storage.local.set({
    [STORAGE_KEYS.shouldDisableExtension]: !enabled,
  });
  await syncState();
}

async function updateSetting(
  key: (typeof STORAGE_KEYS)[keyof typeof STORAGE_KEYS],
  value: boolean,
) {
  await browser.storage.local.set({
    [key]: value,
  });
  await syncState();
}

async function updatePortMode(mode: 'auto' | 'manual') {
  await browser.storage.local.set({
    [STORAGE_KEYS.portMode]: mode,
  });
  await syncState();
}

async function commitManualPort(nextValue = portInputValue) {
  const parsedValue = Number(nextValue);

  if (
    Number.isInteger(parsedValue) &&
    parsedValue >= 1024 &&
    parsedValue <= 65535
  ) {
    await browser.storage.local.set({
      [STORAGE_KEYS.desktopServicePort]: parsedValue,
    });
    await syncState();
    return;
  }

  portInputValue = String(state.desktopServicePort);
  render();
}

function renderMainView() {
  const t = getMessages();
  const content = document.createDocumentFragment();

  content.appendChild(
    createElement('header', 'popup-header', [
      createHeaderTitle(t.title),
      createButton({
        className: 'popup-button popup-button--secondary',
        disabled: state.refreshing,
        icon: createSymbol('↻', 'popup-symbol popup-symbol--small'),
        label: state.refreshing ? t.checking : t.refresh,
        onClick: () => {
          void refreshConnection();
        },
      }),
    ]),
  );

  const statusRow = createElement('div', 'popup-row popup-row--status', [
    createElement('div', 'popup-row__side', [
      createLeadingIcon('☁', state.isConnected ? '#6ccb5f' : '#ff6b6b'),
      createElement('div', 'popup-copy', [
        createText('p', 'popup-label', t.desktopLink),
        createText(
          'p',
          'popup-value',
          state.isConnected ? t.desktopReachable : t.desktopOffline,
        ),
      ]),
    ]),
    createText(
      'span',
      classNames(
        'popup-badge',
        state.isConnected ? 'popup-badge--success' : 'popup-badge--danger',
      ),
      state.isConnected ? t.connected : t.disconnected,
    ),
  ]);

  const extensionStateIcon = state.isEnabled
    ? createSymbol('✓', 'popup-symbol popup-symbol--small', '#6ccb5f')
    : createSymbol('×', 'popup-symbol popup-symbol--small', '#ff6b6b');

  const extensionRow = createElement('div', 'popup-row', [
    createElement('div', 'popup-row__side', [
      createLeadingIcon('⇄', '#60cdff', true),
      createElement('div', 'popup-copy', [
        createElement('div', 'popup-inline', [
          createText('p', 'popup-label', t.extensionState),
          createElement('span', 'popup-inline-state', [extensionStateIcon]),
        ]),
        createText('p', 'popup-copy__muted', t.extensionStateHint),
      ]),
    ]),
    createElement('div', 'popup-control', [
      createControlState(state.isEnabled ? t.enabled : t.disabled),
      createToggle({
        checked: state.isEnabled,
        label: t.extensionState,
        onChange: (checked) => {
          state.isEnabled = checked;
          render();
          void toggleExtension(checked);
        },
      }),
    ]),
  ]);

  const statsGrid = createElement('div', 'popup-stats', [
    createStatCard(t.browser, browserLabel),
    createStatCard(
      t.mode,
      firefox ? t.observedRelayMenu : getHandlingModeLabel(),
    ),
    createStatCard(t.port, getHanabiDesktopServiceHost(state.desktopServicePort)),
    createStatCard(t.version, `v${browser.runtime.getManifest().version}`),
  ]);

  const settingsRow = createElement('div', 'popup-row', [
    createElement('div', 'popup-row__side', [
      createLeadingIcon('⚙', '#cfcfcf', true),
      createElement('div', 'popup-copy', [
        createText('p', 'popup-label', t.settings),
        createText('p', 'popup-copy__muted', t.openSettings),
      ]),
    ]),
    createButton({
      className: 'popup-button popup-button--secondary',
      label: t.openSettings,
      onClick: () => {
        setView('settings');
      },
    }),
  ]);

  content.appendChild(
    createElement('section', 'popup-card', [
      statusRow,
      createDivider(),
      extensionRow,
      createDivider(),
      statsGrid,
      createDivider(),
      settingsRow,
    ]),
  );

  content.appendChild(
    createText(
      'p',
      'popup-footer',
      firefox ? t.footerFirefox : t.footerChromium,
    ),
  );

  return content;
}

function renderSettingsView() {
  const t = getMessages();
  const usesManualPort = state.portMode !== 'auto';
  const content = document.createDocumentFragment();

  content.appendChild(
    createElement('header', 'popup-header popup-header--settings', [
      createButton({
        className: 'popup-button popup-button--secondary',
        icon: createSymbol('←', 'popup-symbol popup-symbol--small'),
        label: t.back,
        onClick: () => {
          setView('main');
        },
      }),
      createHeaderTitle(t.settings, true),
    ]),
  );

  const settingsCard = createElement('section', 'popup-card', [
    createElement('div', 'popup-card__header', [
      createSymbol('⚙', 'popup-symbol popup-symbol--small', '#cfcfcf'),
      createText('p', 'popup-label', t.settings),
    ]),
  ]);

  function createSettingRow(
    label: string,
    hint: string,
    checked: boolean,
    onChange: (checked: boolean) => void,
  ) {
    return createElement('div', 'popup-row', [
      createElement('div', 'popup-copy', [
        createText('p', 'popup-value popup-value--strong', label),
        createText('p', 'popup-copy__muted', hint),
      ]),
      createElement('div', 'popup-control', [
        createControlState(checked ? t.enabled : t.disabled),
        createToggle({
          checked,
          label,
          onChange,
        }),
      ]),
    ]);
  }

  settingsCard.appendChild(
    createSettingRow(
      t.automaticHandoff,
      t.automaticHandoffHint,
      state.enableAutomaticHandoff,
      (checked) => {
        state.enableAutomaticHandoff = checked;
        render();
        void updateSetting(STORAGE_KEYS.enableAutomaticHandoff, checked);
      },
    ),
  );
  settingsCard.appendChild(createDivider());
  settingsCard.appendChild(
    createSettingRow(
      t.contextMenus,
      t.contextMenusHint,
      state.enableContextMenus,
      (checked) => {
        void updateSetting(STORAGE_KEYS.enableContextMenus, checked);
      },
    ),
  );
  settingsCard.appendChild(createDivider());
  settingsCard.appendChild(
    createSettingRow(
      t.notifications,
      t.notificationsHint,
      state.showNotifications,
      (checked) => {
        void updateSetting(STORAGE_KEYS.showNotifications, checked);
      },
    ),
  );
  settingsCard.appendChild(createDivider());
  settingsCard.appendChild(
    createSettingRow(
      t.connectionBadge,
      t.connectionBadgeHint,
      state.showConnectionBadge,
      (checked) => {
        void updateSetting(STORAGE_KEYS.showConnectionBadge, checked);
      },
    ),
  );
  settingsCard.appendChild(createDivider());

  const portModeRow = createElement('div', 'popup-row popup-row--stacked', [
    createElement('div', 'popup-copy', [
      createText('p', 'popup-value popup-value--strong', t.portModeLabel),
      createText(
        'p',
        'popup-copy__muted',
        usesManualPort ? t.portModeManualHint : t.portModeAutoHint,
      ),
    ]),
    createElement('div', 'popup-segmented', [
      createButton({
        className: classNames(
          'popup-segmented__button',
          !usesManualPort && 'is-active',
        ),
        label: t.portModeAuto,
        onClick: () => {
          void updatePortMode('auto');
        },
      }),
      createButton({
        className: classNames(
          'popup-segmented__button',
          usesManualPort && 'is-active',
        ),
        label: t.portModeManual,
        onClick: () => {
          void updatePortMode('manual');
        },
      }),
    ]),
  ]);

  settingsCard.appendChild(portModeRow);

  if (usesManualPort) {
    settingsCard.appendChild(createDivider());

    const manualPortInput = document.createElement('input');
    manualPortInput.className = 'popup-input';
    manualPortInput.inputMode = 'numeric';
    manualPortInput.max = '65535';
    manualPortInput.min = '1024';
    manualPortInput.type = 'number';
    manualPortInput.value = portInputValue;
    manualPortInput.setAttribute('aria-label', t.manualPort);
    manualPortInput.addEventListener('blur', () => {
      void commitManualPort();
    });
    manualPortInput.addEventListener('input', () => {
      portInputValue = manualPortInput.value;
    });
    manualPortInput.addEventListener('keydown', (event) => {
      if (event.key === 'Enter') {
        void commitManualPort(manualPortInput.value);
        manualPortInput.blur();
      }
    });

    settingsCard.appendChild(
      createElement('div', 'popup-row popup-row--stacked', [
        createElement('div', 'popup-copy', [
          createText('p', 'popup-value popup-value--strong', t.manualPort),
          createText('p', 'popup-copy__muted', t.manualPortHint),
        ]),
        manualPortInput,
      ]),
    );
  }

  content.appendChild(settingsCard);
  return content;
}

function render() {
  const root = createElement('div', 'popup-root');
  const shell = createElement('div', 'popup-shell');

  shell.appendChild(
    view === 'settings' ? renderSettingsView() : renderMainView(),
  );
  root.appendChild(shell);
  rootElement.replaceChildren(root);
}

function handleStorageChange(changes: Record<string, unknown>, areaName: string) {
  if (areaName !== 'local') {
    return;
  }

  if (
    STORAGE_KEYS.isConnected in changes ||
    STORAGE_KEYS.popupLocale in changes ||
    STORAGE_KEYS.shouldDisableExtension in changes ||
    STORAGE_KEYS.enableAutomaticHandoff in changes ||
    STORAGE_KEYS.enableContextMenus in changes ||
    STORAGE_KEYS.showNotifications in changes ||
    STORAGE_KEYS.showConnectionBadge in changes ||
    STORAGE_KEYS.desktopServicePort in changes ||
    STORAGE_KEYS.portMode in changes
  ) {
    void syncState();
  }
}

render();
browser.storage.onChanged.addListener(handleStorageChange);
void syncState();
void refreshConnection();
