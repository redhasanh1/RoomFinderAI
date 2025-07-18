-- Database Optimization Script for RoomFinderAI
-- This script creates indexes and optimizes database performance

-- ====================================
-- LISTINGS TABLE OPTIMIZATIONS
-- ====================================

-- Primary indexes for listings table
CREATE INDEX IF NOT EXISTS idx_listings_created_at ON listings(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_listings_updated_at ON listings(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_listings_price ON listings(price);
CREATE INDEX IF NOT EXISTS idx_listings_bedrooms ON listings(bedrooms);
CREATE INDEX IF NOT EXISTS idx_listings_bathrooms ON listings(bathrooms);
CREATE INDEX IF NOT EXISTS idx_listings_property_type ON listings(property_type);
CREATE INDEX IF NOT EXISTS idx_listings_available_date ON listings(available_date);

-- Location-based indexes
CREATE INDEX IF NOT EXISTS idx_listings_location_city ON listings USING GIN ((location->>'city'));
CREATE INDEX IF NOT EXISTS idx_listings_location_state ON listings USING GIN ((location->>'state'));
CREATE INDEX IF NOT EXISTS idx_listings_location_country ON listings USING GIN ((location->>'country'));
CREATE INDEX IF NOT EXISTS idx_listings_location_postal_code ON listings USING GIN ((location->>'postal_code'));

-- Spatial index for location coordinates (if using PostGIS)
CREATE INDEX IF NOT EXISTS idx_listings_location_coordinates ON listings USING GIST (
    ST_Point(
        CAST(location->>'longitude' AS float),
        CAST(location->>'latitude' AS float)
    )
);

-- Full-text search indexes
CREATE INDEX IF NOT EXISTS idx_listings_title_fts ON listings USING GIN (to_tsvector('english', title));
CREATE INDEX IF NOT EXISTS idx_listings_description_fts ON listings USING GIN (to_tsvector('english', description));
CREATE INDEX IF NOT EXISTS idx_listings_combined_fts ON listings USING GIN (
    to_tsvector('english', title || ' ' || description)
);

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_listings_price_bedrooms ON listings(price, bedrooms);
CREATE INDEX IF NOT EXISTS idx_listings_property_type_price ON listings(property_type, price);
CREATE INDEX IF NOT EXISTS idx_listings_available_date_price ON listings(available_date, price);
CREATE INDEX IF NOT EXISTS idx_listings_city_price ON listings((location->>'city'), price);
CREATE INDEX IF NOT EXISTS idx_listings_active_created_at ON listings(is_active, created_at DESC) WHERE is_active = true;

-- Policy-based indexes
CREATE INDEX IF NOT EXISTS idx_listings_pet_policy ON listings(pet_policy) WHERE pet_policy IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_listings_smoking_policy ON listings(smoking_policy) WHERE smoking_policy IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_listings_utilities_included ON listings(utilities_included);

-- View count optimization
CREATE INDEX IF NOT EXISTS idx_listings_view_count ON listings(view_count DESC);

-- ====================================
-- USERS TABLE OPTIMIZATIONS
-- ====================================

-- Primary indexes for users table
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_users_updated_at ON users(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_users_is_active ON users(is_active) WHERE is_active = true;

-- Profile-based indexes
CREATE INDEX IF NOT EXISTS idx_users_first_name ON users(first_name);
CREATE INDEX IF NOT EXISTS idx_users_last_name ON users(last_name);
CREATE INDEX IF NOT EXISTS idx_users_full_name ON users(first_name, last_name);

-- ====================================
-- MESSAGES TABLE OPTIMIZATIONS
-- ====================================

-- Primary indexes for messages table
CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_receiver_id ON messages(receiver_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at DESC);

-- Composite indexes for message queries
CREATE INDEX IF NOT EXISTS idx_messages_conversation_created_at ON messages(conversation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_sender_created_at ON messages(sender_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_unread ON messages(receiver_id, is_read, created_at DESC) WHERE is_read = false;

-- ====================================
-- CONVERSATIONS TABLE OPTIMIZATIONS
-- ====================================

-- Primary indexes for conversations table
CREATE INDEX IF NOT EXISTS idx_conversations_sender_email ON conversations(sender_email);
CREATE INDEX IF NOT EXISTS idx_conversations_receiver_email ON conversations(receiver_email);
CREATE INDEX IF NOT EXISTS idx_conversations_listing_id ON conversations(listing_id);
CREATE INDEX IF NOT EXISTS idx_conversations_created_at ON conversations(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_conversations_updated_at ON conversations(updated_at DESC);

-- Composite indexes for conversation queries
CREATE INDEX IF NOT EXISTS idx_conversations_participants ON conversations(sender_email, receiver_email);
CREATE INDEX IF NOT EXISTS idx_conversations_user_updated_at ON conversations(sender_email, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_conversations_listing_created_at ON conversations(listing_id, created_at DESC);

-- ====================================
-- USER_FAVORITES TABLE OPTIMIZATIONS
-- ====================================

-- Primary indexes for user_favorites table
CREATE INDEX IF NOT EXISTS idx_user_favorites_user_email ON user_favorites(user_email);
CREATE INDEX IF NOT EXISTS idx_user_favorites_listing_id ON user_favorites(listing_id);
CREATE INDEX IF NOT EXISTS idx_user_favorites_created_at ON user_favorites(created_at DESC);

-- Composite indexes for favorites queries
CREATE INDEX IF NOT EXISTS idx_user_favorites_user_listing ON user_favorites(user_email, listing_id);
CREATE INDEX IF NOT EXISTS idx_user_favorites_user_created_at ON user_favorites(user_email, created_at DESC);

-- ====================================
-- AI_CHATS TABLE OPTIMIZATIONS
-- ====================================

-- Primary indexes for ai_chats table
CREATE INDEX IF NOT EXISTS idx_ai_chats_user_id ON ai_chats(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_chats_listing_id ON ai_chats(listing_id);
CREATE INDEX IF NOT EXISTS idx_ai_chats_created_at ON ai_chats(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_chats_updated_at ON ai_chats(updated_at DESC);

-- Composite indexes for AI chat queries
CREATE INDEX IF NOT EXISTS idx_ai_chats_user_updated_at ON ai_chats(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_chats_listing_created_at ON ai_chats(listing_id, created_at DESC);

-- ====================================
-- AI_MESSAGES TABLE OPTIMIZATIONS
-- ====================================

-- Primary indexes for ai_messages table
CREATE INDEX IF NOT EXISTS idx_ai_messages_chat_id ON ai_messages(chat_id);
CREATE INDEX IF NOT EXISTS idx_ai_messages_role ON ai_messages(role);
CREATE INDEX IF NOT EXISTS idx_ai_messages_timestamp ON ai_messages(timestamp DESC);

-- Composite indexes for AI message queries
CREATE INDEX IF NOT EXISTS idx_ai_messages_chat_timestamp ON ai_messages(chat_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_ai_messages_chat_role_timestamp ON ai_messages(chat_id, role, timestamp DESC);

-- ====================================
-- SUBSCRIPTIONS TABLE OPTIMIZATIONS
-- ====================================

-- Primary indexes for subscriptions table
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_email ON subscriptions(user_email);
CREATE INDEX IF NOT EXISTS idx_subscriptions_plan_type ON subscriptions(plan_type);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_created_at ON subscriptions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_subscriptions_current_period_end ON subscriptions(current_period_end);

-- Composite indexes for subscription queries
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_status ON subscriptions(user_email, status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_active_users ON subscriptions(user_email, status, current_period_end) 
    WHERE status IN ('active', 'trialing');

-- ====================================
-- ANALYTICS AND PERFORMANCE INDEXES
-- ====================================

-- Indexes for analytics queries
CREATE INDEX IF NOT EXISTS idx_listings_created_at_month ON listings(DATE_TRUNC('month', created_at));
CREATE INDEX IF NOT EXISTS idx_listings_created_at_day ON listings(DATE_TRUNC('day', created_at));
CREATE INDEX IF NOT EXISTS idx_users_created_at_month ON users(DATE_TRUNC('month', created_at));

-- Performance monitoring indexes
CREATE INDEX IF NOT EXISTS idx_messages_created_at_day ON messages(DATE_TRUNC('day', created_at));
CREATE INDEX IF NOT EXISTS idx_conversations_created_at_day ON conversations(DATE_TRUNC('day', created_at));

-- ====================================
-- PARTITIONING STRATEGIES
-- ====================================

-- Enable partitioning for large tables (messages, ai_messages)
-- Note: This should be done during table creation in production

-- Example partitioning by date for messages table
/*
CREATE TABLE messages_2024_q1 PARTITION OF messages
FOR VALUES FROM ('2024-01-01') TO ('2024-04-01');

CREATE TABLE messages_2024_q2 PARTITION OF messages
FOR VALUES FROM ('2024-04-01') TO ('2024-07-01');

CREATE TABLE messages_2024_q3 PARTITION OF messages
FOR VALUES FROM ('2024-07-01') TO ('2024-10-01');

CREATE TABLE messages_2024_q4 PARTITION OF messages
FOR VALUES FROM ('2024-10-01') TO ('2025-01-01');
*/

-- ====================================
-- MATERIALIZED VIEWS FOR PERFORMANCE
-- ====================================

-- Popular listings materialized view
CREATE MATERIALIZED VIEW IF NOT EXISTS popular_listings AS
SELECT 
    l.id,
    l.title,
    l.price,
    l.bedrooms,
    l.bathrooms,
    l.property_type,
    l.location,
    l.view_count,
    l.created_at,
    COUNT(uf.id) as favorite_count,
    AVG(lr.rating) as average_rating
FROM listings l
LEFT JOIN user_favorites uf ON l.id = uf.listing_id
LEFT JOIN listing_reviews lr ON l.id = lr.listing_id
WHERE l.is_active = true
GROUP BY l.id, l.title, l.price, l.bedrooms, l.bathrooms, l.property_type, l.location, l.view_count, l.created_at
ORDER BY l.view_count DESC, favorite_count DESC;

-- Index on materialized view
CREATE INDEX IF NOT EXISTS idx_popular_listings_view_count ON popular_listings(view_count DESC);
CREATE INDEX IF NOT EXISTS idx_popular_listings_favorite_count ON popular_listings(favorite_count DESC);

-- Recent listings materialized view
CREATE MATERIALIZED VIEW IF NOT EXISTS recent_listings AS
SELECT 
    l.id,
    l.title,
    l.price,
    l.bedrooms,
    l.bathrooms,
    l.property_type,
    l.location,
    l.created_at,
    l.updated_at
FROM listings l
WHERE l.is_active = true
    AND l.created_at >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY l.created_at DESC;

-- Index on recent listings materialized view
CREATE INDEX IF NOT EXISTS idx_recent_listings_created_at ON recent_listings(created_at DESC);

-- City statistics materialized view
CREATE MATERIALIZED VIEW IF NOT EXISTS city_stats AS
SELECT 
    location->>'city' as city,
    location->>'state' as state,
    location->>'country' as country,
    COUNT(*) as total_listings,
    AVG(price) as average_price,
    MIN(price) as min_price,
    MAX(price) as max_price,
    COUNT(DISTINCT property_type) as property_types_count
FROM listings
WHERE is_active = true
GROUP BY location->>'city', location->>'state', location->>'country'
HAVING COUNT(*) >= 5
ORDER BY total_listings DESC;

-- Index on city stats materialized view
CREATE INDEX IF NOT EXISTS idx_city_stats_city ON city_stats(city);
CREATE INDEX IF NOT EXISTS idx_city_stats_total_listings ON city_stats(total_listings DESC);

-- ====================================
-- REFRESH MATERIALIZED VIEWS
-- ====================================

-- Function to refresh all materialized views
CREATE OR REPLACE FUNCTION refresh_materialized_views()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW popular_listings;
    REFRESH MATERIALIZED VIEW recent_listings;
    REFRESH MATERIALIZED VIEW city_stats;
END;
$$ LANGUAGE plpgsql;

-- ====================================
-- QUERY PERFORMANCE OPTIMIZATIONS
-- ====================================

-- Enable query plan caching
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements';

-- Optimize for read-heavy workloads
ALTER SYSTEM SET random_page_cost = 1.1;
ALTER SYSTEM SET seq_page_cost = 1.0;

-- Increase work memory for complex queries
ALTER SYSTEM SET work_mem = '256MB';

-- Optimize checkpoint behavior
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
ALTER SYSTEM SET checkpoint_timeout = '15min';

-- ====================================
-- MONITORING AND MAINTENANCE
-- ====================================

-- Enable query statistics
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Function to analyze slow queries
CREATE OR REPLACE FUNCTION get_slow_queries(limit_count INTEGER DEFAULT 10)
RETURNS TABLE (
    query TEXT,
    calls BIGINT,
    total_time DOUBLE PRECISION,
    mean_time DOUBLE PRECISION,
    rows BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pss.query,
        pss.calls,
        pss.total_exec_time,
        pss.mean_exec_time,
        pss.rows
    FROM pg_stat_statements pss
    ORDER BY pss.total_exec_time DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- Function to get table sizes
CREATE OR REPLACE FUNCTION get_table_sizes()
RETURNS TABLE (
    table_name TEXT,
    size_bytes BIGINT,
    size_pretty TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        schemaname||'.'||tablename as table_name,
        pg_total_relation_size(schemaname||'.'||tablename) as size_bytes,
        pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size_pretty
    FROM pg_tables
    WHERE schemaname = 'public'
    ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get index usage statistics
CREATE OR REPLACE FUNCTION get_index_usage()
RETURNS TABLE (
    table_name TEXT,
    index_name TEXT,
    idx_scan BIGINT,
    idx_tup_read BIGINT,
    idx_tup_fetch BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        schemaname||'.'||tablename as table_name,
        indexname as index_name,
        idx_scan,
        idx_tup_read,
        idx_tup_fetch
    FROM pg_stat_user_indexes
    WHERE schemaname = 'public'
    ORDER BY idx_scan DESC;
END;
$$ LANGUAGE plpgsql;

-- ====================================
-- CLEANUP AND MAINTENANCE JOBS
-- ====================================

-- Function to clean up old data
CREATE OR REPLACE FUNCTION cleanup_old_data()
RETURNS void AS $$
BEGIN
    -- Delete old messages (older than 1 year)
    DELETE FROM messages WHERE created_at < CURRENT_DATE - INTERVAL '1 year';
    
    -- Delete old AI messages (older than 6 months)
    DELETE FROM ai_messages WHERE timestamp < CURRENT_DATE - INTERVAL '6 months';
    
    -- Delete expired listings
    DELETE FROM listings WHERE is_active = false AND updated_at < CURRENT_DATE - INTERVAL '3 months';
    
    -- Update statistics
    ANALYZE;
END;
$$ LANGUAGE plpgsql;

-- ====================================
-- USAGE EXAMPLES
-- ====================================

/*
-- Example optimized queries using the indexes:

-- 1. Search listings by city and price range
SELECT * FROM listings 
WHERE location->>'city' = 'Toronto' 
    AND price BETWEEN 1000 AND 2000 
    AND is_active = true
ORDER BY created_at DESC;

-- 2. Full-text search with price filter
SELECT * FROM listings
WHERE to_tsvector('english', title || ' ' || description) @@ to_tsquery('english', 'apartment & downtown')
    AND price <= 1500
    AND is_active = true
ORDER BY view_count DESC;

-- 3. User's conversations with message counts
SELECT c.*, COUNT(m.id) as message_count
FROM conversations c
LEFT JOIN messages m ON c.id = m.conversation_id
WHERE c.sender_email = 'user@example.com' OR c.receiver_email = 'user@example.com'
GROUP BY c.id
ORDER BY c.updated_at DESC;

-- 4. Popular listings in a specific area
SELECT * FROM popular_listings
WHERE location->>'city' = 'Toronto'
ORDER BY view_count DESC, favorite_count DESC
LIMIT 20;

-- 5. Recent listings with filters
SELECT * FROM recent_listings
WHERE property_type = 'apartment'
    AND bedrooms >= 2
    AND price <= 2000
ORDER BY created_at DESC;
*/

-- ====================================
-- PERFORMANCE MONITORING QUERIES
-- ====================================

-- Check index usage efficiency
SELECT 
    schemaname,
    tablename,
    attname,
    n_distinct,
    correlation
FROM pg_stats
WHERE schemaname = 'public'
    AND tablename IN ('listings', 'users', 'messages', 'conversations')
ORDER BY tablename, attname;

-- Monitor cache hit ratios
SELECT 
    'index hit rate' as name,
    (sum(idx_blks_hit)) / nullif(sum(idx_blks_hit + idx_blks_read),0) * 100 as ratio
FROM pg_statio_user_indexes
UNION ALL
SELECT 
    'table hit rate' as name,
    sum(heap_blks_hit) / nullif(sum(heap_blks_hit) + sum(heap_blks_read),0) * 100 as ratio
FROM pg_statio_user_tables;