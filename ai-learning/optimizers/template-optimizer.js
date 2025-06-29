const DatabaseHelper = require('../utils/database-helper');

class TemplateOptimizer {
    constructor(supabaseClient = null) {
        this.db = new DatabaseHelper(supabaseClient);
        this.templateWeights = {};
        this.explorationRate = 0.2; // 20% exploration, 80% exploitation
        this.minSampleSize = 5; // Minimum samples before considering template performance
    }

    async initialize() {
        await this.loadTemplateWeights();
        await this.initializeDefaultWeights();
    }

    async loadTemplateWeights() {
        try {
            const performanceData = await this.db.getTemplatePerformance('all');
            
            this.templateWeights = {};
            performanceData.forEach(perf => {
                const key = `${perf.template_id}_${perf.strategy_type}`;
                const totalSamples = perf.success_count + perf.failure_count;
                
                if (totalSamples >= this.minSampleSize) {
                    this.templateWeights[key] = {
                        successRate: perf.success_count / totalSamples,
                        averageSavings: perf.avg_savings || 0,
                        sampleSize: totalSamples,
                        weight: this.calculateWeight(perf.success_count / totalSamples, totalSamples),
                        lastUpdated: perf.last_updated
                    };
                }
            });
        } catch (error) {
            console.error('Failed to load template weights:', error);
            this.templateWeights = {};
        }
    }

    async initializeDefaultWeights() {
        // Initialize equal weights for all templates if no data exists
        const strategies = [
            'counter_offer_acceptance',
            'strategic_counter_offers',
            'market_based_responses',
            'security_deposit',
            'move_in_logistics',
            'increase_request'
        ];

        strategies.forEach(strategy => {
            for (let templateId = 0; templateId < 8; templateId++) {
                const key = `${templateId}_${strategy}`;
                if (!this.templateWeights[key]) {
                    this.templateWeights[key] = {
                        successRate: 0.5, // Neutral starting point
                        averageSavings: 0,
                        sampleSize: 0,
                        weight: 1.0, // Equal starting weight
                        lastUpdated: new Date()
                    };
                }
            }
        });
    }

    async selectBestTemplate(context) {
        const { strategyType, marketConditions, landlordPersonality, priceRange } = context;
        
        // Get all templates for this strategy
        const candidateTemplates = this.getTemplatesForStrategy(strategyType);
        
        // Apply context-based filtering
        const contextFilteredTemplates = this.applyContextFiltering(
            candidateTemplates, 
            marketConditions, 
            landlordPersonality, 
            priceRange
        );

        // Select template using epsilon-greedy approach
        const selectedTemplate = this.epsilonGreedySelection(contextFilteredTemplates);
        
        return {
            templateId: selectedTemplate.id,
            strategyType: strategyType,
            confidence: selectedTemplate.weight,
            reason: selectedTemplate.reason,
            alternatives: contextFilteredTemplates.slice(0, 3) // Top 3 alternatives
        };
    }

    getTemplatesForStrategy(strategyType) {
        const templates = [];
        
        for (let templateId = 0; templateId < 8; templateId++) {
            const key = `${templateId}_${strategyType}`;
            const templateData = this.templateWeights[key];
            
            if (templateData) {
                templates.push({
                    id: templateId,
                    strategyType: strategyType,
                    weight: templateData.weight,
                    successRate: templateData.successRate,
                    averageSavings: templateData.averageSavings,
                    sampleSize: templateData.sampleSize,
                    lastUpdated: templateData.lastUpdated
                });
            }
        }
        
        return templates.sort((a, b) => b.weight - a.weight);
    }

    applyContextFiltering(templates, marketConditions, landlordPersonality, priceRange) {
        return templates.map(template => {
            let contextScore = 1.0;
            let reasons = [];

            // Adjust based on landlord personality
            contextScore *= this.getPersonalityMultiplier(template.id, landlordPersonality);
            if (landlordPersonality !== 'unknown') {
                reasons.push(`Optimized for ${landlordPersonality} landlords`);
            }

            // Adjust based on market conditions
            contextScore *= this.getMarketMultiplier(template.id, marketConditions);
            if (marketConditions.competitiveness !== 'medium') {
                reasons.push(`Adapted for ${marketConditions.competitiveness} competition market`);
            }

            // Adjust based on price range
            contextScore *= this.getPriceRangeMultiplier(template.id, priceRange);
            if (priceRange !== 'moderate') {
                reasons.push(`Tailored for ${priceRange} price range`);
            }

            return {
                ...template,
                contextScore: contextScore,
                adjustedWeight: template.weight * contextScore,
                reason: reasons.join(', ') || 'Standard optimization'
            };
        }).sort((a, b) => b.adjustedWeight - a.adjustedWeight);
    }

