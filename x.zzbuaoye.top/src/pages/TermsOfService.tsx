import { makeStyles, tokens, Title1, Title2, Text } from '@fluentui/react-components';
import { 
  Document24Regular,
  Scales24Regular,
  ShieldError24Regular,
  Warning24Regular,
  Globe24Regular,
  ArrowSync24Regular,
  LockClosed24Regular,
  DataUsage24Regular,
  Certificate24Regular,
  DismissCircle24Regular,
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

const TermsOfService = () => {
  const styles = useStyles();
  const { i18n } = useTranslation();
  const isZh = i18n.language === 'zh';

  return (
    <div className={styles.container}>
      <Header />
      <main className={styles.main}>
        <div className={styles.hero}>
          <Title1 className={styles.title}>
            {isZh ? '服务条款' : 'Terms of Service'}
          </Title1>
          <Text className={styles.subtitle}>
            {isZh ? '使用 Hanabi 前请仔细阅读以下条款' : 'Please read these terms carefully before using Hanabi'}
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
                1. 接受条款
              </Title2>
              <Text className={styles.paragraph}>
                欢迎使用 Hanabi Download Manager X（以下简称"本软件"）。通过下载、安装或使用本软件，您同意受本服务条款的约束。如果您不同意这些条款，请不要使用本软件。
              </Text>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><Scales24Regular /></div>
                2. 许可授权
              </Title2>
              <Text className={styles.paragraph}>
                本软件基于 GNU General Public License version 3 (GPL-3.0) 开源许可证发布。您可以：
              </Text>
              <ul className={styles.list}>
                <li className={styles.listItem}>自由使用本软件用于任何目的</li>
                <li className={styles.listItem}>研究软件的工作原理并根据需要进行修改</li>
                <li className={styles.listItem}>重新分发本软件的副本</li>
                <li className={styles.listItem}>分发您修改后的版本</li>
              </ul>
              <Text className={styles.paragraph}>
                但您必须遵守 GPL-3.0 许可证的所有条款，包括在分发时提供源代码。
              </Text>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><ShieldError24Regular /></div>
                3. 使用限制
              </Title2>
              <Text className={styles.paragraph}>
                在使用本软件时，您同意：
              </Text>
              <ul className={styles.list}>
                <li className={styles.listItem}>不将本软件用于任何非法目的</li>
                <li className={styles.listItem}>不下载受版权保护的内容，除非您拥有合法权限</li>
                <li className={styles.listItem}>遵守所有适用的地方、国家和国际法律法规</li>
                <li className={styles.listItem}>不使用本软件进行任何可能损害、禁用、过载或损坏任何服务器或网络的活动</li>
                <li className={styles.listItem}>尊重其他用户和网站的权利</li>
              </ul>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><Warning24Regular /></div>
                4. 免责声明
              </Title2>
              <Text className={styles.paragraph}>
                本软件按"原样"提供，不提供任何明示或暗示的保证，包括但不限于：
              </Text>
              <ul className={styles.list}>
                <li className={styles.listItem}>适销性保证</li>
                <li className={styles.listItem}>特定用途适用性保证</li>
                <li className={styles.listItem}>不侵权保证</li>
                <li className={styles.listItem}>无错误或不间断运行保证</li>
              </ul>
              <div className={styles.highlight}>
                <Text className={styles.paragraph} style={{ marginBottom: 0 }}>
                  您使用本软件的风险由您自行承担。开发者不对因使用或无法使用本软件而导致的任何直接、间接、偶然、特殊或后果性损害承担责任。
                </Text>
              </div>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><Globe24Regular /></div>
                5. 第三方内容
              </Title2>
              <Text className={styles.paragraph}>
                本软件可能允许您访问或下载第三方内容。我们不对此类内容的准确性、合法性或质量负责。您对第三方内容的使用由您与该第三方之间的关系管辖。
              </Text>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><ArrowSync24Regular /></div>
                6. 更新和修改
              </Title2>
              <Text className={styles.paragraph}>
                我们保留随时修改、暂停或终止本软件（或其任何部分）的权利，恕不另行通知。我们也可能随时更新这些服务条款。继续使用本软件即表示您接受任何修订后的条款。
              </Text>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><LockClosed24Regular /></div>
                7. 隐私
              </Title2>
              <Text className={styles.paragraph}>
                本软件不收集、存储或传输您的个人信息。所有下载活动都在您的本地设备上进行。我们重视您的隐私，不会跟踪您的使用行为。
              </Text>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><DataUsage24Regular /></div>
                8. 在线统计服务
              </Title2>
              <Text className={styles.paragraph}>
                本软件提供可选的在线统计功能。使用此功能即表示您同意：
              </Text>
              <ul className={styles.list}>
                <li className={styles.listItem}>允许软件发送匿名统计信息到我们的服务器</li>
                <li className={styles.listItem}>理解此功能仅用于显示在线用户数量</li>
                <li className={styles.listItem}>可以随时在设置中禁用此功能</li>
                <li className={styles.listItem}>收集的数据包括：匿名设备ID、操作系统类型、应用版本号、启动次数</li>
              </ul>
              <div className={styles.highlight}>
                <Text className={styles.paragraph} style={{ marginBottom: 0 }}>
                  我们承诺不会将统计数据用于任何商业目的或与第三方共享。所有数据在24小时无活动后自动删除。
                </Text>
              </div>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><Certificate24Regular /></div>
                9. 知识产权
              </Title2>
              <Text className={styles.paragraph}>
                本软件的源代码受 GPL-3.0 许可证保护。"Hanabi Download Manager X" 名称和标识归原作者所有。未经明确许可，您不得将这些商标用于商业目的。
              </Text>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><DismissCircle24Regular /></div>
                10. 终止
              </Title2>
              <Text className={styles.paragraph}>
                如果您违反这些条款，您使用本软件的权利将自动终止。终止后，您必须停止使用本软件并删除所有副本。
              </Text>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><Scales24Regular /></div>
                11. 适用法律
              </Title2>
              <Text className={styles.paragraph}>
                本条款受中华人民共和国法律管辖。因本条款引起的任何争议应通过友好协商解决。
              </Text>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><Mail24Regular /></div>
                12. 联系我们
              </Title2>
              <Text className={styles.paragraph}>
                如果您对这些服务条款有任何疑问，请通过 GitHub Issues 联系我们：
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
                感谢您使用 Hanabi Download Manager X！
              </Text>
            </div>
          </>
        ) : (
          <>
            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><Document24Regular /></div>
                1. Acceptance of Terms
              </Title2>
              <Text className={styles.paragraph}>
                Welcome to Hanabi Download Manager X (hereinafter referred to as "the Software"). By downloading, installing, or using the Software, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the Software.
              </Text>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><Scales24Regular /></div>
                2. License Grant
              </Title2>
              <Text className={styles.paragraph}>
                The Software is released under the GNU General Public License version 3 (GPL-3.0). You are free to:
              </Text>
              <ul className={styles.list}>
                <li className={styles.listItem}>Use the Software for any purpose</li>
                <li className={styles.listItem}>Study how the Software works and modify it to suit your needs</li>
                <li className={styles.listItem}>Redistribute copies of the Software</li>
                <li className={styles.listItem}>Distribute your modified versions</li>
              </ul>
              <Text className={styles.paragraph}>
                However, you must comply with all terms of the GPL-3.0 license, including providing source code when distributing.
              </Text>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><ShieldError24Regular /></div>
                3. Usage Restrictions
              </Title2>
              <Text className={styles.paragraph}>
                When using the Software, you agree to:
              </Text>
              <ul className={styles.list}>
                <li className={styles.listItem}>Not use the Software for any illegal purposes</li>
                <li className={styles.listItem}>Not download copyrighted content unless you have legal permission</li>
                <li className={styles.listItem}>Comply with all applicable local, national, and international laws and regulations</li>
                <li className={styles.listItem}>Not use the Software for any activities that could damage, disable, overload, or impair any server or network</li>
                <li className={styles.listItem}>Respect the rights of other users and websites</li>
              </ul>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><Warning24Regular /></div>
                4. Disclaimer of Warranties
              </Title2>
              <Text className={styles.paragraph}>
                The Software is provided "as is" without warranty of any kind, either express or implied, including but not limited to:
              </Text>
              <ul className={styles.list}>
                <li className={styles.listItem}>Warranties of merchantability</li>
                <li className={styles.listItem}>Fitness for a particular purpose</li>
                <li className={styles.listItem}>Non-infringement</li>
                <li className={styles.listItem}>Error-free or uninterrupted operation</li>
              </ul>
              <div className={styles.highlight}>
                <Text className={styles.paragraph} style={{ marginBottom: 0 }}>
                  You assume all risks associated with using the Software. The developers shall not be liable for any direct, indirect, incidental, special, or consequential damages arising from the use or inability to use the Software.
                </Text>
              </div>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><Globe24Regular /></div>
                5. Third-Party Content
              </Title2>
              <Text className={styles.paragraph}>
                The Software may allow you to access or download third-party content. We are not responsible for the accuracy, legality, or quality of such content. Your use of third-party content is governed by your relationship with that third party.
              </Text>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><ArrowSync24Regular /></div>
                6. Updates and Modifications
              </Title2>
              <Text className={styles.paragraph}>
                We reserve the right to modify, suspend, or discontinue the Software (or any part thereof) at any time without notice. We may also update these Terms of Service at any time. Continued use of the Software constitutes acceptance of any revised terms.
              </Text>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><LockClosed24Regular /></div>
                7. Privacy
              </Title2>
              <Text className={styles.paragraph}>
                The Software does not collect, store, or transmit your personal information. All download activities occur on your local device. We value your privacy and do not track your usage behavior.
              </Text>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><DataUsage24Regular /></div>
                8. Online Statistics Service
              </Title2>
              <Text className={styles.paragraph}>
                The Software provides an optional online statistics feature. By using this feature, you agree to:
              </Text>
              <ul className={styles.list}>
                <li className={styles.listItem}>Allow the software to send anonymous statistical information to our servers</li>
                <li className={styles.listItem}>Understand this feature is only used to display online user count</li>
                <li className={styles.listItem}>Can disable this feature in settings at any time</li>
                <li className={styles.listItem}>Collected data includes: anonymous device ID, operating system type, application version number, launch count</li>
              </ul>
              <div className={styles.highlight}>
                <Text className={styles.paragraph} style={{ marginBottom: 0 }}>
                  We promise not to use statistical data for any commercial purposes or share it with third parties. All data is automatically deleted after 24 hours of inactivity.
                </Text>
              </div>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><Certificate24Regular /></div>
                9. Intellectual Property
              </Title2>
              <Text className={styles.paragraph}>
                The Software's source code is protected under the GPL-3.0 license. The "Hanabi Download Manager X" name and logo are owned by the original author. You may not use these trademarks for commercial purposes without explicit permission.
              </Text>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><DismissCircle24Regular /></div>
                10. Termination
              </Title2>
              <Text className={styles.paragraph}>
                Your right to use the Software will automatically terminate if you violate these terms. Upon termination, you must cease using the Software and delete all copies.
              </Text>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><Scales24Regular /></div>
                11. Governing Law
              </Title2>
              <Text className={styles.paragraph}>
                These terms are governed by the laws of the People's Republic of China. Any disputes arising from these terms shall be resolved through friendly negotiation.
              </Text>
            </div>

            <div className={styles.card}>
              <Title2 className={styles.sectionTitle}>
                <div className={styles.sectionIcon}><Mail24Regular /></div>
                12. Contact Us
              </Title2>
              <Text className={styles.paragraph}>
                If you have any questions about these Terms of Service, please contact us via GitHub Issues:
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
                Thank you for using Hanabi Download Manager X!
              </Text>
            </div>
          </>
        )}
      </main>
      <Footer />
    </div>
  );
};

export default TermsOfService;
