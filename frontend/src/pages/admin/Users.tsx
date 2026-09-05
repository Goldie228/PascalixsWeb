import { useState, useCallback } from 'react';
import { useQuery } from '@tanstack/react-query';
import { motion } from 'framer-motion';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card';
import { Input } from '@/components/ui/Input';
import { Badge } from '@/components/ui/Badge';
import { Button } from '@/components/ui/Button';
import { LoadingSpinner } from '@/components/ui/LoadingSpinner';
import AdminLayout from '@/components/admin/AdminLayout';
import { api } from '@/services/api';

interface User {
  id: number;
  discord_id: string;
  discord_username: string;
  minecraft_nickname: string | null;
  role: string;
  is_added: boolean;
  is_sponsor: boolean;
  created_at: string;
}

interface UsersResponse {
  users: User[];
  meta: {
    current_page: number;
    total_pages: number;
    total_items: number;
  };
}

function Users() {
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');

  const fetchUsers = useCallback(async () => {
    const params = new URLSearchParams({ page: page.toString() });
    if (search) params.set('q', search);

    const response = await api.get<UsersResponse>('/v1/admin/users', { params });
    return response.data;
  }, [page, search]);

  const { data, isLoading } = useQuery<UsersResponse>({
    queryKey: ['admin-users', page, search],
    queryFn: fetchUsers,
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
          <h1 className="text-2xl font-bold text-base-content">Users</h1>
          <div className="flex w-full gap-2 sm:w-64">
            <Input
              placeholder="Search users..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="flex-1"
            />
            <Button onClick={() => setPage(1)}>Search</Button>
          </div>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>User List</CardTitle>
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
                      Minecraft
                    </th>
                    <th className="pb-3 pr-4 text-left text-sm font-medium text-neutral/60">
                      Role
                    </th>
                    <th className="pb-3 pr-4 text-left text-sm font-medium text-neutral/60">
                      Status
                    </th>
                    <th className="pb-3 pr-4 text-left text-sm font-medium text-neutral/60">
                      Joined
                    </th>
                    <th className="pb-3 text-left text-sm font-medium text-neutral/60">
                      Actions
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {data?.users.map((user) => (
                    <tr
                      key={user.id}
                      className="border-b border-base-300 transition-colors hover:bg-base-200/50"
                    >
                      <td className="py-3 pr-4">
                        <div>
                          <p className="font-medium text-base-content">
                            {user.discord_username}
                          </p>
                          <p className="text-sm text-neutral/60">{user.discord_id}</p>
                        </div>
                      </td>
                      <td className="py-3 pr-4">
                        <Badge variant="outline">
                          {user.minecraft_nickname || 'N/A'}
                        </Badge>
                      </td>
                      <td className="py-3 pr-4">
                        <Badge variant={user.role === 'admin' ? 'error' : 'info'}>
                          {user.role}
                        </Badge>
                      </td>
                      <td className="py-3 pr-4">
                        <div className="flex gap-1">
                          {user.is_added && <Badge variant="success">Added</Badge>}
                          {user.is_sponsor && <Badge variant="warning">Sponsor</Badge>}
                        </div>
                      </td>
                      <td className="py-3 pr-4 text-sm text-neutral/60">
                        {new Date(user.created_at).toLocaleDateString()}
                      </td>
                      <td className="py-3">
                        <Button variant="ghost" size="sm">
                          Edit
                        </Button>
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

export default Users;
