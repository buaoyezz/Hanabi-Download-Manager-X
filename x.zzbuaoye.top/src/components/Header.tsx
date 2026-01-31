import { makeStyles, Button, tokens, Subtitle2, Menu, MenuTrigger, MenuList, MenuItem, MenuPopover, Image, Badge } from '@fluentui/react-components';
import { ArrowDownload24Filled, LocalLanguage24Filled, Megaphone24Filled, Navigation24Filled } from '@fluentui/react-icons';
import { useTranslation } from 'react-i18next';
import { useNavigate } from 'react-router-dom';
import { useAnnouncements } from '../hooks/useAnnouncements';
import logo from '../assets/logo.png';

const useStyles = makeStyles({
  header: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: '20px 56px',
    backgroundColor: 'rgba(255, 255, 255, 0.98)',
    backdropFilter: 'blur(24px)',
    position: 'sticky',
    top: 0,
    zIndex: 1000,
    boxShadow: '0 2px 16px rgba(0, 0, 0, 0.06)',
    borderBottom: `1px solid ${tokens.colorNeutralStroke2}`,
    transition: 'all 0.3s ease',
  },
  logo: {
    display: 'flex',
    alignItems: 'center',
    gap: '14px',
    color: tokens.colorBrandForeground1,
    fontWeight: '700',
    fontSize: '24px',
    cursor: 'pointer',
    transition: 'transform 0.2s ease',
    ':hover': {
      transform: 'scale(1.03)',
    },
  },
  logoImage: {
    height: '40px',
    width: '40px',
    objectFit: 'contain',
    transition: 'transform 0.3s ease',
    ':hover': {
      transform: 'rotate(8deg)',
    },
  },
  nav: {
    display: 'flex',
    gap: '12px',
    alignItems: 'center',
  },
  navButton: {
    fontWeight: '500',
    fontSize: '15px',
    transition: 'all 0.2s ease',
    ':hover': {
      transform: 'translateY(-1px)',
    },
  },
  announcementButton: {
    position: 'relative',
  },
  announcementBadge: {
    position: 'absolute',
    top: '-6px',
    right: '-6px',
    minWidth: '10px',
    height: '10px',
    padding: 0,
    animation: 'pulse 2s infinite',
  },
  primaryButton: {
    fontWeight: '600',
    fontSize: '15px',
    boxShadow: '0 2px 8px rgba(59, 130, 246, 0.25)',
    transition: 'all 0.2s ease',
    ':hover': {
      transform: 'translateY(-2px)',
      boxShadow: '0 4px 12px rgba(59, 130, 246, 0.35)',
    },
  },
  '@keyframes pulse': {
    '0%, 100%': {
      opacity: 1,
    },
    '50%': {
      opacity: 0.5,
    },
  },
});

const Header = () => {
  const styles = useStyles();
  const { t, i18n } = useTranslation();
  const navigate = useNavigate();
  const { hasActiveAnnouncements, loading } = useAnnouncements();

  const scrollToSection = (id: string) => {
    const element = document.getElementById(id);
    if (element) {
      element.scrollIntoView({ behavior: 'smooth' });
    }
  };

  const changeLanguage = (lng: string) => {
    i18n.changeLanguage(lng);
  };

  return (
    <header className={styles.header}>
      <div className={styles.logo} onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })}>
        <Image src={logo} alt="Hanabi Logo" className={styles.logoImage} />
        <Subtitle2>{t('header.title')}</Subtitle2>
      </div>
      <nav className={styles.nav}>
        <Button 
          appearance="subtle" 
          className={styles.navButton}
          icon={<Navigation24Filled />}
          onClick={() => scrollToSection('features')}
        >
          {t('header.features')}
        </Button>
        <Button 
          appearance="subtle" 
          className={styles.navButton}
          onClick={() => scrollToSection('comparison')}
        >
          {t('header.comparison')}
        </Button>
        <Button 
          appearance="subtle" 
          className={styles.navButton}
          onClick={() => scrollToSection('download')}
        >
          {t('header.download')}
        </Button>
        
        {!loading && hasActiveAnnouncements && (
          <div className={styles.announcementButton}>
            <Button 
              appearance="subtle" 
              icon={<Megaphone24Filled />}
              className={styles.navButton}
              onClick={() => navigate('/announcements')}
            >
              {t('header.announcements')}
            </Button>
            <Badge 
              appearance="filled" 
              color="danger"
              className={styles.announcementBadge}
            />
          </div>
        )}
        
        <Menu>
          <MenuTrigger disableButtonEnhancement>
            <Button appearance="subtle" icon={<LocalLanguage24Filled />} className={styles.navButton} />
          </MenuTrigger>
          <MenuPopover>
            <MenuList>
              <MenuItem onClick={() => changeLanguage('en')}>English</MenuItem>
              <MenuItem onClick={() => changeLanguage('zh')}>中文</MenuItem>
            </MenuList>
          </MenuPopover>
        </Menu>

        <Button 
          appearance="primary" 
          icon={<ArrowDownload24Filled />}
          className={styles.primaryButton}
          onClick={() => window.open('https://github.com/buaoyezz/Hanabi-Download-Manager-X/releases', '_blank')}
        >
          {t('header.getStarted')}
        </Button>
      </nav>
    </header>
  );
};

export default Header;
