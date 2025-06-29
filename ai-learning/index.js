const LearningEngine = require('./core/learning-engine');
const TemplateOptimizer = require('./optimizers/template-optimizer');
const PatternAnalyzer = require('./core/pattern-analyzer');
const SuccessTracker = require('./analyzers/success-tracker');

class AILearningSystem {
    constructor(supabaseClient = null) {
        this.learningEngine = new LearningEngine(supabaseClient);
        this.templateOptimizer = new TemplateOptimizer(supabaseClient);
        this.patternAnalyzer = new PatternAnalyzer();
        this.successTracker = new SuccessTracker(supabaseClient);
        
        this.initialized = false;
    }

    async initialize() {
        if (this.initialized) return;
        
        await this.learningEngine.initialize();
        await this.templateOptimizer.initialize();
        await this.patternAnalyzer.initialize();
        await this.successTracker.initialize();
        
        this.initialized = true;
    }

    async processConversation(conversationData) {
        await this.initialize();
        
        const analysis = await this.patternAnalyzer.analyzeConversation(conversationData);
        
        await this.successTracker.recordOutcome(conversationData, analysis);
        
        if (analysis.success) {
            await this.learningEngine.learnFromSuccess(conversationData, analysis);
        }
        
        return analysis;
    }

    async getOptimalTemplate(context) {
        await this.initialize();
        return this.templateOptimizer.selectBestTemplate(context);
    }

    async updateLearning() {
        await this.initialize();
        return this.learningEngine.performLearningCycle();
    }

    async getPerformanceMetrics() {
        await this.initialize();
        return this.successTracker.getMetrics();
    }
}

module.exports = AILearningSystem;