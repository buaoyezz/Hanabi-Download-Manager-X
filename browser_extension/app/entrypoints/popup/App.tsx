import { useEffect, useMemo, useState } from 'react';
import {
  Badge,
  Button,
  Caption1,
  Card,
  Divider,
  Input,
  Label,
  Switch,
  Text,
  makeStyles,
  shorthands,
} from '@fluentui/react-components';
import {
  ArrowLeftRegular,
  ArrowSyncRegular,
  CheckmarkCircleRegular,
  CloudCheckmarkRegular,
  CloudDismissRegular,
  DismissCircleRegular,
  PlugConnectedRegular,
  SettingsRegular,
} from '@fluentui/react-icons';
import { browser } from 'wxt/browser';
import { getBrowserLabel, isFirefoxBrowser } from '@/lib/browser';
import {
  DEFAULT_DESKTOP_SERVICE_PORT,
  getHanabiDesktopServiceHost,
} from '@/lib/extension-meta';
import { getFallbackPopupLocale, getPopupMessages, normalizePopupLocale } from '@/lib/i18n';
import { type PortMode, readPopupStorageState, STORAGE_KEYS } from '@/lib/storage';

const useStyles = makeStyles({
  root: {
    width: '356px',
    maxHeight: '580px',
    backgroundColor: '#1A1A1A',
    color: '#FFFFFF',
    overflowY: 'auto',
  },
  shell: {
    display: 'grid',
    gap: '12px',
    padding: '14px',
  },
  card: {
    backgroundColor: '#202020',
    border: '1px solid #3A3A3A',
    boxShadow: 'none',
  },
  compactHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: '12px',
  },
  headerActions: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
  },
  compactTitle: {
    color: '#CFCFCF',
  },
  statusRow: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: '12px',
  },
  statusSide: {
    display: 'flex',
    alignItems: 'center',
    gap: '10px',
    minWidth: 0,
  },
  leadingIcon: {
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center',
    width: '20px',
    height: '20px',
    flexShrink: 0,
  },
  statusMeta: {
    display: 'grid',
    gap: '2px',
    minWidth: 0,
  },
  statusBadge: {
    minWidth: '92px',
    justifyContent: 'center',
  },
  extensionRow: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    gap: '12px',
  },
  extensionSide: {
    display: 'flex',
    alignItems: 'flex-start',
    gap: '10px',
    minWidth: 0,
  },
  extensionMeta: {
    display: 'grid',
    gap: '4px',
    minWidth: 0,
  },
  extensionTitleRow: {
    display: 'flex',
    alignItems: 'center',
    gap: '6px',
    minWidth: 0,
  },
  extensionControl: {
    display: 'flex',
    alignItems: 'center',
    flexShrink: 0,
    minWidth: '44px',
    justifyContent: 'flex-end',
  },
  stateIcon: {
    flexShrink: 0,
  },
  settingsEntry: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: '12px',
  },
  settingsEntrySide: {
    display: 'flex',
    alignItems: 'center',
    gap: '10px',
    minWidth: 0,
  },
  statGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(2, minmax(0, 1fr))',
    gap: '10px',
  },
  statCard: {
    backgroundColor: '#2B2B2B',
    border: '1px solid #3A3A3A',
    borderRadius: '8px',
    display: 'grid',
    gap: '6px',
    padding: '12px',
  },
  settingsCardBody: {
    display: 'grid',
    gap: '10px',
  },
  settingsHeader: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
  },
  settingRow: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    gap: '12px',
  },
  settingMeta: {
    display: 'grid',
    gap: '4px',
    minWidth: 0,
    flexGrow: 1,
  },
  settingSwitch: {
    flexShrink: 0,
  },
  portInput: {
    minWidth: '100px',
    maxWidth: '120px',
  },
  settingsButton: {
    ...shorthands.padding('0', '12px'),
  },
  footerMeta: {
    color: '#808080',
  },
  actionButton: {
    ...shorthands.padding('0', '14px'),
  },
  portModeGroup: {
    display: 'flex',
    gap: '6px',
    flexShrink: 0,
  },
  portModeButton: {
    minWidth: '52px',
    ...shorthands.padding('2px', '10px'),
  },
});

