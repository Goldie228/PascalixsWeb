import api from './api'
import type { User, Punishment, Appeal, StatsOverview } from '@/types'

export const adminApi = {
  // Users
  getUsers: (params?: { page?: number; per_page?: number; search?: string }) =>
    api.get<{ users: User[]; total: number; page: number }>('/admin/users', { params }),
  updateUser: (userId: number, data: Partial<User>) =>
    api.put<User>(`/admin/users/${userId}`, data),
  deleteUser: (userId: number) => api.delete(`/admin/users/${userId}`),

  // Punishments
  getPunishments: (params?: { page?: number; per_page?: number }) =>
    api.get<{ punishments: Punishment[]; total: number; page: number }>('/admin/punishments', {
      params,
    }),
  createPunishment: (data: {
    user_id: number
    type: string
    reason: string
    duration?: string
  }) => api.post<Punishment>('/admin/punishments', data),
  updatePunishment: (
    punishmentId: number,
    data: { resolved?: boolean; reason?: string }
  ) => api.put<Punishment>(`/admin/punishments/${punishmentId}`, data),
  resolvePunishment: (punishmentId: number) =>
    api.put<Punishment>(`/admin/punishments/${punishmentId}/resolve`),

  // Appeals
  getAppeals: (params?: { page?: number; per_page?: number }) =>
    api.get<{ appeals: Appeal[]; total: number; page: number }>('/admin/appeals', { params }),
  getAppeal: (appealId: number) => api.get<Appeal>(`/admin/appeals/${appealId}`),
  approveAppeal: (appealId: number) => api.put(`/admin/appeals/${appealId}/approve`),
  rejectAppeal: (appealId: number, reason: string) =>
    api.put(`/admin/appeals/${appealId}/reject`, { reason }),

  // Stats
  getStats: () => api.get<StatsOverview>('/admin/stats'),
}

export default adminApi
