class DatabaseHelper {
    constructor(supabaseClient = null) {
        // Use provided Supabase client or try to access from global scope
        this.supabase = supabaseClient || (typeof window !== 'undefined' ? window.supabase : null);
        
        if (!this.supabase && typeof window !== 'undefined') {
            // Try to create client from global config
            const config = window.config;
            if (config && window.supabase && window.supabase.createClient) {
                this.supabase = window.supabase.createClient(config.SUPABASE_URL, config.SUPABASE_ANON_KEY);
            }
        }
    }

    async createLearningTables() {
        const tables = [
            {
                name: 'negotiation_analytics',
                sql: `
                    CREATE TABLE IF NOT EXISTS negotiation_analytics (
                        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                        conversation_id VARCHAR(255),
                        template_used INTEGER,
                        strategy_type VARCHAR(100),
                        success BOOLEAN,
                        final_price INTEGER,
                        initial_price INTEGER,
                        savings_achieved INTEGER,
                        message_count INTEGER,
                        response_time_avg INTEGER,
                        landlord_personality VARCHAR(50),
                        market_conditions JSONB,
                        created_at TIMESTAMP DEFAULT NOW()
                    )
                `
            },
            {
                name: 'template_performance',
                sql: `
                    CREATE TABLE IF NOT EXISTS template_performance (
                        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                        template_id INTEGER,
                        strategy_type VARCHAR(100),
                        success_count INTEGER DEFAULT 0,
                        failure_count INTEGER DEFAULT 0,
                        avg_savings DECIMAL,
                        last_updated TIMESTAMP DEFAULT NOW()
                    )
                `
            },
            {
                name: 'learning_patterns',
                sql: `
                    CREATE TABLE IF NOT EXISTS learning_patterns (
                        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                        pattern_type VARCHAR(100),
                        pattern_data JSONB,
                        success_correlation DECIMAL,
                        sample_size INTEGER,
                        confidence_score DECIMAL,
                        created_at TIMESTAMP DEFAULT NOW()
                    )
                `
            }
        ];

        for (const table of tables) {
            try {
                await this.supabase.rpc('exec_sql', { sql: table.sql });
            } catch (error) {
                console.log(`Table ${table.name} might already exist or creation failed:`, error.message);
            }
        }
    }

    async recordNegotiationOutcome(data) {
        const { error } = await this.supabase
            .from('negotiation_analytics')
            .insert([data]);
        
        if (error) throw error;
        return true;
    }

    async updateTemplatePerformance(templateId, strategyType, success, savings) {
        const { data: existing } = await this.supabase
            .from('template_performance')
            .select('*')
            .eq('template_id', templateId)
            .eq('strategy_type', strategyType)
            .single();

        if (existing) {
            const updates = {
                success_count: success ? existing.success_count + 1 : existing.success_count,
                failure_count: success ? existing.failure_count : existing.failure_count + 1,
                avg_savings: this.calculateNewAverage(existing.avg_savings, savings, existing.success_count + existing.failure_count),
                last_updated: new Date()
            };

            const { error } = await this.supabase
                .from('template_performance')
                .update(updates)
                .eq('id', existing.id);
            
            if (error) throw error;
        } else {
            const { error } = await this.supabase
                .from('template_performance')
                .insert([{
                    template_id: templateId,
                    strategy_type: strategyType,
                    success_count: success ? 1 : 0,
                    failure_count: success ? 0 : 1,
                    avg_savings: savings
                }]);
            
            if (error) throw error;
        }
    }

    async getTemplatePerformance(strategyType) {
        const { data, error } = await this.supabase
            .from('template_performance')
            .select('*')
            .eq('strategy_type', strategyType)
            .order('success_count', { ascending: false });
        
        if (error) throw error;
        return data;
    }

    async getSuccessfulNegotiations(limit = 50) {
        const { data, error } = await this.supabase
            .from('negotiation_analytics')
            .select('*')
            .eq('success', true)
            .order('created_at', { ascending: false })
            .limit(limit);
        
        if (error) throw error;
        return data;
    }

    async storePattern(patternType, patternData, correlation, sampleSize, confidence) {
        const { error } = await this.supabase
            .from('learning_patterns')
            .insert([{
                pattern_type: patternType,
                pattern_data: patternData,
                success_correlation: correlation,
                sample_size: sampleSize,
                confidence_score: confidence
            }]);
        
        if (error) throw error;
        return true;
    }

    async getPatterns(patternType) {
        const { data, error } = await this.supabase
            .from('learning_patterns')
            .select('*')
            .eq('pattern_type', patternType)
            .order('confidence_score', { ascending: false });
        
        if (error) throw error;
        return data;
    }

    calculateNewAverage(currentAvg, newValue, count) {
        if (count === 0) return newValue;
        return ((currentAvg * (count - 1)) + newValue) / count;
    }
}

module.exports = DatabaseHelper;