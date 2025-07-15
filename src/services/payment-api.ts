import { universalApi } from './universal-api';

export interface PaymentConfig {
  stripe?: {
    publishableKey: string;
    secretKey?: string;
    webhookSecret?: string;
  };
  paypal?: {
    clientId: string;
    clientSecret?: string;
    environment: 'sandbox' | 'live';
  };
  backendUrl?: string;
}

export interface PaymentIntent {
  id: string;
  amount: number;
  currency: string;
  status: string;
  client_secret?: string;
  payment_method?: string;
  description?: string;
  metadata?: Record<string, any>;
}

export interface PaymentMethod {
  id: string;
  type: string;
  card?: {
    brand: string;
    last4: string;
    exp_month: number;
    exp_year: number;
  };
  billing_details?: {
    name?: string;
    email?: string;
    address?: any;
  };
}

export interface Customer {
  id: string;
  email?: string;
  name?: string;
  phone?: string;
  address?: any;
  metadata?: Record<string, any>;
}

export interface Subscription {
  id: string;
  customer: string;
  status: string;
  current_period_start: number;
  current_period_end: number;
  plan: {
    id: string;
    amount: number;
    currency: string;
    interval: string;
    product: string;
  };
  metadata?: Record<string, any>;
}

export interface PayPalOrder {
  id: string;
  status: string;
  amount: {
    currency_code: string;
    value: string;
  };
  payer?: any;
  purchase_units?: any[];
  links?: any[];
}

class PaymentApiService {
  private static instance: PaymentApiService;
  private config: PaymentConfig;

  private constructor(config: PaymentConfig) {
    this.config = config;
  }

  static getInstance(config?: PaymentConfig): PaymentApiService {
    if (!PaymentApiService.instance) {
      if (!config) {
        throw new Error('PaymentApiService requires config on first initialization');
      }
      PaymentApiService.instance = new PaymentApiService(config);
    }
    return PaymentApiService.instance;
  }

  // Stripe API Methods
  private get stripeHeaders() {
    if (!this.config.stripe?.secretKey) {
      throw new Error('Stripe secret key not configured');
    }
    
    return {
      'Authorization': `Bearer ${this.config.stripe.secretKey}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    };
  }

  async createStripePaymentIntent(params: {
    amount: number; // in cents
    currency: string;
    customer?: string;
    description?: string;
    metadata?: Record<string, any>;
    payment_method_types?: string[];
    automatic_payment_methods?: { enabled: boolean };
  }): Promise<PaymentIntent> {
    const formData = new URLSearchParams();
    formData.append('amount', params.amount.toString());
    formData.append('currency', params.currency);
    
    if (params.customer) formData.append('customer', params.customer);
    if (params.description) formData.append('description', params.description);
    
    if (params.metadata) {
      Object.entries(params.metadata).forEach(([key, value]) => {
        formData.append(`metadata[${key}]`, value.toString());
      });
    }
    
    if (params.payment_method_types) {
      params.payment_method_types.forEach(type => {
        formData.append('payment_method_types[]', type);
      });
    } else {
      formData.append('payment_method_types[]', 'card');
    }
    
    if (params.automatic_payment_methods) {
      formData.append('automatic_payment_methods[enabled]', params.automatic_payment_methods.enabled.toString());
    }

    const response = await universalApi.post(
      'https://api.stripe.com/v1/payment_intents',
      formData.toString(),
      this.stripeHeaders
    );
    
    return response.data;
  }

  async confirmStripePaymentIntent(paymentIntentId: string, params: {
    payment_method?: string;
    return_url?: string;
  }): Promise<PaymentIntent> {
    const formData = new URLSearchParams();
    
    if (params.payment_method) {
      formData.append('payment_method', params.payment_method);
    }
    
    if (params.return_url) {
      formData.append('return_url', params.return_url);
    }

    const response = await universalApi.post(
      `https://api.stripe.com/v1/payment_intents/${paymentIntentId}/confirm`,
      formData.toString(),
      this.stripeHeaders
    );
    
    return response.data;
  }

