-- Migration: Add tables for Instant Response System
-- Date: 2026-01-24
-- Description: Creates tables for tracking auto-responses and analytics

-- Add is_auto_response flag to messages table
ALTER TABLE messages
ADD COLUMN IF NOT EXISTS is_auto_response BOOLEAN DEFAULT FALSE;

COMMENT ON COLUMN messages.is_auto_response IS 'Indicates if this message was sent automatically by the AI system';

-- Create response analytics table
CREATE TABLE IF NOT EXISTS response_analytics (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    response_time_ms INTEGER NOT NULL,
    response_type VARCHAR(20) NOT NULL CHECK (response_type IN ('auto', 'manual')),
    responded_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE response_analytics IS 'Tracks response times for measuring instant response performance';
COMMENT ON COLUMN response_analytics.response_time_ms IS 'Time taken to respond in milliseconds';
COMMENT ON COLUMN response_analytics.response_type IS 'Type of response: auto (AI) or manual (human)';

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_response_analytics_conversation ON response_analytics(conversation_id);
CREATE INDEX IF NOT EXISTS idx_response_analytics_type ON response_analytics(response_type);
CREATE INDEX IF NOT EXISTS idx_response_analytics_responded_at ON response_analytics(responded_at DESC);

-- Create notifications table for landlord alerts
CREATE TABLE IF NOT EXISTS notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_email VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    listing_id UUID REFERENCES listings(id) ON DELETE CASCADE,
    conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
    read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE notifications IS 'In-app notifications for users (landlords, renters)';
COMMENT ON COLUMN notifications.type IS 'Notification type (e.g., new_inquiry, viewing_request, application)';

-- Create indexes for notifications
CREATE INDEX IF NOT EXISTS idx_notifications_user_email ON notifications(user_email);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON notifications(user_email, read) WHERE read = FALSE;

-- Create view for response time statistics
CREATE OR REPLACE VIEW response_time_stats AS
SELECT
    response_type,
    COUNT(*) AS total_responses,
    AVG(response_time_ms) AS avg_response_time_ms,
    AVG(response_time_ms) / 1000.0 AS avg_response_time_seconds,
    MIN(response_time_ms) AS min_response_time_ms,
    MAX(response_time_ms) AS max_response_time_ms,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY response_time_ms) AS median_response_time_ms
FROM response_analytics
GROUP BY response_type;

COMMENT ON VIEW response_time_stats IS 'Aggregate statistics for response times by type';

-- Create view for daily response metrics
CREATE OR REPLACE VIEW daily_response_metrics AS
SELECT
    DATE(responded_at) AS date,
    response_type,
    COUNT(*) AS responses,
    AVG(response_time_ms) / 1000.0 AS avg_response_seconds
FROM response_analytics
WHERE responded_at >= NOW() - INTERVAL '30 days'
GROUP BY DATE(responded_at), response_type
ORDER BY date DESC, response_type;

COMMENT ON VIEW daily_response_metrics IS 'Daily response metrics for the last 30 days';
