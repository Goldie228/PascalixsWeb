import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import adminApi from '@/services/adminApi'
import type { User } from '@/types'

export function useUsers(params?: { page?: number; per_page?: number; search?: string }) {
  return useQuery({
    queryKey: ['admin-users', params],
    queryFn: () => adminApi.getUsers(params),
    staleTime: 1000 * 60 * 5, // 5 minutes
  })
}

export function useUser(userId: number | undefined) {
  return useQuery({
    queryKey: ['admin-user', userId],
    queryFn: () => adminApi.updateUser(userId!, {}), // placeholder - will be updated
    enabled: !!userId,
    staleTime: 1000 * 60 * 5,
  })
}

export function useUpdateUser() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (data: { userId: number; updates: Partial<User> }) =>
      adminApi.updateUser(data.userId, data.updates),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-users'] })
      queryClient.invalidateQueries({ queryKey: ['admin-user'] })
    },
  })
}

export function useDeleteUser() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (userId: number) => adminApi.deleteUser(userId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-users'] })
    },
  })
}