type PopupState = {
  isConnected: boolean;
  isEnabled: boolean;
  enableContextMenus: boolean;
  showNotifications: boolean;
  showConnectionBadge: boolean;
  desktopServicePort: number;
  portMode: PortMode;
  locale: string;
  refreshing: boolean;
};

type PopupView = 'main' | 'settings';
type ConnectionCheckResponse = {
  status?: 'connected' | 'disconnected';
  apiPort?: number;
  locale?: string;
};

function App() {
  const styles = useStyles();
  const [view, setView] = useState<PopupView>('main');
  const [state, setState] = useState<PopupState>({
    isConnected: false,
    isEnabled: true,
    enableContextMenus: true,
    showNotifications: true,
    showConnectionBadge: true,
    desktopServicePort: DEFAULT_DESKTOP_SERVICE_PORT,
    portMode: 'auto',
    locale: getFallbackPopupLocale(),
    refreshing: false,
  });

  const browserLabel = useMemo(() => getBrowserLabel(), []);
  const firefox = isFirefoxBrowser();
  const locale = normalizePopupLocale(state.locale);
  const t = getPopupMessages(locale);

  async function syncState() {
    const values = await readPopupStorageState();
    setState((current) => ({
      ...current,
      isConnected: values.isConnected,
      isEnabled: !values.shouldDisableExtension,
      enableContextMenus: values.enableContextMenus,
      showNotifications: values.showNotifications,
      showConnectionBadge: values.showConnectionBadge,
      desktopServicePort: values.desktopServicePort,
      portMode: values.portMode,
      locale: values.popupLocale,
    }));
  }

  async function refreshConnection() {
    setState((current) => ({ ...current, refreshing: true }));

    try {
      const response = await browser.runtime.sendMessage({
        action: 'checkConnection',
      }) as ConnectionCheckResponse | undefined;
      if (response) {
        setState((current) => ({
          ...current,
          isConnected: response.status === 'connected',
          desktopServicePort:
            typeof response.apiPort === 'number'
              ? response.apiPort
              : current.desktopServicePort,
          locale: response.locale ?? current.locale,
        }));
      }
      await syncState();
    } finally {
      setState((current) => ({ ...current, refreshing: false }));
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

  useEffect(() => {
    void syncState();
    void refreshConnection();

    const handleChange = (changes: Record<string, unknown>, areaName: string) => {
      if (areaName !== 'local') {
        return;
      }

      if (
        STORAGE_KEYS.isConnected in changes ||
        STORAGE_KEYS.shouldDisableExtension in changes ||
        STORAGE_KEYS.enableContextMenus in changes ||
        STORAGE_KEYS.showNotifications in changes ||
        STORAGE_KEYS.showConnectionBadge in changes ||
        STORAGE_KEYS.desktopServicePort in changes ||
        STORAGE_KEYS.portMode in changes
      ) {
        void syncState();
      }
    };

    browser.storage.onChanged.addListener(handleChange);
    return () => {
      browser.storage.onChanged.removeListener(handleChange);
    };
  }, []);

  function renderMainView() {
    return (
      <>
        <div className={styles.compactHeader}>
          <Text className={styles.compactTitle} size={200} weight="semibold">
            {t.title}
          </Text>
          <div className={styles.headerActions}>
            <Button
              appearance="secondary"
              icon={<ArrowSyncRegular />}
              className={styles.actionButton}
              onClick={() => {
                void refreshConnection();
              }}
              disabled={state.refreshing}
            >
              {state.refreshing ? t.checking : t.refresh}
            </Button>
          </div>
        </div>

        <Card className={styles.card}>
          <div className={styles.statusRow}>
            <div className={styles.statusSide}>
              <span className={styles.leadingIcon}>
                {state.isConnected ? (
                  <CloudCheckmarkRegular primaryFill="#6CCB5F" fontSize={20} />
                ) : (
                  <CloudDismissRegular primaryFill="#FF6B6B" fontSize={20} />
                )}
              </span>
              <div className={styles.statusMeta}>
                <Label size="small">{t.desktopLink}</Label>
                <Caption1>
                  {state.isConnected
                    ? t.desktopReachable
                    : t.desktopOffline}
                </Caption1>
              </div>
            </div>
            <Badge
              appearance="filled"
              color={state.isConnected ? 'success' : 'danger'}
              className={styles.statusBadge}
            >
              {state.isConnected ? t.connected : t.disconnected}
            </Badge>
          </div>

          <Divider />

          <div className={styles.extensionRow}>
            <div className={styles.extensionSide}>
              <span className={styles.leadingIcon}>
                <PlugConnectedRegular fontSize={18} primaryFill="#60CDFF" />
              </span>
              <div className={styles.extensionMeta}>
                <div className={styles.extensionTitleRow}>
                  <Label>{t.extensionState}</Label>
                  {state.isEnabled ? (
                    <CheckmarkCircleRegular
                      className={styles.stateIcon}
                      primaryFill="#6CCB5F"
                      fontSize={16}
                    />
                  ) : (
                    <DismissCircleRegular
                      className={styles.stateIcon}
                      primaryFill="#FF6B6B"
                      fontSize={16}
                    />
                  )}
                </div>
                <Caption1>{t.extensionStateHint}</Caption1>
              </div>
            </div>
            <div className={styles.extensionControl}>
              <Switch
                checked={state.isEnabled}
                onChange={(_, data) => {
                  void toggleExtension(Boolean(data.checked));
                }}
              />
            </div>
          </div>

          <Divider />

          <div className={styles.statGrid}>
            <div className={styles.statCard}>
              <Caption1>{t.browser}</Caption1>
              <Text weight="semibold">{browserLabel}</Text>
            </div>
            <div className={styles.statCard}>
              <Caption1>{t.mode}</Caption1>
              <Text weight="semibold">
                {firefox
                  ? t.observedRelayMenu
                  : t.automaticIntercept}
              </Text>
            </div>
            <div className={styles.statCard}>
              <Caption1>{t.port}</Caption1>
              <Text weight="semibold">
                {getHanabiDesktopServiceHost(state.desktopServicePort)}
              </Text>
            </div>
            <div className={styles.statCard}>
              <Caption1>{t.version}</Caption1>
              <Text weight="semibold">
                v{browser.runtime.getManifest().version}
              </Text>
            </div>
          </div>

          <Divider />

          <div className={styles.settingsEntry}>
            <div className={styles.settingsEntrySide}>
              <span className={styles.leadingIcon}>
                <SettingsRegular fontSize={18} primaryFill="#CFCFCF" />
              </span>
              <Label>{t.settings}</Label>
            </div>
            <Button
              appearance="secondary"
              className={styles.settingsButton}
              onClick={() => {
                setView('settings');
              }}
            >
              {t.openSettings}
            </Button>
          </div>
        </Card>

        <Caption1 className={styles.footerMeta}>
          {firefox
            ? t.footerFirefox
            : t.footerChromium}
        </Caption1>
      </>
    );
  }

  function renderSettingsView() {
    return (
      <>
        <div className={styles.compactHeader}>
          <Button
            appearance="secondary"
            icon={<ArrowLeftRegular />}
            className={styles.settingsButton}
            onClick={() => {
              setView('main');
            }}
          >
            {t.back}
          </Button>
          <Text className={styles.compactTitle} size={200} weight="semibold">
            {t.settings}
          </Text>
        </div>

        <Card className={styles.card}>
          <div className={styles.settingsCardBody}>
            <div className={styles.settingsHeader}>
              <SettingsRegular fontSize={18} primaryFill="#CFCFCF" />
              <Label>{t.settings}</Label>
            </div>

            <div className={styles.settingRow}>
              <div className={styles.settingMeta}>
                <Text weight="medium">{t.contextMenus}</Text>
                <Caption1>{t.contextMenusHint}</Caption1>
              </div>
              <Switch
                className={styles.settingSwitch}
                checked={state.enableContextMenus}
                label={state.enableContextMenus ? t.enabled : t.disabled}
                onChange={(_, data) => {
                  void updateSetting(
                    STORAGE_KEYS.enableContextMenus,
                    Boolean(data.checked),
                  );
                }}
              />
            </div>

            <Divider />

            <div className={styles.settingRow}>
              <div className={styles.settingMeta}>
                <Text weight="medium">{t.notifications}</Text>
                <Caption1>{t.notificationsHint}</Caption1>
              </div>
              <Switch
                className={styles.settingSwitch}
                checked={state.showNotifications}
                label={state.showNotifications ? t.enabled : t.disabled}
                onChange={(_, data) => {
                  void updateSetting(
                    STORAGE_KEYS.showNotifications,
                    Boolean(data.checked),
                  );
                }}
              />
            </div>

            <Divider />

            <div className={styles.settingRow}>
              <div className={styles.settingMeta}>
                <Text weight="medium">{t.connectionBadge}</Text>
                <Caption1>{t.connectionBadgeHint}</Caption1>
              </div>
              <Switch
                className={styles.settingSwitch}
                checked={state.showConnectionBadge}
                label={state.showConnectionBadge ? t.enabled : t.disabled}
                onChange={(_, data) => {
                  void updateSetting(
                    STORAGE_KEYS.showConnectionBadge,
                    Boolean(data.checked),
                  );
                }}
              />
            </div>

            <Divider />

            <div className={styles.settingRow}>
              <div className={styles.settingMeta}>
                <Text weight="medium">{t.portModeLabel}</Text>
                <Caption1>
                  {state.portMode === 'auto'
                    ? t.portModeAutoHint
                    : t.portModeManualHint}
                </Caption1>
              </div>
              <div className={styles.portModeGroup}>
                <Button
                  appearance={state.portMode === 'auto' ? 'primary' : 'secondary'}
                  className={styles.portModeButton}
                  size="small"
                  onClick={() => {
                    void browser.storage.local.set({
                      [STORAGE_KEYS.portMode]: 'auto',
                    }).then(syncState);
                  }}
                >
                  {t.portModeAuto}
                </Button>
                <Button
                  appearance={state.portMode === 'manual' ? 'primary' : 'secondary'}
                  className={styles.portModeButton}
                  size="small"
                  onClick={() => {
                    void browser.storage.local.set({
                      [STORAGE_KEYS.portMode]: 'manual',
                    }).then(syncState);
                  }}
                >
                  {t.portModeManual}
                </Button>
              </div>
            </div>

            {state.portMode !== 'auto' && (
              <>
                <Divider />

                <div className={styles.settingRow}>
                  <div className={styles.settingMeta}>
                    <Text weight="medium">{t.manualPort}</Text>
                    <Caption1>{t.manualPortHint}</Caption1>
                  </div>
                  <Input
                    type="number"
                    min={1024}
                    max={65535}
                    className={styles.portInput}
                    value={String(state.desktopServicePort)}
                    onChange={(_, data) => {
                      const val = Number(data.value);
                      if (Number.isInteger(val) && val >= 1024 && val <= 65535) {
                        void browser.storage.local.set({
                          [STORAGE_KEYS.desktopServicePort]: val,
                        }).then(syncState);
                      }
                    }}
                  />
                </div>
              </>
            )}
          </div>
        </Card>
      </>
    );
  }

  return (
    <div className={styles.root}>
      <div className={styles.shell}>
        {view === 'settings'
          ? renderSettingsView()
          : renderMainView()}
      </div>
    </div>
  );
}

export default App;
