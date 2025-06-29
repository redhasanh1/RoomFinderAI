const DatabaseHelper = require('../utils/database-helper');

class SuccessTracker {
    constructor(supabaseClient = null) {
        this.db = new DatabaseHelper(supabaseClient);
        this.metrics = {
            totalNegotiations: 0,
            successfulNegotiations: 0,
            failedNegotiations: 0,
            totalSavings: 0,
            averageResponseTime: 0,
            recentPerformance: []
        };
    }

    async initialize() {
        await this.loadHistoricalMetrics();
    }

    async loadHistoricalMetrics() {
        try {
            const historicalData = await this.db.getSuccessfulNegotiations(1000);
            
            this.metrics.totalNegotiations = historicalData.length;
            this.metrics.successfulNegotiations = historicalData.filter(n => n.success).length;
            this.metrics.failedNegotiations = this.metrics.totalNegotiations - this.metrics.successfulNegotiations;
            this.metrics.totalSavings = historicalData.reduce((sum, n) => sum + (n.savings_achieved || 0), 0);
            this.metrics.averageResponseTime = this.calculateAverageResponseTime(historicalData);
            
            // Calculate recent performance (last 30 days)
            const thirtyDaysAgo = new Date();
            thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
            
            this.metrics.recentPerformance = historicalData
                .filter(n => new Date(n.created_at) > thirtyDaysAgo)
                .slice(0, 100);
                
        } catch (error) {
            console.error('Failed to load historical metrics:', error);
        }
    }

    async recordOutcome(conversationData, analysis) {
        try {
            // Record in database
            const outcomeData = {
                conversation_id: conversationData.id,
                template_used: analysis.templateUsed,
                strategy_type: analysis.strategyType,
                success: analysis.success,
                final_price: analysis.finalPrice,
                initial_price: analysis.initialPrice,
                savings_achieved: analysis.savingsAchieved,
                message_count: conversationData.messages?.length || 0,
                response_time_avg: this.calculateConversationResponseTime(conversationData),
                landlord_personality: analysis.landlordPersonality,
                market_conditions: analysis.marketConditions
            };

            await this.db.recordNegotiationOutcome(outcomeData);

            // Update local metrics
            await this.updateLocalMetrics(outcomeData);

            // Trigger alerts if needed
            await this.checkPerformanceAlerts(outcomeData);

            return true;
        } catch (error) {
            console.error('Failed to record outcome:', error);
            return false;
        }
    }

    async updateLocalMetrics(outcomeData) {
        this.metrics.totalNegotiations++;
        
        if (outcomeData.success) {
            this.metrics.successfulNegotiations++;
            this.metrics.totalSavings += outcomeData.savings_achieved || 0;
        } else {
            this.metrics.failedNegotiations++;
        }

        // Update recent performance
        this.metrics.recentPerformance.unshift(outcomeData);
        if (this.metrics.recentPerformance.length > 100) {
            this.metrics.recentPerformance.pop();
        }

        // Recalculate averages
        this.metrics.averageResponseTime = this.calculateAverageResponseTime(this.metrics.recentPerformance);
    }

    async getMetrics() {
        const currentMetrics = {
            ...this.metrics,
            successRate: this.calculateSuccessRate(),
            averageSavings: this.calculateAverageSavings(),
            performanceTrend: this.calculatePerformanceTrend(),
            templateAnalysis: await this.getTemplateAnalysis(),
            strategyAnalysis: await this.getStrategyAnalysis(),
            timeBasedAnalysis: this.getTimeBasedAnalysis(),
            marketAnalysis: this.getMarketAnalysis(),
            landlordAnalysis: this.getLandlordAnalysis()
        };

        return currentMetrics;
    }

    calculateSuccessRate() {
        if (this.metrics.totalNegotiations === 0) return 0;
        return this.metrics.successfulNegotiations / this.metrics.totalNegotiations;
    }

    calculateAverageSavings() {
        if (this.metrics.successfulNegotiations === 0) return 0;
        return this.metrics.totalSavings / this.metrics.successfulNegotiations;
    }

