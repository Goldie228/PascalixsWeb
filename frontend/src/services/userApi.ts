import api from './api'
import type { User, Punishment, AvatarData, ReportAttachment, PunishmentAppealData } from '@/types'

export interface TwoFactorVerifyData {
  otp_attempt: string
}

export interface TwoFactorVerifyResponse {
  success: boolean
  message?: string
  error?: string
  qr_code_url?: string
  valid_until?: string
}

export interface TwoFactorResendResponse {
  success: boolean
  message?: string
  valid_until?: string
}

export interface AccountDeleteResponse {
  success: boolean
  message?: string
  error?: string
}

export interface EmailVerificationResponse {
  success: boolean
  message?: string
  error?: string
  email?: string
}

export interface PasswordResetCheckResponse {
  verified: boolean
  message?: string
  error?: string
}

export const userApi = {
  getProfile: (nickname: string) => api.get<User>(`/players/${nickname}`),
  getPublicProfile: (nickname: string) => api.get<User>(`/players/${nickname}`),
  getPunishments: (nickname: string) => api.get<Punishment[]>(`/players/${nickname}/punishments`),
  getPasswordCheck: (nickname: string) =>
    api.get<{ hasPassword: boolean }>(`/players/${nickname}/password_check`),
  validatePassword: (nickname: string, password: string) =>
    api.post<{ valid: boolean }>('/players/validate_password', { nickname, password }),
  getUserData: (userId: number) => api.get<User>(`/users/${userId}`),
  lookupEmail: (email: string) =>
    api.get<{ found: boolean; user_id: number }>(`/lookup_email?email=${email}`),

  // Change Email
  requestChangeEmail: (data: { email: string; password: string }) =>
    api.post('/account/change_email_process', data),

  // Reset Password
  sendResetPasswordEmail: (data: { email: string }) =>
    api.post('/validate_new_password', data),
  resetPassword: (data: {
    current_password?: string
    new_password: string
    password_confirmation: string
  }) => api.post('/validate_new_password', data),

  // About Me
  updateAboutMe: (data: { about_me: string }) =>
    api.post('/profile/update_about_me', data),

  // Social Integrations
  bindYoutube: (data: { channel_id: string }) => api.post('/integrations/youtube', data),
  unbindYoutube: () => api.delete('/profile/youtube_unbind'),
  bindTiktok: (data: { tiktok_id: string }) => api.post('/integrations/tiktok', data),
  unbindTiktok: () => api.delete('/profile/tiktok_unbind'),
  bindTwitch: (data: { twitch_id: string }) => api.post('/integrations/twitch', data),
  unbindTwitch: () => api.delete('/profile/twitch_unbind'),

  // Bank Account
  getBankAccount: () => api.get('/profile/bank_account'),
  updateBankAccount: (data: {
    account_number: string
    bank_name: string
    swift_code: string
  }) => api.put('/profile/bank_account', data),

  // Report User
  reportUser: (data: FormData) =>
    api.post('/user/add_report', data, { headers: { 'Content-Type': 'multipart/form-data' } }),
  getReport: (reportId: number | string) =>
    api.get(`/reports/${reportId}`),
  revokeReport: (reportId: number) =>
    api.post(`/revoke_report/${reportId}`),

  // Avatar
  getAvatar: (userId: number) => api.get<AvatarData>(`/discord_avatar/${userId}`),
  uploadAvatar: (userId: number, file: File) => {
    const formData = new FormData()
    formData.append('avatar', file)
    return api.post(`/discord_avatar/${userId}`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    })
  },
  deleteAvatar: (userId: number) => api.delete(`/discord_avatar/${userId}`),

  // Punishment Appeal
  getAppealData: (punishmentId: number) =>
    api.get<PunishmentAppealData>(`/load_punishment_appeal/${punishmentId}`),
  submitAppeal: (punishmentId: number, message: string) =>
    api.post(`/send_punishment_appeal/${punishmentId}`, { message }),
  revokeAppeal: (punishmentId: number) =>
    api.delete(`/send_punishment_appeal_revoke/${punishmentId}`),

  // --- 2FA ---
  verify2FA: (data: TwoFactorVerifyData) =>
    api.post<TwoFactorVerifyResponse>('/two_factor_auth/verify', data),
  resend2FACode: () =>
    api.post<TwoFactorResendResponse>('/two_factor_auth/resend_code'),
  get2FAStatus: () =>
    api.get<{ enabled: boolean; qr_code_url?: string }>('/two_factor_auth/status'),

  // --- Account Deletion ---
  deleteAccount: (password: string) =>
    api.post<AccountDeleteResponse>('/account/delete', { password }),
  confirmAccountDelete: (token: string) =>
    api.get<AccountDeleteResponse>(`/account/delete/confirm/${token}`),
  cancelAccountDelete: () =>
    api.post<AccountDeleteResponse>('/account/delete/cancel'),

  // --- Email Verification ---
  resendEmailVerification: (email: string) =>
    api.post<EmailVerificationResponse>('/account/resend_verification', { email }),
  checkEmailVerificationStatus: (email: string) =>
    api.get<EmailVerificationResponse>(`/account/verification_status/${email}`),

  // --- Password Reset Check ---
  checkPasswordResetStatus: (email: string) =>
    api.get<PasswordResetCheckResponse>(`/account/password_reset_status/${email}`),
}

export default userApi
