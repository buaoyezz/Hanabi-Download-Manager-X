import { useEffect, useMemo, useState } from 'react';
import {
  Badge,
  Button,
  Caption1,
  Card,
  Divider,
  Label,
  Switch,
  Text,
  makeStyles,
  shorthands,
} from '@fluentui/react-components';
import {
  ArrowSyncRegular,
  CloudCheckmarkRegular,
  CloudDismissRegular,
  PlugConnectedRegular,
} from '@fluentui/react-icons';
import { browser } from 'wxt/browser';
import { getBrowserLabel, isFirefoxBrowser } from '@/lib/browser';
import { HANABI_DESKTOP_SERVICE_HOST } from '@/lib/extension-meta';
import { getFallbackPopupLocale, getPopupMessages, normalizePopupLocale } from '@/lib/i18n';
import { readPopupStorageState, STORAGE_KEYS } from '@/lib/storage';

const useStyles = makeStyles({
  root: {
    width: '356px',
    minHeight: '320px',
    backgroundColor: '#1A1A1A',
    color: '#FFFFFF',
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
  },
  statusMeta: {
    display: 'grid',
    gap: '2px',
  },
  statusBadge: {
    minWidth: '92px',
    justifyContent: 'center',
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
  switchRow: {
    display: 'grid',
    gap: '8px',
  },
  switchLabelRow: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
  },
  footer: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: '10px',
  },
  footerMeta: {
    color: '#808080',
  },
  actionButton: {
    ...shorthands.padding('0', '14px'),
  },
});

type PopupState = {
  isConnected: boolean;
  isEnabled: boolean;
  locale: string;
  refreshing: boolean;
};

function App() {
  const styles = useStyles();
  const [state, setState] = useState<PopupState>({
    isConnected: false,
    isEnabled: true,
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
      locale: values.popupLocale,
    }));
  }

  async function refreshConnection() {
    setState((current) => ({ ...current, refreshing: true }));

    try {
      await browser.runtime.sendMessage({ action: 'checkConnection' });
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

  useEffect(() => {
    void syncState();
    void refreshConnection();

    const handleChange = (changes: Record<string, unknown>, areaName: string) => {
      if (areaName !== 'local') {
        return;
      }

      if (
        STORAGE_KEYS.isConnected in changes ||
        STORAGE_KEYS.shouldDisableExtension in changes
      ) {
        void syncState();
      }
    };

    browser.storage.onChanged.addListener(handleChange);
    return () => {
      browser.storage.onChanged.removeListener(handleChange);
    };
  }, []);

  return (
    <div className={styles.root}>
      <div className={styles.shell}>
        <div className={styles.compactHeader}>
          <Text className={styles.compactTitle} size={200} weight="semibold">
            {t.title}
          </Text>
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

        <Card className={styles.card}>
          <div className={styles.statusRow}>
            <div className={styles.statusSide}>
              {state.isConnected ? (
                <CloudCheckmarkRegular primaryFill="#6CCB5F" fontSize={20} />
              ) : (
                <CloudDismissRegular primaryFill="#FF6B6B" fontSize={20} />
              )}
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
              <Text weight="semibold">{HANABI_DESKTOP_SERVICE_HOST}</Text>
            </div>
            <div className={styles.statCard}>
              <Caption1>{t.version}</Caption1>
              <Text weight="semibold">
                v{browser.runtime.getManifest().version}
              </Text>
            </div>
          </div>
        </Card>

        <Card className={styles.card}>
          <div className={styles.switchRow}>
            <div className={styles.switchLabelRow}>
              <PlugConnectedRegular fontSize={18} primaryFill="#60CDFF" />
              <Label>{t.extensionState}</Label>
            </div>
            <Switch
              checked={state.isEnabled}
              label={state.isEnabled ? t.enabled : t.disabled}
              onChange={(_, data) => {
                void toggleExtension(Boolean(data.checked));
              }}
            />
            <Caption1>{t.bridgeHint}</Caption1>
          </div>
        </Card>

        <Caption1 className={styles.footerMeta}>
          {firefox
            ? t.footerFirefox
            : t.footerChromium}
        </Caption1>
      </div>
    </div>
  );
}

export default App;
