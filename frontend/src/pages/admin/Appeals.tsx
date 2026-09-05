import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { motion } from 'framer-motion';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card';
import { Badge } from '@/components/ui/Badge';
import { Button } from '@/components/ui/Button';
import { LoadingSpinner } from '@/components/ui/LoadingSpinner';
import AdminLayout from '@/components/admin/AdminLayout';
import { api } from '@/services/api';

interface Appeal {
  id: number;
  user_id: number;
  punishment_id: number;
  reason: string;
  status: 'pending' | 'approved' | 'rejected';
  created_at: string;
}

interface AppealsResponse {
  appeals: Appeal[];
  meta: {
    current_page: number;
    total_pages: number;
    total_items: number;
  };
}

function Appeals() {
  const [page, setPage] = useState(1);

  const { data, isLoading } = useQuery<AppealsResponse>({
    queryKey: ['admin-appeals', page],
    queryFn: async () => {
      const response = await api.get<AppealsResponse>(
        `/v1/admin/appeals?page=${page}`
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
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-base-content">Appeals</h1>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>Appeal List</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-base-300">
                    <th className="pb-3 pr-4 text-left text-sm font-medium text-neutral/60">
                      User
                    </th>
                    <th className="pb-3 pr-4 text-left text-sm font-medium text-neutral/60">
                      Punishment
                    </th>
                    <th className="pb-3 pr-4 text-left text-sm font-medium text-neutral/60">
                      Reason
                    </th>
                    <th className="pb-3 pr-4 text-left text-sm font-medium text-neutral/60">
                      Status
                    </th>
                    <th className="pb-3 pr-4 text-left text-sm font-medium text-neutral/60">
                      Created
                    </th>
                    <th className="pb-3 text-left text-sm font-medium text-neutral/60">
                      Actions
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {data?.appeals.map((appeal) => (
                    <tr
                      key={appeal.id}
                      className="border-b border-base-300 transition-colors hover:bg-base-200/50"
                    >
                      <td className="py-3 pr-4 text-sm text-base-content">
                        User #{appeal.user_id}
                      </td>
                      <td className="py-3 pr-4 text-sm text-neutral/60">
                        Punishment #{appeal.punishment_id}
                      </td>
                      <td className="py-3 pr-4 text-sm text-base-content">
                        {appeal.reason}
                      </td>
                      <td className="py-3 pr-4">
                        <Badge
                          variant={
                            appeal.status === 'approved'
                              ? 'success'
                              : appeal.status === 'rejected'
                              ? 'error'
                              : 'warning'
                          }
                        >
                          {appeal.status}
                        </Badge>
                      </td>
                      <td className="py-3 pr-4 text-sm text-neutral/60">
                        {new Date(appeal.created_at).toLocaleDateString()}
                      </td>
                      <td className="py-3">
                        {appeal.status === 'pending' && (
                          <div className="flex gap-2">
                            <Button variant="success" size="sm">
                              Approve
                            </Button>
                            <Button variant="destructive" size="sm">
                              Reject
                            </Button>
                          </div>
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

export default Appeals;
