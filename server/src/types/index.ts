export interface ApiError extends Error {
  status: number;
  details?: Array<{ field: string; message: string }>;
}

export interface HealthResponse {
  status: string;
  timestamp: string;
  uptime: number;
}
