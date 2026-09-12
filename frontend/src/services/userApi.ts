import api from './api'
import type { User, Punishment } from '@/types'

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
}

export default userApi
