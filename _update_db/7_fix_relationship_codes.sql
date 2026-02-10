-- ============================================================================
-- MIGRATION: Relationship Enum Alignment v2.22
-- Purpose: Merge 17 relationship codes → 14 codes per SRS
-- Date: 2026-02-10
-- SAFE: Không xóa data, chỉ rename/merge codes
-- ============================================================================

-- ============================================================================
-- STEP 1: Insert new relationship codes (ong, ba, chau)
-- These must exist BEFORE we can UPDATE FKs to reference them
-- ============================================================================
INSERT INTO relationships (relationship_code, name_vi, name_en, category, display_order) VALUES
('ong', 'Ông', 'Grandfather', 'family', 11),
('ba', 'Bà', 'Grandmother', 'family', 12),
('chau', 'Cháu', 'Grandchild', 'family', 13)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- STEP 2: Migrate data in connection_invites
-- ============================================================================
UPDATE connection_invites 
SET relationship_code = 'ong' 
WHERE relationship_code IN ('ong_noi', 'ong_ngoai');

UPDATE connection_invites 
SET relationship_code = 'ba' 
WHERE relationship_code IN ('ba_noi', 'ba_ngoai');

UPDATE connection_invites 
SET relationship_code = 'chau' 
WHERE relationship_code IN ('chau_trai', 'chau_gai');

-- inverse_relationship_code cũng cần update
UPDATE connection_invites 
SET inverse_relationship_code = 'ong' 
WHERE inverse_relationship_code IN ('ong_noi', 'ong_ngoai');

UPDATE connection_invites 
SET inverse_relationship_code = 'ba' 
WHERE inverse_relationship_code IN ('ba_noi', 'ba_ngoai');

UPDATE connection_invites 
SET inverse_relationship_code = 'chau' 
WHERE inverse_relationship_code IN ('chau_trai', 'chau_gai');

-- ============================================================================
-- STEP 3: Migrate data in user_emergency_contacts
-- ============================================================================
UPDATE user_emergency_contacts 
SET relationship_code = 'ong' 
WHERE relationship_code IN ('ong_noi', 'ong_ngoai');

UPDATE user_emergency_contacts 
SET relationship_code = 'ba' 
WHERE relationship_code IN ('ba_noi', 'ba_ngoai');

UPDATE user_emergency_contacts 
SET relationship_code = 'chau' 
WHERE relationship_code IN ('chau_trai', 'chau_gai');

-- inverse cũng cần update
UPDATE user_emergency_contacts 
SET inverse_relationship_code = 'ong' 
WHERE inverse_relationship_code IN ('ong_noi', 'ong_ngoai');

UPDATE user_emergency_contacts 
SET inverse_relationship_code = 'ba' 
WHERE inverse_relationship_code IN ('ba_noi', 'ba_ngoai');

UPDATE user_emergency_contacts 
SET inverse_relationship_code = 'chau' 
WHERE inverse_relationship_code IN ('chau_trai', 'chau_gai');

-- ============================================================================
-- STEP 4: Migrate data in encouragement_messages (nếu có)
-- ============================================================================
DO $$ BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'encouragement_messages' AND column_name = 'relationship_code'
    ) THEN
        UPDATE encouragement_messages 
        SET relationship_code = 'ong' 
        WHERE relationship_code IN ('ong_noi', 'ong_ngoai');

        UPDATE encouragement_messages 
        SET relationship_code = 'ba' 
        WHERE relationship_code IN ('ba_noi', 'ba_ngoai');

        UPDATE encouragement_messages 
        SET relationship_code = 'chau' 
        WHERE relationship_code IN ('chau_trai', 'chau_gai');

        RAISE NOTICE '✅ Migrated encouragement_messages relationship codes';
    END IF;
END $$;

-- ============================================================================
-- STEP 5: Delete old inverse_mapping entries (BEFORE deleting old relationship codes)
-- ============================================================================
DELETE FROM relationship_inverse_mapping 
WHERE relationship_code IN ('ong_noi', 'ong_ngoai', 'ba_noi', 'ba_ngoai', 'chau_trai', 'chau_gai')
   OR inverse_code IN ('ong_noi', 'ong_ngoai', 'ba_noi', 'ba_ngoai', 'chau_trai', 'chau_gai');

-- ============================================================================
-- STEP 6: Delete old relationship codes (now safe — no FKs reference them)
-- ============================================================================
DELETE FROM relationships 
WHERE relationship_code IN ('ong_noi', 'ong_ngoai', 'ba_noi', 'ba_ngoai', 'chau_trai', 'chau_gai');

-- ============================================================================
-- STEP 7: Insert new inverse_mapping for new codes
-- ============================================================================
INSERT INTO relationship_inverse_mapping (relationship_code, target_gender, inverse_code) VALUES
-- Ông/Bà → Cháu
('ong', 0, 'chau'),
('ong', 1, 'chau'),
('ba', 0, 'chau'),
('ba', 1, 'chau'),
-- Cháu → Ông/Bà
('chau', 0, 'ong'),
('chau', 1, 'ba')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- STEP 8: Update display_order to match SRS order
-- ============================================================================
UPDATE relationships SET display_order = 1  WHERE relationship_code = 'con_trai';
UPDATE relationships SET display_order = 2  WHERE relationship_code = 'con_gai';
UPDATE relationships SET display_order = 3  WHERE relationship_code = 'vo';
UPDATE relationships SET display_order = 4  WHERE relationship_code = 'chong';
UPDATE relationships SET display_order = 5  WHERE relationship_code = 'bo';
UPDATE relationships SET display_order = 6  WHERE relationship_code = 'me';
UPDATE relationships SET display_order = 7  WHERE relationship_code = 'anh_trai';
UPDATE relationships SET display_order = 8  WHERE relationship_code = 'chi_gai';
UPDATE relationships SET display_order = 9  WHERE relationship_code = 'em_trai';
UPDATE relationships SET display_order = 10 WHERE relationship_code = 'em_gai';
UPDATE relationships SET display_order = 11 WHERE relationship_code = 'ong';
UPDATE relationships SET display_order = 12 WHERE relationship_code = 'ba';
UPDATE relationships SET display_order = 13 WHERE relationship_code = 'chau';
UPDATE relationships SET display_order = 99 WHERE relationship_code = 'khac';

-- ============================================================================
-- VERIFY
-- ============================================================================
DO $$
DECLARE
    rel_count INTEGER;
    old_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO rel_count FROM relationships;
    SELECT COUNT(*) INTO old_count FROM relationships 
    WHERE relationship_code IN ('ong_noi', 'ong_ngoai', 'ba_noi', 'ba_ngoai', 'chau_trai', 'chau_gai');

    IF rel_count = 14 AND old_count = 0 THEN
        RAISE NOTICE '✅ Migration v2.22 successful: 14 relationship types, 0 old codes remaining';
    ELSE
        RAISE WARNING '⚠️ Migration check: % total types, % old codes still exist', rel_count, old_count;
    END IF;
END $$;
