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

-- -- ============================================================================
-- -- 3. DATA MIGRATION: Populate inverse_relationship_code based on GENDER
-- --    Gender: 0 = Nam (Male), 1 = Nữ (Female)
-- -- ============================================================================

-- -- 3.1 Migrate connection_invites
-- -- Logic: Dựa vào gender của SENDER (người gửi invite) để xác định inverse
-- -- Ví dụ: Patient (Female) gọi Caregiver là "con_trai" 
-- --        → Caregiver gọi Patient là "me" (không phải "bo")
-- UPDATE connection_invites ci SET inverse_relationship_code = 
--     CASE 
--         -- Con -> Cha/Mẹ (dựa vào gender của Sender)
--         WHEN ci.relationship_code = 'con_trai' AND u.gender = 1 THEN 'me'    -- Sender là Nữ -> Mẹ
--         WHEN ci.relationship_code = 'con_trai' AND u.gender = 0 THEN 'bo'    -- Sender là Nam -> Bố
--         WHEN ci.relationship_code = 'con_gai' AND u.gender = 1 THEN 'me'     -- Sender là Nữ -> Mẹ
--         WHEN ci.relationship_code = 'con_gai' AND u.gender = 0 THEN 'bo'     -- Sender là Nam -> Bố
        
--         -- Cha/Mẹ -> Con (dựa vào gender của Receiver - cần join khác)
--         WHEN ci.relationship_code = 'bo' THEN 'con_trai'     -- Bố -> mặc định Con trai
--         WHEN ci.relationship_code = 'me' THEN 'con_gai'      -- Mẹ -> mặc định Con gái
        
--         -- Cháu -> Ông/Bà (dựa vào gender của Sender)
--         WHEN ci.relationship_code = 'chau_trai' AND u.gender = 0 THEN 'ong_noi'
--         WHEN ci.relationship_code = 'chau_trai' AND u.gender = 1 THEN 'ba_noi'
--         WHEN ci.relationship_code = 'chau_gai' AND u.gender = 0 THEN 'ong_noi'
--         WHEN ci.relationship_code = 'chau_gai' AND u.gender = 1 THEN 'ba_noi'
        
--         -- Ông/Bà -> Cháu (dựa vào gender của Receiver)
--         WHEN ci.relationship_code = 'ong_noi' THEN 'chau_trai'   -- default
--         WHEN ci.relationship_code = 'ba_noi' THEN 'chau_gai'     -- default
--         WHEN ci.relationship_code = 'ong_ngoai' THEN 'chau_trai' -- default
--         WHEN ci.relationship_code = 'ba_ngoai' THEN 'chau_gai'   -- default
        
--         -- Anh/Chị/Em (dựa vào gender của Sender)
--         WHEN ci.relationship_code = 'anh_trai' AND u.gender = 0 THEN 'em_trai'
--         WHEN ci.relationship_code = 'anh_trai' AND u.gender = 1 THEN 'em_gai'
--         WHEN ci.relationship_code = 'chi_gai' AND u.gender = 0 THEN 'em_trai'
--         WHEN ci.relationship_code = 'chi_gai' AND u.gender = 1 THEN 'em_gai'
--         WHEN ci.relationship_code = 'em_trai' AND u.gender = 0 THEN 'anh_trai'
--         WHEN ci.relationship_code = 'em_trai' AND u.gender = 1 THEN 'chi_gai'
--         WHEN ci.relationship_code = 'em_gai' AND u.gender = 0 THEN 'anh_trai'
--         WHEN ci.relationship_code = 'em_gai' AND u.gender = 1 THEN 'chi_gai'
        
--         -- Vợ/Chồng đối xứng
--         WHEN ci.relationship_code = 'vo' THEN 'chong'
--         WHEN ci.relationship_code = 'chong' THEN 'vo'
        
--         -- Khác -> giữ nguyên
--         WHEN ci.relationship_code = 'khac' THEN 'khac'
        
--         -- Default nếu không có gender
--         ELSE ci.relationship_code
--     END
-- FROM users u
-- WHERE ci.sender_id = u.user_id
--   AND ci.inverse_relationship_code IS NULL 
--   AND ci.relationship_code IS NOT NULL;

