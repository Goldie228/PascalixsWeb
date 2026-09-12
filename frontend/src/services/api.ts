import axios from 'axios'
import type { User } from '@/types'
import { intercept401 } from './auth-refresh'

const api = axios.create({
  baseURL: '/api/v1',
  headers: {
    'Content-Type': 'application/json',
  },
})

api.interceptors.request.use((config) => {
  const token = localStorage.getItem('token')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

api.interceptors.response.use(
  (response) => response,
  (error) => intercept401(error)
)

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
