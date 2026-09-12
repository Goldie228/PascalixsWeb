import api from './api'
import type { Notification } from '@/types'

export const notificationApi = {
  getNotifications: (params?: { page?: number; per_page?: number }) =>
    api.get<{ notifications: Notification[]; total: number; unread: number; page: number }>(
      '/notifications',
      { params }
    ),
  markAsRead: (id: number) => api.put(`/notifications/${id}/read`),
  markAllAsRead: () => api.put('/notifications/read-all'),
  getUnreadCount: () => api.get<{ count: number }>('/notifications/unread-count'),
}

// Backward-compatible aliases for existing usage
export const markRead = notificationApi.markAsRead
export const markAllRead = notificationApi.markAllAsRead

export default notificationApi
