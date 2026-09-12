import { useQuery } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import api from '@/services/api'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { Badge } from '@/components/ui/Badge'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import ServerStats from '@/components/ServerStats'
import NewsList from '@/components/NewsList'

interface Punishment {
  id: number
  type: string
  active: boolean
  issued_at: string
  user?: { username?: string }
}

function Dashboard() {
  const { data: punishmentsData, isLoading: punishmentsLoading } = useQuery({
    queryKey: ['recent-punishments'],
    queryFn: async () => {
      const response = await api.get('/admin/punishments', { params: { per_page: 5 } })
      return response.data
    },
    staleTime: 1000 * 60 * 5,
    retry: 1,
  })

  useQuery({
    queryKey: ['news'],
    queryFn: () => api.get('/news'),
    staleTime: 1000 * 60 * 15,
  })

  return (
    <div className="min-h-screen bg-base-100 py-8">
      <div className="container mx-auto max-w-4xl px-4">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
        >
          <h1 className="mb-6 text-3xl font-bold text-base-content">Dashboard</h1>

          <ServerStats />

          <div className="mt-6 grid gap-6 md:grid-cols-2">
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.1 }}
            >
              <Card>
                <CardHeader>
                  <CardTitle>Recent Punishments</CardTitle>
                </CardHeader>
                <CardContent>
                  {punishmentsLoading ? (
                    <div className="flex justify-center py-8">
                      <LoadingSpinner size="lg" />
                    </div>
                  ) : (
                    <div className="space-y-2">
                      {punishmentsData?.data?.punishments?.slice(0, 5).map((p: Punishment) => (
                        <div
                          key={p.id}
                          className="flex items-center justify-between rounded-lg bg-base-200 p-2"
                        >
                          <div>
                            <span className="font-medium text-base-content capitalize">
                              {p.type.replace(/_/g, ' ')}
                            </span>
                          </div>
                          <div className="flex items-center gap-2">
                            <Badge variant={p.active ? 'error' : 'success'}>
                              {p.active ? 'Active' : 'Resolved'}
                            </Badge>
                            <span className="text-xs text-neutral/60">
                              {new Date(p.issued_at).toLocaleDateString()}
                            </span>
                          </div>
                        </div>
                      ))}
                      {!punishmentsLoading &&
                        !punishmentsData?.data?.punishments?.length && (
                          <p className="py-4 text-center text-neutral/60">No punishments found.</p>
                        )}
                    </div>
                  )}
                </CardContent>
              </Card>
            </motion.div>

            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.2 }}
            >
              <Card>
                <CardHeader>
                  <CardTitle>News</CardTitle>
                </CardHeader>
                <CardContent>
                  <NewsList />
                </CardContent>
              </Card>
            </motion.div>
          </div>
        </motion.div>
      </div>
    </div>
  )
}

export default Dashboard
