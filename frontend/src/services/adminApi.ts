import api from './api'
import type {
  User,
  Punishment,
  Appeal,
  StatsOverview,
  DiscordAvatar,
  Complaint,
  Product,
  PunishmentReason,
  RemovedPlayer,
  GalleryAlbum,
  AdminPlayer,
  Purchase,
} from '@/types'

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

  // Avatars
  getAvatars: (params?: {
    page?: number
    per?: number
    sort_by?: string
    sort_order?: string
    status?: string
    from?: string
    to?: string
    user_name?: string
  }) =>
    api.get<{ avatars: DiscordAvatar[]; pagination: { total: number; page: number; per: number } }>('/admin/avatars', {
      params,
    }),
  approveAvatar: (avatarId: number) =>
    api.patch<DiscordAvatar>(`/admin/avatars/${avatarId}/approve`),
  rejectAvatar: (avatarId: number) =>
    api.patch<DiscordAvatar>(`/admin/avatars/${avatarId}/reject`),

  // Complaints
  getComplaints: (params?: { page?: number; per?: number; status?: string; search?: string }) =>
    api.get<{ complaints: Complaint[]; pagination: { total: number; page: number; per: number } }>('/admin/complaints', {
      params,
    }),
  getComplaint: (complaintId: number) => api.get<Complaint>(`/admin/complaints/${complaintId}`),
  markComplaintRead: (complaintId: number) =>
    api.patch(`/admin/complaints/${complaintId}/read`),
  deleteComplaint: (complaintId: number) =>
    api.delete(`/admin/complaints/${complaintId}`),

  // Products
  getProducts: (params?: { page?: number; per_page?: number }) =>
    api.get<{ products: Product[]; total: number; page: number }>('/admin/products', {
      params,
    }),
  updateProductPrice: (productId: number, price: number) =>
    api.patch(`/admin/products/${productId}/price`, { price }),

  // Punishment Reasons
  getPunishmentReasons: (params?: { page?: number; per?: number; search?: string }) =>
    api.get<{ punishment_reasons: PunishmentReason[]; total: number; page: number }>(
      '/admin/punishment_reasons',
      { params },
    ),
  createPunishmentReason: (data: { name: string; description?: string; active?: boolean }) =>
    api.post<PunishmentReason>('/admin/punishment_reasons', data),
  updatePunishmentReason: (
    id: number,
    data: { name?: string; description?: string; active?: boolean },
  ) => api.put<PunishmentReason>(`/admin/punishment_reasons/${id}`, data),
  deletePunishmentReason: (id: number) => api.delete(`/admin/punishment_reasons/${id}`),

  // Purchases
  getPurchases: (params?: { page?: number; per?: number; search?: string; status?: string }) =>
    api.get<{ purchases: Purchase[]; pagination: { total: number; page: number; per: number } }>('/admin/purchases', { params }),
  getPurchase: (purchaseId: number) => api.get<Purchase>(`/admin/purchases/${purchaseId}`),

  // Removed Players
  getRemovedPlayers: (params?: { page?: number; per_page?: number }) =>
    api.get<{ removed_players: RemovedPlayer[]; total: number; page: number }>(
      '/admin/removed_players',
      { params },
    ),
  restorePlayer: (nickname: string) =>
    api.post(`/admin/removed_players/${encodeURIComponent(nickname)}/restore`),

  // Gallery
  getGalleries: (params?: { page?: number; per_page?: number }) =>
    api.get<{ galleries: GalleryAlbum[]; total: number; page: number }>('/admin/gallery', {
      params,
    }),
  createGallery: (data: { title: string; description?: string; photoUrls?: string[] }) =>
    api.post<GalleryAlbum>('/admin/gallery', data),
  updateGallery: (id: number, data: { title?: string; description?: string }) =>
    api.put<GalleryAlbum>(`/admin/gallery/${id}`, data),
  deleteGallery: (id: number) => api.delete(`/admin/gallery/${id}`),

  // Players
  getPlayers: (params?: { page?: number; per_page?: number }) =>
    api.get<{ players: AdminPlayer[]; total: number; page: number }>('/admin/players', {
      params,
    }),
  updatePlayer: (nickname: string, data: Partial<AdminPlayer>) =>
    api.put<AdminPlayer>(`/admin/players/${encodeURIComponent(nickname)}`, data),
  banPlayer: (nickname: string, data: { reason: string; duration?: string }) =>
    api.post(`/admin/players/${encodeURIComponent(nickname)}/punishments`, data),
  mutePlayer: (nickname: string, data: { reason: string; duration: string }) =>
    api.post(`/admin/players/${encodeURIComponent(nickname)}/mute`, data),
  cancelPunishment: (nickname: string, data: { reason: string }) =>
    api.post(`/admin/players/${encodeURIComponent(nickname)}/cancel_punishment`, data),
  changePlayerPassword: (nickname: string, data: { password: string }) =>
    api.post(`/admin/players/${encodeURIComponent(nickname)}/change_password`, data),
  deletePlayer: (nickname: string) =>
    api.delete(`/admin/players/${encodeURIComponent(nickname)}`),
  reportPlayer: (nickname: string, data: { reported_user_id: number; reason: string; attachments?: unknown[] }) =>
    api.post(`/admin/players/${encodeURIComponent(nickname)}/report`, data),

  // Removed Players - add
  addRemovedPlayer: (data: { nickname: string; reason: string }) =>
    api.post('/admin/removed_players', data),

  // Purchases - refund
  refundPurchase: (purchaseId: number) =>
    api.post(`/admin/purchases/${purchaseId}/refund`),

  // Player edit data
  editPlayer: (nickname: string) =>
    api.get(`/admin/players/${encodeURIComponent(nickname)}/edit_player`),

  // Appeal data for admin
  getAppealData: (appealId: number) =>
    api.get(`/admin/get_appeal_data/${appealId}`),

  // Update player account
  updateAccount: (
    nickname: string,
    data: { email?: string; discord?: string; pass?: string; is_sponsor?: boolean },
  ) =>
    api.post(`/admin/players/${encodeURIComponent(nickname)}/update_account`, data),
}

export default adminApi
