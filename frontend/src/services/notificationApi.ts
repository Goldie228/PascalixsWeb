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

export default notificationApi
