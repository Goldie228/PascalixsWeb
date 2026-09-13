import api from './api'

export interface Player {
  id: number
  username: string
  email: string
  role: string
  is_added: boolean
  is_sponsor: boolean
  created_at: string
  last_login_at?: string
}

export interface PlayersResponse {
  players: Player[]
  total: number
  page: number
}

export const playersApi = {
  list: (params?: {
    page?: number
    per_page?: number
    search?: string
    role?: string
    sort?: string
    order?: 'asc' | 'desc'
  }) => api.get<PlayersResponse>('/players', { params }),
}

export default playersApi
