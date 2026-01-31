import { makeStyles, tokens, Title1, Text, Button } from '@fluentui/react-components';
import { Home24Regular, ArrowLeft24Regular } from '@fluentui/react-icons';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import Header from '../components/Header';
import Footer from '../components/Footer';

const useStyles = makeStyles({
  container: {
    display: 'flex',
    flexDirection: 'column',
    minHeight: '100vh',
    backgroundColor: tokens.colorNeutralBackground1,
  },
  main: {
    flex: 1,
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    padding: '80px 32px',
    textAlign: 'center',
  },
  errorCode: {
    fontSize: '120px',
    fontWeight: '700',
    color: tokens.colorBrandForeground1,
    lineHeight: 1,
    marginBottom: '24px',
    opacity: 0.8,
  },
  title: {
    marginBottom: '16px',
    color: tokens.colorNeutralForeground1,
  },
  description: {
    marginBottom: '48px',
    maxWidth: '500px',
    color: tokens.colorNeutralForeground2,
    lineHeight: '1.6',
  },
  actions: {
    display: 'flex',
    gap: '16px',
    flexWrap: 'wrap',
    justifyContent: 'center',
  },
});

const NotFound = () => {
  const styles = useStyles();
  const navigate = useNavigate();
  const { i18n } = useTranslation();
  const isZh = i18n.language === 'zh';

  return (
    <div className={styles.container}>
      <Header />
      <main className={styles.main}>
        <div className={styles.errorCode}>404</div>
        <Title1 className={styles.title}>
          {isZh ? '页面未找到' : 'Page Not Found'}
        </Title1>
        <Text className={styles.description}>
          {isZh 
            ? '抱歉，您访问的页面不存在。可能是链接错误或页面已被移除。'
            : 'Sorry, the page you are looking for does not exist. It may have been moved or deleted.'}
        </Text>
        <div className={styles.actions}>
          <Button
            appearance="primary"
            size="large"
            icon={<Home24Regular />}
            onClick={() => navigate('/')}
          >
            {isZh ? '返回首页' : 'Go Home'}
          </Button>
          <Button
            appearance="secondary"
            size="large"
            icon={<ArrowLeft24Regular />}
            onClick={() => navigate(-1)}
          >
            {isZh ? '返回上一页' : 'Go Back'}
          </Button>
        </div>
      </main>
      <Footer />
    </div>
  );
};

export default NotFound;
