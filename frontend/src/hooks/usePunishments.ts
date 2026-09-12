import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import adminApi from '@/services/adminApi'

export function usePunishments(params?: { page?: number; per_page?: number }) {
  return useQuery({
    queryKey: ['admin-punishments', params],
    queryFn: () => adminApi.getPunishments(params),
    staleTime: 1000 * 60 * 5,
  })
}

export function useCreatePunishment() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (data: { user_id: number; type: string; reason: string; duration?: string }) =>
      adminApi.createPunishment(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-punishments'] })
    },
  })
}

export function useResolvePunishment() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (punishmentId: number) => adminApi.resolvePunishment(punishmentId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-punishments'] })
    },
  })
}
