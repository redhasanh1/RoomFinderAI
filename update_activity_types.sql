-- Update user_activities table to include verification activity types
ALTER TABLE user_activities DROP CONSTRAINT IF EXISTS user_activities_activity_type_check;

ALTER TABLE user_activities ADD CONSTRAINT user_activities_activity_type_check 
CHECK (activity_type IN (
    'registered', 
    'profile_updated', 
    'listing_created', 
    'subscription_bought', 
    'subscription_renewed', 
    'message_received', 
    'message_sent',
    'id_verified',
    'face_verified',
    'verification_failed'
));