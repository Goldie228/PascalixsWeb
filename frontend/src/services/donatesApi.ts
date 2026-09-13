import api from './api'

export interface Donation {
  id: number
  amount: number
  currency: string
  status: string
  created_at: string
  updated_at: string
}

export interface DonationsResponse {
  donates: Donation[]
  total: number
  page: number
}

export const donatesApi = {
  list: (params?: {
    page?: number
    per_page?: number
  }) => api.get<DonationsResponse>('/my_donates', { params }),
}

export default donatesApi
