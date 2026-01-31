import { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { 
  makeStyles, 
  tokens, 
  Title1, 
  Body1, 
  Card,
  CardPreview,
  Badge,
  Spinner,
  Button,
  Text
} from '@fluentui/react-components';
import { 
  Info24Regular, 
  Warning24Regular, 
  CheckmarkCircle24Regular, 
  ErrorCircle24Regular,
  ArrowLeft24Regular
} from '@fluentui/react-icons';
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import type { Announcement } from '../types/announcement';
import { announcementService } from '../services/announcementService';

const useStyles = makeStyles({
  container: {
    minHeight: '100vh',
    backgroundColor: tokens.colorNeutralBackground1,
    padding: '24px',
  },
  header: {
    maxWidth: '1200px',
    margin: '0 auto',
    marginBottom: '32px',
  },
  backButton: {
    marginBottom: '16px',
  },
  content: {
    maxWidth: '1200px',
    margin: '0 auto',
  },
  loadingContainer: {
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    minHeight: '200px',
  },
  emptyState: {
    textAlign: 'center',
    padding: '48px 24px',
    color: tokens.colorNeutralForeground3,
  },
  announcementCard: {
    marginBottom: '16px',
    cursor: 'pointer',
    transition: 'all 0.2s ease',
    ':hover': {
      transform: 'translateY(-2px)',
      boxShadow: tokens.shadow16,
    },
  },
  cardHeader: {
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
    marginBottom: '8px',
  },
  cardContent: {
    padding: '16px',
  },
  cardMeta: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: '12px',
    fontSize: '12px',
    color: tokens.colorNeutralForeground3,
  },
  priorityBadge: {
    marginLeft: '8px',
  },
});

const typeIcons = {
  info: Info24Regular,
  warning: Warning24Regular,
  success: CheckmarkCircle24Regular,
  error: ErrorCircle24Regular,
};

const typeColors = {
  info: tokens.colorBrandForeground1,
  warning: tokens.colorPaletteMarigoldForeground1,
  success: tokens.colorPaletteGreenForeground1,
  error: tokens.colorPaletteRedForeground1,
};

const priorityColors = {
  low: 'outline',
  medium: 'filled',
  high: 'filled',
} as const;

const Announcements = () => {
  const styles = useStyles();
  const { t } = useTranslation();
  const navigate = useNavigate();
  const [announcements, setAnnouncements] = useState<Announcement[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadAnnouncements();
  }, []);

  const loadAnnouncements = async () => {
    try {
      setLoading(true);
      const response = await announcementService.getAnnouncements();
      setAnnouncements(response.announcements);
    } catch (error) {
      console.error('Failed to load announcements:', error);
    } finally {
      setLoading(false);
    }
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleString();
  };

  const renderAnnouncementCard = (announcement: Announcement, index: number) => {
    const IconComponent = typeIcons[announcement.type];
    
    return (
      <motion.div
        key={announcement.id}
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: index * 0.1 }}
      >
        <Card className={styles.announcementCard}>
          <CardPreview>
            <div className={styles.cardContent}>
              <div className={styles.cardHeader}>
                <IconComponent 
                  style={{ color: typeColors[announcement.type] }}
                />
                <Title1 as="h3">{announcement.title}</Title1>
                <Badge 
                  appearance={priorityColors[announcement.priority]}
                  className={styles.priorityBadge}
                >
                  {t(`announcements.priority.${announcement.priority}`)}
                </Badge>
              </div>
              <Body1>{announcement.content}</Body1>
              <div className={styles.cardMeta}>
                <Text size={200}>
                  {t('announcements.publishedAt')}: {formatDate(announcement.createdAt)}
                </Text>
                {announcement.expiresAt && (
                  <Text size={200}>
                    {t('announcements.expiresAt')}: {formatDate(announcement.expiresAt)}
                  </Text>
                )}
              </div>
            </div>
          </CardPreview>
        </Card>
      </motion.div>
    );
  };

  return (
    <div className={styles.container}>
      <div className={styles.header}>
        <Button
          appearance="subtle"
          icon={<ArrowLeft24Regular />}
          onClick={() => navigate('/')}
          className={styles.backButton}
        >
          {t('announcements.backToHome')}
        </Button>
        <Title1>{t('announcements.title')}</Title1>
      </div>

      <div className={styles.content}>
        {loading ? (
          <div className={styles.loadingContainer}>
            <Spinner size="large" label={t('announcements.loading')} />
          </div>
        ) : announcements.length === 0 ? (
          <div className={styles.emptyState}>
            <Info24Regular style={{ fontSize: '48px', marginBottom: '16px' }} />
            <Title1>{t('announcements.noAnnouncements')}</Title1>
            <Body1>{t('announcements.noAnnouncementsDesc')}</Body1>
          </div>
        ) : (
          announcements.map((announcement, index) => 
            renderAnnouncementCard(announcement, index)
          )
        )}
      </div>
    </div>
  );
};

export default Announcements;