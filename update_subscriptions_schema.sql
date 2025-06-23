-- Update subscriptions table to support cancellation tracking
-- Add new columns for cancellation management
ALTER TABLE subscriptions 
ADD COLUMN IF NOT EXISTS cancellation_requested_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS cancellation_effective_date TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS cancellation_reason TEXT;

-- Update status enum to include pending_cancellation
ALTER TABLE subscriptions DROP CONSTRAINT IF EXISTS subscriptions_status_check;
ALTER TABLE subscriptions ADD CONSTRAINT subscriptions_status_check 
CHECK (status IN ('active', 'canceled', 'expired', 'paused', 'pending_cancellation'));

-- Update payment_method enum to include Google Pay and Apple Pay
ALTER TABLE subscriptions DROP CONSTRAINT IF EXISTS subscriptions_payment_method_check;
ALTER TABLE subscriptions ADD CONSTRAINT subscriptions_payment_method_check 
CHECK (payment_method IN ('card', 'etransfer', 'google_pay', 'apple_pay', 'wallet'));

-- Create index for cancellation dates
CREATE INDEX IF NOT EXISTS idx_subscriptions_cancellation_effective ON subscriptions(cancellation_effective_date);
CREATE INDEX IF NOT EXISTS idx_subscriptions_cancellation_requested ON subscriptions(cancellation_requested_at);

-- Add a function to automatically cancel subscriptions when their effective date passes
CREATE OR REPLACE FUNCTION auto_cancel_expired_subscriptions()
RETURNS INTEGER AS $$
DECLARE
    updated_count INTEGER;
BEGIN
    UPDATE subscriptions 
    SET status = 'canceled',
        updated_at = NOW()
    WHERE status = 'pending_cancellation' 
    AND cancellation_effective_date <= NOW();
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RETURN updated_count;
END;
$$ LANGUAGE plpgsql;

-- Create a trigger to run the auto-cancellation function
-- This would typically be run via a cron job or scheduled task
-- For now, we'll create the function and it can be called periodically