import { makeStyles, Button, Display, tokens, Image, Badge } from '@fluentui/react-components';
import { ArrowDownload24Filled, Play24Filled, Sparkle24Filled } from '@fluentui/react-icons';
import { motion } from 'framer-motion';
import { useTranslation } from 'react-i18next';
import logo from '../assets/logo.png';

const useStyles = makeStyles({
  hero: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    textAlign: 'center',
    padding: '160px 32px 140px',
    background: `linear-gradient(180deg, ${tokens.colorBrandBackground2} 0%, ${tokens.colorNeutralBackground1} 100%)`,
    minHeight: '85vh',
    position: 'relative',
    overflow: 'hidden',
    '::before': {
      content: '""',
      position: 'absolute',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      background: 'radial-gradient(circle at 30% 20%, rgba(59, 130, 246, 0.15) 0%, transparent 50%), radial-gradient(circle at 70% 60%, rgba(249, 115, 22, 0.1) 0%, transparent 50%)',
      pointerEvents: 'none',
    },
  },
  badge: {
    marginBottom: '24px',
    position: 'relative',
    zIndex: 1,
  },
  title: {
    marginBottom: '24px',
    color: tokens.colorNeutralForeground1,
    fontSize: 'clamp(2.75rem, 6vw, 4.5rem)',
    fontWeight: '800',
    letterSpacing: '-0.03em',
    lineHeight: '1.1',
    position: 'relative',
    zIndex: 1,
    background: `linear-gradient(135deg, ${tokens.colorNeutralForeground1} 0%, ${tokens.colorBrandForeground1} 100%)`,
    WebkitBackgroundClip: 'text',
    WebkitTextFillColor: 'transparent',
    backgroundClip: 'text',
  },
  subtitle: {
    marginBottom: '48px',
    maxWidth: '720px',
    color: tokens.colorNeutralForeground2,
    lineHeight: '1.8',
    fontSize: 'clamp(1.125rem, 2.5vw, 1.5rem)',
    fontWeight: '400',
    position: 'relative',
    zIndex: 1,
  },
  actions: {
    display: 'flex',
    gap: '16px',
    flexWrap: 'wrap',
    justifyContent: 'center',
    position: 'relative',
    zIndex: 1,
    marginBottom: '32px',
  },
  primaryButton: {
    height: '56px',
    padding: '0 32px',
    fontSize: '16px',
    fontWeight: '600',
    borderRadius: '12px',
    boxShadow: '0 4px 16px rgba(59, 130, 246, 0.3)',
    transition: 'all 0.2s ease',
    ':hover': {
      transform: 'translateY(-2px)',
      boxShadow: '0 8px 24px rgba(59, 130, 246, 0.4)',
    },
  },
  secondaryButton: {
    height: '56px',
    padding: '0 32px',
    fontSize: '16px',
    fontWeight: '600',
    borderRadius: '12px',
    transition: 'all 0.2s ease',
    ':hover': {
      transform: 'translateY(-2px)',
    },
  },
  logoContainer: {
    marginBottom: '40px',
    position: 'relative',
    zIndex: 1,
  },
  heroLogo: {
    width: '140px',
    height: '140px',
    objectFit: 'contain',
    filter: 'drop-shadow(0 12px 32px rgba(0, 0, 0, 0.15))',
    animation: 'float 4s ease-in-out infinite',
  },
  stats: {
    display: 'flex',
    gap: '48px',
    flexWrap: 'wrap',
    justifyContent: 'center',
    position: 'relative',
    zIndex: 1,
    marginTop: '24px',
  },
  stat: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    gap: '8px',
  },
  statNumber: {
    fontSize: '32px',
    fontWeight: '700',
    color: tokens.colorBrandForeground1,
  },
  statLabel: {
    fontSize: '14px',
    color: tokens.colorNeutralForeground3,
    fontWeight: '500',
  },
  '@keyframes float': {
    '0%, 100%': {
      transform: 'translateY(0px) rotate(0deg)',
    },
    '50%': {
      transform: 'translateY(-15px) rotate(2deg)',
    },
  },
});

const Hero = () => {
  const styles = useStyles();
  const { t } = useTranslation();

  return (
    <section className={styles.hero}>
      <motion.div
        className={styles.badge}
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.6 }}
      >
        <Badge 
          appearance="filled" 
          color="brand"
          size="large"
          icon={<Sparkle24Filled />}
        >
          {t('hero.badge', { defaultValue: '2026 全新版本' })}
        </Badge>
      </motion.div>

      <motion.div
        className={styles.logoContainer}
        initial={{ opacity: 0, scale: 0.7 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ duration: 0.7, type: 'spring', stiffness: 100 }}
      >
        <Image src={logo} alt="Hanabi Logo" className={styles.heroLogo} />
      </motion.div>
      
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.8, delay: 0.2 }}
      >
        <Display className={styles.title}>
          {t('hero.title')}
        </Display>
      </motion.div>
      
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.8, delay: 0.3 }}
      >
        <div className={styles.subtitle} dangerouslySetInnerHTML={{ __html: t('hero.subtitle') }} />
      </motion.div>

      <motion.div
        className={styles.actions}
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.8, delay: 0.4 }}
      >
        <Button 
          appearance="primary" 
          size="large"
          icon={<ArrowDownload24Filled />}
          className={styles.primaryButton}
          onClick={() => window.open('https://github.com/buaoyezz/Hanabi-Download-Manager-X/releases', '_blank')}
        >
          {t('hero.downloadNow')}
        </Button>
        <Button 
          appearance="outline" 
          size="large"
          icon={<Play24Filled />}
          className={styles.secondaryButton}
          onClick={() => document.getElementById('features')?.scrollIntoView({ behavior: 'smooth' })}
        >
          {t('hero.learnMore')}
        </Button>
      </motion.div>

      <motion.div
        className={styles.stats}
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 0.8, delay: 0.6 }}
      >
        <div className={styles.stat}>
          <div className={styles.statNumber}>10x</div>
          <div className={styles.statLabel}>{t('hero.stats.faster', { defaultValue: '更快速度' })}</div>
        </div>
        <div className={styles.stat}>
          <div className={styles.statNumber}>100%</div>
          <div className={styles.statLabel}>{t('hero.stats.free', { defaultValue: '完全免费' })}</div>
        </div>
        <div className={styles.stat}>
          <div className={styles.statNumber}>∞</div>
          <div className={styles.statLabel}>{t('hero.stats.downloads', { defaultValue: '无限下载' })}</div>
        </div>
      </motion.div>
    </section>
  );
};

export default Hero;
