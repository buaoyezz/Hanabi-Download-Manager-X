import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import {
  makeStyles,
  tokens,
  Title1,
  Title2,
  Body1,
  Card,
  CardHeader,
  CardPreview,
  Button,
  Badge,
  Menu,
  MenuTrigger,
  MenuPopover,
  MenuList,
  MenuItem,
  Spinner,
  MessageBar,
  MessageBarBody,
  Toolbar,
  ToolbarButton,
  SearchBox,
  Dropdown,
  Option,
  Table,
  TableHeader,
  TableHeaderCell,
  TableBody,
  TableRow,
  TableCell
} from '@fluentui/react-components';
import {
  Add24Regular,
  Edit24Regular,
  Delete24Regular,
  MoreHorizontal24Regular,
  ArrowClockwise24Regular,
  Send24Regular,
  Eye24Regular,
  SignOut24Regular,
  Settings24Regular
} from '@fluentui/react-icons';
import { motion } from 'framer-motion';
import { adminService } from '../services/adminService';
import { websocketService } from '../services/websocketService';
import type { Announcement, AdminUser } from '../types/announcement';

const useStyles = makeStyles({
  container: {
    minHeight: '100vh',
    backgroundColor: tokens.colorNeutralBackground1,
    padding: '24px',
  },
  header: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '24px',
  },
  userInfo: {
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
  },
  statsGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
    gap: '16px',
    marginBottom: '24px',
  },
  statCard: {
    padding: '16px',
    textAlign: 'center',
  },
  statNumber: {
    fontSize: '32px',
    fontWeight: 'bold',
    color: tokens.colorBrandForeground1,
  },
  toolbar: {
    marginBottom: '16px',
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: '12px',
  },
  searchFilters: {
    display: 'flex',
    gap: '12px',
    alignItems: 'center',
  },
  dataGrid: {
    minHeight: '400px',
  },
  loadingContainer: {
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    minHeight: '200px',
  },
  badge: {
    textTransform: 'capitalize',
  },
});

const typeColors = {
  info: 'informative',
  warning: 'warning',
  success: 'success',
  error: 'danger',
} as const;

const priorityColors = {
  low: 'outline',
  medium: 'filled',
  high: 'filled',
} as const;

