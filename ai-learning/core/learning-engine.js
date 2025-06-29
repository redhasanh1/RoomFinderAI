const DatabaseHelper = require('../utils/database-helper');
const PatternAnalyzer = require('./pattern-analyzer');
const TemplateOptimizer = require('../optimizers/template-optimizer');

class LearningEngine {
    constructor(supabaseClient = null) {
        this.db = new DatabaseHelper(supabaseClient);
        this.patternAnalyzer = new PatternAnalyzer();
        this.templateOptimizer = new TemplateOptimizer(supabaseClient);
        this.learningCycles = 0;
        this.lastLearningUpdate = null;
    }

    async initialize() {
        try {
            await this.db.createLearningTables();
            await this.loadExistingPatterns();
        } catch (error) {
            console.error('Learning engine initialization failed:', error);
        }
    }

    async loadExistingPatterns() {
        try {
            const patterns = await this.db.getPatterns('all');
            this.knownPatterns = patterns || [];
        } catch (error) {
            console.error('Failed to load existing patterns:', error);
            this.knownPatterns = [];
        }
    }

    async learnFromSuccess(conversationData, analysis) {
        try {
            await this.recordLearningData(conversationData, analysis);
            
            const patterns = await this.patternAnalyzer.extractSuccessPatterns(conversationData);
            await this.updateKnownPatterns(patterns);
            
            await this.templateOptimizer.updateTemplateWeights(
                analysis.templateUsed,
                analysis.strategyType,
                true,
                analysis.savingsAchieved
            );

            this.learningCycles++;
            
            if (this.shouldPerformLearningCycle()) {
                await this.performLearningCycle();
            }

        } catch (error) {
            console.error('Failed to learn from success:', error);
        }
    }

    async recordLearningData(conversationData, analysis) {
        const learningData = {
            conversation_id: conversationData.id,
            template_used: analysis.templateUsed,
            strategy_type: analysis.strategyType,
            success: analysis.success,
            final_price: analysis.finalPrice,
            initial_price: analysis.initialPrice,
            savings_achieved: analysis.savingsAchieved,
            message_count: conversationData.messages?.length || 0,
            response_time_avg: this.calculateAverageResponseTime(conversationData),
            landlord_personality: analysis.landlordPersonality,
            market_conditions: analysis.marketConditions
        };

        await this.db.recordNegotiationOutcome(learningData);
    }

    async updateKnownPatterns(newPatterns) {
        for (const pattern of newPatterns) {
            const existingPattern = this.knownPatterns.find(p => 
                p.pattern_type === pattern.type && 
                JSON.stringify(p.pattern_data) === JSON.stringify(pattern.data)
            );

            if (existingPattern) {
                const updatedCorrelation = this.updateCorrelation(
                    existingPattern.success_correlation,
                    pattern.correlation,
                    existingPattern.sample_size
                );
                
                existingPattern.success_correlation = updatedCorrelation;
                existingPattern.sample_size += 1;
                existingPattern.confidence_score = this.calculateConfidence(
                    updatedCorrelation,
                    existingPattern.sample_size
                );
            } else {
                await this.db.storePattern(
                    pattern.type,
                    pattern.data,
                    pattern.correlation,
                    1,
                    pattern.confidence
                );
                
                this.knownPatterns.push({
                    pattern_type: pattern.type,
                    pattern_data: pattern.data,
                    success_correlation: pattern.correlation,
                    sample_size: 1,
                    confidence_score: pattern.confidence
                });
            }
        }
    }

    async performLearningCycle() {
        try {
            const recentData = await this.db.getSuccessfulNegotiations(100);
            
            const insights = await this.analyzeRecentPerformance(recentData);
            
            await this.optimizeTemplateSelection(insights);
            
            await this.updateLearningStrategies(insights);
            
            this.lastLearningUpdate = new Date();
            
            return {
                learningCycles: this.learningCycles,
                insights: insights,
                patternsLearned: this.knownPatterns.length,
                lastUpdate: this.lastLearningUpdate
            };

        } catch (error) {
            console.error('Learning cycle failed:', error);
            return null;
        }
    }

    async analyzeRecentPerformance(data) {
        const insights = {
            totalNegotiations: data.length,
            averageSuccessRate: this.calculateSuccessRate(data),
            bestPerformingTemplates: await this.findBestTemplates(data),
            marketTrends: this.analyzeMarketTrends(data),
            landlordPersonalityInsights: this.analyzeLandlordPatterns(data),
            timeBasedPatterns: this.analyzeTimePatterns(data)
        };

        return insights;
    }

    async optimizeTemplateSelection(insights) {
        for (const templateInsight of insights.bestPerformingTemplates) {
            await this.templateOptimizer.adjustTemplateWeight(
                templateInsight.templateId,
                templateInsight.strategyType,
                templateInsight.performanceScore
            );
        }
    }

    async updateLearningStrategies(insights) {
        if (insights.averageSuccessRate < 0.5) {
            await this.increaseExplorationRate();
        } else if (insights.averageSuccessRate > 0.8) {
            await this.focusOnExploitation();
        }
    }

