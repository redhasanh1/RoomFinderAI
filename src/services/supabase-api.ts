import { universalApi } from './universal-api';

export interface SupabaseConfig {
  url: string;
  anonKey: string;
  serviceRoleKey?: string;
}

export interface SupabaseAuth {
  access_token: string;
  refresh_token: string;
  expires_in: number;
  token_type: string;
  user: any;
}

export interface SupabaseQuery {
  select?: string;
  where?: Record<string, any>;
  order?: { column: string; ascending?: boolean };
  limit?: number;
  offset?: number;
}

class SupabaseApiService {
  private static instance: SupabaseApiService;
  private config: SupabaseConfig;
  private accessToken: string | null = null;

  private constructor(config: SupabaseConfig) {
    this.config = config;
    this.setupDefaultHeaders();
  }

  static getInstance(config?: SupabaseConfig): SupabaseApiService {
    if (!SupabaseApiService.instance) {
      if (!config) {
        throw new Error('SupabaseApiService requires config on first initialization');
      }
      SupabaseApiService.instance = new SupabaseApiService(config);
    }
    return SupabaseApiService.instance;
  }

  private setupDefaultHeaders() {
    universalApi.setHeader('apikey', this.config.anonKey);
    universalApi.setHeader('Authorization', `Bearer ${this.config.anonKey}`);
    universalApi.setHeader('Content-Type', 'application/json');
    universalApi.setHeader('Prefer', 'return=representation');
  }

  // Set access token for authenticated requests
  setAccessToken(token: string) {
    this.accessToken = token;
    universalApi.setHeader('Authorization', `Bearer ${token}`);
  }

  // Clear access token
  clearAccessToken() {
    this.accessToken = null;
    universalApi.setHeader('Authorization', `Bearer ${this.config.anonKey}`);
  }

  // Authentication methods
  async signUp(email: string, password: string, metadata?: any) {
    const response = await universalApi.post(`${this.config.url}/auth/v1/signup`, {
      email,
      password,
      data: metadata,
    });
    return response.data;
  }

  async signIn(email: string, password: string) {
    const response = await universalApi.post(`${this.config.url}/auth/v1/token?grant_type=password`, {
      email,
      password,
    });
    
    if (response.data.access_token) {
      this.setAccessToken(response.data.access_token);
    }
    
    return response.data;
  }

  async signOut() {
    if (this.accessToken) {
      await universalApi.post(`${this.config.url}/auth/v1/logout`, {});
      this.clearAccessToken();
    }
  }

  async refreshToken(refreshToken: string) {
    const response = await universalApi.post(`${this.config.url}/auth/v1/token?grant_type=refresh_token`, {
      refresh_token: refreshToken,
    });
    
    if (response.data.access_token) {
      this.setAccessToken(response.data.access_token);
    }
    
    return response.data;
  }

  async getUser() {
    const response = await universalApi.get(`${this.config.url}/auth/v1/user`);
    return response.data;
  }

  async updateUser(attributes: any) {
    const response = await universalApi.put(`${this.config.url}/auth/v1/user`, attributes);
    return response.data;
  }

  async resetPassword(email: string) {
    const response = await universalApi.post(`${this.config.url}/auth/v1/recover`, {
      email,
    });
    return response.data;
  }

  // Database methods
  async select(table: string, query: SupabaseQuery = {}) {
    let url = `${this.config.url}/rest/v1/${table}`;
    const params = new URLSearchParams();

    if (query.select) {
      params.append('select', query.select);
    }

    if (query.where) {
      Object.entries(query.where).forEach(([key, value]) => {
        if (typeof value === 'string') {
          params.append(key, `eq.${value}`);
        } else if (typeof value === 'object' && value !== null) {
          // Handle operators like { gt: 10 }, { like: '%search%' }
          Object.entries(value).forEach(([operator, operatorValue]) => {
            params.append(key, `${operator}.${operatorValue}`);
          });
        }
      });
    }

    if (query.order) {
      const direction = query.order.ascending !== false ? 'asc' : 'desc';
      params.append('order', `${query.order.column}.${direction}`);
    }

    if (query.limit) {
      params.append('limit', query.limit.toString());
    }

    if (query.offset) {
      params.append('offset', query.offset.toString());
    }

    if (params.toString()) {
      url += `?${params.toString()}`;
    }

    const response = await universalApi.get(url);
    return response.data;
  }

