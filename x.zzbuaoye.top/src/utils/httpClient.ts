import { getCurrentConfig, REQUEST_CONFIG } from '../config/api';

export interface RequestOptions {
  method?: 'GET' | 'POST' | 'PUT' | 'DELETE' | 'PATCH';
  headers?: Record<string, string>;
  body?: any;
  timeout?: number;
  retries?: number;
}

export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  message?: string;
  error?: string;
  code?: number;
}

class HttpClient {
  private baseUrl: string;
  private defaultHeaders: Record<string, string>;

  constructor() {
    this.baseUrl = getCurrentConfig().baseUrl;
    this.defaultHeaders = {
      'Content-Type': 'application/json',
    };
  }

  // 设置认证token
  setAuthToken(token: string) {
    this.defaultHeaders['Authorization'] = `Bearer ${token}`;
  }

  // 清除认证token
  clearAuthToken() {
    delete this.defaultHeaders['Authorization'];
  }

  // 获取存储的token
  getStoredToken(): string | null {
    return localStorage.getItem('admin_token');
  }

  // 设置存储的token
  setStoredToken(token: string) {
    localStorage.setItem('admin_token', token);
    this.setAuthToken(token);
  }

  // 清除存储的token
  clearStoredToken() {
    localStorage.removeItem('admin_token');
    this.clearAuthToken();
  }

  // 发送请求
  async request<T = any>(
    endpoint: string, 
    options: RequestOptions = {}
  ): Promise<ApiResponse<T>> {
    const {
      method = 'GET',
      headers = {},
      body,
      timeout = REQUEST_CONFIG.timeout,
      retries = REQUEST_CONFIG.retries,
    } = options;

    const url = `${this.baseUrl}${endpoint}`;
    const requestHeaders = { ...this.defaultHeaders, ...headers };

    // 自动添加存储的token
    const storedToken = this.getStoredToken();
    if (storedToken && !requestHeaders['Authorization']) {
      requestHeaders['Authorization'] = `Bearer ${storedToken}`;
    }

    const requestOptions: RequestInit = {
      method,
      headers: requestHeaders,
      body: body ? JSON.stringify(body) : undefined,
    };

    let lastError: Error;

    for (let attempt = 0; attempt <= retries; attempt++) {
      try {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), timeout);

        const response = await fetch(url, {
          ...requestOptions,
          signal: controller.signal,
        });

        clearTimeout(timeoutId);

        const responseData = await response.json();

        if (!response.ok) {
          // 处理401未授权错误
          if (response.status === 401) {
            this.clearStoredToken();
            window.dispatchEvent(new CustomEvent('auth:unauthorized'));
          }

          return {
            success: false,
            error: responseData.message || `HTTP ${response.status}`,
            code: response.status,
          };
        }

        return {
          success: true,
          data: responseData.data || responseData,
          message: responseData.message,
        };

      } catch (error) {
        lastError = error as Error;
        
        // 如果是最后一次尝试，抛出错误
        if (attempt === retries) {
          break;
        }

        // 等待后重试
        await new Promise(resolve => 
          setTimeout(resolve, REQUEST_CONFIG.retryDelay * (attempt + 1))
        );
      }
    }

    return {
      success: false,
      error: lastError!.message || 'Network error',
    };
  }

  // GET请求
  async get<T = any>(endpoint: string, options?: Omit<RequestOptions, 'method' | 'body'>) {
    return this.request<T>(endpoint, { ...options, method: 'GET' });
  }

  // POST请求
  async post<T = any>(endpoint: string, body?: any, options?: Omit<RequestOptions, 'method'>) {
    return this.request<T>(endpoint, { ...options, method: 'POST', body });
  }

  // PUT请求
  async put<T = any>(endpoint: string, body?: any, options?: Omit<RequestOptions, 'method'>) {
    return this.request<T>(endpoint, { ...options, method: 'PUT', body });
  }

  // DELETE请求
  async delete<T = any>(endpoint: string, options?: Omit<RequestOptions, 'method' | 'body'>) {
    return this.request<T>(endpoint, { ...options, method: 'DELETE' });
  }

  // PATCH请求
  async patch<T = any>(endpoint: string, body?: any, options?: Omit<RequestOptions, 'method'>) {
    return this.request<T>(endpoint, { ...options, method: 'PATCH', body });
  }
}

export const httpClient = new HttpClient();