  async getStripePaymentIntent(paymentIntentId: string): Promise<PaymentIntent> {
    const response = await universalApi.get(
      `https://api.stripe.com/v1/payment_intents/${paymentIntentId}`,
      this.stripeHeaders
    );
    
    return response.data;
  }

  async createStripeCustomer(params: {
    email?: string;
    name?: string;
    phone?: string;
    address?: any;
    metadata?: Record<string, any>;
  }): Promise<Customer> {
    const formData = new URLSearchParams();
    
    if (params.email) formData.append('email', params.email);
    if (params.name) formData.append('name', params.name);
    if (params.phone) formData.append('phone', params.phone);
    
    if (params.address) {
      Object.entries(params.address).forEach(([key, value]) => {
        formData.append(`address[${key}]`, value.toString());
      });
    }
    
    if (params.metadata) {
      Object.entries(params.metadata).forEach(([key, value]) => {
        formData.append(`metadata[${key}]`, value.toString());
      });
    }

    const response = await universalApi.post(
      'https://api.stripe.com/v1/customers',
      formData.toString(),
      this.stripeHeaders
    );
    
    return response.data;
  }

  async getStripeCustomer(customerId: string): Promise<Customer> {
    const response = await universalApi.get(
      `https://api.stripe.com/v1/customers/${customerId}`,
      this.stripeHeaders
    );
    
    return response.data;
  }

  async createStripeSubscription(params: {
    customer: string;
    items: { price: string; quantity?: number }[];
    trial_period_days?: number;
    metadata?: Record<string, any>;
  }): Promise<Subscription> {
    const formData = new URLSearchParams();
    formData.append('customer', params.customer);
    
    params.items.forEach((item, index) => {
      formData.append(`items[${index}][price]`, item.price);
      if (item.quantity) {
        formData.append(`items[${index}][quantity]`, item.quantity.toString());
      }
    });
    
    if (params.trial_period_days) {
      formData.append('trial_period_days', params.trial_period_days.toString());
    }
    
    if (params.metadata) {
      Object.entries(params.metadata).forEach(([key, value]) => {
        formData.append(`metadata[${key}]`, value.toString());
      });
    }

    const response = await universalApi.post(
      'https://api.stripe.com/v1/subscriptions',
      formData.toString(),
      this.stripeHeaders
    );
    
    return response.data;
  }

  async cancelStripeSubscription(subscriptionId: string): Promise<Subscription> {
    const response = await universalApi.delete(
      `https://api.stripe.com/v1/subscriptions/${subscriptionId}`,
      this.stripeHeaders
    );
    
    return response.data;
  }

  // PayPal API Methods
  private get paypalHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  private get paypalBaseUrl() {
    return this.config.paypal?.environment === 'live' 
      ? 'https://api.paypal.com' 
      : 'https://api.sandbox.paypal.com';
  }

  async getPayPalAccessToken(): Promise<string> {
    if (!this.config.paypal?.clientId || !this.config.paypal?.clientSecret) {
      throw new Error('PayPal credentials not configured');
    }

    const credentials = btoa(`${this.config.paypal.clientId}:${this.config.paypal.clientSecret}`);
    
    const response = await universalApi.post(
      `${this.paypalBaseUrl}/v1/oauth2/token`,
      'grant_type=client_credentials',
      {
        'Authorization': `Basic ${credentials}`,
        'Accept': 'application/json',
        'Accept-Language': 'en_US',
        'Content-Type': 'application/x-www-form-urlencoded',
      }
    );
    
    return response.data.access_token;
  }

  async createPayPalOrder(params: {
    amount: string;
    currency: string;
    description?: string;
    return_url?: string;
    cancel_url?: string;
  }): Promise<PayPalOrder> {
    const accessToken = await this.getPayPalAccessToken();
    
    const orderData = {
      intent: 'CAPTURE',
      purchase_units: [{
        amount: {
          currency_code: params.currency,
          value: params.amount,
        },
        description: params.description,
      }],
      application_context: {
        return_url: params.return_url,
        cancel_url: params.cancel_url,
      },
    };

    const response = await universalApi.post(
      `${this.paypalBaseUrl}/v2/checkout/orders`,
      orderData,
      {
        ...this.paypalHeaders,
        'Authorization': `Bearer ${accessToken}`,
      }
    );
    
    return response.data;
  }