    calculatePerformanceTrend() {
        if (this.metrics.recentPerformance.length < 10) return 'insufficient_data';
        
        const recent = this.metrics.recentPerformance.slice(0, 20);
        const older = this.metrics.recentPerformance.slice(20, 40);
        
        const recentSuccessRate = recent.filter(n => n.success).length / recent.length;
        const olderSuccessRate = older.filter(n => n.success).length / older.length;
        
        const difference = recentSuccessRate - olderSuccessRate;
        
        if (difference > 0.1) return 'improving';
        if (difference < -0.1) return 'declining';
        return 'stable';
    }

    async getTemplateAnalysis() {
        const templatePerformance = {};
        
        this.metrics.recentPerformance.forEach(negotiation => {
            const key = `template_${negotiation.template_used}`;
            if (!templatePerformance[key]) {
                templatePerformance[key] = {
                    templateId: negotiation.template_used,
                    successes: 0,
                    failures: 0,
                    totalSavings: 0,
                    responseTime: 0,
                    count: 0
                };
            }
            
            const template = templatePerformance[key];
            template.count++;
            template.responseTime += negotiation.response_time_avg || 0;
            
            if (negotiation.success) {
                template.successes++;
                template.totalSavings += negotiation.savings_achieved || 0;
            } else {
                template.failures++;
            }
        });

        // Calculate derived metrics
        Object.values(templatePerformance).forEach(template => {
            template.successRate = template.successes / (template.successes + template.failures);
            template.averageSavings = template.successes > 0 ? template.totalSavings / template.successes : 0;
            template.averageResponseTime = template.responseTime / template.count;
        });

        return Object.values(templatePerformance)
            .sort((a, b) => b.successRate - a.successRate);
    }

    async getStrategyAnalysis() {
        const strategyPerformance = {};
        
        this.metrics.recentPerformance.forEach(negotiation => {
            const strategy = negotiation.strategy_type;
            if (!strategyPerformance[strategy]) {
                strategyPerformance[strategy] = {
                    strategy: strategy,
                    successes: 0,
                    failures: 0,
                    totalSavings: 0,
                    count: 0,
                    averageMessageCount: 0
                };
            }
            
            const strategyData = strategyPerformance[strategy];
            strategyData.count++;
            strategyData.averageMessageCount += negotiation.message_count || 0;
            
            if (negotiation.success) {
                strategyData.successes++;
                strategyData.totalSavings += negotiation.savings_achieved || 0;
            } else {
                strategyData.failures++;
            }
        });

        // Calculate derived metrics
        Object.values(strategyPerformance).forEach(strategy => {
            strategy.successRate = strategy.successes / (strategy.successes + strategy.failures);
            strategy.averageSavings = strategy.successes > 0 ? strategy.totalSavings / strategy.successes : 0;
            strategy.averageMessageCount = strategy.averageMessageCount / strategy.count;
        });

        return Object.values(strategyPerformance)
            .sort((a, b) => b.successRate - a.successRate);
    }

    getTimeBasedAnalysis() {
        const hourlyPerformance = {};
        const dailyPerformance = {};
        
        this.metrics.recentPerformance.forEach(negotiation => {
            const date = new Date(negotiation.created_at);
            const hour = date.getHours();
            const day = date.toLocaleDateString('en-US', { weekday: 'long' });
            
            // Hourly analysis
            if (!hourlyPerformance[hour]) {
                hourlyPerformance[hour] = { hour, successes: 0, failures: 0, count: 0 };
            }
            hourlyPerformance[hour].count++;
            if (negotiation.success) {
                hourlyPerformance[hour].successes++;
            } else {
                hourlyPerformance[hour].failures++;
            }
            
            // Daily analysis
            if (!dailyPerformance[day]) {
                dailyPerformance[day] = { day, successes: 0, failures: 0, count: 0 };
            }
            dailyPerformance[day].count++;
            if (negotiation.success) {
                dailyPerformance[day].successes++;
            } else {
                dailyPerformance[day].failures++;
            }
        });

        // Calculate success rates
        Object.values(hourlyPerformance).forEach(hour => {
            hour.successRate = hour.successes / (hour.successes + hour.failures);
        });
        
        Object.values(dailyPerformance).forEach(day => {
            day.successRate = day.successes / (day.successes + day.failures);
        });

        return {
            hourly: Object.values(hourlyPerformance).sort((a, b) => a.hour - b.hour),
            daily: Object.values(dailyPerformance).sort((a, b) => b.successRate - a.successRate)
        };
    }