  async insert(table: string, data: any | any[]) {
    const response = await universalApi.post(`${this.config.url}/rest/v1/${table}`, data);
    return response.data;
  }

  async update(table: string, data: any, query: SupabaseQuery = {}) {
    let url = `${this.config.url}/rest/v1/${table}`;
    const params = new URLSearchParams();

    if (query.where) {
      Object.entries(query.where).forEach(([key, value]) => {
        if (typeof value === 'string') {
          params.append(key, `eq.${value}`);
        } else if (typeof value === 'object' && value !== null) {
          Object.entries(value).forEach(([operator, operatorValue]) => {
            params.append(key, `${operator}.${operatorValue}`);
          });
        }
      });
    }

    if (params.toString()) {
      url += `?${params.toString()}`;
    }

    const response = await universalApi.patch(url, data);
    return response.data;
  }

  async delete(table: string, query: SupabaseQuery = {}) {
    let url = `${this.config.url}/rest/v1/${table}`;
    const params = new URLSearchParams();

    if (query.where) {
      Object.entries(query.where).forEach(([key, value]) => {
        if (typeof value === 'string') {
          params.append(key, `eq.${value}`);
        } else if (typeof value === 'object' && value !== null) {
          Object.entries(value).forEach(([operator, operatorValue]) => {
            params.append(key, `${operator}.${operatorValue}`);
          });
        }
      });
    }

    if (params.toString()) {
      url += `?${params.toString()}`;
    }

    const response = await universalApi.delete(url);
    return response.data;
  }

  // Storage methods
  async uploadFile(bucket: string, path: string, file: File | Blob, options?: {
    cacheControl?: string;
    contentType?: string;
    upsert?: boolean;
  }) {
    const url = `${this.config.url}/storage/v1/object/${bucket}/${path}`;
    const headers: Record<string, string> = {};

    if (options?.cacheControl) {
      headers['Cache-Control'] = options.cacheControl;
    }

    if (options?.contentType) {
      headers['Content-Type'] = options.contentType;
    }

    if (options?.upsert) {
      headers['x-upsert'] = 'true';
    }

    const response = await universalApi.uploadFile(url, file, 'file', {}, headers);
    return response.data;
  }

  async downloadFile(bucket: string, path: string) {
    const url = `${this.config.url}/storage/v1/object/${bucket}/${path}`;
    const response = await universalApi.request({
      url,
      method: 'GET',
      responseType: 'blob',
    });
    return response.data;
  }

  async deleteFile(bucket: string, path: string) {
    const url = `${this.config.url}/storage/v1/object/${bucket}/${path}`;
    const response = await universalApi.delete(url);
    return response.data;
  }

  async listFiles(bucket: string, folder?: string, options?: {
    limit?: number;
    offset?: number;
    search?: string;
  }) {
    const url = `${this.config.url}/storage/v1/object/list/${bucket}`;
    const params = new URLSearchParams();

    if (folder) {
      params.append('prefix', folder);
    }

    if (options?.limit) {
      params.append('limit', options.limit.toString());
    }

    if (options?.offset) {
      params.append('offset', options.offset.toString());
    }

    if (options?.search) {
      params.append('search', options.search);
    }

    const finalUrl = params.toString() ? `${url}?${params.toString()}` : url;
    const response = await universalApi.get(finalUrl);
    return response.data;
  }

  // RPC (Remote Procedure Call) methods
  async rpc(functionName: string, params?: any) {
    const response = await universalApi.post(`${this.config.url}/rest/v1/rpc/${functionName}`, params);
    return response.data;
  }

  // Real-time subscriptions (simplified for mobile)
  async subscribe(table: string, callback: (payload: any) => void) {
    // This is a simplified implementation
    // For full real-time support, you'd need to implement WebSocket connections
    console.warn('Real-time subscriptions not fully implemented in mobile wrapper');
    return {
      unsubscribe: () => {
        console.log('Unsubscribed from', table);
      },
    };
  }
}

// Export singleton instance creator
export const createSupabaseApi = (config: SupabaseConfig) => {
  return SupabaseApiService.getInstance(config);
};

export default SupabaseApiService;