  async capturePayPalOrder(orderId: string): Promise<PayPalOrder> {
    const accessToken = await this.getPayPalAccessToken();
    
    const response = await universalApi.post(
      `${this.paypalBaseUrl}/v2/checkout/orders/${orderId}/capture`,
      {},
      {
        ...this.paypalHeaders,
        'Authorization': `Bearer ${accessToken}`,
      }
    );
    
    return response.data;
  }

  async getPayPalOrder(orderId: string): Promise<PayPalOrder> {
    const accessToken = await this.getPayPalAccessToken();
    
    const response = await universalApi.get(
      `${this.paypalBaseUrl}/v2/checkout/orders/${orderId}`,
      {
        ...this.paypalHeaders,
        'Authorization': `Bearer ${accessToken}`,
      }
    );
    
    return response.data;
  }

  // Backend Integration Methods (if using your own backend)
  async createBackendPaymentIntent(params: {
    amount: number;
    currency: string;
    customer_id?: string;
    description?: string;
    metadata?: Record<string, any>;
  }): Promise<PaymentIntent> {
    if (!this.config.backendUrl) {
      throw new Error('Backend URL not configured');
    }

    const response = await universalApi.post(
      `${this.config.backendUrl}/api/payments/create-intent`,
      params
    );
    
    return response.data;
  }

  async confirmBackendPayment(params: {
    payment_intent_id: string;
    payment_method_id: string;
  }): Promise<PaymentIntent> {
    if (!this.config.backendUrl) {
      throw new Error('Backend URL not configured');
    }

    const response = await universalApi.post(
      `${this.config.backendUrl}/api/payments/confirm`,
      params
    );
    
    return response.data;
  }

  async getBackendPaymentStatus(paymentIntentId: string): Promise<PaymentIntent> {
    if (!this.config.backendUrl) {
      throw new Error('Backend URL not configured');
    }

    const response = await universalApi.get(
      `${this.config.backendUrl}/api/payments/status/${paymentIntentId}`
    );
    
    return response.data;
  }

  // Webhook verification (for backend use)
  async verifyStripeWebhook(payload: string, signature: string): Promise<boolean> {
    if (!this.config.stripe?.webhookSecret) {
      throw new Error('Stripe webhook secret not configured');
    }

    try {
      // This is a simplified implementation
      // In a real app, you'd use Stripe's webhook signature verification
      const response = await universalApi.post(
        `${this.config.backendUrl}/api/webhooks/stripe/verify`,
        { payload, signature, secret: this.config.stripe.webhookSecret }
      );
      
      return response.data.verified;
    } catch (error) {
      console.error('Webhook verification failed:', error);
      return false;
    }
  }

  // Utility methods
  formatCurrency(amount: number, currency: string): string {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: currency.toUpperCase(),
    }).format(amount / 100); // Convert from cents
  }

  validateCardNumber(cardNumber: string): boolean {
    // Basic Luhn algorithm implementation
    const cleaned = cardNumber.replace(/\s/g, '');
    if (!/^\d+$/.test(cleaned)) return false;
    
    let sum = 0;
    let alternate = false;
    
    for (let i = cleaned.length - 1; i >= 0; i--) {
      let digit = parseInt(cleaned[i]);
      
      if (alternate) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      
      sum += digit;
      alternate = !alternate;
    }
    
    return sum % 10 === 0;
  }

  validateExpiryDate(month: number, year: number): boolean {
    const now = new Date();
    const currentYear = now.getFullYear();
    const currentMonth = now.getMonth() + 1;
    
    return (year > currentYear) || (year === currentYear && month >= currentMonth);
  }

  validateCVC(cvc: string): boolean {
    return /^\d{3,4}$/.test(cvc);
  }
}

// Export singleton instance creator
export const createPaymentApi = (config: PaymentConfig) => {
  return PaymentApiService.getInstance(config);
};

export default PaymentApiService;