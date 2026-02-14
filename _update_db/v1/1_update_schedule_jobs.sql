-- =====================================================
-- SCHEDULE_JOBS MASTER DATA
-- =====================================================

INSERT INTO schedule_jobs (key, name, task, schedule, pattern, queue, enabled, app, description, options, created_at, updated_at) VALUES
(
    'poll_sos_expired_countdowns',
    'Job poll SOS countdown hết hạn',
    'schedule_service.tasks.sos.poll_expired_countdowns',
    '{"type": "interval", "every": 5}',
    '*/5s',
    'sos',
    true,
    'schedule_service',
    'Option C: Poll expired SOS countdown events every 10s and trigger send_sos_alerts',
    '{"max_retries": 0}',
    NOW(),
    NOW()
),(
    'caregiver_alerts_batch_21h',
    'Job cảnh báo Caregiver batch 21:00',
    'schedule_service.tasks.alerts.run_batch_alerts',
    '{"type": "crontab", "minute": "0", "hour": "21"}',
    '0 21 * * *',
    'alerts',
    true,
    'schedule_service',
    'US 1.2: Daily batch evaluation for compliance alerts (tuân thủ thuốc/đo HA kém, bỏ lỡ 3 liều liên tiếp) at 21:00',
    '{"max_retries": 3}',
    NOW(),
    NOW()
)
ON CONFLICT (key) DO UPDATE SET
    name = EXCLUDED.name,
    task = EXCLUDED.task,
    schedule = EXCLUDED.schedule,
    pattern = EXCLUDED.pattern,
    queue = EXCLUDED.queue,
    enabled = EXCLUDED.enabled,
    app = EXCLUDED.app,
    description = EXCLUDED.description,
    options = EXCLUDED.options,
    updated_at = NOW();
