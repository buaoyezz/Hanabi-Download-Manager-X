import { makeStyles, tokens, Title1, Title2, Text } from '@fluentui/react-components';
import { 
  Document24Regular,
  LockClosed24Regular,
  Database24Regular,
  ShieldError24Regular,
  Globe24Regular,
  DataUsage24Regular,
  Code24Regular,
  People24Regular,
  Checkmark24Regular,
  ArrowSync24Regular,
  Mail24Regular,
  Calendar24Regular
} from '@fluentui/react-icons';
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
    maxWidth: '1000px',
    margin: '0 auto',
    padding: '64px 24px 80px',
    width: '100%',
    '@media (min-width: 768px)': {
      padding: '80px 48px 100px',
    },
  },
  hero: {
    marginBottom: '56px',
    textAlign: 'center',
  },
  title: {
    marginBottom: '16px',
    fontSize: '42px',
    fontWeight: 700,
    background: `linear-gradient(135deg, ${tokens.colorBrandForeground1} 0%, ${tokens.colorBrandForeground2} 100%)`,
    WebkitBackgroundClip: 'text',
    WebkitTextFillColor: 'transparent',
    backgroundClip: 'text',
  },
  subtitle: {
    color: tokens.colorNeutralForeground3,
    fontSize: '16px',
    marginTop: '12px',
  },
  lastUpdated: {
    display: 'inline-flex',
    alignItems: 'center',
    gap: '8px',
    marginTop: '20px',
    padding: '8px 16px',
    backgroundColor: tokens.colorNeutralBackground3,
    borderRadius: tokens.borderRadiusMedium,
    color: tokens.colorNeutralForeground2,
    fontSize: '14px',
  },
  card: {
    marginBottom: '24px',
    padding: '32px',
    backgroundColor: tokens.colorNeutralBackground2,
    borderRadius: tokens.borderRadiusXLarge,
    border: `1px solid ${tokens.colorNeutralStroke2}`,
    boxShadow: tokens.shadow4,
    transition: 'all 0.2s ease',
    ':hover': {
      boxShadow: tokens.shadow8,
      transform: 'translateY(-2px)',
    },
  },
  sectionTitle: {
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
    marginBottom: '20px',
    color: tokens.colorBrandForeground1,
    fontSize: '24px',
    fontWeight: 600,
  },
  sectionIcon: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    width: '32px',
    height: '32px',
    borderRadius: tokens.borderRadiusMedium,
    backgroundColor: tokens.colorBrandBackground2,
    color: tokens.colorBrandForeground1,
  },
  paragraph: {
    marginBottom: '16px',
    lineHeight: '1.7',
    color: tokens.colorNeutralForeground1,
    fontSize: '15px',
  },
  list: {
    marginLeft: '0',
    marginBottom: '20px',
    paddingLeft: '0',
    listStyle: 'none',
  },
  listItem: {
    display: 'flex',
    alignItems: 'flex-start',
    gap: '12px',
    marginBottom: '14px',
    lineHeight: '1.7',
    color: tokens.colorNeutralForeground1,
    fontSize: '15px',
    '::before': {
      content: '"✓"',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      minWidth: '20px',
      height: '20px',
      marginTop: '2px',
      borderRadius: '50%',
      backgroundColor: tokens.colorPaletteGreenBackground2,
      color: tokens.colorPaletteGreenForeground1,
      fontSize: '12px',
      fontWeight: 'bold',
    },
  },
  highlight: {
    padding: '20px 24px',
    marginBottom: '20px',
    backgroundColor: tokens.colorNeutralBackground4,
    borderLeft: `4px solid ${tokens.colorBrandForeground1}`,
    borderRadius: tokens.borderRadiusMedium,
  },
  link: {
    color: tokens.colorBrandForeground1,
    textDecoration: 'none',
    fontWeight: 500,
    transition: 'color 0.2s ease',
    ':hover': {
      color: tokens.colorBrandForeground2,
      textDecoration: 'underline',
    },
  },
  footer: {
    marginTop: '60px',
    paddingTop: '32px',
    borderTop: `2px solid ${tokens.colorNeutralStroke2}`,
    textAlign: 'center',
  },
  footerText: {
    color: tokens.colorNeutralForeground3,
    fontSize: '14px',
    fontStyle: 'italic',
  },
});

