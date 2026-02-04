-- ============================================================================
-- MIGRATION: Add inverse_relationship_code (v2.12 → v2.13)
-- Version: 2.13
-- Date: 2026-02-04
-- Purpose: Add inverse_relationship_code column for bidirectional relationship awareness
-- Prerequisite: DB already has v2.12 schema (connection_invites, user_emergency_contacts)
-- ============================================================================

-- ============================================================================
-- 1. ADD COLUMN: connection_invites
-- ============================================================================

ALTER TABLE connection_invites 
ADD COLUMN IF NOT EXISTS inverse_relationship_code VARCHAR(30) 
    REFERENCES relationships(relationship_code);

COMMENT ON COLUMN connection_invites.relationship_code IS 'Sender mô tả Receiver là [X]';
COMMENT ON COLUMN connection_invites.inverse_relationship_code IS 'Receiver mô tả Sender là [X]';

-- ============================================================================
-- 2. ADD COLUMN: user_emergency_contacts
-- ============================================================================

ALTER TABLE user_emergency_contacts 
ADD COLUMN IF NOT EXISTS inverse_relationship_code VARCHAR(30) 
    REFERENCES relationships(relationship_code);

COMMENT ON COLUMN user_emergency_contacts.relationship_code IS 'Patient (user_id) mô tả Caregiver (linked_user_id) là [X]';
COMMENT ON COLUMN user_emergency_contacts.inverse_relationship_code IS 'Caregiver (linked_user_id) mô tả Patient (user_id) là [X]';


-- ============================================================================
-- TABLE 1.5: relationship_inverse_mapping (v2.21 - Gender-based Inverse Derivation)
-- Purpose: Derive inverse_relationship_code based on original code + target gender
-- Owner: user-service
-- ============================================================================

CREATE TABLE IF NOT EXISTS relationship_inverse_mapping (
    relationship_code VARCHAR(30) NOT NULL REFERENCES relationships(relationship_code),
    target_gender SMALLINT NOT NULL,  -- 0: Nam, 1: Nữ (gender of the OTHER party)
    inverse_code VARCHAR(30) NOT NULL REFERENCES relationships(relationship_code),
    PRIMARY KEY (relationship_code, target_gender)
);

-- Seed data: Mapping logic for all 17 relationship types × 2 genders
INSERT INTO relationship_inverse_mapping (relationship_code, target_gender, inverse_code) VALUES
-- Con → Cha/Mẹ (nếu Sender gọi Receiver là "con", thì inverse = "cha/mẹ" tùy gender của Sender)
('con_trai', 0, 'bo'),       -- Receiver (con trai) → Sender là Nam = Bố
('con_trai', 1, 'me'),       -- Receiver (con trai) → Sender là Nữ = Mẹ
('con_gai', 0, 'bo'),        -- Receiver (con gái) → Sender là Nam = Bố
('con_gai', 1, 'me'),        -- Receiver (con gái) → Sender là Nữ = Mẹ

-- Cha/Mẹ → Con (nếu gọi người kia là "cha/mẹ", inverse = "con" tùy gender của Sender)
('bo', 0, 'con_trai'),       -- Receiver (bố) → Sender là Nam = Con trai
('bo', 1, 'con_gai'),        -- Receiver (bố) → Sender là Nữ = Con gái
('me', 0, 'con_trai'),       -- Receiver (mẹ) → Sender là Nam = Con trai
('me', 1, 'con_gai'),        -- Receiver (mẹ) → Sender là Nữ = Con gái

-- Anh/Chị → Em
('anh_trai', 0, 'em_trai'),  -- Receiver (anh trai) → Sender là Nam = Em trai
('anh_trai', 1, 'em_gai'),   -- Receiver (anh trai) → Sender là Nữ = Em gái
('chi_gai', 0, 'em_trai'),   -- Receiver (chị gái) → Sender là Nam = Em trai
('chi_gai', 1, 'em_gai'),    -- Receiver (chị gái) → Sender là Nữ = Em gái

-- Em → Anh/Chị
('em_trai', 0, 'anh_trai'),  -- Receiver (em trai) → Sender là Nam = Anh trai
('em_trai', 1, 'chi_gai'),   -- Receiver (em trai) → Sender là Nữ = Chị gái
('em_gai', 0, 'anh_trai'),   -- Receiver (em gái) → Sender là Nam = Anh trai
('em_gai', 1, 'chi_gai'),    -- Receiver (em gái) → Sender là Nữ = Chị gái

-- Vợ/Chồng (gender-matched)
('vo', 0, 'chong'),          -- Receiver (vợ) → Sender là Nam = Chồng
('vo', 1, 'khac'),           -- Receiver (vợ) → Sender là Nữ = N/A (fallback khác)
('chong', 0, 'khac'),        -- Receiver (chồng) → Sender là Nam = N/A (fallback khác)
('chong', 1, 'vo'),          -- Receiver (chồng) → Sender là Nữ = Vợ

-- Ông/Bà → Cháu
('ong_noi', 0, 'chau_trai'), -- Receiver (ông nội) → Sender là Nam = Cháu trai
('ong_noi', 1, 'chau_gai'),  -- Receiver (ông nội) → Sender là Nữ = Cháu gái
('ba_noi', 0, 'chau_trai'),
('ba_noi', 1, 'chau_gai'),
('ong_ngoai', 0, 'chau_trai'),
('ong_ngoai', 1, 'chau_gai'),
('ba_ngoai', 0, 'chau_trai'),
('ba_ngoai', 1, 'chau_gai'),

-- Cháu → Ông/Bà (default to nội, có thể customize)
('chau_trai', 0, 'ong_noi'), -- Receiver (cháu trai) → Sender là Nam = Ông nội
('chau_trai', 1, 'ba_noi'),  -- Receiver (cháu trai) → Sender là Nữ = Bà nội
('chau_gai', 0, 'ong_noi'),
('chau_gai', 1, 'ba_noi'),

-- Khác (fallback to khác)
('khac', 0, 'khac'),
('khac', 1, 'khac')
ON CONFLICT DO NOTHING;

COMMENT ON TABLE relationship_inverse_mapping IS 'v2.21: Gender-based inverse relationship derivation lookup';
COMMENT ON COLUMN relationship_inverse_mapping.target_gender IS '0: Nam, 1: Nữ - giới tính của bên còn lại';
COMMENT ON COLUMN relationship_inverse_mapping.inverse_code IS 'Mối quan hệ inverse được suy ra';