-- -- 3.2 Migrate user_emergency_contacts 
-- -- Logic: Dựa vào gender của Patient (user_id) VÀ Caregiver (linked_user_id)
-- -- Note: relationship_code = Patient gọi Caregiver là [X]
-- --       inverse_relationship_code = Caregiver gọi Patient là [X]
-- -- FIXED: Sử dụng subquery thay vì LEFT JOIN để tránh lỗi PostgreSQL
-- UPDATE user_emergency_contacts SET inverse_relationship_code = 
--     CASE 
--         -- Patient gọi Caregiver là "con_trai" -> Caregiver gọi Patient là "bo"/"me"
--         WHEN relationship_code = 'con_trai' AND (SELECT gender FROM users WHERE user_id = user_emergency_contacts.user_id) = 1 THEN 'me'
--         WHEN relationship_code = 'con_trai' AND (SELECT gender FROM users WHERE user_id = user_emergency_contacts.user_id) = 0 THEN 'bo'
--         WHEN relationship_code = 'con_gai' AND (SELECT gender FROM users WHERE user_id = user_emergency_contacts.user_id) = 1 THEN 'me'
--         WHEN relationship_code = 'con_gai' AND (SELECT gender FROM users WHERE user_id = user_emergency_contacts.user_id) = 0 THEN 'bo'
        
--         -- Patient gọi Caregiver là "bo"/"me" -> Caregiver gọi Patient là "con_..."
--         -- Dựa vào gender của Caregiver (linked_user_id)
--         WHEN relationship_code = 'bo' AND (SELECT gender FROM users WHERE user_id = user_emergency_contacts.linked_user_id) = 0 THEN 'con_trai'
--         WHEN relationship_code = 'bo' AND (SELECT gender FROM users WHERE user_id = user_emergency_contacts.linked_user_id) = 1 THEN 'con_gai'
--         WHEN relationship_code = 'me' AND (SELECT gender FROM users WHERE user_id = user_emergency_contacts.linked_user_id) = 0 THEN 'con_trai'
--         WHEN relationship_code = 'me' AND (SELECT gender FROM users WHERE user_id = user_emergency_contacts.linked_user_id) = 1 THEN 'con_gai'
        
--         -- Cháu -> Ông/Bà (dựa vào gender của Patient)
--         WHEN relationship_code = 'chau_trai' AND (SELECT gender FROM users WHERE user_id = user_emergency_contacts.user_id) = 0 THEN 'ong_noi'
--         WHEN relationship_code = 'chau_trai' AND (SELECT gender FROM users WHERE user_id = user_emergency_contacts.user_id) = 1 THEN 'ba_noi'
--         WHEN relationship_code = 'chau_gai' AND (SELECT gender FROM users WHERE user_id = user_emergency_contacts.user_id) = 0 THEN 'ong_noi'
--         WHEN relationship_code = 'chau_gai' AND (SELECT gender FROM users WHERE user_id = user_emergency_contacts.user_id) = 1 THEN 'ba_noi'
        
--         -- Ông/Bà -> Cháu (dựa vào gender của Caregiver)
--         WHEN relationship_code = 'ong_noi' AND (SELECT gender FROM users WHERE user_id = user_emergency_contacts.linked_user_id) = 0 THEN 'chau_trai'
--         WHEN relationship_code = 'ong_noi' AND (SELECT gender FROM users WHERE user_id = user_emergency_contacts.linked_user_id) = 1 THEN 'chau_gai'
--         WHEN relationship_code = 'ba_noi' AND (SELECT gender FROM users WHERE user_id = user_emergency_contacts.linked_user_id) = 0 THEN 'chau_trai'
--         WHEN relationship_code = 'ba_noi' AND (SELECT gender FROM users WHERE user_id = user_emergency_contacts.linked_user_id) = 1 THEN 'chau_gai'
--         WHEN relationship_code = 'ong_ngoai' AND (SELECT gender FROM users WHERE user_id = user_emergency_contacts.linked_user_id) = 0 THEN 'chau_trai'
--         WHEN relationship_code = 'ong_ngoai' AND (SELECT gender FROM users WHERE user_id = user_emergency_contacts.linked_user_id) = 1 THEN 'chau_gai'
--         WHEN relationship_code = 'ba_ngoai' AND (SELECT gender FROM users WHERE user_id = user_emergency_contacts.linked_user_id) = 0 THEN 'chau_trai'
--         WHEN relationship_code = 'ba_ngoai' AND (SELECT gender FROM users WHERE user_id = user_emergency_contacts.linked_user_id) = 1 THEN 'chau_gai'
        
