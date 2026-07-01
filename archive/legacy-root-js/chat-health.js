// Chat health monitoring and diagnostics module
window.ChatHealthMonitor = (function() {
    let healthCheckInterval;
    let connectionStatus = 'unknown';
    let lastHealthCheck = null;
    let diagnosticsEnabled = false;
    let healthMetrics = {
        messagesSent: 0,
        messagesReceived: 0,
        connectionErrors: 0,
        lastError: null,
        uptime: Date.now()
    };

    // Initialize health monitoring
    function initialize() {
        diagnosticsEnabled = true;
        connectionStatus = 'initializing';
        
        setupHealthChecks();
        setupErrorHandlers();
        
        console.log('🔍 Chat health monitoring initialized');
    }

    // Setup periodic health checks
    function setupHealthChecks() {
        // Check connection health every 30 seconds
        healthCheckInterval = setInterval(() => {
            performHealthCheck();
        }, 30000);
        
        // Initial health check
        setTimeout(performHealthCheck, 1000);
    }

    // Perform health check
    async function performHealthCheck() {
        if (!diagnosticsEnabled) return;

        const startTime = Date.now();
        lastHealthCheck = new Date();

        try {
            // Check Supabase connection
            if (!window.AppConfig?.supabase) {
                setConnectionStatus('error', 'Supabase not initialized');
                return;
            }

            // Test database connectivity with a simple query
            const { data, error } = await window.AppConfig.supabase
                .from('conversations')
                .select('count')
                .limit(1);

            if (error) {
                throw new Error(`Database connection failed: ${error.message}`);
            }

            // Check realtime connection status
            const channels = window.AppConfig.supabase.getChannels();
            const hasActiveChannels = channels.length > 0;
            const allChannelsConnected = channels.every(channel => 
                channel.state === 'joined' || channel.state === 'joining'
            );

            if (hasActiveChannels && allChannelsConnected) {
                setConnectionStatus('healthy', 'All systems operational');
            } else if (hasActiveChannels) {
                setConnectionStatus('degraded', 'Some realtime channels disconnected');
            } else {
                setConnectionStatus('warning', 'No active realtime channels');
            }

            const responseTime = Date.now() - startTime;
            console.log(`💚 Chat health check passed (${responseTime}ms)`);

        } catch (error) {
            setConnectionStatus('error', error.message);
            healthMetrics.connectionErrors++;
            healthMetrics.lastError = {
                message: error.message,
                timestamp: new Date().toISOString()
            };
            
            console.error('❌ Chat health check failed:', error);
        }
    }

    // Set connection status
    function setConnectionStatus(status, message) {
        connectionStatus = status;
        
        // Update UI if status indicator exists
        updateStatusIndicator(status, message);
        
        // Log status changes
        if (status === 'error') {
            console.error('🔴 Chat Status:', status, '-', message);
        } else if (status === 'warning' || status === 'degraded') {
            console.warn('🟡 Chat Status:', status, '-', message);
        } else {
            console.log('🟢 Chat Status:', status, '-', message);
        }
    }

    // Update status indicator in UI
    function updateStatusIndicator(status, message) {
        // Look for existing status indicator
        let statusIndicator = document.getElementById('chatStatusIndicator');
        
        if (!statusIndicator) {
            // Create status indicator if it doesn't exist
            statusIndicator = document.createElement('div');
            statusIndicator.id = 'chatStatusIndicator';
            statusIndicator.className = 'fixed bottom-20 right-20 px-3 py-1 rounded-full text-xs font-medium z-40';
            statusIndicator.style.display = 'none'; // Hidden by default
            document.body.appendChild(statusIndicator);
        }

        // Update indicator based on status
        statusIndicator.className = 'fixed bottom-20 right-20 px-3 py-1 rounded-full text-xs font-medium z-40';
        
        switch (status) {
            case 'healthy':
                statusIndicator.classList.add('bg-green-100', 'text-green-800');
                statusIndicator.textContent = '● Chat Online';
                statusIndicator.style.display = 'none'; // Hide when healthy
                break;
            case 'warning':
            case 'degraded':
                statusIndicator.classList.add('bg-yellow-100', 'text-yellow-800');
                statusIndicator.textContent = '⚠ Chat Issues';
                statusIndicator.style.display = 'block';
                statusIndicator.title = message;
                break;
            case 'error':
                statusIndicator.classList.add('bg-red-100', 'text-red-800');
                statusIndicator.textContent = '● Chat Offline';
                statusIndicator.style.display = 'block';
                statusIndicator.title = message;
                break;
            default:
                statusIndicator.style.display = 'none';
        }
    }

    // Setup error handlers
    function setupErrorHandlers() {
        // Listen for Supabase connection errors
        if (window.AppConfig?.supabase) {
            window.AppConfig.supabase.auth.onAuthStateChange((event, session) => {
                if (event === 'SIGNED_OUT') {
                    setConnectionStatus('warning', 'User signed out - chat may be limited');
                } else if (event === 'SIGNED_IN') {
                    setConnectionStatus('healthy', 'User authenticated');
                }
            });
        }

        // Global error handler for chat-related errors
        window.addEventListener('error', (event) => {
            if (event.error && event.error.message.toLowerCase().includes('chat')) {
                recordError('Global chat error', event.error);
            }
        });

        // Unhandled promise rejections
        window.addEventListener('unhandledrejection', (event) => {
            if (event.reason && event.reason.toString().toLowerCase().includes('chat')) {
                recordError('Chat promise rejection', event.reason);
            }
        });
    }

    // Record error in metrics
    function recordError(type, error) {
        healthMetrics.connectionErrors++;
        healthMetrics.lastError = {
            type: type,
            message: error.toString(),
            timestamp: new Date().toISOString()
        };
        
        console.error(`🔍 Chat Error Recorded [${type}]:`, error);
    }

    // Record message sent
    function recordMessageSent() {
        if (diagnosticsEnabled) {
            healthMetrics.messagesSent++;
        }
    }

    // Record message received
    function recordMessageReceived() {
        if (diagnosticsEnabled) {
            healthMetrics.messagesReceived++;
        }
    }

    // Get current health status
    function getHealthStatus() {
        return {
            status: connectionStatus,
            lastCheck: lastHealthCheck,
            metrics: { ...healthMetrics },
            uptime: Date.now() - healthMetrics.uptime
        };
    }

    // Get detailed diagnostics
    function getDiagnostics() {
        const supabaseChannels = window.AppConfig?.supabase?.getChannels() || [];
        const chatManager = window.ChatManager;
        
        return {
            timestamp: new Date().toISOString(),
            connection: {
                status: connectionStatus,
                lastHealthCheck: lastHealthCheck,
                supabaseInitialized: !!window.AppConfig?.supabase,
                channelsActive: supabaseChannels.length,
                channelDetails: supabaseChannels.map(ch => ({
                    topic: ch.topic,
                    state: ch.state,
                    joinedAt: ch.joinedAt
                }))
            },
            chat: {
                managerInitialized: !!chatManager,
                activeConversations: chatManager?.activeConversations?.size || 0,
                unreadCounts: chatManager?.unreadCounts?.size || 0
            },
            metrics: { ...healthMetrics },
            performance: {
                uptime: Date.now() - healthMetrics.uptime,
                messagesPerMinute: calculateMessagesPerMinute()
            },
            browser: {
                userAgent: navigator.userAgent,
                online: navigator.onLine,
                cookieEnabled: navigator.cookieEnabled
            }
        };
    }

    // Calculate messages per minute
    function calculateMessagesPerMinute() {
        const uptimeMinutes = (Date.now() - healthMetrics.uptime) / (1000 * 60);
        const totalMessages = healthMetrics.messagesSent + healthMetrics.messagesReceived;
        return uptimeMinutes > 0 ? (totalMessages / uptimeMinutes).toFixed(2) : 0;
    }

    // Export diagnostics to console
    function exportDiagnostics() {
        const diagnostics = getDiagnostics();
        console.group('🔍 Chat Health Diagnostics');
        console.table({
            'Connection Status': diagnostics.connection.status,
            'Last Health Check': diagnostics.connection.lastHealthCheck,
            'Active Conversations': diagnostics.chat.activeConversations,
            'Messages Sent': diagnostics.metrics.messagesSent,
            'Messages Received': diagnostics.metrics.messagesReceived,
            'Connection Errors': diagnostics.metrics.connectionErrors,
            'Uptime (minutes)': Math.round(diagnostics.performance.uptime / (1000 * 60)),
            'Messages/min': diagnostics.performance.messagesPerMinute
        });
        
        if (diagnostics.metrics.lastError) {
            console.error('Last Error:', diagnostics.metrics.lastError);
        }
        
        if (diagnostics.connection.channelDetails.length > 0) {
            console.table(diagnostics.connection.channelDetails);
        }
        
        console.groupEnd();
        
        return diagnostics;
    }

    // Force health check
    function forceHealthCheck() {
        console.log('🔍 Forcing chat health check...');
        return performHealthCheck();
    }

    // Reset metrics
    function resetMetrics() {
        healthMetrics = {
            messagesSent: 0,
            messagesReceived: 0,
            connectionErrors: 0,
            lastError: null,
            uptime: Date.now()
        };
        console.log('🔄 Chat health metrics reset');
    }

    // Enable/disable diagnostics
    function setDiagnosticsEnabled(enabled) {
        diagnosticsEnabled = enabled;
        
        if (enabled) {
            console.log('🔍 Chat diagnostics enabled');
            if (!healthCheckInterval) {
                setupHealthChecks();
            }
        } else {
            console.log('🔍 Chat diagnostics disabled');
            if (healthCheckInterval) {
                clearInterval(healthCheckInterval);
                healthCheckInterval = null;
            }
        }
    }

    // Cleanup function
    function cleanup() {
        if (healthCheckInterval) {
            clearInterval(healthCheckInterval);
            healthCheckInterval = null;
        }
        
        const statusIndicator = document.getElementById('chatStatusIndicator');
        if (statusIndicator) {
            statusIndicator.remove();
        }
        
        diagnosticsEnabled = false;
        console.log('🔍 Chat health monitoring cleaned up');
    }

    // Public API
    return {
        initialize,
        getHealthStatus,
        getDiagnostics,
        exportDiagnostics,
        forceHealthCheck,
        resetMetrics,
        setDiagnosticsEnabled,
        recordMessageSent,
        recordMessageReceived,
        recordError,
        cleanup,
        get isEnabled() { return diagnosticsEnabled; },
        get connectionStatus() { return connectionStatus; }
    };
})();

// Global functions for console access
window.chatDiagnostics = function() {
    return window.ChatHealthMonitor?.exportDiagnostics();
};

window.chatHealth = function() {
    return window.ChatHealthMonitor?.getHealthStatus();
};