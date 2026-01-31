import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import {
  makeStyles,
  tokens,
  Title1,
  Body1,
  Card,
  CardHeader,
  CardPreview,
  Input,
  Button,
  Field,
  Spinner,
  MessageBar,
  MessageBarBody,
  Image
} from '@fluentui/react-components';
import { Eye24Regular, EyeOff24Regular, Person24Regular, LockClosed24Regular } from '@fluentui/react-icons';
import { motion } from 'framer-motion';
import { adminService } from '../services/adminService';
import logo from '../assets/logo.png';

const useStyles = makeStyles({
  container: {
    minHeight: '100vh',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: tokens.colorNeutralBackground1,
    padding: '24px',
  },
  loginCard: {
    width: '100%',
    maxWidth: '400px',
    padding: '32px',
  },
  header: {
    textAlign: 'center',
    marginBottom: '32px',
  },
  logo: {
    height: '48px',
    width: '48px',
    marginBottom: '16px',
  },
  form: {
    display: 'flex',
    flexDirection: 'column',
    gap: '16px',
  },
  passwordField: {
    position: 'relative',
  },
  passwordToggle: {
    position: 'absolute',
    right: '8px',
    top: '50%',
    transform: 'translateY(-50%)',
    border: 'none',
    background: 'transparent',
    cursor: 'pointer',
    padding: '4px',
    color: tokens.colorNeutralForeground3,
  },
  submitButton: {
    marginTop: '8px',
  },
  messageBar: {
    marginBottom: '16px',
  },
  backLink: {
    textAlign: 'center',
    marginTop: '24px',
  },
});

const AdminLogin = () => {
  const styles = useStyles();
  const { t } = useTranslation();
  const navigate = useNavigate();
  
  const [formData, setFormData] = useState({
    username: '',
    password: '',
  });
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleInputChange = (field: string, value: string) => {
    setFormData(prev => ({ ...prev, [field]: value }));
    if (error) setError(''); // 清除错误信息
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!formData.username || !formData.password) {
      setError(t('admin.login.validation.required'));
      return;
    }

    setLoading(true);
    setError('');

    try {
      const response = await adminService.login(formData);
      
      if (response.success) {
        // 登录成功，跳转到管理面板
        navigate('/admin/dashboard');
      } else {
        setError(response.message || t('admin.login.error.failed'));
      }
    } catch (error) {
      console.error('Login error:', error);
      setError(t('admin.login.error.network'));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className={styles.container}>
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5 }}
      >
        <Card className={styles.loginCard}>
          <CardHeader>
            <div className={styles.header}>
              <Image src={logo} alt="Logo" className={styles.logo} />
              <Title1>{t('admin.login.title')}</Title1>
              <Body1>{t('admin.login.subtitle')}</Body1>
            </div>
          </CardHeader>
          
          <CardPreview>
            <form onSubmit={handleSubmit} className={styles.form}>
              {error && (
                <MessageBar intent="error" className={styles.messageBar}>
                  <MessageBarBody>{error}</MessageBarBody>
                </MessageBar>
              )}

              <Field label={t('admin.login.username')}>
                <Input
                  value={formData.username}
                  onChange={(e) => handleInputChange('username', e.target.value)}
                  placeholder={t('admin.login.usernamePlaceholder')}
                  contentBefore={<Person24Regular />}
                  disabled={loading}
                />
              </Field>

              <Field label={t('admin.login.password')}>
                <div className={styles.passwordField}>
                  <Input
                    type={showPassword ? 'text' : 'password'}
                    value={formData.password}
                    onChange={(e) => handleInputChange('password', e.target.value)}
                    placeholder={t('admin.login.passwordPlaceholder')}
                    contentBefore={<LockClosed24Regular />}
                    disabled={loading}
                  />
                  <button
                    type="button"
                    className={styles.passwordToggle}
                    onClick={() => setShowPassword(!showPassword)}
                    disabled={loading}
                  >
                    {showPassword ? <EyeOff24Regular /> : <Eye24Regular />}
                  </button>
                </div>
              </Field>

              <Button
                type="submit"
                appearance="primary"
                disabled={loading || !formData.username || !formData.password}
                className={styles.submitButton}
              >
                {loading ? (
                  <>
                    <Spinner size="tiny" />
                    {t('admin.login.loggingIn')}
                  </>
                ) : (
                  t('admin.login.submit')
                )}
              </Button>
            </form>
          </CardPreview>
        </Card>

        <div className={styles.backLink}>
          <Button
            appearance="subtle"
            onClick={() => navigate('/')}
          >
            {t('admin.login.backToHome')}
          </Button>
        </div>
      </motion.div>
    </div>
  );
};

export default AdminLogin;