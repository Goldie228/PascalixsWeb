import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import adminApi from '@/services/adminApi'

export function useAppeals(params?: { page?: number; per_page?: number }) {
  return useQuery({
    queryKey: ['admin-appeals', params],
    queryFn: () => adminApi.getAppeals(params),
    staleTime: 1000 * 60 * 5,
  })
}

export function useApproveAppeal() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (appealId: number) => adminApi.approveAppeal(appealId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-appeals'] })
    },
  })
}

export function useRejectAppeal() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: ({ appealId, reason }: { appealId: number; reason: string }) =>
      adminApi.rejectAppeal(appealId, reason),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-appeals'] })
    },
  })
}
