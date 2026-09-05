import { useQuery } from '@tanstack/react-query';
import { motion } from 'framer-motion';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card';
import { Badge } from '@/components/ui/Badge';
import { LoadingSpinner } from '@/components/ui/LoadingSpinner';

interface Punishment {
  id: number;
  type: string;
  active: boolean;
  issued_at: string;
}

function Dashboard() {
  const { data: punishments, isLoading } = useQuery<Punishment[]>({
    queryKey: ['punishments'],
    queryFn: async () => {
      const response = await fetch('/api/v1/punishments');
      if (!response.ok) return [];
      return response.json();
    },
    retry: 1,
    staleTime: 1000 * 60,
  });

  if (isLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <LoadingSpinner size="lg" />
      </div>
    );
  }

  const activeCount = punishments?.filter((p) => p.active).length || 0;
  const totalCount = punishments?.length || 0;

  return (
    <div className="min-h-screen bg-base-100 py-8">
      <div className="container mx-auto max-w-4xl px-4">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
        >
          <h1 className="mb-6 text-3xl font-bold text-base-content">Dashboard</h1>

          <div className="grid gap-6 md:grid-cols-2">
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.1 }}
            >
              <Card>
                <CardHeader>
                  <CardTitle>Active Punishments</CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="flex items-center gap-3">
                    <p className="text-3xl font-bold text-error">{activeCount}</p>
                    <Badge variant="error">{activeCount > 0 ? 'Needs attention' : 'None'}</Badge>
                  </div>
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
                  <CardTitle>Total Punishments</CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-3xl font-bold text-base-content">{totalCount}</p>
                </CardContent>
              </Card>
            </motion.div>
          </div>

          {punishments && punishments.length > 0 && (
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.3 }}
              className="mt-6"
            >
              <h2 className="mb-4 text-xl font-semibold text-base-content">Recent Punishments</h2>
              <div className="space-y-3">
                {punishments.slice(0, 5).map((punishment) => (
                  <Card key={punishment.id}>
                    <CardContent className="flex items-center justify-between py-4">
                      <div>
                        <p className="font-medium text-base-content capitalize">
                          {punishment.type.replace(/_/g, ' ')}
                        </p>
                        <p className="text-sm text-neutral/60">
                          {new Date(punishment.issued_at).toLocaleDateString()}
                        </p>
                      </div>
                      <Badge variant={punishment.active ? 'error' : 'success'}>
                        {punishment.active ? 'Active' : 'Resolved'}
                      </Badge>
                    </CardContent>
                  </Card>
                ))}
              </div>
            </motion.div>
          )}

          {(!punishments || punishments.length === 0) && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 0.3 }}
            >
              <Card>
                <CardContent className="py-8 text-center">
                  <p className="text-neutral/60">No punishments found.</p>
                </CardContent>
              </Card>
            </motion.div>
          )}
        </motion.div>
      </div>
    </div>
  );
}

export default Dashboard;
