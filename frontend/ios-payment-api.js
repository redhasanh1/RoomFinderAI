/**
 * iOS-Compatible Payment API for RoomFinderAI
 * 
 * This module provides iOS-compatible payment functionality that replaces all
 * payment API calls with @capacitor/http for reliable iOS networking.
 */

import { fetch } from './ios-universal-fetch.js';
import { createClient } from './ios-supabase-client.js';
import iosAuthManager from './ios-auth-manager.js';

// API Configuration
const STRIPE_API_URL = 'https://api.stripe.com/v1';
const PAYPAL_API_URL = 'https://api.paypal.com/v1';
const BACKEND_API_URL = 'https://roomfinder-ai-negotiator-production.up.railway.app/api';

class IOSPaymentAPI {
    constructor() {
        this.supabase = createClient(
            'https://zmxyysauqtfkvntgtjsm.supabase.co',
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpteHl5c2F1cXRma3ZudGd0anNtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY5NTc3OTQsImV4cCI6MjA1MjUzMzc5NH0.F6M7G-fxnRDnKzWAWgO4y0Z7IuKIDaecvSUBz8aVeQM'
        );
        this.debug = true;
        this.stripePublishableKey = null;
        this.paypalClientId = null;
        
        if (this.debug) {
            console.log('💳 iOS Payment API initialized');
        }
    }

    /**
     * Set Stripe publishable key
     */
    setStripeKey(publishableKey) {
        this.stripePublishableKey = publishableKey;
        if (this.debug) {
            console.log('🔑 Stripe publishable key set');
        }
    }

    /**
     * Set PayPal client ID
     */
    setPayPalClientId(clientId) {
        this.paypalClientId = clientId;
        if (this.debug) {
            console.log('🔑 PayPal client ID set');
        }
    }

    /**
     * Get payment configuration from backend
     */
    async getPaymentConfig() {
        try {
            if (this.debug) {
                console.log('⚙️ Getting payment configuration');
            }

            const response = await fetch(`${BACKEND_API_URL}/config`, {
                method: 'GET',
                headers: {
                    'Content-Type': 'application/json'
                }
            });

            if (!response.ok) {
                throw new Error(`Failed to get payment config: ${response.statusText}`);
            }

            const config = await response.json();

            // Set keys from config
            if (config.stripe_publishable_key) {
                this.setStripeKey(config.stripe_publishable_key);
            }
            if (config.paypal_client_id) {
                this.setPayPalClientId(config.paypal_client_id);
            }

            if (this.debug) {
                console.log('✅ Payment configuration retrieved');
            }

            return { data: config, error: null };
        } catch (error) {
            console.error('❌ Get payment config error:', error);
            return { data: null, error };
        }
    }

