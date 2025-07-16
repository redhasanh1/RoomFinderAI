import { CapacitorHttp, HttpResponse } from '@capacitor-community/http';
import { Capacitor } from '@capacitor/core';

export interface ApiRequestOptions {
  url: string;
  method: 'GET' | 'POST' | 'PUT' | 'DELETE' | 'PATCH';
  headers?: Record<string, string>;
  data?: any;
  timeout?: number;
  responseType?: 'json' | 'text' | 'blob' | 'arraybuffer';
}

export interface ApiResponse<T = any> {
  data: T;
  status: number;
  headers: Record<string, string>;
  url: string;
}

export interface ApiError {
  message: string;
  status?: number;
  data?: any;
  url?: string;
}

class UniversalApiService {
  private static instance: UniversalApiService;
  private baseHeaders: Record<string, string> = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  private constructor() {}

  static getInstance(): UniversalApiService {
    if (!UniversalApiService.instance) {
      UniversalApiService.instance = new UniversalApiService();
    }
    return UniversalApiService.instance;
  }

  // Set default headers for all requests
  setDefaultHeaders(headers: Record<string, string>) {
    this.baseHeaders = { ...this.baseHeaders, ...headers };
  }

  // Add or update a specific header
  setHeader(key: string, value: string) {
    this.baseHeaders[key] = value;
  }

  // Remove a header
  removeHeader(key: string) {
    delete this.baseHeaders[key];
  }

  // Main API request method
  async request<T = any>(options: ApiRequestOptions): Promise<ApiResponse<T>> {
    const { url, method, headers = {}, data, timeout = 30000, responseType = 'json' } = options;

    // Merge headers with base headers
    const requestHeaders = { ...this.baseHeaders, ...headers };

    // Log request details for debugging
    this.logRequest(method, url, requestHeaders, data);

    try {
      let response: HttpResponse;

      if (Capacitor.isNativePlatform()) {
        // Use Capacitor HTTP for native platforms (iOS/Android)
        response = await CapacitorHttp.request({
          url,
          method,
          headers: requestHeaders,
          data: data ? (typeof data === 'object' ? JSON.stringify(data) : data) : undefined,
          responseType,
          timeout,
        });
      } else {
        // Use regular fetch for web platform
        const fetchOptions: RequestInit = {
          method,
          headers: requestHeaders,
          body: data ? (typeof data === 'object' ? JSON.stringify(data) : data) : undefined,
          signal: timeout ? AbortSignal.timeout(timeout) : undefined,
        };

        const fetchResponse = await fetch(url, fetchOptions);
        
        let responseData: any;
        if (responseType === 'json') {
          responseData = await fetchResponse.json();
        } else if (responseType === 'text') {
          responseData = await fetchResponse.text();
        } else if (responseType === 'blob') {
          responseData = await fetchResponse.blob();
        } else if (responseType === 'arraybuffer') {
          responseData = await fetchResponse.arrayBuffer();
        }

        response = {
          data: responseData,
          status: fetchResponse.status,
          headers: Object.fromEntries(fetchResponse.headers.entries()),
          url: fetchResponse.url,
        };
      }

      this.logResponse(response);

      if (response.status >= 200 && response.status < 300) {
        return {
          data: response.data,
          status: response.status,
          headers: response.headers,
          url: response.url,
        };
      } else {
        throw this.createError(
          `HTTP Error ${response.status}`,
          response.status,
          response.data,
          url
        );
      }
    } catch (error) {
      this.logError(error, url);
      
      if (error instanceof Error) {
        throw this.createError(error.message, undefined, undefined, url);
      } else {
        throw this.createError('Unknown error occurred', undefined, error, url);
      }
    }
  }

  // Convenience methods for common HTTP verbs
  async get<T = any>(url: string, headers?: Record<string, string>): Promise<ApiResponse<T>> {
    return this.request<T>({ url, method: 'GET', headers });
  }

  async post<T = any>(url: string, data?: any, headers?: Record<string, string>): Promise<ApiResponse<T>> {
    return this.request<T>({ url, method: 'POST', data, headers });
  }

  async put<T = any>(url: string, data?: any, headers?: Record<string, string>): Promise<ApiResponse<T>> {
    return this.request<T>({ url, method: 'PUT', data, headers });
  }

  async delete<T = any>(url: string, headers?: Record<string, string>): Promise<ApiResponse<T>> {
    return this.request<T>({ url, method: 'DELETE', headers });
  }

  async patch<T = any>(url: string, data?: any, headers?: Record<string, string>): Promise<ApiResponse<T>> {
    return this.request<T>({ url, method: 'PATCH', data, headers });
  }

  // Upload files using multipart/form-data
  async uploadFile<T = any>(
    url: string,
    file: File | Blob,
    fieldName: string = 'file',
    additionalFields?: Record<string, any>,
    headers?: Record<string, string>
  ): Promise<ApiResponse<T>> {
    const formData = new FormData();
    formData.append(fieldName, file);

    if (additionalFields) {
      Object.entries(additionalFields).forEach(([key, value]) => {
        formData.append(key, value);
      });
    }

    const uploadHeaders = { ...headers };
    // Remove Content-Type header to let the browser set it with boundary
    delete uploadHeaders['Content-Type'];

    return this.request<T>({
      url,
      method: 'POST',
      data: formData,
      headers: uploadHeaders,
    });
  }

  // Helper method to create standardized errors
  private createError(message: string, status?: number, data?: any, url?: string): ApiError {
    return {
      message,
      status,
      data,
      url,
    };
  }

  // Logging methods for debugging
  private logRequest(method: string, url: string, headers: Record<string, string>, data?: any) {
    if (process.env.NODE_ENV === 'development') {
      console.group(`🚀 API Request: ${method} ${url}`);
      console.log('Headers:', headers);
      if (data) {
        console.log('Data:', data);
      }
      console.groupEnd();
    }
  }

  private logResponse(response: HttpResponse) {
    if (process.env.NODE_ENV === 'development') {
      console.group(`✅ API Response: ${response.status} ${response.url}`);
      console.log('Status:', response.status);
      console.log('Headers:', response.headers);
      console.log('Data:', response.data);
      console.groupEnd();
    }
  }

  private logError(error: any, url?: string) {
    if (process.env.NODE_ENV === 'development') {
      console.group(`❌ API Error: ${url || 'Unknown URL'}`);
      console.error('Error:', error);
      console.groupEnd();
    }
  }
}

// Export singleton instance
export const universalApi = UniversalApiService.getInstance();
export default universalApi;