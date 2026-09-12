import { useState } from 'react'
import { motion } from 'framer-motion'
import { Search, UserPlus, Edit, Trash2, Check, X } from 'lucide-react'
import { useUsers, useUpdateUser, useDeleteUser } from '@/hooks/useUsers'
import { Card, CardContent } from '@/components/ui/Card'
import { Button } from '@/components/ui/Button'
import { Badge } from '@/components/ui/Badge'
import { Input } from '@/components/ui/Input'
import { Modal } from '@/components/ui/Modal'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import AdminLayout from '@/components/admin/AdminLayout'
import type { AdminUser } from '@/types'

function AdminUsers() {
  const [search, setSearch] = useState('')
  const [selectedUser, setSelectedUser] = useState<AdminUser | null>(null)
  const [isEditModalOpen, setIsEditModalOpen] = useState(false)
  const [isDeleteModalOpen, setIsDeleteModalOpen] = useState(false)
  const [editForm, setEditForm] = useState<{ role: 'player' | 'moderator' | 'admin' | undefined }>({ role: undefined })
  const [page, setPage] = useState(1)

  const { data, isLoading, refetch } = useUsers({ page, per_page: 20, search })

  // The API response structure: { users: AdminUser[], total: number, page: number }
  const users = (data?.data as { users: AdminUser[]; total: number } | undefined)?.users || []
  const total = (data?.data as { total: number } | undefined)?.total || 0
  const totalPages = Math.ceil(total / 20)

  const updateUser = useUpdateUser()
  const deleteUser = useDeleteUser()

  const handleEdit = (user: AdminUser) => {
    setSelectedUser(user)
    setEditForm({ role: user.role as 'player' | 'moderator' | 'admin' | undefined })
    setIsEditModalOpen(true)
  }

  const handleSaveEdit = async () => {
    if (!selectedUser) return
    await updateUser.mutateAsync({
      userId: selectedUser.id,
      updates: { role: editForm.role },
    })
    setIsEditModalOpen(false)
    refetch()
  }

  const handleDelete = async (userId: number) => {
    if (!confirm('Are you sure you want to delete this user? This action cannot be undone.')) return
    await deleteUser.mutateAsync(userId)
    setIsDeleteModalOpen(false)
    refetch()
  }

  const getRoleBadge = (role?: string) => {
    switch (role) {
      case 'admin':
        return <Badge variant="error">Admin</Badge>
      case 'moderator':
        return <Badge variant="warning">Moderator</Badge>
      case 'sponsor':
        return <Badge variant="info">Sponsor</Badge>
      default:
        return <Badge variant="default">Player</Badge>
    }
  }

  return (
    <AdminLayout>
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3 }}
      >
        <div className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 className="text-2xl font-bold text-base-content">User Management</h1>
            <p className="text-sm text-neutral/60">Manage all registered users</p>
          </div>
          <Button>
            <UserPlus className="w-4 h-4 mr-2" />
            Add User
          </Button>
        </div>

        <Card>
          <CardContent className="p-0">
            {/* Search bar */}
            <div className="p-4 border-b border-base-300">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-neutral/50" />
                <Input
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  placeholder="Search users by username or email..."
                  className="pl-10"
                  onKeyDown={(e) => e.key === 'Enter' && refetch()}
                />
              </div>
            </div>

            {/* Users table */}
            {isLoading ? (
              <div className="p-8 text-center">
                <LoadingSpinner size="md" />
                <p className="text-neutral/60 mt-2">Loading users...</p>
              </div>
            ) : users.length === 0 ? (
              <div className="p-8 text-center text-neutral/60">No users found</div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="border-b border-base-300">
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">User</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">Role</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">Joined</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">Status</th>
                      <th className="text-right p-4 text-sm font-medium text-neutral/60">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {users.map((user) => (
                      <tr
                        key={user.id}
                        className="border-b border-base-300 transition-colors hover:bg-base-200/50"
                      >
                        <td className="p-4">
                          <div className="flex items-center gap-3">
                            <div className="w-10 h-10 rounded-full bg-base-300 flex items-center justify-center">
                              <span className="text-base-content font-bold">
                                {user.discord_username?.[0]?.toUpperCase() || '?'}
                              </span>
                            </div>
                            <div>
                              <p className="font-medium text-base-content">{user.discord_username}</p>
                              <p className="text-neutral/60 text-sm">
                                {user.minecraft_nickname || 'No nickname'}
                              </p>
                            </div>
                          </div>
                        </td>
                        <td className="p-4">{getRoleBadge(user.role)}</td>
                        <td className="p-4 text-neutral/60">
                          {new Date(user.created_at).toLocaleDateString()}
                        </td>
                        <td className="p-4">
                          <Badge variant={user.is_added ? 'success' : 'error'}>
                            {user.is_added ? 'Added' : 'Not Added'}
                          </Badge>
                        </td>
                        <td className="p-4">
                          <div className="flex items-center justify-end gap-2">
                            <Button
                              variant="ghost"
                              size="sm"
                              onClick={() => handleEdit(user)}
                            >
                              <Edit className="w-4 h-4" />
                            </Button>
                            <Button
                              variant="destructive"
                              size="sm"
                              onClick={() => {
                                setSelectedUser(user)
                                setIsDeleteModalOpen(true)
                              }}
                            >
                              <Trash2 className="w-4 h-4" />
                            </Button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}

            {/* Pagination */}
            {totalPages > 1 && (
              <div className="p-4 flex items-center justify-between border-t border-base-300">
                <p className="text-sm text-neutral/60">
                  Showing {users.length} of {total} users
                </p>
                <div className="flex items-center gap-2">
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setPage(Math.max(1, page - 1))}
                    disabled={page === 1}
                  >
                    Previous
                  </Button>
                  <span className="text-neutral/60 px-2">
                    {page} / {totalPages}
                  </span>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setPage(Math.min(totalPages, page + 1))}
                    disabled={page === totalPages}
                  >
                    Next
                  </Button>
                </div>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Edit User Modal */}
        <Modal
          isOpen={isEditModalOpen}
          onClose={() => setIsEditModalOpen(false)}
          title="Edit User"
        >
          {selectedUser && (
            <div className="space-y-4">
              <div className="flex items-center gap-3 mb-4">
                <div className="w-12 h-12 rounded-full bg-base-300 flex items-center justify-center">
                  <span className="text-base-content font-bold">
                    {selectedUser.discord_username?.[0]?.toUpperCase() || '?'}
                  </span>
                </div>
                <div>
                  <p className="font-bold text-base-content">{selectedUser.discord_username}</p>
                  <p className="text-neutral/60 text-sm">ID: {selectedUser.id}</p>
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-base-content mb-1">Role</label>
                <select
                  value={editForm.role}
                  onChange={(e) => setEditForm({ role: e.target.value as 'player' | 'moderator' | 'admin' | undefined })}
                  className="w-full h-10 rounded-lg border border-neutral/20 bg-base-200 px-3 py-2 text-sm text-base-content focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
                >
                  <option value="">Player</option>
                  <option value="moderator">Moderator</option>
                  <option value="admin">Admin</option>
                  <option value="sponsor">Sponsor</option>
                </select>
              </div>

              <div className="flex gap-2 pt-4">
                <Button
                  className="flex-1"
                  onClick={handleSaveEdit}
                  isLoading={updateUser.isPending}
                >
                  <Check className="w-4 h-4 mr-2" />
                  Save Changes
                </Button>
                <Button
                  variant="outline"
                  className="flex-1"
                  onClick={() => setIsEditModalOpen(false)}
                >
                  <X className="w-4 h-4 mr-2" />
                  Cancel
                </Button>
              </div>
            </div>
          )}
        </Modal>

        {/* Delete User Modal */}
        <Modal
          isOpen={isDeleteModalOpen}
          onClose={() => setIsDeleteModalOpen(false)}
          title="Delete User"
        >
          {selectedUser && (
            <div className="space-y-4">
              <div className="p-4 bg-error/10 border border-error/20 rounded-lg">
                <p className="text-error font-medium">Warning: This action cannot be undone</p>
                <p className="text-neutral/60 text-sm mt-1">
                  Deleting {selectedUser.discord_username} will remove all associated data permanently.
                </p>
              </div>

              <div className="flex gap-2">
                <Button
                  variant="destructive"
                  className="flex-1"
                  onClick={() => handleDelete(selectedUser.id)}
                  isLoading={deleteUser.isPending}
                >
                  <Trash2 className="w-4 h-4 mr-2" />
                  Delete User
                </Button>
                <Button
                  variant="outline"
                  className="flex-1"
                  onClick={() => setIsDeleteModalOpen(false)}
                >
                  Cancel
                </Button>
              </div>
            </div>
          )}
        </Modal>
      </motion.div>
    </AdminLayout>
  )
}

export default AdminUsers
