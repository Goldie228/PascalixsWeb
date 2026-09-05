import { useQuery } from '@tanstack/react-query';
import { motion } from 'framer-motion';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card';
import { LoadingSpinner } from '@/components/ui/LoadingSpinner';
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
}

function Stats() {
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
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-base-content">Statistics</h1>
        </div>

        <div className="grid gap-6 md:grid-cols-2">
          <Card>
            <CardHeader>
              <CardTitle>User Statistics</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="flex items-center justify-between">
                <span className="text-neutral/60">Total Users</span>
                <span className="text-2xl font-bold text-primary">
                  {stats?.users.total}
                </span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-neutral/60">Added Users</span>
                <span className="text-2xl font-bold text-success">
                  {stats?.users.added}
                </span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-neutral/60">Sponsors</span>
                <span className="text-2xl font-bold text-warning">
                  {stats?.users.sponsors}
                </span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-neutral/60">Created Today</span>
                <span className="text-2xl font-bold text-info">
                  {stats?.users.created_today}
                </span>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Punishment Statistics</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="flex items-center justify-between">
                <span className="text-neutral/60">Total Punishments</span>
                <span className="text-2xl font-bold text-base-content">
                  {stats?.punishments.total}
                </span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-neutral/60">Active Punishments</span>
                <span className="text-2xl font-bold text-error">
                  {stats?.punishments.active}
                </span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-neutral/60">Resolved Punishments</span>
                <span className="text-2xl font-bold text-success">
                  {stats?.punishments.resolved}
                </span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-neutral/60">Issued Today</span>
                <span className="text-2xl font-bold text-info">
                  {stats?.punishments.issued_today}
                </span>
              </div>
            </CardContent>
          </Card>
        </div>
      </motion.div>
    </AdminLayout>
  );
}

export default Stats;
