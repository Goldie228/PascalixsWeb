import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { motion } from 'framer-motion';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card';
import { Badge } from '@/components/ui/Badge';
import { Button } from '@/components/ui/Button';
import { LoadingSpinner } from '@/components/ui/LoadingSpinner';
import AdminLayout from '@/components/admin/AdminLayout';
import { api } from '@/services/api';

interface Punishment {
  id: number;
  type: string;
  user_id: number;
  reason: string;
  issuer: string;
  issued_at: string;
  active: boolean;
}

interface PunishmentsResponse {
  punishments: Punishment[];
  meta: {
    current_page: number;
    total_pages: number;
    total_items: number;
  };
}

function Punishments() {
  const [page, setPage] = useState(1);

  const { data, isLoading } = useQuery<PunishmentsResponse>({
    queryKey: ['admin-punishments', page],
    queryFn: async () => {
      const response = await api.get<PunishmentsResponse>(
        `/v1/admin/punishments?page=${page}`
      );
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
          <h1 className="text-2xl font-bold text-base-content">Punishments</h1>
          <Button>Create Punishment</Button>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>Punishment List</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-base-300">
                    <th className="pb-3 pr-4 text-left text-sm font-medium text-neutral/60">
                      Type
                    </th>
                    <th className="pb-3 pr-4 text-left text-sm font-medium text-neutral/60">
                      User
                    </th>
                    <th className="pb-3 pr-4 text-left text-sm font-medium text-neutral/60">
                      Reason
                    </th>
                    <th className="pb-3 pr-4 text-left text-sm font-medium text-neutral/60">
                      Issuer
                    </th>
                    <th className="pb-3 pr-4 text-left text-sm font-medium text-neutral/60">
                      Issued
                    </th>
                    <th className="pb-3 pr-4 text-left text-sm font-medium text-neutral/60">
                      Status
                    </th>
                    <th className="pb-3 text-left text-sm font-medium text-neutral/60">
                      Actions
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {data?.punishments.map((punishment) => (
                    <tr
                      key={punishment.id}
                      className="border-b border-base-300 transition-colors hover:bg-base-200/50"
                    >
                      <td className="py-3 pr-4">
                        <Badge variant={punishment.type === 'ban' ? 'error' : 'warning'}>
                          {punishment.type}
                        </Badge>
                      </td>
                      <td className="py-3 pr-4 text-sm text-base-content">
                        User #{punishment.user_id}
                      </td>
                      <td className="py-3 pr-4 text-sm text-base-content">
                        {punishment.reason}
                      </td>
                      <td className="py-3 pr-4 text-sm text-neutral/60">
                        {punishment.issuer}
                      </td>
                      <td className="py-3 pr-4 text-sm text-neutral/60">
                        {new Date(punishment.issued_at).toLocaleDateString()}
                      </td>
                      <td className="py-3 pr-4">
                        <Badge variant={punishment.active ? 'error' : 'success'}>
                          {punishment.active ? 'Active' : 'Resolved'}
                        </Badge>
                      </td>
                      <td className="py-3">
                        {punishment.active && (
                          <Button variant="ghost" size="sm">
                            Resolve
                          </Button>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {/* Pagination */}
            <div className="mt-4 flex flex-col items-center justify-between gap-4 sm:flex-row">
              <p className="text-sm text-neutral/60">
                Page {data?.meta.current_page} of {data?.meta.total_pages}
              </p>
              <div className="flex gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  disabled={page === 1}
                  onClick={() => setPage(page - 1)}
                >
                  Previous
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  disabled={page === data?.meta.total_pages}
                  onClick={() => setPage(page + 1)}
                >
                  Next
                </Button>
              </div>
            </div>
          </CardContent>
        </Card>
      </motion.div>
    </AdminLayout>
  );
}

export default Punishments;
