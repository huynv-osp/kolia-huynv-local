CREATE TABLE IF NOT EXISTS onboarding_screens (
    id              SERIAL PRIMARY KEY,
    image_file_id   UUID REFERENCES files(file_id) ON DELETE SET NULL,
    title           VARCHAR(255) NOT NULL,
    content         TEXT NOT NULL,
    display_order   INTEGER NOT NULL DEFAULT 0,
    status          SMALLINT NOT NULL DEFAULT 1,
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TRIGGER set_updated_at_onboarding_screens
    BEFORE UPDATE ON onboarding_screens
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_onboarding_screens_status_order
    ON onboarding_screens(status, display_order);

-- =============================================================================
-- V4: Education Sync - Thêm cột phục vụ đồng bộ VT Marketing + bảng sync log
-- =============================================================================

-- 1. Mở rộng status CHECK constraint
-- edu_categories: thêm 'pending_review', 'rejected'
ALTER TABLE edu_categories DROP CONSTRAINT IF EXISTS edu_categories_status_check;
ALTER TABLE edu_categories ADD CONSTRAINT edu_categories_status_check
  CHECK (status IN ('active', 'inactive', 'deleted', 'pending_review', 'rejected'));

-- edu_contents: tương tự
ALTER TABLE edu_contents DROP CONSTRAINT IF EXISTS edu_contents_status_check;
ALTER TABLE edu_contents ADD CONSTRAINT edu_contents_status_check
  CHECK (status IN ('active', 'inactive', 'deleted', 'pending_review', 'rejected'));


-- 2. Thêm cột sync cho edu_categories
ALTER TABLE edu_categories ADD COLUMN IF NOT EXISTS source_id VARCHAR(50);
ALTER TABLE edu_categories ADD COLUMN IF NOT EXISTS source_system VARCHAR(20) DEFAULT 'ADMIN';
ALTER TABLE edu_categories ADD COLUMN IF NOT EXISTS is_admin_modified BOOLEAN DEFAULT false;
ALTER TABLE edu_categories ADD COLUMN IF NOT EXISTS last_synced_at TIMESTAMPTZ;
ALTER TABLE edu_categories ADD COLUMN IF NOT EXISTS marketing_updated_at TIMESTAMPTZ;

-- Unique index trên source_id (chỉ khi NOT NULL)
CREATE UNIQUE INDEX IF NOT EXISTS idx_edu_categories_source_id
  ON edu_categories(source_id) WHERE source_id IS NOT NULL;


-- 3. Thêm cột sync + data mới cho edu_contents
ALTER TABLE edu_contents ADD COLUMN IF NOT EXISTS source_id VARCHAR(50);
ALTER TABLE edu_contents ADD COLUMN IF NOT EXISTS source_system VARCHAR(20) DEFAULT 'ADMIN';
ALTER TABLE edu_contents ADD COLUMN IF NOT EXISTS slug VARCHAR(255);
ALTER TABLE edu_contents ADD COLUMN IF NOT EXISTS thumbnail_url VARCHAR(500);
ALTER TABLE edu_contents ADD COLUMN IF NOT EXISTS is_admin_modified BOOLEAN DEFAULT false;
ALTER TABLE edu_contents ADD COLUMN IF NOT EXISTS last_synced_at TIMESTAMPTZ;
ALTER TABLE edu_contents ADD COLUMN IF NOT EXISTS marketing_updated_at TIMESTAMPTZ;
ALTER TABLE edu_contents ADD COLUMN IF NOT EXISTS published_at TIMESTAMPTZ;
ALTER TABLE edu_contents ADD COLUMN IF NOT EXISTS seo_title VARCHAR(255);
ALTER TABLE edu_contents ADD COLUMN IF NOT EXISTS seo_description TEXT;
ALTER TABLE edu_contents ADD COLUMN IF NOT EXISTS author_qualification VARCHAR(200);
ALTER TABLE edu_contents ADD COLUMN IF NOT EXISTS author_image_url VARCHAR(500);
ALTER TABLE edu_contents ADD COLUMN IF NOT EXISTS author_introduction TEXT;
ALTER TABLE edu_contents ADD COLUMN IF NOT EXISTS comment_count INTEGER DEFAULT 0;
ALTER TABLE edu_contents ADD COLUMN IF NOT EXISTS post_source_url VARCHAR(500);
ALTER TABLE edu_contents ADD COLUMN IF NOT EXISTS pending_data JSONB DEFAULT NULL;
ALTER TABLE edu_contents ADD COLUMN IF NOT EXISTS pending_at TIMESTAMPTZ DEFAULT NULL;

ALTER TABLE edu_categories ADD COLUMN IF NOT EXISTS pending_data jsonb;
ALTER TABLE edu_categories ADD COLUMN IF NOT EXISTS pending_at timestamptz;

CREATE UNIQUE INDEX IF NOT EXISTS idx_edu_contents_source_id
  ON edu_contents(source_id) WHERE source_id IS NOT NULL;


-- 4. Bảng lịch sử đồng bộ (sync logs)
CREATE TABLE IF NOT EXISTS edu_sync_logs (
    id BIGSERIAL PRIMARY KEY,
    data_type VARCHAR(20) NOT NULL,          -- 'CATEGORY' | 'POST'
    sync_type VARCHAR(20) NOT NULL,          -- 'MANUAL' | 'AUTO'
    status VARCHAR(20) NOT NULL,             -- 'SUCCESS' | 'PARTIAL' | 'FAILED'
    total_fetched INTEGER DEFAULT 0,         -- Tổng items fetch được từ VT
    total_created INTEGER DEFAULT 0,         -- Số items tạo mới
    total_updated INTEGER DEFAULT 0,         -- Số items cập nhật
    total_skipped INTEGER DEFAULT 0,         -- Số items bỏ qua (unchanged)
    total_errors INTEGER DEFAULT 0,          -- Số items lỗi
    error_message TEXT,                      -- Lỗi tổng (vd: connection timeout)
    error_details JSONB,                     -- Chi tiết lỗi: [{sourceId, name, reason}]
    started_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    triggered_by VARCHAR(100),               -- admin username hoặc 'SYSTEM'
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_edu_sync_logs_type_created
  ON edu_sync_logs(data_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_edu_sync_logs_status
  ON edu_sync_logs(status);

-- =============================================================================
-- V5: Thêm cột success_details vào edu_sync_logs
-- Lưu danh sách items đồng bộ thành công: [{sourceId, name, action, adminId}]
-- =============================================================================

ALTER TABLE edu_sync_logs
    ADD COLUMN IF NOT EXISTS success_details JSONB;

COMMENT ON COLUMN edu_sync_logs.success_details IS
    'Chi tiết items thành công: [{sourceId, name, action, adminId}] — action: CREATE | UPDATE';

