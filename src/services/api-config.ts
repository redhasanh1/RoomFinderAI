import { createSupabaseApi } from './supabase-api';
import { createOpenAIApi } from './openai-api';
import { createPaymentApi } from './payment-api';

// API Configuration
export const API_CONFIG = {
  supabase: {
    url: process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://your-project.supabase.co',
    anonKey: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || 'your-anon-key',
    serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY || 'your-service-role-key',
  },
  openai: {
    apiKey: process.env.OPENAI_API_KEY || 'your-openai-api-key',
    organization: process.env.OPENAI_ORGANIZATION || undefined,
  },
  payment: {
    stripe: {
      publishableKey: process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY || 'your-stripe-publishable-key',
      secretKey: process.env.STRIPE_SECRET_KEY || 'your-stripe-secret-key',
      webhookSecret: process.env.STRIPE_WEBHOOK_SECRET || 'your-webhook-secret',
    },
    paypal: {
      clientId: process.env.NEXT_PUBLIC_PAYPAL_CLIENT_ID || 'your-paypal-client-id',
      clientSecret: process.env.PAYPAL_CLIENT_SECRET || 'your-paypal-client-secret',
      environment: (process.env.PAYPAL_ENVIRONMENT as 'sandbox' | 'live') || 'sandbox',
    },
    backendUrl: process.env.NEXT_PUBLIC_BACKEND_URL || 'https://roomfinder-ai-negotiator-production.up.railway.app',
  },
};

// Initialize API services
export const supabaseApi = createSupabaseApi(API_CONFIG.supabase);
export const openaiApi = createOpenAIApi(API_CONFIG.openai);
export const paymentApi = createPaymentApi(API_CONFIG.payment);

// Export individual services
export { supabaseApi, openaiApi, paymentApi };

// Export for convenient importing
export default {
  supabase: supabaseApi,
  openai: openaiApi,
  payment: paymentApi,
};