    epsilonGreedySelection(templates) {
        if (templates.length === 0) {
            return { id: 0, weight: 0.5, reason: 'Default fallback' };
        }

        // Exploration: randomly select template
        if (Math.random() < this.explorationRate) {
            const randomTemplate = templates[Math.floor(Math.random() * templates.length)];
            return {
                ...randomTemplate,
                reason: `Exploration: ${randomTemplate.reason}`
            };
        }

        // Exploitation: select best performing template
        return {
            ...templates[0],
            reason: `Best performer: ${templates[0].reason}`
        };
    }

    async updateTemplateWeights(templateId, strategyType, success, savings) {
        const key = `${templateId}_${strategyType}`;
        
        // Update database
        await this.db.updateTemplatePerformance(templateId, strategyType, success, savings);
        
        // Update local weights
        if (!this.templateWeights[key]) {
            this.templateWeights[key] = {
                successRate: success ? 1 : 0,
                averageSavings: savings || 0,
                sampleSize: 1,
                weight: success ? 1.2 : 0.8,
                lastUpdated: new Date()
            };
        } else {
            const current = this.templateWeights[key];
            const newSampleSize = current.sampleSize + 1;
            
            // Update success rate using incremental average
            current.successRate = (current.successRate * current.sampleSize + (success ? 1 : 0)) / newSampleSize;
            
            // Update average savings
            current.averageSavings = (current.averageSavings * current.sampleSize + (savings || 0)) / newSampleSize;
            
            // Update sample size
            current.sampleSize = newSampleSize;
            
            // Recalculate weight
            current.weight = this.calculateWeight(current.successRate, current.sampleSize);
            
            // Update timestamp
            current.lastUpdated = new Date();
        }
    }

    async adjustTemplateWeight(templateId, strategyType, performanceScore) {
        const key = `${templateId}_${strategyType}`;
        
        if (this.templateWeights[key]) {
            // Gradually adjust weight based on performance
            const currentWeight = this.templateWeights[key].weight;
            const targetWeight = Math.max(0.1, Math.min(2.0, performanceScore));
            
            // Use exponential moving average for smooth transitions
            const alpha = 0.1; // Learning rate
            this.templateWeights[key].weight = currentWeight * (1 - alpha) + targetWeight * alpha;
            this.templateWeights[key].lastUpdated = new Date();
        }
    }

    calculateWeight(successRate, sampleSize) {
        // Wilson Score Interval for better handling of small sample sizes
        if (sampleSize === 0) return 0.5;
        
        const z = 1.96; // 95% confidence interval
        const p = successRate;
        const n = sampleSize;
        
        const numerator = p + (z * z) / (2 * n) - z * Math.sqrt((p * (1 - p)) / n + (z * z) / (4 * n * n));
        const denominator = 1 + (z * z) / n;
        
        const lowerBound = numerator / denominator;
        
        // Scale to 0.1 - 2.0 range for template selection
        return Math.max(0.1, Math.min(2.0, lowerBound * 2));
    }

    getPersonalityMultiplier(templateId, personality) {
        // Template-specific personality adjustments
        const personalityMultipliers = {
            'cooperative': {
                0: 1.2, 1: 1.1, 2: 1.0, 3: 0.9, 4: 1.1, 5: 1.0, 6: 1.2, 7: 1.1
            },
            'aggressive': {
                0: 0.8, 1: 1.2, 2: 1.3, 3: 1.1, 4: 0.9, 5: 1.2, 6: 0.8, 7: 1.0
            },
            'professional': {
                0: 1.0, 1: 1.1, 2: 1.2, 3: 1.3, 4: 1.2, 5: 1.1, 6: 1.0, 7: 1.1
            },
            'neutral': {
                0: 1.0, 1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0
            }
        };

        return personalityMultipliers[personality]?.[templateId] || 1.0;
    }

