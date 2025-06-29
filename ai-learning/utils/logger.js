class LearningLogger {
    constructor() {
        this.logLevel = process.env.LEARNING_LOG_LEVEL || 'info';
        this.enableConsoleLogging = true;
        this.enableFileLogging = false; // Could be enhanced to write to files
    }

    log(level, message, data = null) {
        const timestamp = new Date().toISOString();
        const logEntry = {
            timestamp,
            level,
            message,
            data
        };

        if (this.shouldLog(level)) {
            if (this.enableConsoleLogging) {
                this.logToConsole(logEntry);
            }
            
            if (this.enableFileLogging) {
                this.logToFile(logEntry);
            }
        }
    }

    info(message, data = null) {
        this.log('info', message, data);
    }

    warn(message, data = null) {
        this.log('warn', message, data);
    }

    error(message, data = null) {
        this.log('error', message, data);
    }

    debug(message, data = null) {
        this.log('debug', message, data);
    }

    success(message, data = null) {
        this.log('success', message, data);
    }

    learning(message, data = null) {
        this.log('learning', message, data);
    }

    shouldLog(level) {
        const levels = ['debug', 'info', 'warn', 'error', 'success', 'learning'];
        const configuredLevel = levels.indexOf(this.logLevel);
        const messageLevel = levels.indexOf(level);
        
        return messageLevel >= configuredLevel;
    }

    logToConsole(logEntry) {
        const { timestamp, level, message, data } = logEntry;
        const emoji = this.getLevelEmoji(level);
        const color = this.getLevelColor(level);
        
        let output = `${emoji} [${timestamp}] ${level.toUpperCase()}: ${message}`;
        
        if (data) {
            output += `\nData: ${JSON.stringify(data, null, 2)}`;
        }
        
        // Color output based on level
        if (typeof console[level] === 'function') {
            console[level](output);
        } else {
            console.log(output);
        }
    }

    logToFile(logEntry) {
        // File logging implementation
        // Could be enhanced to write to actual log files
        // For now, just a placeholder
    }

    getLevelEmoji(level) {
        const emojis = {
            debug: '🔍',
            info: 'ℹ️',
            warn: '⚠️',
            error: '❌',
            success: '✅',
            learning: '🧠'
        };
        
        return emojis[level] || 'ℹ️';
    }

    getLevelColor(level) {
        const colors = {
            debug: '\x1b[36m', // cyan
            info: '\x1b[37m',  // white
            warn: '\x1b[33m',  // yellow
            error: '\x1b[31m', // red
            success: '\x1b[32m', // green
            learning: '\x1b[35m' // magenta
        };
        
        return colors[level] || '\x1b[37m';
    }

    // Performance logging methods
    startTimer(label) {
        const startTime = process.hrtime();
        return {
            label,
            startTime,
            end: () => {
                const diff = process.hrtime(startTime);
                const milliseconds = diff[0] * 1000 + diff[1] * 1e-6;
                this.info(`Timer ${label}: ${milliseconds.toFixed(2)}ms`);
                return milliseconds;
            }
        };
    }

    logPerformanceMetrics(metrics) {
        this.learning('Performance Metrics', {
            successRate: `${(metrics.successRate * 100).toFixed(1)}%`,
            totalNegotiations: metrics.totalNegotiations,
            averageSavings: `$${metrics.averageSavings?.toFixed(2) || 0}`,
            bestTemplate: metrics.bestTemplate,
            learningCycles: metrics.learningCycles
        });
    }

    logTemplateSelection(templateId, strategy, reason, confidence) {
        this.learning('Template Selection', {
            templateId,
            strategy,
            reason,
            confidence: `${(confidence * 100).toFixed(1)}%`
        });
    }

    logNegotiationOutcome(conversationId, success, finalPrice, savings, strategy) {
        const level = success ? 'success' : 'warn';
        this.log(level, 'Negotiation Outcome', {
            conversationId,
            success,
            finalPrice: `$${finalPrice}`,
            savings: `$${savings}`,
            strategy
        });
    }

    logLearningUpdate(insights) {
        this.learning('Learning Update', {
            patternsLearned: insights.patternsLearned,
            templatesOptimized: insights.templatesOptimized,
            performanceImprovement: insights.performanceImprovement
        });
    }

    logError(operation, error, context = null) {
        this.error(`${operation} Failed`, {
            error: error.message,
            stack: error.stack,
            context
        });
    }

    // Analytics logging
    logAnalytics(event, data) {
        this.info(`Analytics: ${event}`, data);
    }

    logExperiment(experimentName, variant, outcome) {
        this.learning('A/B Test Result', {
            experiment: experimentName,
            variant,
            outcome
        });
    }

    // Configuration methods
    setLogLevel(level) {
        this.logLevel = level;
        this.info(`Log level set to: ${level}`);
    }

    enableFileLogging(enabled) {
        this.enableFileLogging = enabled;
        this.info(`File logging ${enabled ? 'enabled' : 'disabled'}`);
    }

    enableConsoleLogging(enabled) {
        this.enableConsoleLogging = enabled;
        if (enabled) {
            this.info('Console logging enabled');
        }
    }

    // Summary methods
    logDailySummary(summary) {
        this.success('Daily Learning Summary', {
            date: new Date().toDateString(),
            totalNegotiations: summary.totalNegotiations,
            successRate: `${(summary.successRate * 100).toFixed(1)}%`,
            totalSavings: `$${summary.totalSavings.toFixed(2)}`,
            newPatternsLearned: summary.newPatterns,
            topPerformingTemplate: summary.topTemplate,
            improvementSuggestions: summary.suggestions
        });
    }

    logWeeklySummary(summary) {
        this.success('Weekly Learning Summary', {
            week: summary.weekRange,
            performanceImprovement: `${(summary.improvement * 100).toFixed(1)}%`,
            bestStrategies: summary.bestStrategies,
            areasForImprovement: summary.improvements,
            recommendedActions: summary.actions
        });
    }
}

// Create singleton instance
const logger = new LearningLogger();

module.exports = logger;