    /**
     * Process payment using backend
     */
    async processPayment(paymentData) {
        try {
            const currentUser = iosAuthManager.getCurrentUser();
            if (!currentUser) {
                throw new Error('User must be authenticated to process payments');
            }

            if (this.debug) {
                console.log('💳 Processing payment:', paymentData.plan);
            }

            const response = await fetch(`${BACKEND_API_URL}/process-payment`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${currentUser.access_token || ''}`
                },
                body: JSON.stringify({
                    ...paymentData,
                    user_email: currentUser.email
                })
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(`Payment processing failed: ${errorData.error || response.statusText}`);
            }

            const result = await response.json();

            if (this.debug) {
                console.log('✅ Payment processed successfully');
            }

            return { data: result, error: null };
        } catch (error) {
            console.error('❌ Process payment error:', error);
            return { data: null, error };
        }
    }

    /**
     * Create Stripe payment intent
     */
    async createStripePaymentIntent(amount, currency = 'usd', metadata = {}) {
        try {
            if (this.debug) {
                console.log('💳 Creating Stripe payment intent for amount:', amount);
            }

            const response = await fetch(`${BACKEND_API_URL}/create-payment-intent`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    amount: amount * 100, // Convert to cents
                    currency,
                    metadata
                })
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(`Failed to create payment intent: ${errorData.error || response.statusText}`);
            }

            const result = await response.json();

            if (this.debug) {
                console.log('✅ Stripe payment intent created');
            }

            return { data: result, error: null };
        } catch (error) {
            console.error('❌ Create payment intent error:', error);
            return { data: null, error };
        }
    }

    /**
     * Confirm Stripe payment
     */
    async confirmStripePayment(paymentIntentId, paymentMethod) {
        try {
            if (this.debug) {
                console.log('💳 Confirming Stripe payment:', paymentIntentId);
            }

            const response = await fetch(`${BACKEND_API_URL}/confirm-payment`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    payment_intent_id: paymentIntentId,
                    payment_method: paymentMethod
                })
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(`Payment confirmation failed: ${errorData.error || response.statusText}`);
            }

            const result = await response.json();

            if (this.debug) {
                console.log('✅ Stripe payment confirmed');
            }

            return { data: result, error: null };
        } catch (error) {
            console.error('❌ Confirm payment error:', error);
            return { data: null, error };
        }
    }

    /**
     * Create subscription
     */
    async createSubscription(planId, customerData) {
        try {
            const currentUser = iosAuthManager.getCurrentUser();
            if (!currentUser) {
                throw new Error('User must be authenticated to create subscriptions');
            }

            if (this.debug) {
                console.log('📋 Creating subscription for plan:', planId);
            }

            const response = await fetch(`${BACKEND_API_URL}/create-subscription`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${currentUser.access_token || ''}`
                },
                body: JSON.stringify({
                    plan_id: planId,
                    customer_data: {
                        ...customerData,
                        email: currentUser.email
                    }
                })
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(`Subscription creation failed: ${errorData.error || response.statusText}`);
            }

            const result = await response.json();

            // Update user profile with subscription info
            await this.updateUserSubscription(result.subscription);

            if (this.debug) {
                console.log('✅ Subscription created successfully');
            }

            return { data: result, error: null };
        } catch (error) {
            console.error('❌ Create subscription error:', error);
            return { data: null, error };
        }
    }

    /**
     * Cancel subscription
     */
    async cancelSubscription(subscriptionId) {
        try {
            const currentUser = iosAuthManager.getCurrentUser();
            if (!currentUser) {
                throw new Error('User must be authenticated to cancel subscriptions');
            }

            if (this.debug) {
                console.log('❌ Canceling subscription:', subscriptionId);
            }

            const response = await fetch(`${BACKEND_API_URL}/cancel-subscription`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${currentUser.access_token || ''}`
                },
                body: JSON.stringify({
                    subscription_id: subscriptionId
                })
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(`Subscription cancellation failed: ${errorData.error || response.statusText}`);
            }

            const result = await response.json();

            // Update user profile
            await this.updateUserSubscription(null);

            if (this.debug) {
                console.log('✅ Subscription canceled successfully');
            }

            return { data: result, error: null };
        } catch (error) {
            console.error('❌ Cancel subscription error:', error);
            return { data: null, error };
        }
    }

    /**
     * Get user's subscription status
     */
    async getSubscriptionStatus() {
        try {
            const currentUser = iosAuthManager.getCurrentUser();
            if (!currentUser) {
                throw new Error('User must be authenticated to get subscription status');
            }

            if (this.debug) {
                console.log('📋 Getting subscription status');
            }

            const profile = await this.supabase
                .from('profiles')
                .select('*')
                .eq('email', currentUser.email)
                .single()
                .exec();

            if (!profile) {
                return { data: { status: 'none', type: 'free' }, error: null };
            }

            const subscriptionData = {
                status: profile.subscription_status || 'none',
                type: profile.subscription_type || 'free',
                plan_id: profile.plan_id || null,
                expires_at: profile.subscription_expires_at || null,
                created_at: profile.subscription_created_at || null
            };

            if (this.debug) {
                console.log('✅ Retrieved subscription status:', subscriptionData.type);
            }

            return { data: subscriptionData, error: null };
        } catch (error) {
            console.error('❌ Get subscription status error:', error);
            return { data: null, error };
        }
    }

    /**
     * Update user subscription in database
     */
    async updateUserSubscription(subscriptionData) {
        try {
            const currentUser = iosAuthManager.getCurrentUser();
            if (!currentUser) {
                throw new Error('User must be authenticated to update subscription');
            }

            const updates = subscriptionData ? {
                subscription_status: subscriptionData.status,
                subscription_type: subscriptionData.type,
                plan_id: subscriptionData.plan_id,
                subscription_expires_at: subscriptionData.expires_at,
                subscription_created_at: subscriptionData.created_at,
                updated_at: new Date().toISOString()
            } : {
                subscription_status: 'canceled',
                subscription_type: 'free',
                plan_id: null,
                subscription_expires_at: null,
                updated_at: new Date().toISOString()
            };

            const { error } = await this.supabase
                .from('profiles')
                .update(updates)
                .eq('email', currentUser.email);

            if (error) {
                throw error;
            }

            if (this.debug) {
                console.log('✅ User subscription updated in database');
            }

            return { error: null };
        } catch (error) {
            console.error('❌ Update user subscription error:', error);
            return { error };
        }
    }

    /**
     * Get payment history
     */
    async getPaymentHistory() {
        try {
            const currentUser = iosAuthManager.getCurrentUser();
            if (!currentUser) {
                throw new Error('User must be authenticated to get payment history');
            }

            if (this.debug) {
                console.log('📋 Getting payment history');
            }

            const response = await fetch(`${BACKEND_API_URL}/payment-history`, {
                method: 'GET',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${currentUser.access_token || ''}`
                }
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(`Failed to get payment history: ${errorData.error || response.statusText}`);
            }

            const history = await response.json();

            if (this.debug) {
                console.log(`✅ Retrieved ${history.length} payment records`);
            }

            return { data: history, error: null };
        } catch (error) {
            console.error('❌ Get payment history error:', error);
            return { data: [], error };
        }
    }

    /**
     * Get available plans
     */
    async getAvailablePlans() {
        try {
            if (this.debug) {
                console.log('📋 Getting available plans');
            }

            const response = await fetch(`${BACKEND_API_URL}/plans`, {
                method: 'GET',
                headers: {
                    'Content-Type': 'application/json'
                }
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(`Failed to get plans: ${errorData.error || response.statusText}`);
            }

            const plans = await response.json();

            if (this.debug) {
                console.log(`✅ Retrieved ${plans.length} available plans`);
            }

            return { data: plans, error: null };
        } catch (error) {
            console.error('❌ Get available plans error:', error);
            
            // Return default plans as fallback
            const defaultPlans = [
                {
                    id: 'basic',
                    name: 'Basic Plan',
                    price: 9.99,
                    interval: 'month',
                    features: ['Basic listings', 'Standard support', 'Mobile app access']
                },
                {
                    id: 'premium',
                    name: 'Premium Plan',
                    price: 19.99,
                    interval: 'month',
                    features: ['Unlimited listings', 'Priority support', 'Advanced analytics', 'AI features']
                },
                {
                    id: 'enterprise',
                    name: 'Enterprise Plan',
                    price: 49.99,
                    interval: 'month',
                    features: ['Everything in Premium', 'Custom integrations', 'Dedicated support', 'White label options']
                }
            ];
            
            return { data: defaultPlans, error: null };
        }
    }

    /**
     * Validate payment method
     */
    async validatePaymentMethod(paymentMethod) {
        try {
            if (this.debug) {
                console.log('🔍 Validating payment method');
            }

            const response = await fetch(`${BACKEND_API_URL}/validate-payment-method`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    payment_method: paymentMethod
                })
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(`Payment method validation failed: ${errorData.error || response.statusText}`);
            }

            const result = await response.json();

            if (this.debug) {
                console.log('✅ Payment method validated');
            }

            return { data: result, error: null };
        } catch (error) {
            console.error('❌ Validate payment method error:', error);
            return { data: null, error };
        }
    }

    /**
     * Process refund
     */
    async processRefund(paymentId, amount = null, reason = '') {
        try {
            const currentUser = iosAuthManager.getCurrentUser();
            if (!currentUser) {
                throw new Error('User must be authenticated to process refunds');
            }

            if (this.debug) {
                console.log('💸 Processing refund for payment:', paymentId);
            }

            const response = await fetch(`${BACKEND_API_URL}/process-refund`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${currentUser.access_token || ''}`
                },
                body: JSON.stringify({
                    payment_id: paymentId,
                    amount: amount,
                    reason: reason
                })
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(`Refund processing failed: ${errorData.error || response.statusText}`);
            }

            const result = await response.json();

            if (this.debug) {
                console.log('✅ Refund processed successfully');
            }

            return { data: result, error: null };
        } catch (error) {
            console.error('❌ Process refund error:', error);
            return { data: null, error };
        }
    }

    /**
     * Get payment methods
     */
    async getPaymentMethods() {
        try {
            const currentUser = iosAuthManager.getCurrentUser();
            if (!currentUser) {
                throw new Error('User must be authenticated to get payment methods');
            }

            if (this.debug) {
                console.log('💳 Getting payment methods');
            }

            const response = await fetch(`${BACKEND_API_URL}/payment-methods`, {
                method: 'GET',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${currentUser.access_token || ''}`
                }
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(`Failed to get payment methods: ${errorData.error || response.statusText}`);
            }

            const methods = await response.json();

            if (this.debug) {
                console.log(`✅ Retrieved ${methods.length} payment methods`);
            }

            return { data: methods, error: null };
        } catch (error) {
            console.error('❌ Get payment methods error:', error);
            return { data: [], error };
        }
    }

    /**
     * Add payment method
     */
    async addPaymentMethod(paymentMethodData) {
        try {
            const currentUser = iosAuthManager.getCurrentUser();
            if (!currentUser) {
                throw new Error('User must be authenticated to add payment methods');
            }

            if (this.debug) {
                console.log('➕ Adding payment method');
            }

            const response = await fetch(`${BACKEND_API_URL}/add-payment-method`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${currentUser.access_token || ''}`
                },
                body: JSON.stringify(paymentMethodData)
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(`Failed to add payment method: ${errorData.error || response.statusText}`);
            }

            const result = await response.json();

            if (this.debug) {
                console.log('✅ Payment method added successfully');
            }

            return { data: result, error: null };
        } catch (error) {
            console.error('❌ Add payment method error:', error);
            return { data: null, error };
        }
    }

    /**
     * Remove payment method
     */
    async removePaymentMethod(paymentMethodId) {
        try {
            const currentUser = iosAuthManager.getCurrentUser();
            if (!currentUser) {
                throw new Error('User must be authenticated to remove payment methods');
            }

            if (this.debug) {
                console.log('🗑️ Removing payment method:', paymentMethodId);
            }

            const response = await fetch(`${BACKEND_API_URL}/remove-payment-method`, {
                method: 'DELETE',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${currentUser.access_token || ''}`
                },
                body: JSON.stringify({
                    payment_method_id: paymentMethodId
                })
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(`Failed to remove payment method: ${errorData.error || response.statusText}`);
            }

            const result = await response.json();

            if (this.debug) {
                console.log('✅ Payment method removed successfully');
            }

            return { data: result, error: null };
        } catch (error) {
            console.error('❌ Remove payment method error:', error);
            return { data: null, error };
        }
    }
}

// Create singleton instance
const iosPaymentAPI = new IOSPaymentAPI();

/**
 * Export singleton instance
 */
export default iosPaymentAPI;

/**
 * Export payment functions for convenience
 */
export const {
    setStripeKey,
    setPayPalClientId,
    getPaymentConfig,
    processPayment,
    createStripePaymentIntent,
    confirmStripePayment,
    createSubscription,
    cancelSubscription,
    getSubscriptionStatus,
    updateUserSubscription,
    getPaymentHistory,
    getAvailablePlans,
    validatePaymentMethod,
    processRefund,
    getPaymentMethods,
    addPaymentMethod,
    removePaymentMethod
} = iosPaymentAPI;

console.log('✅ iOS Payment API module loaded successfully');