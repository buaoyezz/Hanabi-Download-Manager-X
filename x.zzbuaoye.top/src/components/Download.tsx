import { makeStyles, Button, Title2, Text, tokens } from '@fluentui/react-components';
import { ArrowDownload24Filled, Code24Filled, WindowNew24Filled } from '@fluentui/react-icons';
import { useTranslation } from 'react-i18next';
import { motion } from 'framer-motion';

const useStyles = makeStyles({
  section: {
    padding: '120px 48px',
    background: `linear-gradient(135deg, ${tokens.colorBrandBackground2} 0%, ${tokens.colorBrandBackground} 100%)`,
    textAlign: 'center',
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    gap: '40px',
    position: 'relative',
    overflow: 'hidden',
    '::before': {
      content: '""',
      position: 'absolute',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      background: 'radial-gradient(circle at 30% 20%, rgba(255, 255, 255, 0.15) 0%, transparent 50%), radial-gradient(circle at 70% 80%, rgba(255, 255, 255, 0.1) 0%, transparent 50%)',
      pointerEvents: 'none',
    },
  },
  content: {
    position: 'relative',
    zIndex: 1,
    maxWidth: '800px',
  },
  title: {
    fontSize: 'clamp(2rem, 4vw, 3rem)',
    fontWeight: '800',
    color: tokens.colorNeutralForeground1,
    marginBottom: '20px',
    letterSpacing: '-0.02em',
  },
  description: {
    maxWidth: '680px',
    margin: '0 auto 16px',
    color: tokens.colorNeutralForeground1,
    lineHeight: '1.8',
    fontSize: '1.125rem',
  },
  requirements: {
    color: tokens.colorNeutralForeground2,
    fontSize: '0.95rem',
    fontStyle: 'italic',
  },
  buttons: {
    display: 'flex',
    gap: '16px',
    flexWrap: 'wrap',
    justifyContent: 'center',
    position: 'relative',
    zIndex: 1,
    marginTop: '16px',
  },
  primaryButton: {
    height: '56px',
    padding: '0 40px',
    fontSize: '16px',
    fontWeight: '600',
    borderRadius: '12px',
    boxShadow: '0 4px 20px rgba(0, 0, 0, 0.15)',
    transition: 'all 0.2s ease',
    ':hover': {
      transform: 'translateY(-2px)',
      boxShadow: '0 8px 28px rgba(0, 0, 0, 0.2)',
    },
  },
  secondaryButton: {
    height: '56px',
    padding: '0 40px',
    fontSize: '16px',
    fontWeight: '600',
    borderRadius: '12px',
    backgroundColor: 'rgba(255, 255, 255, 0.9)',
    transition: 'all 0.2s ease',
    ':hover': {
      transform: 'translateY(-2px)',
      backgroundColor: 'rgba(255, 255, 255, 1)',
    },
  },
  platformBadges: {
    display: 'flex',
    gap: '24px',
    justifyContent: 'center',
    flexWrap: 'wrap',
    marginTop: '32px',
    position: 'relative',
    zIndex: 1,
  },
  badge: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    padding: '12px 24px',
    backgroundColor: 'rgba(255, 255, 255, 0.15)',
    backdropFilter: 'blur(10px)',
    borderRadius: '12px',
    border: '1px solid rgba(255, 255, 255, 0.2)',
    color: tokens.colorNeutralForeground1,
    fontSize: '14px',
    fontWeight: '500',
  },
});

const Download = () => {
  const styles = useStyles();
  const { t } = useTranslation();

  return (
    <section id="download" className={styles.section}>
      <motion.div
        className={styles.content}
        initial={{ opacity: 0, y: 30 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true }}
        transition={{ duration: 0.6 }}
      >
        <Title2 className={styles.title}>{t('download.title')}</Title2>
        <div className={styles.description} dangerouslySetInnerHTML={{ __html: t('download.description') }} />
        <Text className={styles.requirements}>
          {t('download.requirements')}
        </Text>
      </motion.div>

      <motion.div
        className={styles.buttons}
        initial={{ opacity: 0, y: 20 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true }}
        transition={{ duration: 0.6, delay: 0.2 }}
      >
        <Button 
          appearance="primary" 
          size="large"
          icon={<ArrowDownload24Filled />}
          className={styles.primaryButton}
          onClick={() => window.open('https://github.com/buaoyezz/Hanabi-Download-Manager-X/releases', '_blank')}
        >
          {t('download.buttonWindows')}
        </Button>
        <Button 
          appearance="secondary" 
          size="large"
          icon={<Code24Filled />}
          className={styles.secondaryButton}
          onClick={() => window.open('https://github.com/buaoyezz/Hanabi-Download-Manager-X', '_blank')}
        >
          {t('download.buttonSource')}
        </Button>
      </motion.div>

      <motion.div
        className={styles.platformBadges}
        initial={{ opacity: 0 }}
        whileInView={{ opacity: 1 }}
        viewport={{ once: true }}
        transition={{ duration: 0.6, delay: 0.4 }}
      >
        <div className={styles.badge}>
          <WindowNew24Filled />
          Windows 10/11
        </div>
        <div className={styles.badge}>
          <Code24Filled />
          {t('download.openSource', { defaultValue: '开源免费' })}
        </div>
      </motion.div>
    </section>
  );
};

export default Download;
