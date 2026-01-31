import { makeStyles, Text, tokens, Image } from '@fluentui/react-components';
import { Heart20Filled } from '@fluentui/react-icons';
import { useTranslation } from 'react-i18next';
import logo from '../assets/logo.png';

const useStyles = makeStyles({
  footer: {
    padding: '80px 48px 32px',
    backgroundColor: '#fafafa',
    borderTop: `2px solid ${tokens.colorNeutralStroke2}`,
  },
  footerContent: {
    maxWidth: '1280px',
    margin: '0 auto',
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))',
    gap: '48px',
    marginBottom: '48px',
  },
  brandSection: {
    display: 'flex',
    flexDirection: 'column',
    gap: '16px',
  },
  brandLogo: {
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
    marginBottom: '8px',
  },
  logoImage: {
    width: '40px',
    height: '40px',
    objectFit: 'contain',
  },
  brandName: {
    fontSize: '20px',
    fontWeight: '600',
    color: tokens.colorBrandForeground1,
  },
  brandDesc: {
    color: tokens.colorNeutralForeground2,
    lineHeight: '1.6',
    fontSize: '14px',
  },
  linksSection: {
    display: 'flex',
    flexDirection: 'column',
    gap: '16px',
  },
  sectionTitle: {
    fontSize: '16px',
    fontWeight: '600',
    color: tokens.colorNeutralForeground1,
    marginBottom: '8px',
  },
  linksList: {
    display: 'flex',
    flexDirection: 'column',
    gap: '12px',
    listStyle: 'none',
    padding: 0,
    margin: 0,
  },
  link: {
    color: tokens.colorNeutralForeground2,
    textDecoration: 'none',
    fontSize: '14px',
    fontWeight: '400',
    transition: 'all 0.2s ease',
    display: 'inline-block',
    position: 'relative',
    width: 'fit-content',
    '::after': {
      content: '""',
      position: 'absolute',
      bottom: '-2px',
      left: 0,
      right: 0,
      height: '2px',
      backgroundColor: tokens.colorBrandForeground1,
      transform: 'scaleX(0)',
      transformOrigin: 'left',
      transition: 'transform 0.2s ease',
    },
    ':hover': {
      color: tokens.colorBrandForeground1,
      transform: 'translateX(4px)',
      '::after': {
        transform: 'scaleX(1)',
      },
    },
  },
  bottomBar: {
    paddingTop: '32px',
    borderTop: `1px solid ${tokens.colorNeutralStroke2}`,
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    flexWrap: 'wrap',
    gap: '16px',
    maxWidth: '1280px',
    margin: '0 auto',
  },
  copyright: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    color: tokens.colorNeutralForeground3,
    fontSize: '13px',
  },
  madeWithLove: {
    display: 'flex',
    alignItems: 'center',
    gap: '6px',
    color: tokens.colorNeutralForeground3,
    fontSize: '13px',
  },
  heartIcon: {
    color: '#e74c3c',
    animation: 'heartbeat 1.5s ease-in-out infinite',
  },
  '@keyframes heartbeat': {
    '0%, 100%': {
      transform: 'scale(1)',
    },
    '10%, 30%': {
      transform: 'scale(1.1)',
    },
    '20%, 40%': {
      transform: 'scale(1)',
    },
  },
});

const Footer = () => {
  const styles = useStyles();
  const { t } = useTranslation();

  return (
    <footer className={styles.footer}>
      <div className={styles.footerContent}>
        {/* Brand Section */}
        <div className={styles.brandSection}>
          <div className={styles.brandLogo}>
            <Image src={logo} alt="Hanabi Logo" className={styles.logoImage} />
            <span className={styles.brandName}>Hanabi Download Manager X</span>
          </div>
          <Text className={styles.brandDesc}>
            {t('hero.subtitle')}
            <br />
            {t('hero.subtitle2')}
          </Text>
        </div>

        {/* Quick Links */}
        <div className={styles.linksSection}>
          <div className={styles.sectionTitle}>{t('footer.quickLinks') || 'Quick Links'}</div>
          <ul className={styles.linksList}>
            <li>
              <a href="#features" className={styles.link}>{t('header.features')}</a>
            </li>
            <li>
              <a href="#comparison" className={styles.link}>{t('header.comparison')}</a>
            </li>
            <li>
              <a href="#download" className={styles.link}>{t('header.download')}</a>
            </li>
          </ul>
        </div>

        {/* Resources */}
        <div className={styles.linksSection}>
          <div className={styles.sectionTitle}>{t('footer.resources') || 'Resources'}</div>
          <ul className={styles.linksList}>
            <li>
              <a href="https://github.com/buaoyezz/Hanabi-Download-Manager-X" className={styles.link} target="_blank" rel="noopener noreferrer">
                GitHub
              </a>
            </li>
            <li>
              <a href="https://github.com/buaoyezz/Hanabi-Download-Manager-X/releases" className={styles.link} target="_blank" rel="noopener noreferrer">
                {t('footer.releases') || 'Releases'}
              </a>
            </li>
            <li>
              <a href="https://github.com/buaoyezz/Hanabi-Download-Manager-X/issues" className={styles.link} target="_blank" rel="noopener noreferrer">
                {t('footer.issues') || 'Issues'}
              </a>
            </li>
          </ul>
        </div>

        {/* Legal */}
        <div className={styles.linksSection}>
          <div className={styles.sectionTitle}>{t('footer.legal') || 'Legal'}</div>
          <ul className={styles.linksList}>
            <li>
              <a href="/privacy" className={styles.link}>{t('footer.privacy')}</a>
            </li>
            <li>
              <a href="/terms" className={styles.link}>{t('footer.terms')}</a>
            </li>
            <li>
              <Text className={styles.brandDesc}>{t('footer.license')}</Text>
            </li>
          </ul>
        </div>
      </div>

      {/* Bottom Bar */}
      <div className={styles.bottomBar}>
        <div className={styles.copyright}>
          <Text>{t('footer.copyright')}</Text>
        </div>
        <div className={styles.madeWithLove}>
          <Text>{t('footer.design')}</Text>
          <Heart20Filled className={styles.heartIcon} />
        </div>
      </div>
    </footer>
  );
};

export default Footer;
