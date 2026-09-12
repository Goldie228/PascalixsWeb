import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import notificationApi from '@/services/notificationApi'
import type { Notification } from '@/types'

export function useNotifications(params?: { page?: number; per_page?: number }) {
  return useQuery({
    queryKey: ['notifications', params],
    queryFn: () => notificationApi.getNotifications(params),
    staleTime: 1000 * 30, // 30 seconds
    refetchInterval: 30000, // refetch every 30 seconds
  })
}

export function useMarkAsRead() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (id: number) => notificationApi.markAsRead(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['notifications'] })
    },
  })
}

export function useMarkAllAsRead() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: () => notificationApi.markAllAsRead(),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['notifications'] })
    },
  })
}