    getMarketAnalysis() {
        const marketPerformance = {};
        
        this.metrics.recentPerformance.forEach(negotiation => {
            const conditions = negotiation.market_conditions;
            if (!conditions) return;
            
            const key = `${conditions.competitiveness}_${conditions.marketTrend}`;
            if (!marketPerformance[key]) {
                marketPerformance[key] = {
                    competitiveness: conditions.competitiveness,
                    marketTrend: conditions.marketTrend,
                    successes: 0,
                    failures: 0,
                    totalSavings: 0,
                    count: 0
                };
            }
            
            const market = marketPerformance[key];
            market.count++;
            
            if (negotiation.success) {
                market.successes++;
                market.totalSavings += negotiation.savings_achieved || 0;
            } else {
                market.failures++;
            }
        });

        // Calculate derived metrics
        Object.values(marketPerformance).forEach(market => {
            market.successRate = market.successes / (market.successes + market.failures);
            market.averageSavings = market.successes > 0 ? market.totalSavings / market.successes : 0;
        });

        return Object.values(marketPerformance)
            .sort((a, b) => b.successRate - a.successRate);
    }

    getLandlordAnalysis() {
        const landlordPerformance = {};
        
        this.metrics.recentPerformance.forEach(negotiation => {
            const personality = negotiation.landlord_personality || 'unknown';
            if (!landlordPerformance[personality]) {
                landlordPerformance[personality] = {
                    personality: personality,
                    successes: 0,
                    failures: 0,
                    totalSavings: 0,
                    averageResponseTime: 0,
                    count: 0
                };
            }
            
            const landlord = landlordPerformance[personality];
            landlord.count++;
            landlord.averageResponseTime += negotiation.response_time_avg || 0;
            
            if (negotiation.success) {
                landlord.successes++;
                landlord.totalSavings += negotiation.savings_achieved || 0;
            } else {
                landlord.failures++;
            }
        });

        // Calculate derived metrics
        Object.values(landlordPerformance).forEach(landlord => {
            landlord.successRate = landlord.successes / (landlord.successes + landlord.failures);
            landlord.averageSavings = landlord.successes > 0 ? landlord.totalSavings / landlord.successes : 0;
            landlord.averageResponseTime = landlord.averageResponseTime / landlord.count;
        });

        return Object.values(landlordPerformance)
            .sort((a, b) => b.successRate - a.successRate);
    }

    calculateConversationResponseTime(conversationData) {
        if (!conversationData.messages || conversationData.messages.length < 2) return 0;
        
        let totalTime = 0;
        let intervals = 0;
        
        for (let i = 1; i < conversationData.messages.length; i++) {
            const timeDiff = new Date(conversationData.messages[i].created_at) - 
                           new Date(conversationData.messages[i-1].created_at);
            totalTime += timeDiff;
            intervals++;
        }
        
        return intervals > 0 ? Math.round(totalTime / intervals / 1000 / 60) : 0; // minutes
    }

    calculateAverageResponseTime(negotiations) {
        if (negotiations.length === 0) return 0;
        const totalTime = negotiations.reduce((sum, n) => sum + (n.response_time_avg || 0), 0);
        return totalTime / negotiations.length;
    }

