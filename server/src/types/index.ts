export interface AuthLocals {
  userId: string;
  email: string | null;
  isGuest: boolean;
}

export interface HealthResponse {
  status: string;
  timestamp: string;
  uptime: number;
  services?: {
    database: 'ok' | 'error';
    redis: 'ok' | 'disconnected' | 'error';
  };
}

export interface SuccessResponse<T> {
  status: number;
  data: T;
}

export interface ValidatedLocals {
  body?: unknown;
  query?: unknown;
  params?: unknown;
}