--         -- Anh/Chị/Em (dựa vào gender của Patient)
--         WHEN relationship_code = 'anh_trai' AND (SELECT gender FROM users WHERE user_id = user_emergency_contacts.user_id) = 0 THEN 'em_trai'
--         WHEN relationship_code = 'anh_trai' AND (SELECT gender FROM users WHERE user_id = user_emergency_contacts.user_id) = 1 THEN 'em_gai'
--         WHEN relationship_code = 'chi_gai' AND (SELECT gender FROM users WHERE user_id = user_emergency_contacts.user_id) = 0 THEN 'em_trai'
--         WHEN relationship_code = 'chi_gai' AND (SELECT gender FROM users WHERE user_id = user_emergency_contacts.user_id) = 1 THEN 'em_gai'
--         WHEN relationship_code = 'em_trai' AND (SELECT gender FROM users WHERE user_id = user_emergency_contacts.user_id) = 0 THEN 'anh_trai'
--         WHEN relationship_code = 'em_trai' AND (SELECT gender FROM users WHERE user_id = user_emergency_contacts.user_id) = 1 THEN 'chi_gai'
--         WHEN relationship_code = 'em_gai' AND (SELECT gender FROM users WHERE user_id = user_emergency_contacts.user_id) = 0 THEN 'anh_trai'
--         WHEN relationship_code = 'em_gai' AND (SELECT gender FROM users WHERE user_id = user_emergency_contacts.user_id) = 1 THEN 'chi_gai'
        
--         -- Vợ/Chồng
--         WHEN relationship_code = 'vo' THEN 'chong'
--         WHEN relationship_code = 'chong' THEN 'vo'
        
--         -- Khác
--         WHEN relationship_code = 'khac' THEN 'khac'
        
--         ELSE relationship_code
--     END
-- WHERE inverse_relationship_code IS NULL 
--   AND relationship_code IS NOT NULL
--   AND contact_type IN ('caregiver', 'both');

-- -- ============================================================================
-- -- 4. VERIFICATION
-- -- ============================================================================

-- DO $$
-- DECLARE
--     invites_count INTEGER;
--     contacts_count INTEGER;
--     invites_null INTEGER;
--     contacts_null INTEGER;
-- BEGIN
--     -- Count records updated
--     SELECT COUNT(*) INTO invites_count 
--     FROM connection_invites WHERE inverse_relationship_code IS NOT NULL;
    
--     SELECT COUNT(*) INTO contacts_count 
--     FROM user_emergency_contacts 
--     WHERE inverse_relationship_code IS NOT NULL AND contact_type IN ('caregiver', 'both');
    
--     -- Count NULL records (may need manual review)
--     SELECT COUNT(*) INTO invites_null 
--     FROM connection_invites 
--     WHERE inverse_relationship_code IS NULL AND relationship_code IS NOT NULL;
    
--     SELECT COUNT(*) INTO contacts_null 
--     FROM user_emergency_contacts 
--     WHERE inverse_relationship_code IS NULL 
--       AND relationship_code IS NOT NULL 
--       AND contact_type IN ('caregiver', 'both');
    
--     RAISE NOTICE '✅ Migration v2.13 completed';
--     RAISE NOTICE '   connection_invites: % records migrated', invites_count;
--     RAISE NOTICE '   user_emergency_contacts: % records migrated', contacts_count;
    
--     IF invites_null > 0 OR contacts_null > 0 THEN
--         RAISE WARNING '⚠️ Records with NULL inverse_relationship_code:';
--         RAISE WARNING '   connection_invites: % records', invites_null;
--         RAISE WARNING '   user_emergency_contacts: % records', contacts_null;
--         RAISE NOTICE '   These may need manual review (likely missing gender data)';
--     END IF;
-- END $$;

-- -- ============================================================================
-- -- 5. MANUAL REVIEW QUERY (run to check unmigrated records)
-- -- ============================================================================
-- /*
-- -- Find records that couldn't be migrated (likely due to NULL gender)
-- SELECT 
--     ci.invite_id,
--     ci.relationship_code,
--     ci.inverse_relationship_code,
--     u.gender as sender_gender,
--     u.full_name as sender_name
-- FROM connection_invites ci
-- JOIN users u ON ci.sender_id = u.user_id
-- WHERE ci.inverse_relationship_code IS NULL 
--   AND ci.relationship_code IS NOT NULL;

-- SELECT 
--     uec.contact_id,
--     uec.relationship_code,
--     uec.inverse_relationship_code,
--     p.gender as patient_gender,
--     p.full_name as patient_name,
--     c.gender as caregiver_gender,
--     c.full_name as caregiver_name
-- FROM user_emergency_contacts uec
-- JOIN users p ON uec.user_id = p.user_id
-- LEFT JOIN users c ON uec.linked_user_id = c.user_id
-- WHERE uec.inverse_relationship_code IS NULL 
--   AND uec.relationship_code IS NOT NULL
--   AND uec.contact_type IN ('caregiver', 'both');
-- */

-- -- ============================================================================
-- -- 6. ROLLBACK (if needed)
-- -- ============================================================================
-- /*
-- -- Rollback v2.13
-- ALTER TABLE connection_invites DROP COLUMN IF EXISTS inverse_relationship_code;
-- ALTER TABLE user_emergency_contacts DROP COLUMN IF EXISTS inverse_relationship_code;
-- */
