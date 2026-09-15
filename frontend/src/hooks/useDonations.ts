import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { donatesApi } from '@/services/donatesApi'
import type {
  PurchaseCreateInput,
  PurchaseRecord,
  PurchaseType,
  ProductPrice,
  PunishmentPriceResponse,
  SearchUser,
  UserSearchResponse,
} from '@/types'

// GET /get_unban_price -> { total_price, punishments }
export function useUnbanPrice() {
  return useQuery({
    queryKey: ['unban-price'],
    queryFn: () => donatesApi.getUnbanPrice(),
  })
}

// GET /get_unmute_price -> { total_price, punishments }
export function useUnmutePrice() {
  return useQuery({
    queryKey: ['unmute-price'],
    queryFn: () => donatesApi.getUnmutePrice(),
  })
}

// GET /api/v1/product/:product_type -> { type, price }
export function useProductPrice(productType: PurchaseType, enabled = true) {
  return useQuery({
    queryKey: ['product-price', productType],
    queryFn: () => donatesApi.getProductPrice(productType),
    enabled,
  })
}

// GET /get_not_public_users?page=&search=&per_page= -> { users, has_more }
export function useSearchUsers(params: {
  page: number
  search: string
  per_page?: number
}) {
  return useQuery({
    queryKey: ['user-search', params],
    queryFn: () => donatesApi.searchUsers(params),
  })
}

// POST /purchases — create a purchase with an optional receipt upload.
export function useCreatePurchase() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (data: { input: PurchaseCreateInput; actorUserId: string | number }) =>
      donatesApi.createPurchase(data.input, data.actorUserId),
    onSuccess: (data: PurchaseRecord) => {
      queryClient.invalidateQueries({ queryKey: ['purchases'] })
      queryClient.invalidateQueries({ queryKey: ['my-donates'] })
      return data
    },
  })
}
