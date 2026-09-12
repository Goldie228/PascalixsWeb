import { useQuery } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { Link } from 'react-router-dom'
import { Users, Ban, FileText, TrendingUp, Clock, AlertTriangle, Shield, ChevronRight } from 'lucide-react'
import api from '@/services/api'
import { Card, CardContent } from '@/components/ui/Card'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import AdminLayout from '@/components/admin/AdminLayout'

interface AdminStatsData {
  total_users?: number
  active_users?: number
  active_punishments?: number
  pending_appeals?: number
  total_punishments?: number
}

function AdminOverview() {
  const { data: stats, isLoading: statsLoading } = useQuery<AdminStatsData>({
    queryKey: ['admin-stats'],
    queryFn: () => api.get('/admin/stats').then((res) => res.data),
    staleTime: 1000 * 60 * 5,
  })

  const { data: recentPunishments } = useQuery({
    queryKey: ['admin-recent-punishments'],
    queryFn: () => api.get('/admin/punishments', { params: { per_page: 5 } }),
    staleTime: 1000 * 60 * 5,
  })

  const { data: pendingAppeals } = useQuery({
    queryKey: ['admin-pending-appeals'],
    queryFn: () => api.get('/admin/appeals', { params: { per_page: 5 } }),
    staleTime: 1000 * 60 * 5,
  })

  const resolutionRate = stats?.total_punishments
    ? (((stats.total_punishments - (stats.active_punishments || 0)) / stats.total_punishments) * 100).toFixed(1)
    : null

  const quickStats = [
    {
      title: 'Total Users',
      value: stats?.total_users || '—',
      icon: Users,
      color: 'text-blue-400',
      bg: 'bg-blue-400/10',
      link: '/admin/users',
    },
    {
      title: 'Active Punishments',
      value: stats?.active_punishments ?? '—',
      icon: Ban,
      color: 'text-red-400',
      bg: 'bg-red-400/10',
      link: '/admin/punishments',
    },
    {
      title: 'Pending Appeals',
      value: stats?.pending_appeals ?? '—',
      icon: FileText,
      color: 'text-amber-400',
      bg: 'bg-amber-400/10',
      link: '/admin/appeals',
    },
    {
      title: 'Resolution Rate',
      value: resolutionRate ? `${resolutionRate}%` : '—',
      icon: TrendingUp,
      color: 'text-green-400',
      bg: 'bg-green-400/10',
      link: '/admin/stats',
    },
  ]

  return (
    <AdminLayout>
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3 }}
      >
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-base-content">Admin Dashboard</h1>
          <p className="text-sm text-neutral/60">Overview of server status and recent activity</p>
        </div>

        {/* Quick Stats Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          {quickStats.map((stat) => {
            const Icon = stat.icon
            return (
              <Link key={stat.title} to={stat.link} className="block">
                <Card className="hover:shadow-md transition-shadow cursor-pointer">
                  <CardContent className="p-6">
                    <div className="flex items-start justify-between">
                      <div>
                        <p className="text-neutral/60 text-sm mb-1">{stat.title}</p>
                        <p className="text-3xl font-bold text-base-content">{stat.value}</p>
                      </div>
                      <div className={`p-3 rounded-lg ${stat.bg}`}>
                        <Icon className={`w-6 h-6 ${stat.color}`} />
                      </div>
                    </div>
                  </CardContent>
                </Card>
              </Link>
            )
          })}
        </div>

        {/* Recent Activity */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mt-6">
          {/* Recent Punishments */}
          <Card>
            <CardContent className="p-6">
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-2">
                  <AlertTriangle className="w-5 h-5 text-red-400" />
                  <h3 className="text-lg font-semibold text-base-content">Recent Punishments</h3>
                </div>
                <Link to="/admin/punishments" className="text-blue-400 hover:text-blue-300 text-sm flex items-center">
                  View all <ChevronRight className="w-4 h-4" />
                </Link>
              </div>
              <div className="space-y-2">
                {(() => {
                  const puns = recentPunishments?.data as { punishments?: Array<{
                    id: number
                    user?: { username?: string; discord_username?: string }
                    type: string
                    reason: string
                    resolved?: boolean
                    active?: boolean
                    issued_at: string
                  }> } | undefined
                  return (puns?.punishments?.slice(0, 5) || []).map((p) => (
                    <div key={p.id} className="flex items-center justify-between p-3 bg-base-200 rounded-lg">
                      <div>
                        <p className="font-medium text-base-content">
                          {p.user?.username || p.user?.discord_username || 'Unknown'}
                        </p>
                        <p className="text-neutral/60 text-sm">{p.reason}</p>
                      </div>
                      <div className="text-right">
                        <span className={`inline-flex items-center px-2 py-1 rounded text-xs font-medium ${
                          p.resolved || !p.active
                            ? 'bg-success/10 text-success'
                            : 'bg-error/10 text-error'
                        }`}>
                          {p.resolved || !p.active ? 'Resolved' : 'Active'}
                        </span>
                        <p className="text-neutral/60 text-xs mt-1">
                          {new Date(p.issued_at).toLocaleDateString()}
                        </p>
                      </div>
                    </div>
                  ))
                })()}
                {(!recentPunishments?.data || !(recentPunishments.data as any)?.punishments?.length) && (
                  <p className="text-neutral/60 text-center py-4">No recent punishments</p>
                )}
              </div>
            </CardContent>
          </Card>

          {/* Pending Appeals */}
          <Card>
            <CardContent className="p-6">
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-2">
                  <FileText className="w-5 h-5 text-amber-400" />
                  <h3 className="text-lg font-semibold text-base-content">Pending Appeals</h3>
                </div>
                <Link to="/admin/appeals" className="text-blue-400 hover:text-blue-300 text-sm flex items-center">
                  View all <ChevronRight className="w-4 h-4" />
                </Link>
              </div>
              <div className="space-y-2">
                {(() => {
                  const appls = pendingAppeals?.data as { appeals?: Array<{
                    id: number
                    player?: { username?: string }
                    user_id: number
                    reason: string
                    status: string
                    created_at: string
                  }> } | undefined
                  return (appls?.appeals?.slice(0, 5) || []).map((a) => (
                    <div key={a.id} className="flex items-center justify-between p-3 bg-base-200 rounded-lg">
                      <div>
                        <p className="font-medium text-base-content">
                          {a.player?.username || `User #${a.user_id}`}
                        </p>
                        <p className="text-neutral/60 text-sm line-clamp-1">{a.reason}</p>
                      </div>
                      <div className="text-right">
                        <span className="inline-flex items-center px-2 py-1 rounded text-xs font-medium bg-amber-400/10 text-amber-400">
                          Pending
                        </span>
                        <p className="text-neutral/60 text-xs mt-1">
                          {new Date(a.created_at).toLocaleDateString()}
                        </p>
                      </div>
                    </div>
                  ))
                })()}
                {(!pendingAppeals?.data || !(pendingAppeals.data as any)?.appeals?.length) && (
                  <p className="text-neutral/60 text-center py-4">No pending appeals</p>
                )}
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Quick Actions */}
        <Card className="mt-6">
          <CardContent className="p-6">
            <div className="flex items-center gap-2 mb-4">
              <Shield className="w-5 h-5 text-blue-400" />
              <h3 className="text-lg font-semibold text-base-content">Quick Actions</h3>
            </div>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              <Link to="/admin/users" className="p-4 bg-base-200 rounded-lg hover:bg-base-300 transition-colors text-center">
                <Users className="w-6 h-6 text-blue-400 mx-auto mb-2" />
                <p className="text-base-content text-sm font-medium">Manage Users</p>
              </Link>
              <Link to="/admin/punishments" className="p-4 bg-base-200 rounded-lg hover:bg-base-300 transition-colors text-center">
                <Ban className="w-6 h-6 text-red-400 mx-auto mb-2" />
                <p className="text-base-content text-sm font-medium">Manage Punishments</p>
              </Link>
              <Link to="/admin/appeals" className="p-4 bg-base-200 rounded-lg hover:bg-base-300 transition-colors text-center">
                <FileText className="w-6 h-6 text-amber-400 mx-auto mb-2" />
                <p className="text-base-content text-sm font-medium">Review Appeals</p>
              </Link>
              <Link to="/admin/stats" className="p-4 bg-base-200 rounded-lg hover:bg-base-300 transition-colors text-center">
                <TrendingUp className="w-6 h-6 text-green-400 mx-auto mb-2" />
                <p className="text-base-content text-sm font-medium">View Statistics</p>
              </Link>
            </div>
          </CardContent>
        </Card>
      </motion.div>
    </AdminLayout>
  )
}

export default AdminOverview
