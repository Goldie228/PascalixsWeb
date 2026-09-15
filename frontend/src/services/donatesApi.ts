import api from './api'
import type {
  PurchaseCreateInput,
  PurchaseRecord,
  PurchaseType,
  ProductPrice,
  PunishmentPriceResponse,
  SearchUser,
  UserSearchResponse,
} from '@/types'

export interface Donation {
  id: number
  amount: number
  currency: string
  status: string
  purchase_type: string
  created_at: string
  updated_at: string
  product_name?: string
}

export interface DonationsResponse {
  donates: Donation[]
  total: number
  page: number
  per_page: number
  total_pages: number
}

export interface DonationFilters {
  status?: string
  purchase_type?: string
  date_from?: string
  date_to?: string
  sort_by?: 'created_at' | 'amount' | 'status' | 'purchase_type'
  sort_order?: 'asc' | 'desc'
  page?: number
  per_page?: number
}

export interface PurchaseListFilters {
  purchase_type?: PurchaseType
  status?: string
  target_user_id?: string | number
  page?: number
  per_page?: number
}

export interface SearchUsersParams {
  page?: number
  search?: string
  per_page?: number
}

export const donatesApi = {
  list: (filters?: DonationFilters) =>
    api.get<DonationsResponse>('/my_donates', { params: filters }),

  // GET /api/v1/product/:product_type -> { type, price }
  getProductPrice: (productType: string) =>
    api.get<ProductPrice>(`/product/${encodeURIComponent(productType.toLowerCase())}`),

  // GET /get_unban_price -> { total_price, punishments }
  getUnbanPrice: () => api.get<PunishmentPriceResponse>('/get_unban_price'),

  // GET /get_unmute_price -> { total_price, punishments }
  getUnmutePrice: () => api.get<PunishmentPriceResponse>('/get_unmute_price'),

  // GET /get_not_public_users?page=&search=&per_page= -> { users, has_more }
  searchUsers: ({ page = 1, search = '', per_page = 10 }: SearchUsersParams = {}) =>
    api.get<UserSearchResponse>('/get_not_public_users', {
      params: { page, search, per_page },
    }),

  // POST /purchases — builds multipart form (purchase[...], receipt, actor_user_id).
  createPurchase: (data: PurchaseCreateInput, actorUserId: string | number) => {
    const formData = new FormData()
    formData.append('purchase[purchase_type]', data.purchase_type)
    formData.append('purchase[amount]', String(data.amount))
    formData.append('purchase[currency]', data.currency || 'USD')
    formData.append(
      'purchase[purchaser_user_id]',
      String(data.purchaser_user_id ?? actorUserId),
    )
    if (data.target_user_id) {
      formData.append('purchase[target_user_id]', String(data.target_user_id))
    }
    if (data.punishment_id) {
      formData.append('purchase[punishment_id]', String(data.punishment_id))
    }
    if (data.receipt) {
      formData.append('receipt', data.receipt)
    }
    formData.append('actor_user_id', String(actorUserId))

    return api.post<PurchaseRecord>('/purchases', formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    })
  },

  // PATCH /purchases/:id — replace receipt (multipart: receipt, receipt_to_purge).
  replaceReceipt: (id: string, formData: FormData) =>
    api.patch<PurchaseRecord>(`/purchases/${id}`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    }),

  // DELETE /purchases/:id
  deletePurchase: (id: string) => api.delete(`/purchases/${id}`),

  // GET /purchases?purchase_type=&status=&target_user_id=
  listPurchases: (filters: PurchaseListFilters = {}) =>
    api.get<PurchaseRecord[]>('/purchases', { params: filters }),
}

export default donatesApi
export type { SearchUser }