const PrivacyPolicy = () => {
  const styles = useStyles();
  const { i18n } = useTranslation();
  const isZh = i18n.language === 'zh';

  return (
    <div className={styles.container}>
      <Header />
      <main className={styles.main}>
        <div className={styles.hero}>
          <Title1 className={styles.title}>
            {isZh ? '隐私政策' : 'Privacy Policy'}
          </Title1>
          <Text className={styles.subtitle}>
            {isZh ? '我们重视您的隐私，承诺保护您的个人信息' : 'We value your privacy and are committed to protecting your personal information'}
          </Text>
          <div className={styles.lastUpdated}>
            <Calendar24Regular />
            <Text>
              {isZh ? '最后更新：2026年1月17日' : 'Last Updated: January 17, 2026'}
            </Text>
          </div>
        </div>

        {isZh ? (
          <>
            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><Document24Regular /></div>
                1. 概述
              </Title2>
              <Text className={styles.paragraph}>
                Hanabi Download Manager X（以下简称"本软件"）非常重视您的隐私。本隐私政策说明了我们如何处理您的信息。
              </Text>
              <div className={styles.highlight}>
                <Text className={styles.paragraph} style={{ marginBottom: 0, fontWeight: 600 }}>
                  简而言之：我们不收集、不存储、不传输您的任何个人信息。
                </Text>
              </div>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><LockClosed24Regular /></div>
                2. 信息收集
              </Title2>
              <Text className={styles.paragraph}>
                本软件是一个完全本地运行的应用程序，我们：
              </Text>
              <ul className={styles.list}>
                <li className={styles.listItem}>不收集您的个人身份信息</li>
                <li className={styles.listItem}>不收集您的下载历史</li>
                <li className={styles.listItem}>不收集您的浏览数据</li>
                <li className={styles.listItem}>不使用任何追踪技术（如 cookies、分析工具等）</li>
                <li className={styles.listItem}>不要求您注册账户或提供个人信息</li>
                <li className={styles.listItem}>本网站仅使用一个 Cookie 来存储您的语言偏好（中文/英文），有效期30天。这是唯一使用的 Cookie，不用于追踪或分析。</li>
              </ul>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><Database24Regular /></div>
                3. 数据存储
              </Title2>
              <Text className={styles.paragraph}>
                所有数据（包括下载任务、设置、配置等）都存储在您的本地设备上。我们无法访问这些数据，也不会将其传输到任何远程服务器。
              </Text>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><ShieldError24Regular /></div>
                4. 第三方服务
              </Title2>
              <Text className={styles.paragraph}>
                本软件不集成任何第三方分析服务、广告网络或数据收集工具。您的下载活动完全私密，仅在您的设备上进行。
              </Text>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><Globe24Regular /></div>
                5. 网络连接
              </Title2>
              <Text className={styles.paragraph}>
                本软件仅在以下情况下建立网络连接：
              </Text>
              <ul className={styles.list}>
                <li className={styles.listItem}>执行您请求的下载任务</li>
                <li className={styles.listItem}>检查软件更新（如果您启用此功能）</li>
                <li className={styles.listItem}>发送在线统计信息（如果您启用此功能）</li>
              </ul>
              <Text className={styles.paragraph}>
                这些连接直接在您的设备和目标服务器之间建立，不经过我们的服务器。
              </Text>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><DataUsage24Regular /></div>
                6. 在线统计功能
              </Title2>
              <Text className={styles.paragraph}>
                本软件包含可选的在线统计功能，用于显示当前有多少用户正在使用 Hanabi。此功能收集以下最小化信息：
              </Text>
              <ul className={styles.list}>
                <li className={styles.listItem}>匿名设备 ID（随机生成的 UUID，不包含任何个人信息）</li>
                <li className={styles.listItem}>操作系统类型（如 Windows、macOS）</li>
                <li className={styles.listItem}>应用版本号</li>
                <li className={styles.listItem}>启动次数（仅用于统计活跃度）</li>
                <li className={styles.listItem}>最后启动时间</li>
              </ul>
              <Text className={styles.paragraph}>
                此功能默认启用，但您可以随时在设置中关闭。收集的数据仅用于显示在线用户数量，不会用于任何其他目的。数据在24小时无活动后自动删除。
              </Text>
              <div className={styles.highlight}>
                <Text className={styles.paragraph} style={{ marginBottom: 0 }}>
                  <strong>重要说明：</strong>设备 ID 是完全随机生成的，不与您的任何个人信息关联。我们无法通过此 ID 识别您的身份。
                </Text>
              </div>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><Code24Regular /></div>
                7. 开源透明
              </Title2>
              <Text className={styles.paragraph}>
                本软件是开源的，源代码托管在 GitHub 上。您可以随时审查代码以验证我们的隐私承诺。
              </Text>
              <Text className={styles.paragraph}>
                GitHub 仓库：
                <a 
                  href="https://github.com/buaoyezz/Hanabi-Download-Manager-X" 
                  target="_blank" 
                  rel="noopener noreferrer"
                  className={styles.link}
                >
                  https://github.com/buaoyezz/Hanabi-Download-Manager-X
                </a>
              </Text>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><People24Regular /></div>
                8. 儿童隐私
              </Title2>
              <Text className={styles.paragraph}>
                本软件不针对13岁以下的儿童，我们也不会故意收集儿童的个人信息。由于我们不收集任何信息，因此不存在儿童隐私风险。
              </Text>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><Checkmark24Regular /></div>
                9. 您的权利
              </Title2>
              <Text className={styles.paragraph}>
                由于我们不收集您的数据，因此不存在需要访问、修改或删除的数据。您完全控制存储在本地设备上的所有信息。
              </Text>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><ArrowSync24Regular /></div>
                10. 政策变更
              </Title2>
              <Text className={styles.paragraph}>
                我们可能会不时更新本隐私政策。任何更改都将在本页面上发布。我们承诺始终保持"零数据收集"的原则。
              </Text>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><Mail24Regular /></div>
                11. 联系我们
              </Title2>
              <Text className={styles.paragraph}>
                如果您对本隐私政策有任何疑问，请通过 GitHub Issues 联系我们：
              </Text>
              <Text className={styles.paragraph}>
                <a 
                  href="https://github.com/buaoyezz/Hanabi-Download-Manager-X/issues" 
                  target="_blank" 
                  rel="noopener noreferrer"
                  className={styles.link}
                >
                  https://github.com/buaoyezz/Hanabi-Download-Manager-X/issues
                </a>
              </Text>
            </div>

            <div className={styles.footer}>
              <Text className={styles.footerText}>
                您的隐私对我们至关重要。感谢您信任 Hanabi Download Manager X！
              </Text>
            </div>
          </>
        ) : (
          <>
            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><Document24Regular /></div>
                1. Overview
              </Title2>
              <Text className={styles.paragraph}>
                Hanabi Download Manager X (hereinafter referred to as "the Software") takes your privacy very seriously. This Privacy Policy explains how we handle your information.
              </Text>
              <div className={styles.highlight}>
                <Text className={styles.paragraph} style={{ marginBottom: 0, fontWeight: 600 }}>
                  In short: We do not collect, store, or transmit any of your personal information.
                </Text>
              </div>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><LockClosed24Regular /></div>
                2. Information Collection
              </Title2>
              <Text className={styles.paragraph}>
                The Software is a completely local application. We:
              </Text>
              <ul className={styles.list}>
                <li className={styles.listItem}>Do not collect your personal identification information</li>
                <li className={styles.listItem}>Do not collect your download history</li>
                <li className={styles.listItem}>Do not collect your browsing data</li>
                <li className={styles.listItem}>Do not use any tracking technologies (such as cookies, analytics tools, etc.)</li>
                <li className={styles.listItem}>Do not require you to register an account or provide personal information</li>
                <li className={styles.listItem}>This website only uses one cookie to store your language preference (Chinese/English) for 30 days. This is the only cookie used and is not used for tracking or analytics.</li>
              </ul>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><Database24Regular /></div>
                3. Data Storage
              </Title2>
              <Text className={styles.paragraph}>
                All data (including download tasks, settings, configurations, etc.) is stored on your local device. We cannot access this data and do not transmit it to any remote servers.
              </Text>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><ShieldError24Regular /></div>
                4. Third-Party Services
              </Title2>
              <Text className={styles.paragraph}>
                The Software does not integrate any third-party analytics services, advertising networks, or data collection tools. Your download activities are completely private and occur only on your device.
              </Text>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><Globe24Regular /></div>
                5. Network Connections
              </Title2>
              <Text className={styles.paragraph}>
                The Software only establishes network connections in the following cases:
              </Text>
              <ul className={styles.list}>
                <li className={styles.listItem}>To perform download tasks you request</li>
                <li className={styles.listItem}>To check for software updates (if you enable this feature)</li>
                <li className={styles.listItem}>To send online statistics information (if you enable this feature)</li>
              </ul>
              <Text className={styles.paragraph}>
                These connections are established directly between your device and the target servers, not through our servers.
              </Text>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><DataUsage24Regular /></div>
                6. Online Statistics Feature
              </Title2>
              <Text className={styles.paragraph}>
                The Software includes an optional online statistics feature to show how many users are currently using Hanabi. This feature collects the following minimal information:
              </Text>
              <ul className={styles.list}>
                <li className={styles.listItem}>Anonymous device ID (randomly generated UUID, contains no personal information)</li>
                <li className={styles.listItem}>Operating system type (e.g., Windows, macOS)</li>
                <li className={styles.listItem}>Application version number</li>
                <li className={styles.listItem}>Launch count (for activity statistics only)</li>
                <li className={styles.listItem}>Last launch time</li>
              </ul>
              <Text className={styles.paragraph}>
                This feature is enabled by default but can be disabled in settings at any time. Collected data is only used to display online user count and is not used for any other purpose. Data is automatically deleted after 24 hours of inactivity.
              </Text>
              <div className={styles.highlight}>
                <Text className={styles.paragraph} style={{ marginBottom: 0 }}>
                  <strong>Important Note:</strong> The device ID is completely randomly generated and is not associated with any of your personal information. We cannot identify you through this ID.
                </Text>
              </div>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><Code24Regular /></div>
                7. Open Source Transparency
              </Title2>
              <Text className={styles.paragraph}>
                The Software is open source, with source code hosted on GitHub. You can review the code at any time to verify our privacy commitments.
              </Text>
              <Text className={styles.paragraph}>
                GitHub Repository:
                <a 
                  href="https://github.com/buaoyezz/Hanabi-Download-Manager-X" 
                  target="_blank" 
                  rel="noopener noreferrer"
                  className={styles.link}
                >
                  https://github.com/buaoyezz/Hanabi-Download-Manager-X
                </a>
              </Text>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><People24Regular /></div>
                8. Children's Privacy
              </Title2>
              <Text className={styles.paragraph}>
                The Software is not directed at children under 13, and we do not knowingly collect personal information from children. Since we do not collect any information, there are no children's privacy risks.
              </Text>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><Checkmark24Regular /></div>
                9. Your Rights
              </Title2>
              <Text className={styles.paragraph}>
                Since we do not collect your data, there is no data to access, modify, or delete. You have complete control over all information stored on your local device.
              </Text>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><ArrowSync24Regular /></div>
                10. Policy Changes
              </Title2>
              <Text className={styles.paragraph}>
                We may update this Privacy Policy from time to time. Any changes will be posted on this page. We are committed to maintaining our "zero data collection" principle.
              </Text>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><Mail24Regular /></div>
                11. Contact Us
              </Title2>
              <Text className={styles.paragraph}>
                If you have any questions about this Privacy Policy, please contact us via GitHub Issues:
              </Text>
              <Text className={styles.paragraph}>
                <a 
                  href="https://github.com/buaoyezz/Hanabi-Download-Manager-X/issues" 
                  target="_blank" 
                  rel="noopener noreferrer"
                  className={styles.link}
                >
                  https://github.com/buaoyezz/Hanabi-Download-Manager-X/issues
                </a>
              </Text>
            </div>

            <div className={styles.footer}>
              <Text className={styles.footerText}>
                Your privacy is paramount to us. Thank you for trusting Hanabi Download Manager X!
              </Text>
            </div>
          </>
        )}
      </main>
      <Footer />
    </div>
  );
};

export default PrivacyPolicy;