    getMarketMultiplier(templateId, marketConditions) {
        let multiplier = 1.0;

        // Adjust based on competitiveness
        if (marketConditions.competitiveness === 'high') {
            // More aggressive templates work better in competitive markets
            const aggressiveTemplates = [1, 2, 5]; // Templates known to be more assertive
            if (aggressiveTemplates.includes(templateId)) {
                multiplier *= 1.2;
            } else {
                multiplier *= 0.9;
            }
        } else if (marketConditions.competitiveness === 'low') {
            // Gentler approaches work better in less competitive markets
            const gentleTemplates = [0, 3, 6, 7]; // Templates known to be more cooperative
            if (gentleTemplates.includes(templateId)) {
                multiplier *= 1.2;
            } else {
                multiplier *= 0.9;
            }
        }

        // Adjust based on market trend
        if (marketConditions.marketTrend === 'rising') {
            // Quick action templates work better in rising markets
            const quickActionTemplates = [0, 4]; // Templates that encourage quick decisions
            if (quickActionTemplates.includes(templateId)) {
                multiplier *= 1.1;
            }
        }

        return multiplier;
    }

    getPriceRangeMultiplier(templateId, priceRange) {
        const priceRangeMultipliers = {
            'budget': {
                0: 1.1, 1: 1.2, 2: 0.9, 3: 1.1, 4: 1.0, 5: 0.8, 6: 1.1, 7: 1.0
            },
            'moderate': {
                0: 1.0, 1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0
            },
            'premium': {
                0: 0.9, 1: 0.9, 2: 1.2, 3: 1.1, 4: 1.1, 5: 1.2, 6: 0.9, 7: 1.0
            },
            'luxury': {
                0: 0.8, 1: 0.8, 2: 1.3, 3: 1.2, 4: 1.1, 5: 1.3, 6: 0.8, 7: 0.9
            }
        };

        return priceRangeMultipliers[priceRange]?.[templateId] || 1.0;
    }

    async getTemplatePerformanceReport() {
        const report = {
            totalTemplates: Object.keys(this.templateWeights).length,
            bestPerformers: [],
            worstPerformers: [],
            strategies: {},
            recentUpdates: []
        };

        // Convert weights to array for analysis
        const templateArray = Object.entries(this.templateWeights).map(([key, data]) => {
            const [templateId, strategyType] = key.split('_');
            return {
                templateId: parseInt(templateId),
                strategyType: strategyType,
                key: key,
                ...data
            };
        });

        // Sort by performance
        const sortedByPerformance = templateArray.sort((a, b) => b.weight - a.weight);
        
        report.bestPerformers = sortedByPerformance.slice(0, 5);
        report.worstPerformers = sortedByPerformance.slice(-5).reverse();

        // Group by strategy
        templateArray.forEach(template => {
            if (!report.strategies[template.strategyType]) {
                report.strategies[template.strategyType] = {
                    templates: [],
                    averageSuccessRate: 0,
                    totalSamples: 0
                };
            }
            report.strategies[template.strategyType].templates.push(template);
        });

        // Calculate strategy averages
        Object.keys(report.strategies).forEach(strategy => {
            const templates = report.strategies[strategy].templates;
            const totalSamples = templates.reduce((sum, t) => sum + t.sampleSize, 0);
            const weightedSuccessRate = templates.reduce((sum, t) => sum + (t.successRate * t.sampleSize), 0);
            
            report.strategies[strategy].averageSuccessRate = totalSamples > 0 ? weightedSuccessRate / totalSamples : 0;
            report.strategies[strategy].totalSamples = totalSamples;
        });

        // Recent updates
        report.recentUpdates = templateArray
            .filter(t => t.lastUpdated && new Date() - new Date(t.lastUpdated) < 24 * 60 * 60 * 1000)
            .sort((a, b) => new Date(b.lastUpdated) - new Date(a.lastUpdated))
            .slice(0, 10);

        return report;
    }

    async optimizeExplorationRate() {
        // Dynamically adjust exploration rate based on recent performance
        const recentPerformance = await this.getRecentPerformanceMetrics();
        
        if (recentPerformance.successRate < 0.6) {
            // Increase exploration if performance is poor
            this.explorationRate = Math.min(0.4, this.explorationRate + 0.05);
        } else if (recentPerformance.successRate > 0.8) {
            // Decrease exploration if performance is good
            this.explorationRate = Math.max(0.1, this.explorationRate - 0.02);
        }
        
        return this.explorationRate;
    }

    async getRecentPerformanceMetrics() {
        // This would query recent performance data
        // For now, return a placeholder
        return {
            successRate: 0.7,
            sampleSize: 50,
            timeframe: '7 days'
        };
    }
}

module.exports = TemplateOptimizer;