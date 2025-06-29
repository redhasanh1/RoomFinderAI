class StatisticsHelper {
    // Basic statistical functions
    static mean(numbers) {
        if (numbers.length === 0) return 0;
        return numbers.reduce((sum, num) => sum + num, 0) / numbers.length;
    }

    static median(numbers) {
        if (numbers.length === 0) return 0;
        const sorted = [...numbers].sort((a, b) => a - b);
        const mid = Math.floor(sorted.length / 2);
        return sorted.length % 2 === 0 
            ? (sorted[mid - 1] + sorted[mid]) / 2
            : sorted[mid];
    }

    static standardDeviation(numbers) {
        const avg = this.mean(numbers);
        const squaredDiffs = numbers.map(num => Math.pow(num - avg, 2));
        const variance = this.mean(squaredDiffs);
        return Math.sqrt(variance);
    }

    static variance(numbers) {
        const avg = this.mean(numbers);
        const squaredDiffs = numbers.map(num => Math.pow(num - avg, 2));
        return this.mean(squaredDiffs);
    }

    // Confidence intervals
    static confidenceInterval(numbers, confidence = 0.95) {
        const n = numbers.length;
        if (n < 2) return { lower: 0, upper: 0, margin: 0 };

        const mean = this.mean(numbers);
        const stdDev = this.standardDeviation(numbers);
        const stdError = stdDev / Math.sqrt(n);
        
        // Use t-distribution for small samples
        const tValue = this.getTValue(confidence, n - 1);
        const margin = tValue * stdError;
        
        return {
            lower: mean - margin,
            upper: mean + margin,
            margin: margin
        };
    }

    static getTValue(confidence, degreesOfFreedom) {
        // Simplified t-value lookup for common confidence levels
        const tTable = {
            0.90: { 1: 6.314, 5: 2.015, 10: 1.812, 20: 1.725, 30: 1.697, Infinity: 1.645 },
            0.95: { 1: 12.706, 5: 2.571, 10: 2.228, 20: 2.086, 30: 2.042, Infinity: 1.960 },
            0.99: { 1: 63.657, 5: 4.032, 10: 3.169, 20: 2.845, 30: 2.750, Infinity: 2.576 }
        };
        
        const table = tTable[confidence] || tTable[0.95];
        
        // Find closest degrees of freedom
        const dfs = Object.keys(table).map(Number).sort((a, b) => a - b);
        let closestDf = dfs.find(df => df >= degreesOfFreedom) || Infinity;
        
        return table[closestDf];
    }

    // A/B Testing
    static tTest(groupA, groupB) {
        const n1 = groupA.length;
        const n2 = groupB.length;
        
        if (n1 < 2 || n2 < 2) {
            return { significant: false, pValue: 1, confidence: 0 };
        }

        const mean1 = this.mean(groupA);
        const mean2 = this.mean(groupB);
        const var1 = this.variance(groupA);
        const var2 = this.variance(groupB);
        
        // Pooled variance for equal variance assumption
        const pooledVariance = ((n1 - 1) * var1 + (n2 - 1) * var2) / (n1 + n2 - 2);
        const standardError = Math.sqrt(pooledVariance * (1/n1 + 1/n2));
        
        const tStatistic = (mean1 - mean2) / standardError;
        const degreesOfFreedom = n1 + n2 - 2;
        
        // Simplified p-value calculation
        const pValue = this.calculatePValue(Math.abs(tStatistic), degreesOfFreedom);
        
        return {
            tStatistic: tStatistic,
            pValue: pValue,
            significant: pValue < 0.05,
            confidence: (1 - pValue) * 100,
            effect: mean1 - mean2,
            effectSize: (mean1 - mean2) / Math.sqrt(pooledVariance)
        };
    }

    static calculatePValue(tStat, df) {
        // Simplified p-value approximation
        // In production, you'd use a proper statistical library
        if (df >= 30) {
            // Use normal approximation for large samples
            return 2 * (1 - this.normalCDF(tStat));
        }
        
        // Rough approximation for small samples
        const criticalValues = {
            1: [12.706, 63.657],
            5: [2.571, 4.032],
            10: [2.228, 3.169],
            20: [2.086, 2.845],
            30: [2.042, 2.750]
        };
        
        const closest = Object.keys(criticalValues)
            .map(Number)
            .reduce((prev, curr) => 
                Math.abs(curr - df) < Math.abs(prev - df) ? curr : prev
            );
        
        const [critical05, critical01] = criticalValues[closest];
        
        if (tStat >= critical01) return 0.01;
        if (tStat >= critical05) return 0.05;
        if (tStat >= critical05 * 0.8) return 0.1;
        return 0.2;
    }

    static normalCDF(x) {
        // Approximation of normal cumulative distribution function
        return 0.5 * (1 + this.erf(x / Math.sqrt(2)));
    }

    static erf(x) {
        // Approximation of error function
        const a1 =  0.254829592;
        const a2 = -0.284496736;
        const a3 =  1.421413741;
        const a4 = -1.453152027;
        const a5 =  1.061405429;
        const p  =  0.3275911;

        const sign = x >= 0 ? 1 : -1;
        x = Math.abs(x);

        const t = 1.0 / (1.0 + p * x);
        const y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * Math.exp(-x * x);

        return sign * y;
    }

    // Success rate analysis
    static calculateSuccessRate(successes, total) {
        if (total === 0) return 0;
        return successes / total;
    }

    static successRateConfidence(successes, total, confidence = 0.95) {
        if (total === 0) return { lower: 0, upper: 0, margin: 0 };
        
        const p = successes / total;
        const z = this.getZValue(confidence);
        const margin = z * Math.sqrt((p * (1 - p)) / total);
        
        return {
            lower: Math.max(0, p - margin),
            upper: Math.min(1, p + margin),
            margin: margin
        };
    }

    static getZValue(confidence) {
        const zValues = {
            0.90: 1.645,
            0.95: 1.960,
            0.99: 2.576
        };
        return zValues[confidence] || 1.960;
    }

    // Template performance analysis
    static analyzeTemplatePerformance(templateData) {
        const results = templateData.map(template => {
            const total = template.successes + template.failures;
            const successRate = this.calculateSuccessRate(template.successes, total);
            const confidence = this.successRateConfidence(template.successes, total);
            
            return {
                templateId: template.templateId,
                successRate: successRate,
                sampleSize: total,
                confidence: confidence,
                significance: total >= 30 ? 'high' : total >= 10 ? 'medium' : 'low'
            };
        });
        
        return results.sort((a, b) => b.successRate - a.successRate);
    }

    // Correlation analysis
    static correlation(x, y) {
        if (x.length !== y.length || x.length === 0) return 0;
        
        const meanX = this.mean(x);
        const meanY = this.mean(y);
        
        let numerator = 0;
        let denomX = 0;
        let denomY = 0;
        
        for (let i = 0; i < x.length; i++) {
            const deltaX = x[i] - meanX;
            const deltaY = y[i] - meanY;
            
            numerator += deltaX * deltaY;
            denomX += deltaX * deltaX;
            denomY += deltaY * deltaY;
        }
        
        const denominator = Math.sqrt(denomX * denomY);
        return denominator === 0 ? 0 : numerator / denominator;
    }

    // Trend analysis
    static linearRegression(x, y) {
        if (x.length !== y.length || x.length < 2) {
            return { slope: 0, intercept: 0, rSquared: 0 };
        }
        
        const n = x.length;
        const sumX = x.reduce((sum, val) => sum + val, 0);
        const sumY = y.reduce((sum, val) => sum + val, 0);
        const sumXY = x.reduce((sum, val, i) => sum + val * y[i], 0);
        const sumXX = x.reduce((sum, val) => sum + val * val, 0);
        const sumYY = y.reduce((sum, val) => sum + val * val, 0);
        
        const slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
        const intercept = (sumY - slope * sumX) / n;
        
        // Calculate R-squared
        const meanY = sumY / n;
        const totalSumSquares = y.reduce((sum, val) => sum + Math.pow(val - meanY, 2), 0);
        const residualSumSquares = y.reduce((sum, val, i) => {
            const predicted = slope * x[i] + intercept;
            return sum + Math.pow(val - predicted, 2);
        }, 0);
        
        const rSquared = totalSumSquares === 0 ? 0 : 1 - (residualSumSquares / totalSumSquares);
        
        return { slope, intercept, rSquared };
    }

    // Performance metrics
    static calculatePerformanceMetrics(data) {
        const successCount = data.filter(d => d.success).length;
        const totalCount = data.length;
        const successRate = this.calculateSuccessRate(successCount, totalCount);
        
        const savings = data.filter(d => d.success).map(d => d.savings || 0);
        const averageSavings = this.mean(savings);
        
        const responseTimes = data.map(d => d.responseTime || 0).filter(t => t > 0);
        const averageResponseTime = this.mean(responseTimes);
        
        return {
            successRate,
            successCount,
            totalCount,
            averageSavings,
            averageResponseTime,
            confidence: this.successRateConfidence(successCount, totalCount),
            trend: this.calculateTrend(data)
        };
    }

    static calculateTrend(data) {
        if (data.length < 5) return 'insufficient_data';
        
        const recent = data.slice(-10);
        const older = data.slice(-20, -10);
        
        if (older.length === 0) return 'insufficient_data';
        
        const recentSuccess = this.calculateSuccessRate(
            recent.filter(d => d.success).length, 
            recent.length
        );
        const olderSuccess = this.calculateSuccessRate(
            older.filter(d => d.success).length, 
            older.length
        );
        
        const difference = recentSuccess - olderSuccess;
        
        if (Math.abs(difference) < 0.05) return 'stable';
        return difference > 0 ? 'improving' : 'declining';
    }

    // Statistical significance testing for A/B tests
    static abTestSignificance(controlGroup, testGroup, alpha = 0.05) {
        const controlSuccess = controlGroup.filter(d => d.success).length;
        const testSuccess = testGroup.filter(d => d.success).length;
        
        const controlTotal = controlGroup.length;
        const testTotal = testGroup.length;
        
        if (controlTotal < 10 || testTotal < 10) {
            return {
                significant: false,
                reason: 'insufficient_sample_size',
                minSampleSize: 10
            };
        }
        
        const p1 = controlSuccess / controlTotal;
        const p2 = testSuccess / testTotal;
        
        const pooledP = (controlSuccess + testSuccess) / (controlTotal + testTotal);
        const se = Math.sqrt(pooledP * (1 - pooledP) * (1/controlTotal + 1/testTotal));
        
        const zScore = (p2 - p1) / se;
        const pValue = 2 * (1 - this.normalCDF(Math.abs(zScore)));
        
        return {
            significant: pValue < alpha,
            pValue: pValue,
            zScore: zScore,
            effect: p2 - p1,
            effectSize: (p2 - p1) / Math.sqrt(pooledP * (1 - pooledP)),
            controlRate: p1,
            testRate: p2,
            improvement: ((p2 - p1) / p1) * 100
        };
    }
}

module.exports = StatisticsHelper;