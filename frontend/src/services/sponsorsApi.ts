import api from './api'

export interface Sponsor {
  id: number
  minecraft_nickname: string
  discord_username: string
  discord_avatar_url: string
  is_sponsor: boolean
  sponsor_level: 'gold' | 'silver' | 'bronze' | 'none'
  created_at: string
}

export interface SponsorsResponse {
  sponsors: Sponsor[]
  total: number
  page: number
  per_page: number
  total_pages: number
}

export interface SponsorsFilters {
  search?: string
  sort?: 'minecraft_nickname' | 'discord_username' | 'created_at'
  order?: 'asc' | 'desc'
  page?: number
  per_page?: number
}

export const sponsorsApi = {
  list: (params?: SponsorsFilters) => api.get<SponsorsResponse>('/sponsors', { params }),
}

export default sponsorsApi