const AdminDashboard = () => {
  const styles = useStyles();
  const { t } = useTranslation();
  const navigate = useNavigate();
  
  const [user, setUser] = useState<AdminUser | null>(null);
  const [announcements, setAnnouncements] = useState<Announcement[]>([]);
  const [stats, setStats] = useState({
    totalAnnouncements: 0,
    activeAnnouncements: 0,
    totalViews: 0,
    pushSubscriptions: 0,
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [searchQuery, setSearchQuery] = useState('');
  const [typeFilter, setTypeFilter] = useState('all');
  const [priorityFilter, setPriorityFilter] = useState('all');
  // const [selectedAnnouncements, setSelectedAnnouncements] = useState<string[]>([]);

  useEffect(() => {
    initializeDashboard();
    setupWebSocket();
    
    return () => {
      websocketService.disconnect();
    };
  }, []);

  const initializeDashboard = async () => {
    try {
      setLoading(true);
      
      // 检查登录状态
      if (!adminService.isLoggedIn()) {
        navigate('/admin/login');
        return;
      }

      // 获取用户信息
      const userInfo = await adminService.getProfile();
      if (!userInfo) {
        navigate('/admin/login');
        return;
      }
      setUser(userInfo);

      // 加载数据
      await Promise.all([
        loadAnnouncements(),
        loadStats(),
      ]);
    } catch (error) {
      console.error('Dashboard initialization error:', error);
      setError(t('admin.dashboard.error.loadFailed'));
    } finally {
      setLoading(false);
    }
  };

  const setupWebSocket = () => {
    websocketService.connect();
    
    // 监听公告相关事件
    websocketService.on('announcement:created', handleAnnouncementCreated);
    websocketService.on('announcement:updated', handleAnnouncementUpdated);
    websocketService.on('announcement:deleted', handleAnnouncementDeleted);
  };

  const loadAnnouncements = async () => {
    try {
      const response = await adminService.getAllAnnouncements({
        search: searchQuery || undefined,
        type: typeFilter !== 'all' ? typeFilter : undefined,
        priority: priorityFilter !== 'all' ? priorityFilter : undefined,
      });
      setAnnouncements(response.announcements);
    } catch (error) {
      console.error('Failed to load announcements:', error);
    }
  };

  const loadStats = async () => {
    try {
      const statsData = await adminService.getStats();
      if (statsData) {
        setStats(statsData);
      }
    } catch (error) {
      console.error('Failed to load stats:', error);
    }
  };

  const handleAnnouncementCreated = (announcement: Announcement) => {
    setAnnouncements(prev => [announcement, ...prev]);
    loadStats(); // 更新统计数据
  };

  const handleAnnouncementUpdated = (announcement: Announcement) => {
    setAnnouncements(prev => 
      prev.map(item => item.id === announcement.id ? announcement : item)
    );
  };

  const handleAnnouncementDeleted = (data: { id: string }) => {
    setAnnouncements(prev => prev.filter(item => item.id !== data.id));
    loadStats(); // 更新统计数据
  };

  const handleLogout = async () => {
    await adminService.logout();
    navigate('/admin/login');
  };

  const handleCreateAnnouncement = () => {
    navigate('/admin/announcements/create');
  };

  const handleEditAnnouncement = (id: string) => {
    navigate(`/admin/announcements/edit/${id}`);
  };

  const handleDeleteAnnouncement = async (id: string) => {
    if (window.confirm(t('admin.dashboard.confirmDelete'))) {
      const success = await adminService.deleteAnnouncement(id);
      if (success) {
        setAnnouncements(prev => prev.filter(item => item.id !== id));
        loadStats();
      }
    }
  };

  const handleSendPush = async (id: string) => {
    const success = await adminService.sendPushNotification(id);
    if (success) {
      // 显示成功消息
      console.log('Push notification sent successfully');
    }
  };

  const handleRefresh = () => {
    loadAnnouncements();
    loadStats();
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleString();
  };

  if (loading) {
    return (
      <div className={styles.loadingContainer}>
        <Spinner size="large" label={t('admin.dashboard.loading')} />
      </div>
    );
  }

  return (
    <div className={styles.container}>
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5 }}
      >
        {/* 头部 */}
        <div className={styles.header}>
          <div>
            <Title1>{t('admin.dashboard.title')}</Title1>
            <Body1>{t('admin.dashboard.subtitle')}</Body1>
          </div>
          
          <div className={styles.userInfo}>
            <Body1>{t('admin.dashboard.welcome', { name: user?.username })}</Body1>
            <Menu>
              <MenuTrigger disableButtonEnhancement>
                <Button appearance="subtle" icon={<Settings24Regular />} />
              </MenuTrigger>
              <MenuPopover>
                <MenuList>
                  <MenuItem icon={<Eye24Regular />}>
                    {t('admin.dashboard.viewSite')}
                  </MenuItem>
                  <MenuItem icon={<SignOut24Regular />} onClick={handleLogout}>
                    {t('admin.dashboard.logout')}
                  </MenuItem>
                </MenuList>
              </MenuPopover>
            </Menu>
          </div>
        </div>

        {error && (
          <MessageBar intent="error" style={{ marginBottom: '16px' }}>
            <MessageBarBody>{error}</MessageBarBody>
          </MessageBar>
        )}

        {/* 统计卡片 */}
        <div className={styles.statsGrid}>
          <Card className={styles.statCard}>
            <CardPreview>
              <div className={styles.statNumber}>{stats.totalAnnouncements}</div>
              <Body1>{t('admin.dashboard.stats.total')}</Body1>
            </CardPreview>
          </Card>
          
          <Card className={styles.statCard}>
            <CardPreview>
              <div className={styles.statNumber}>{stats.activeAnnouncements}</div>
              <Body1>{t('admin.dashboard.stats.active')}</Body1>
            </CardPreview>
          </Card>
          
          <Card className={styles.statCard}>
            <CardPreview>
              <div className={styles.statNumber}>{stats.totalViews}</div>
              <Body1>{t('admin.dashboard.stats.views')}</Body1>
            </CardPreview>
          </Card>
          
          <Card className={styles.statCard}>
            <CardPreview>
              <div className={styles.statNumber}>{stats.pushSubscriptions}</div>
              <Body1>{t('admin.dashboard.stats.subscribers')}</Body1>
            </CardPreview>
          </Card>
        </div>

        {/* 工具栏 */}
        <Toolbar className={styles.toolbar}>
          <div className={styles.searchFilters}>
            <SearchBox
              placeholder={t('admin.dashboard.search')}
              value={searchQuery}
              onChange={(_, data) => setSearchQuery(data.value)}
            />
            
            <Dropdown
              placeholder={t('admin.dashboard.filterType')}
              value={typeFilter}
              onOptionSelect={(_, data) => setTypeFilter(data.optionValue || 'all')}
            >
              <Option value="all">{t('admin.dashboard.allTypes')}</Option>
              <Option value="info">{t('admin.dashboard.type.info')}</Option>
              <Option value="warning">{t('admin.dashboard.type.warning')}</Option>
              <Option value="success">{t('admin.dashboard.type.success')}</Option>
              <Option value="error">{t('admin.dashboard.type.error')}</Option>
            </Dropdown>
            
            <Dropdown
              placeholder={t('admin.dashboard.filterPriority')}
              value={priorityFilter}
              onOptionSelect={(_, data) => setPriorityFilter(data.optionValue || 'all')}
            >
              <Option value="all">{t('admin.dashboard.allPriorities')}</Option>
              <Option value="low">{t('admin.dashboard.priority.low')}</Option>
              <Option value="medium">{t('admin.dashboard.priority.medium')}</Option>
              <Option value="high">{t('admin.dashboard.priority.high')}</Option>
            </Dropdown>
          </div>

          <div>
            <ToolbarButton
              icon={<ArrowClockwise24Regular />}
              onClick={handleRefresh}
            >
              {t('admin.dashboard.refresh')}
            </ToolbarButton>
            
            <ToolbarButton
              appearance="primary"
              icon={<Add24Regular />}
              onClick={handleCreateAnnouncement}
            >
              {t('admin.dashboard.create')}
            </ToolbarButton>
          </div>
        </Toolbar>

        {/* 公告列表 */}
        <Card>
          <CardHeader>
            <Title2>{t('admin.dashboard.announcements')}</Title2>
          </CardHeader>
          
          <CardPreview>
            <Table className={styles.dataGrid}>
              <TableHeader>
                <TableRow>
                  <TableHeaderCell>{t('admin.dashboard.table.title')}</TableHeaderCell>
                  <TableHeaderCell>{t('admin.dashboard.table.type')}</TableHeaderCell>
                  <TableHeaderCell>{t('admin.dashboard.table.priority')}</TableHeaderCell>
                  <TableHeaderCell>{t('admin.dashboard.table.status')}</TableHeaderCell>
                  <TableHeaderCell>{t('admin.dashboard.table.created')}</TableHeaderCell>
                  <TableHeaderCell>{t('admin.dashboard.table.actions')}</TableHeaderCell>
                </TableRow>
              </TableHeader>
              
              <TableBody>
                {announcements.map((announcement) => (
                  <TableRow key={announcement.id}>
                    <TableCell>{announcement.title}</TableCell>
                    <TableCell>
                      <Badge 
                        appearance="filled" 
                        color={typeColors[announcement.type]}
                        className={styles.badge}
                      >
                        {t(`admin.dashboard.type.${announcement.type}`)}
                      </Badge>
                    </TableCell>
                    <TableCell>
                      <Badge 
                        appearance={priorityColors[announcement.priority]}
                        className={styles.badge}
                      >
                        {t(`admin.dashboard.priority.${announcement.priority}`)}
                      </Badge>
                    </TableCell>
                    <TableCell>
                      <Badge 
                        appearance={announcement.isActive ? 'filled' : 'outline'}
                        color={announcement.isActive ? 'success' : 'subtle'}
                      >
                        {announcement.isActive ? t('admin.dashboard.active') : t('admin.dashboard.inactive')}
                      </Badge>
                    </TableCell>
                    <TableCell>{formatDate(announcement.createdAt)}</TableCell>
                    <TableCell>
                      <Menu>
                        <MenuTrigger disableButtonEnhancement>
                          <Button appearance="subtle" icon={<MoreHorizontal24Regular />} />
                        </MenuTrigger>
                        <MenuPopover>
                          <MenuList>
                            <MenuItem 
                              icon={<Edit24Regular />}
                              onClick={() => handleEditAnnouncement(announcement.id)}
                            >
                              {t('admin.dashboard.edit')}
                            </MenuItem>
                            <MenuItem 
                              icon={<Send24Regular />}
                              onClick={() => handleSendPush(announcement.id)}
                            >
                              {t('admin.dashboard.sendPush')}
                            </MenuItem>
                            <MenuItem 
                              icon={<Delete24Regular />}
                              onClick={() => handleDeleteAnnouncement(announcement.id)}
                            >
                              {t('admin.dashboard.delete')}
                            </MenuItem>
                          </MenuList>
                        </MenuPopover>
                      </Menu>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardPreview>
        </Card>
      </motion.div>
    </div>
  );
};

export default AdminDashboard;