    calculateAverageResponseTime(conversationData) {
        if (!conversationData.messages || conversationData.messages.length < 2) return 0;
        
        let totalTime = 0;
        let responseCount = 0;
        
        for (let i = 1; i < conversationData.messages.length; i++) {
            const timeDiff = new Date(conversationData.messages[i].created_at) - 
                           new Date(conversationData.messages[i-1].created_at);
            totalTime += timeDiff;
            responseCount++;
        }
        
        return responseCount > 0 ? Math.round(totalTime / responseCount / 1000 / 60) : 0; // minutes
    }

    shouldPerformLearningCycle() {
        return this.learningCycles % 10 === 0 || 
               (this.lastLearningUpdate && Date.now() - this.lastLearningUpdate > 24 * 60 * 60 * 1000);
    }

    updateCorrelation(existingCorr, newCorr, sampleSize) {
        return (existingCorr * sampleSize + newCorr) / (sampleSize + 1);
    }

    calculateConfidence(correlation, sampleSize) {
        return Math.min(0.99, correlation * Math.sqrt(sampleSize / 30));
    }

    calculateSuccessRate(data) {
        if (data.length === 0) return 0;
        return data.filter(d => d.success).length / data.length;
    }

    async findBestTemplates(data) {
        const templatePerformance = {};
        
        data.forEach(negotiation => {
            const key = `${negotiation.template_used}_${negotiation.strategy_type}`;
            if (!templatePerformance[key]) {
                templatePerformance[key] = {
                    templateId: negotiation.template_used,
                    strategyType: negotiation.strategy_type,
                    successes: 0,
                    total: 0,
                    totalSavings: 0
                };
            }
            
            templatePerformance[key].total++;
            if (negotiation.success) {
                templatePerformance[key].successes++;
                templatePerformance[key].totalSavings += negotiation.savings_achieved || 0;
            }
        });

        return Object.values(templatePerformance)
            .map(tp => ({
                ...tp,
                successRate: tp.successes / tp.total,
                averageSavings: tp.totalSavings / tp.successes || 0,
                performanceScore: (tp.successes / tp.total) * Math.log(tp.total + 1)
            }))
            .sort((a, b) => b.performanceScore - a.performanceScore)
            .slice(0, 5);
    }

    analyzeMarketTrends(data) {
        return {
            averageSavings: data.reduce((sum, d) => sum + (d.savings_achieved || 0), 0) / data.length,
            priceRanges: this.groupByPriceRange(data),
            seasonalPatterns: this.analyzeSeasonalData(data)
        };
    }

    analyzeLandlordPatterns(data) {
        const personalityGroups = data.reduce((groups, d) => {
            const personality = d.landlord_personality || 'unknown';
            if (!groups[personality]) groups[personality] = [];
            groups[personality].push(d);
            return groups;
        }, {});

        return Object.entries(personalityGroups).map(([personality, negotiations]) => ({
            personality,
            count: negotiations.length,
            successRate: negotiations.filter(n => n.success).length / negotiations.length,
            averageSavings: negotiations.reduce((sum, n) => sum + (n.savings_achieved || 0), 0) / negotiations.length
        }));
    }

    analyzeTimePatterns(data) {
        const hourGroups = data.reduce((groups, d) => {
            const hour = new Date(d.created_at).getHours();
            const timeSlot = this.getTimeSlot(hour);
            if (!groups[timeSlot]) groups[timeSlot] = [];
            groups[timeSlot].push(d);
            return groups;
        }, {});

        return Object.entries(hourGroups).map(([timeSlot, negotiations]) => ({
            timeSlot,
            count: negotiations.length,
            successRate: negotiations.filter(n => n.success).length / negotiations.length
        }));
    }

    groupByPriceRange(data) {
        const ranges = {
            'under_1000': data.filter(d => d.final_price < 1000),
            '1000_2000': data.filter(d => d.final_price >= 1000 && d.final_price < 2000),
            '2000_3000': data.filter(d => d.final_price >= 2000 && d.final_price < 3000),
            'over_3000': data.filter(d => d.final_price >= 3000)
        };

        return Object.entries(ranges).map(([range, negotiations]) => ({
            range,
            count: negotiations.length,
            successRate: negotiations.length > 0 ? negotiations.filter(n => n.success).length / negotiations.length : 0
        }));
    }

    analyzeSeasonalData(data) {
        const monthGroups = data.reduce((groups, d) => {
            const month = new Date(d.created_at).getMonth();
            if (!groups[month]) groups[month] = [];
            groups[month].push(d);
            return groups;
        }, {});

        return Object.entries(monthGroups).map(([month, negotiations]) => ({
            month: parseInt(month),
            count: negotiations.length,
            successRate: negotiations.filter(n => n.success).length / negotiations.length
        }));
    }

    getTimeSlot(hour) {
        if (hour >= 6 && hour < 12) return 'morning';
        if (hour >= 12 && hour < 18) return 'afternoon';
        if (hour >= 18 && hour < 22) return 'evening';
        return 'night';
    }

    async increaseExplorationRate() {
        // Implement exploration increase logic
    }

    async focusOnExploitation() {
        // Implement exploitation focus logic
    }
}

module.exports = LearningEngine;