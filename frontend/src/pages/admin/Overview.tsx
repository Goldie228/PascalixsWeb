import { useQuery } from '@tanstack/react-query';
import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card';
import { Badge } from '@/components/ui/Badge';
import { LoadingSpinner } from '@/components/ui/LoadingSpinner';
import { Button } from '@/components/ui/Button';
import AdminLayout from '@/components/admin/AdminLayout';
import { api } from '@/services/api';

interface StatsData {
  users: {
    total: number;
    added: number;
    sponsors: number;
    created_today: number;
  };
  punishments: {
    total: number;
    active: number;
    resolved: number;
    issued_today: number;
  };
  recent_activity: {
    users: Array<{
      id: number;
      discord_username: string;
      created_at: string;
    }>;
    punishments: Array<{
      id: number;
      type: string;
      reason: string;
      active: boolean;
      issued_at: string;
    }>;
  };
}

function Overview() {
  const { data: stats, isLoading } = useQuery<StatsData>({
    queryKey: ['admin-stats'],
    queryFn: async () => {
      const response = await api.get('/v1/admin/stats/overview');
      return response.data;
    },
  });

  if (isLoading) {
    return (
      <AdminLayout>
        <div className="flex items-center justify-center">
          <LoadingSpinner size="lg" />
        </div>
      </AdminLayout>
    );
  }

  return (
    <AdminLayout>
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3 }}
      >
        <div className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <h1 className="text-2xl font-bold text-base-content">Overview</h1>
          <div className="flex gap-2">
            <Button asChild>
              <Link to="/admin/users">Manage Users</Link>
            </Button>
            <Button variant="outline" asChild>
              <Link to="/admin/punishments">Manage Punishments</Link>
            </Button>
          </div>
        </div>

        {/* Stats Grid */}
        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
          <Card>
            <CardHeader>
              <CardTitle>Total Users</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-3xl font-bold text-primary">{stats?.users.total || 0}</p>
              <p className="text-sm text-neutral/60">
                +{stats?.users.created_today || 0} today
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Added Users</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-3xl font-bold text-success">
                {stats?.users.added || 0}
              </p>
              <p className="text-sm text-neutral/60">
                {stats?.users.total
                  ? Math.round((stats.users.added / stats.users.total) * 100)
                  : 0}
                % of total
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Active Punishments</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-3xl font-bold text-error">{stats?.punishments.active || 0}</p>
              <p className="text-sm text-neutral/60">
                +{stats?.punishments.issued_today || 0} today
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Resolved Punishments</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-3xl font-bold text-success">
                {stats?.punishments.resolved || 0}
              </p>
              <p className="text-sm text-neutral/60">
                {stats?.punishments.total
                  ? Math.round((stats.punishments.resolved / stats.punishments.total) * 100)
                  : 0}
                % of total
              </p>
            </CardContent>
          </Card>
        </div>

        {/* Recent Activity */}
        <div className="mt-6 grid gap-6 lg:grid-cols-2">
          <Card>
            <CardHeader>
              <CardTitle>Recent Users</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-3">
                {(stats?.recent_activity.users.slice(0, 5) || []).map((user) => (
                  <div key={user.id} className="flex items-center justify-between">
                    <div>
                      <p className="font-medium text-base-content">{user.discord_username}</p>
                      <p className="text-sm text-neutral/60">
                        {new Date(user.created_at).toLocaleDateString()}
                      </p>
                    </div>
                    <Badge variant="info">New</Badge>
                  </div>
                ))}
                {(stats?.recent_activity.users.length || 0) === 0 && (
                  <p className="text-sm text-neutral/60">No recent users</p>
                )}
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Recent Punishments</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-3">
                {(stats?.recent_activity.punishments.slice(0, 5) || []).map((punishment) => (
                  <div key={punishment.id} className="flex items-center justify-between">
                    <div>
                      <p className="font-medium text-base-content">{punishment.type}</p>
                      <p className="text-sm text-neutral/60">{punishment.reason}</p>
                    </div>
                    <Badge variant={punishment.active ? 'error' : 'success'}>
                      {punishment.active ? 'Active' : 'Resolved'}
                    </Badge>
                  </div>
                ))}
                {(stats?.recent_activity.punishments.length || 0) === 0 && (
                  <p className="text-sm text-neutral/60">No recent punishments</p>
                )}
              </div>
            </CardContent>
          </Card>
        </div>
      </motion.div>
    </AdminLayout>
  );
}

export default Overview;
