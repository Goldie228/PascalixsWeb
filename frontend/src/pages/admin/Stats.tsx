import { motion } from 'framer-motion'
import { Users, Ban, AlertTriangle, TrendingUp, Calendar, Clock, FileText } from 'lucide-react'
import { useStats } from '@/hooks/useStats'
import { Card, CardContent } from '@/components/ui/Card'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import AdminLayout from '@/components/admin/AdminLayout'

interface StatsOverview {
  total_users: number
  active_users: number
  total_punishments: number
  active_punishments: number
  total_appeals: number
  pending_appeals: number
  new_users_today: number
  new_users_this_week: number
  punishments_today: number
  punishments_this_week: number
}

function AdminStats() {
  const { data, isLoading } = useStats()
  const stats = (data?.data as StatsOverview | undefined)

  const statCards = [
    {
      title: 'Total Users',
      value: stats?.total_users || 0,
      change: `+${stats?.new_users_today || 0} today`,
      icon: Users,
      color: 'text-blue-400',
      bg: 'bg-blue-400/10',
    },
    {
      title: 'Active Users',
      value: stats?.active_users || 0,
      change: `${((stats?.active_users || 0) / (stats?.total_users || 1) * 100).toFixed(1)}% of total`,
      icon: TrendingUp,
      color: 'text-green-400',
      bg: 'bg-green-400/10',
    },
    {
      title: 'Total Punishments',
      value: stats?.total_punishments || 0,
      change: `${stats?.punishments_today || 0} today`,
      icon: Ban,
      color: 'text-red-400',
      bg: 'bg-red-400/10',
    },
    {
      title: 'Active Punishments',
      value: stats?.active_punishments || 0,
      change: `${(stats?.total_punishments || 0) - (stats?.active_punishments || 0)} resolved`,
      icon: AlertTriangle,
      color: 'text-amber-400',
      bg: 'bg-amber-400/10',
    },
    {
      title: 'Total Appeals',
      value: stats?.total_appeals || 0,
      change: `${stats?.pending_appeals || 0} pending`,
      icon: FileText,
      color: 'text-purple-400',
      bg: 'bg-purple-400/10',
    },
    {
      title: 'New This Week',
      value: stats?.new_users_this_week || 0,
      change: `${stats?.punishments_this_week || 0} punishments`,
      icon: Calendar,
      color: 'text-cyan-400',
      bg: 'bg-cyan-400/10',
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
          <h1 className="text-2xl font-bold text-base-content">Statistics</h1>
          <p className="text-sm text-neutral/60">Overview of server activity and metrics</p>
        </div>

        {isLoading ? (
          <div className="flex items-center justify-center min-h-[400px]">
            <LoadingSpinner size="lg" />
          </div>
        ) : (
          <>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {statCards.map((stat) => {
                const Icon = stat.icon
                return (
                  <Card key={stat.title}>
                    <CardContent className="p-6">
                      <div className="flex items-start justify-between">
                        <div>
                          <p className="text-neutral/60 text-sm mb-1">{stat.title}</p>
                          <p className="text-3xl font-bold text-base-content">{stat.value.toLocaleString()}</p>
                          <p className="text-neutral/60 text-xs mt-1">{stat.change}</p>
                        </div>
                        <div className={`p-3 rounded-lg ${stat.bg}`}>
                          <Icon className={`w-6 h-6 ${stat.color}`} />
                        </div>
                      </div>
                    </CardContent>
                  </Card>
                )
              })}
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mt-6">
              {/* Recent Activity */}
              <Card>
                <CardContent className="p-6">
                  <div className="flex items-center gap-2 mb-4">
                    <Clock className="w-5 h-5 text-blue-400" />
                    <h3 className="text-lg font-semibold text-base-content">Recent Activity</h3>
                  </div>
                  <div className="space-y-3">
                    <div className="flex items-center justify-between p-3 bg-base-200 rounded-lg">
                      <div>
                        <p className="text-base-content text-sm">New user registrations</p>
                        <p className="text-neutral/60 text-xs">Last 24 hours</p>
                      </div>
                      <span className="text-2xl font-bold text-green-400">{stats?.new_users_today || 0}</span>
                    </div>
                    <div className="flex items-center justify-between p-3 bg-base-200 rounded-lg">
                      <div>
                        <p className="text-base-content text-sm">Punishments issued</p>
                        <p className="text-neutral/60 text-xs">Last 24 hours</p>
                      </div>
                      <span className="text-2xl font-bold text-red-400">{stats?.punishments_today || 0}</span>
                    </div>
                    <div className="flex items-center justify-between p-3 bg-base-200 rounded-lg">
                      <div>
                        <p className="text-base-content text-sm">Appeals pending</p>
                        <p className="text-neutral/60 text-xs">Awaiting review</p>
                      </div>
                      <span className="text-2xl font-bold text-amber-400">{stats?.pending_appeals || 0}</span>
                    </div>
                  </div>
                </CardContent>
              </Card>

              {/* Weekly Summary */}
              <Card>
                <CardContent className="p-6">
                  <div className="flex items-center gap-2 mb-4">
                    <TrendingUp className="w-5 h-5 text-green-400" />
                    <h3 className="text-lg font-semibold text-base-content">Weekly Summary</h3>
                  </div>
                  <div className="space-y-3">
                    <div className="flex items-center justify-between p-3 bg-base-200 rounded-lg">
                      <p className="text-base-content text-sm">New users this week</p>
                      <span className="text-xl font-bold text-green-400">{stats?.new_users_this_week || 0}</span>
                    </div>
                    <div className="flex items-center justify-between p-3 bg-base-200 rounded-lg">
                      <p className="text-base-content text-sm">Punishments this week</p>
                      <span className="text-xl font-bold text-red-400">{stats?.punishments_this_week || 0}</span>
                    </div>
                    <div className="flex items-center justify-between p-3 bg-base-200 rounded-lg">
                      <p className="text-base-content text-sm">Resolution rate</p>
                      <span className="text-xl font-bold text-blue-400">
                        {stats?.total_punishments
                          ? (((stats.total_punishments - stats.active_punishments) / stats.total_punishments) * 100).toFixed(1)
                          : 0}
                        %
                      </span>
                    </div>
                  </div>
                </CardContent>
              </Card>
            </div>
          </>
        )}
      </motion.div>
    </AdminLayout>
  )
}

export default AdminStats