    async checkPerformanceAlerts(outcomeData) {
        const recentFailures = this.metrics.recentPerformance
            .slice(0, 10)
            .filter(n => !n.success).length;

        // Alert if 70% or more of last 10 negotiations failed
        if (recentFailures >= 7) {
            await this.sendAlert('high_failure_rate', {
                failureRate: recentFailures / 10,
                recentNegotiations: 10,
                message: 'High failure rate detected in recent negotiations'
            });
        }

        // Alert if success rate dropped below 40% in last 20 negotiations
        const last20 = this.metrics.recentPerformance.slice(0, 20);
        if (last20.length >= 20) {
            const successRate = last20.filter(n => n.success).length / 20;
            if (successRate < 0.4) {
                await this.sendAlert('low_success_rate', {
                    successRate: successRate,
                    threshold: 0.4,
                    message: 'Success rate dropped below acceptable threshold'
                });
            }
        }

        // Alert if average savings dropped significantly
        const recentSavings = this.metrics.recentPerformance
            .slice(0, 10)
            .filter(n => n.success)
            .reduce((sum, n) => sum + (n.savings_achieved || 0), 0) / 10;

        const historicalSavings = this.calculateAverageSavings();
        
        if (recentSavings < historicalSavings * 0.5 && historicalSavings > 0) {
            await this.sendAlert('low_savings', {
                recentSavings: recentSavings,
                historicalSavings: historicalSavings,
                message: 'Recent savings significantly below historical average'
            });
        }
    }

    async sendAlert(alertType, data) {
        // This would integrate with your notification system
        console.log(`🚨 PERFORMANCE ALERT: ${alertType}`, data);
        
        // Could send to Discord, Slack, email, etc.
        // For now, just log to console
        
        // Example Discord webhook integration:
        /*
        if (process.env.DISCORD_WEBHOOK_URL) {
            await fetch(process.env.DISCORD_WEBHOOK_URL, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    content: `🚨 **${alertType.toUpperCase()}**: ${data.message}`,
                    embeds: [{
                        title: 'Performance Alert',
                        fields: Object.entries(data).map(([key, value]) => ({
                            name: key,
                            value: value.toString(),
                            inline: true
                        }))
                    }]
                })
            });
        }
        */
    }

    async getPerformanceReport(days = 30) {
        const cutoffDate = new Date();
        cutoffDate.setDate(cutoffDate.getDate() - days);
        
        const periodData = this.metrics.recentPerformance.filter(n => 
            new Date(n.created_at) > cutoffDate
        );

        const report = {
            period: `${days} days`,
            totalNegotiations: periodData.length,
            successfulNegotiations: periodData.filter(n => n.success).length,
            successRate: periodData.length > 0 ? periodData.filter(n => n.success).length / periodData.length : 0,
            totalSavings: periodData.filter(n => n.success).reduce((sum, n) => sum + (n.savings_achieved || 0), 0),
            averageSavings: 0,
            topPerformingTemplates: [],
            topPerformingStrategies: [],
            improvementOpportunities: []
        };

        if (report.successfulNegotiations > 0) {
            report.averageSavings = report.totalSavings / report.successfulNegotiations;
        }

        // Get top performing templates and strategies
        const templateAnalysis = await this.getTemplateAnalysis();
        const strategyAnalysis = await this.getStrategyAnalysis();

        report.topPerformingTemplates = templateAnalysis.slice(0, 3);
        report.topPerformingStrategies = strategyAnalysis.slice(0, 3);

        // Identify improvement opportunities
        const worstTemplates = templateAnalysis.slice(-3);
        const worstStrategies = strategyAnalysis.slice(-3);

        report.improvementOpportunities = [
            ...worstTemplates.map(t => ({
                type: 'template',
                id: t.templateId,
                successRate: t.successRate,
                recommendation: 'Consider revising or reducing usage'
            })),
            ...worstStrategies.map(s => ({
                type: 'strategy',
                name: s.strategy,
                successRate: s.successRate,
                recommendation: 'Analyze and improve strategy implementation'
            }))
        ].filter(opp => opp.successRate < 0.5);

        return report;
    }
}

module.exports = SuccessTracker;