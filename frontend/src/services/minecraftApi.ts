import api from './api'

export interface MinecraftRegisterData {
  nickname: string
  password: string
  password_confirmation: string
}

export interface MinecraftVerifyData {
  nickname: string
  code: string
}

export interface MinecraftRegisterResponse {
  status: 'pending' | 'success' | 'error'
  message?: string
  errors?: Record<string, string[]>
  redirectUrl?: string
}

export const minecraftApi = {
  // Register Minecraft account (step 1: submit credentials)
  register: (data: MinecraftRegisterData) =>
    api.post<MinecraftRegisterResponse>('/auth/register-minecraft', data),

  // Verify Minecraft account (step 2: submit verification code)
  verify: (data: MinecraftVerifyData) =>
    api.post<MinecraftRegisterResponse>('/auth/verify-minecraft', data),

  // Resend verification code
  resendCode: (nickname: string) =>
    api.post<MinecraftRegisterResponse>('/auth/resend-minecraft-code', { nickname }),

  // Check registration status
  checkStatus: (nickname: string) =>
    api.get<MinecraftRegisterResponse>(`/auth/minecraft-status/${nickname}`),

  // Legacy alias
  verify: (username: string) =>
    api.post('/auth/register_minecraft', { username }),

  // Gateway: Minecraft server status
  gameStatus: () =>
    api.get('/api/v1/minecraft/status'),

  // Gateway: Sync events from game server
  gameSync: (data: Record<string, unknown>) =>
    api.post('/api/v1/minecraft/sync', data),
}

export default minecraftApi
