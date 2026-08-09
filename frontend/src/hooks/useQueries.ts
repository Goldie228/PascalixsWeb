import { useQuery } from '@tanstack/react-query'
import { serverApi } from '@/services/api'

export function useServerStats() {
  return useQuery({
    queryKey: ['server-stats'],
    queryFn: () => serverApi.stats(),
    refetchInterval: 30000,
  })
}

export function useNews() {
  return useQuery({
    queryKey: ['news'],
    queryFn: () => serverApi.news(),
  })
}

export function useVotes() {
  return useQuery({
    queryKey: ['votes'],
    queryFn: () => serverApi.votes(),
  })
}
