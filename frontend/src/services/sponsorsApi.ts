import api from './api'

export interface Sponsor {
  id: number
  username: string
  email: string
  role: string
  is_sponsor: boolean
  created_at: string
}

export interface SponsorsResponse {
  sponsors: Sponsor[]
  total: number
  page: number
}

export const sponsorsApi = {
  list: (params?: {
    page?: number
    per_page?: number
    search?: string
  }) => api.get<SponsorsResponse>('/sponsors', { params }),
}

export default sponsorsApi
