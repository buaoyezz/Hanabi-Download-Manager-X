-- 公告系统数据库初始化脚本

-- 创建公告表
CREATE TABLE IF NOT EXISTS announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    type VARCHAR(20) NOT NULL CHECK (type IN ('info', 'warning', 'success', 'error')),
    priority VARCHAR(20) NOT NULL CHECK (priority IN ('low', 'medium', 'high')),
    is_active BOOLEAN DEFAULT true,
    expires_at TIMESTAMP WITH TIME ZONE,
    author_id UUID,
    author_name VARCHAR(100),
    tags TEXT[],
    target_audience VARCHAR(20) DEFAULT 'all' CHECK (target_audience IN ('all', 'desktop', 'web')),
    push_enabled BOOLEAN DEFAULT false,
    read_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 创建管理员用户表
CREATE TABLE IF NOT EXISTS admin_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) DEFAULT 'admin' CHECK (role IN ('admin', 'moderator')),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_login TIMESTAMP WITH TIME ZONE
);

-- 创建推送订阅表
CREATE TABLE IF NOT EXISTS push_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    endpoint TEXT NOT NULL UNIQUE,
    p256dh_key TEXT NOT NULL,
    auth_key TEXT NOT NULL,
    user_agent TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 创建公告阅读记录表
CREATE TABLE IF NOT EXISTS announcement_reads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    announcement_id UUID NOT NULL REFERENCES announcements(id) ON DELETE CASCADE,
    user_identifier VARCHAR(255), -- 可以是IP地址或用户ID
    read_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(announcement_id, user_identifier)
);

-- 创建推送通知记录表
CREATE TABLE IF NOT EXISTS push_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    announcement_id UUID REFERENCES announcements(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    icon VARCHAR(255),
    badge VARCHAR(255),
    data JSONB,
    sent_count INTEGER DEFAULT 0,
    failed_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    sent_at TIMESTAMP WITH TIME ZONE
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_announcements_active ON announcements(is_active);
CREATE INDEX IF NOT EXISTS idx_announcements_created ON announcements(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_announcements_expires ON announcements(expires_at);
CREATE INDEX IF NOT EXISTS idx_announcements_type ON announcements(type);
CREATE INDEX IF NOT EXISTS idx_announcements_priority ON announcements(priority);
CREATE INDEX IF NOT EXISTS idx_announcements_author ON announcements(author_id);

CREATE INDEX IF NOT EXISTS idx_admin_users_username ON admin_users(username);
CREATE INDEX IF NOT EXISTS idx_admin_users_email ON admin_users(email);
CREATE INDEX IF NOT EXISTS idx_admin_users_active ON admin_users(is_active);

CREATE INDEX IF NOT EXISTS idx_push_subscriptions_active ON push_subscriptions(is_active);
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_endpoint ON push_subscriptions(endpoint);

CREATE INDEX IF NOT EXISTS idx_announcement_reads_announcement ON announcement_reads(announcement_id);
CREATE INDEX IF NOT EXISTS idx_announcement_reads_user ON announcement_reads(user_identifier);

-- 创建更新时间触发器函数
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 为需要的表创建更新时间触发器
CREATE TRIGGER update_announcements_updated_at BEFORE UPDATE ON announcements
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_admin_users_updated_at BEFORE UPDATE ON admin_users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_push_subscriptions_updated_at BEFORE UPDATE ON push_subscriptions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 插入默认管理员用户
-- 密码: admin123 (bcrypt hash)
INSERT INTO admin_users (username, email, password_hash, role) 
VALUES (
    'admin', 
    'admin@localhost', 
    '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 
    'admin'
) ON CONFLICT (username) DO NOTHING;

-- 插入示例公告
INSERT INTO announcements (
    title, 
    content, 
    type, 
    priority, 
    is_active, 
    expires_at, 
    author_name, 
    tags, 
    target_audience,
    push_enabled
) VALUES 
(
    '🎉 欢迎使用公告系统',
    '恭喜！您的公告系统已成功部署。您可以通过管理面板创建和管理公告，支持推送通知、实时更新等功能。',
    'success',
    'high',
    true,
    NOW() + INTERVAL '30 days',
    'System',
    ARRAY['welcome', 'system', 'deployment'],
    'all',
    true
),
(
    '📋 系统功能介绍',
    '本系统支持多种公告类型、优先级设置、过期时间管理、推送通知、实时更新等功能。管理员可以通过后台轻松管理所有公告。',
    'info',
    'medium',
    true,
    NOW() + INTERVAL '7 days',
    'System',
    ARRAY['features', 'introduction'],
    'all',
    false
),
(
    '🔧 默认账户信息',
    '默认管理员账户 - 用户名: admin, 密码: admin123。请登录后立即修改密码以确保安全。',
    'warning',
    'high',
    true,
    NOW() + INTERVAL '1 day',
    'System',
    ARRAY['security', 'account'],
    'all',
    false
) ON CONFLICT DO NOTHING;

-- 创建视图：活跃公告
CREATE OR REPLACE VIEW active_announcements AS
SELECT * FROM announcements 
WHERE is_active = true 
AND (expires_at IS NULL OR expires_at > NOW())
ORDER BY priority DESC, created_at DESC;

-- 创建视图：公告统计
CREATE OR REPLACE VIEW announcement_stats AS
SELECT 
    COUNT(*) as total_announcements,
    COUNT(*) FILTER (WHERE is_active = true AND (expires_at IS NULL OR expires_at > NOW())) as active_announcements,
    COUNT(*) FILTER (WHERE type = 'info') as info_count,
    COUNT(*) FILTER (WHERE type = 'warning') as warning_count,
    COUNT(*) FILTER (WHERE type = 'success') as success_count,
    COUNT(*) FILTER (WHERE type = 'error') as error_count,
    COUNT(*) FILTER (WHERE priority = 'high') as high_priority_count,
    COUNT(*) FILTER (WHERE priority = 'medium') as medium_priority_count,
    COUNT(*) FILTER (WHERE priority = 'low') as low_priority_count,
    SUM(read_count) as total_reads
FROM announcements;

-- 授权
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO announcements_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO announcements_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO announcements_user;