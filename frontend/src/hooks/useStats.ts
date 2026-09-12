import { useQuery } from '@tanstack/react-query'
import adminApi from '@/services/adminApi'

export function useStats() {
  return useQuery({
    queryKey: ['admin-stats'],
    queryFn: () => adminApi.getStats(),
    staleTime: 1000 * 60 * 5,
  })
}
