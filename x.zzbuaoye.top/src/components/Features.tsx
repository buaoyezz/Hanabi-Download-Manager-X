import { makeStyles, Card, Text, tokens, Title2, Title3 } from '@fluentui/react-components';
import { 
  Flash24Filled, 
  Server24Filled, 
  PaintBrush24Filled,
  Checkmark24Filled,
  ArrowSync24Filled,
  Shield24Filled,
  CloudArrowDown24Filled,
  Settings24Filled
} from '@fluentui/react-icons';
import { motion } from 'framer-motion';
import { useTranslation } from 'react-i18next';

const useStyles = makeStyles({
  section: {
    padding: '120px 48px',
    backgroundColor: tokens.colorNeutralBackground1,
    position: 'relative',
  },
  header: {
    textAlign: 'center',
    marginBottom: '80px',
    maxWidth: '800px',
    margin: '0 auto 80px',
  },
  title: {
    fontSize: 'clamp(2rem, 4vw, 3rem)',
    fontWeight: '800',
    color: tokens.colorNeutralForeground1,
    marginBottom: '16px',
    letterSpacing: '-0.02em',
  },
  description: {
    fontSize: '1.125rem',
    color: tokens.colorNeutralForeground2,
    lineHeight: '1.7',
  },
  grid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))',
    gap: '32px',
    maxWidth: '1400px',
    margin: '0 auto',
  },
  card: {
    height: '100%',
    padding: '48px 36px',
    transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
    borderRadius: '20px',
    border: `2px solid ${tokens.colorNeutralStroke2}`,
    backgroundColor: tokens.colorNeutralBackground1,
    boxShadow: '0 4px 16px rgba(0, 0, 0, 0.04)',
    position: 'relative',
    overflow: 'hidden',
    cursor: 'pointer',
    '::before': {
      content: '""',
      position: 'absolute',
      top: 0,
      left: 0,
      right: 0,
      height: '5px',
      background: `linear-gradient(90deg, ${tokens.colorBrandForeground1}, ${tokens.colorBrandForeground2})`,
      transform: 'scaleX(0)',
      transformOrigin: 'left',
      transition: 'transform 0.3s ease',
    },
    ':hover': {
      transform: 'translateY(-8px)',
      boxShadow: '0 20px 40px rgba(0, 0, 0, 0.12)',
      border: `2px solid ${tokens.colorBrandStroke1}`,
      '::before': {
        transform: 'scaleX(1)',
      },
    },
  },
  iconContainer: {
    width: '72px',
    height: '72px',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: '28px',
    background: `linear-gradient(135deg, ${tokens.colorBrandBackground2}, ${tokens.colorBrandBackground})`,
    borderRadius: '18px',
    transition: 'transform 0.3s ease',
    boxShadow: '0 8px 24px rgba(59, 130, 246, 0.2)',
  },
  icon: {
    fontSize: '36px',
    color: tokens.colorBrandForeground1,
  },
  cardTitle: {
    marginBottom: '16px',
    fontWeight: '700',
    fontSize: '1.5rem',
    color: tokens.colorNeutralForeground1,
    letterSpacing: '-0.01em',
  },
  cardDesc: {
    color: tokens.colorNeutralForeground2,
    lineHeight: '1.8',
    fontSize: '1rem',
  },
  improvementsSection: {
    marginTop: '120px',
    maxWidth: '1000px',
    margin: '120px auto 0',
  },
  improvementsGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
    gap: '24px',
  },
  improvementCard: {
    padding: '32px 28px',
    borderRadius: '16px',
    backgroundColor: tokens.colorNeutralBackground2,
    border: `1px solid ${tokens.colorNeutralStroke2}`,
    transition: 'all 0.2s ease',
    ':hover': {
      transform: 'translateY(-4px)',
      boxShadow: '0 12px 24px rgba(0, 0, 0, 0.08)',
      backgroundColor: tokens.colorNeutralBackground1,
    },
  },
  improvementIcon: {
    marginBottom: '16px',
    color: tokens.colorBrandForeground1,
  },
  improvementText: {
    fontSize: '0.95rem',
    lineHeight: '1.6',
    color: tokens.colorNeutralForeground1,
    fontWeight: '500',
  },
});

const Features = () => {
  const styles = useStyles();
  const { t } = useTranslation();

  const features = [
    {
      icon: <PaintBrush24Filled />,
      title: t('features.design.title'),
      description: t('features.design.description'),
    },
    {
      icon: <Flash24Filled />,
      title: t('features.core.title'),
      description: t('features.core.description'),
    },
    {
      icon: <Server24Filled />,
      title: t('features.experience.title'),
      description: t('features.experience.description'),
    },
  ];

  const improvements = [
    { icon: <CloudArrowDown24Filled />, text: t('features.improvements.list.0', { defaultValue: '多线程并发下载' }) },
    { icon: <ArrowSync24Filled />, text: t('features.improvements.list.1', { defaultValue: '断点续传支持' }) },
    { icon: <Shield24Filled />, text: t('features.improvements.list.2', { defaultValue: '安全可靠' }) },
    { icon: <Settings24Filled />, text: t('features.improvements.list.3', { defaultValue: '高度可定制' }) },
    { icon: <Checkmark24Filled />, text: t('features.improvements.list.4', { defaultValue: '完全免费开源' }) },
    { icon: <Flash24Filled />, text: t('features.improvements.list.5', { defaultValue: '极速体验' }) },
  ];

  return (
    <section id="features" className={styles.section}>
      <div className={styles.header}>
        <Title2 className={styles.title}>{t('features.title')}</Title2>
        <div className={styles.description} dangerouslySetInnerHTML={{ __html: t('features.description', { defaultValue: '强大的功能，极致的体验' }) }} />
      </div>

      <div className={styles.grid}>
        {features.map((feature, index) => (
          <motion.div
            key={index}
            initial={{ opacity: 0, y: 40 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: "-80px" }}
            transition={{ duration: 0.5, delay: index * 0.1 }}
          >
            <Card className={styles.card}>
              <div className={styles.iconContainer}>
                <div className={styles.icon}>{feature.icon}</div>
              </div>
              <Title3 className={styles.cardTitle}>{feature.title}</Title3>
              <div className={styles.cardDesc} dangerouslySetInnerHTML={{ __html: feature.description }} />
            </Card>
          </motion.div>
        ))}
      </div>

      <div className={styles.improvementsSection}>
        <div className={styles.header}>
          <Title2 className={styles.title}>{t('features.improvements.title')}</Title2>
        </div>
        <div className={styles.improvementsGrid}>
          {improvements.map((item, index) => (
            <motion.div
              key={index}
              initial={{ opacity: 0, scale: 0.9 }}
              whileInView={{ opacity: 1, scale: 1 }}
              viewport={{ once: true }}
              transition={{ duration: 0.3, delay: index * 0.05 }}
            >
              <div className={styles.improvementCard}>
                <div className={styles.improvementIcon}>{item.icon}</div>
                <Text className={styles.improvementText}>{item.text}</Text>
              </div>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
};

export default Features;
