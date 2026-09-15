import api from './api'

export interface Player {
  id: number
  minecraft_nickname: string
  discord_username: string
  discord_avatar_url: string
  role_id: number
  role_name: string
  role_color: string
  is_sponsor: boolean
  has_tiktok: boolean
  has_twitch: boolean
  has_youtube: boolean
  punishment_status: number // 0=none, 1=none, 2=muted, 3=banned
  status: 'online' | 'offline' | 'ban'
  is_online: boolean
  created_at: string
}

export interface PlayersResponse {
  players: Player[]
  total: number
  page: number
  per_page: number
  total_pages: number
}

export interface PlayersFilters {
  search?: string
  role?: string
  sort?: 'minecraft_nickname' | 'discord_username' | 'role_weight'
  order?: 'asc' | 'desc'
  filters?: string[] // 'online' | 'offline'
  page?: number
  per_page?: number
}

export const playersApi = {
  list: (params?: PlayersFilters) => api.get<PlayersResponse>('/players', { params }),
}

export default playersApi
