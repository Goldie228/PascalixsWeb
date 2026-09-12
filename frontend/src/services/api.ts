import axios from 'axios'
import type { User } from '@/types'
import { intercept401 } from './auth-refresh'

interface ApiError extends Error {
  status?: number
  details?: any
  errors?: any
}

interface ExtendedConfig extends Record<string, any> {
  retry?: number
  retryDelay?: number
  _retry?: boolean
  _retryCount?: number
}

const api = axios.create({
  baseURL: '/api/v1',
  headers: {
    'Content-Type': 'application/json',
  },
})

// Request interceptor with optional dev logging
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('token')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }

  return config
})

// Response interceptor with error transformation and 429 retry
api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config as ExtendedConfig
    const retry = originalRequest?.retry ?? 3
    const retryDelay = originalRequest?.retryDelay ?? 1000

    // Handle 401 with token refresh
    error = await intercept401(error)
    if (error?.response?.status === 401) {
      // Refresh failed, re-throw
      return Promise.reject(transformError(error))
    }

    // Handle 429 Too Many Requests with retry logic
    if (
      error.response?.status === 429 &&
      !originalRequest._retry &&
      retry > 0
    ) {
      originalRequest._retry = true
      const retryCount = originalRequest._retryCount || 0
      if (retryCount < retry) {
        originalRequest._retryCount = retryCount + 1
        const delay = retryDelay * (retryCount + 1)
        await new Promise((resolve) => setTimeout(resolve, delay))
        return api(originalRequest as any)
      }
    }

    return Promise.reject(transformError(error))
  }
)

// Transform raw axios errors into consistent API error format
function transformError(error: any): ApiError {
  if (error.response) {
    // Server responded with error status
    const data = error.response.data
    const message =
      data?.message ||
      data?.error ||
      `API Error ${error.response.status}`

    const apiError = new Error(message) as ApiError
    apiError.name = 'ApiError'
    apiError.status = error.response.status
    apiError.details = data?.details
    apiError.errors = data?.errors
    return apiError
  }

  if (error.request) {
    // Request made but no response received
    return new Error('Network error. Please check your connection.') as ApiError
  }

  // Something else happened
  return error as ApiError
}

export const authApi = {
  login: (username: string, password: string) =>
    api.post('/auth/login', { username, password }),
  register: (data: {
    username: string
    email: string
    password: string
    passwordConfirmation: string
  }) => api.post('/auth/register', data),
  logout: () => api.post('/auth/logout'),
  me: () => api.get<User>('/users/me'),
}

export const serverApi = {
  stats: () => api.get('/servers/stats'),
  news: () => api.get('/news'),
  votes: () => api.get('/votes'),
  vote: (siteId: number) => api.post(`/votes/${siteId}/vote`),
}

export const gameApi = {
  getPlayer: (uuid: string) => api.get(`/game/player/${uuid}`),
  getServerInfo: () => api.get('/game/server'),
}

export const notificationApi = {
  getNotifications: () => api.get('/notifications'),
  markRead: (id: number) => api.put(`/notifications/${id}/read`),
  markAllRead: () => api.put('/notifications/read-all'),
}

export default api
