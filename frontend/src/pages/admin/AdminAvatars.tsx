import { useState } from 'react'
import { motion } from 'framer-motion'
import { useTranslation } from 'react-i18next'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { Search, Eye, Check, X } from 'lucide-react'
import { Card, CardContent } from '@/components/ui/Card'
import { Button } from '@/components/ui/Button'
import { Badge } from '@/components/ui/Badge'
import { Modal } from '@/components/ui/Modal'
import { Input } from '@/components/ui/Input'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import { useToast } from '@/components/ui/Toast'
import AdminLayout from '@/components/admin/AdminLayout'
import { adminApi } from '@/services/adminApi'
import type { DiscordAvatar } from '@/types'

function getStatusBadge(status: DiscordAvatar['status']) {
  const map = { pending: 'warning' as const, approved: 'success' as const, rejected: 'error' as const }
  return <Badge variant={map[status]}>{status}</Badge>
}

function AdminAvatars() {
  const { t } = useTranslation()
  const { success: showSuccess } = useToast()
  const queryClient = useQueryClient()

  const [page, setPage] = useState(1)
  const [perPage, setPerPage] = useState(50)
  const [sortBy, setSortBy] = useState('created_at')
  const [sortOrder, setSortOrder] = useState('desc')
  const [statusFilter, setStatusFilter] = useState('')
  const [search, setSearch] = useState('')
  const [selected, setSelected] = useState<DiscordAvatar | null>(null)

  const { data, isLoading } = useQuery({
    queryKey: ['admin-avatars', page, perPage, sortBy, sortOrder, statusFilter, search],
    queryFn: () => adminApi.getAvatars({ page, per: perPage, sort_by: sortBy, sort_order: sortOrder, status: statusFilter || undefined, user_name: search || undefined }),
    staleTime: 1000 * 60 * 5,
  })

  const approve = useMutation({
    mutationFn: (id: number) => adminApi.approveAvatar(id),
    onSuccess: () => { showSuccess(t('admin.avatars.approved')); queryClient.invalidateQueries({ queryKey: ['admin-avatars'] }) },
  })

  const reject = useMutation({
    mutationFn: (id: number) => adminApi.rejectAvatar(id),
    onSuccess: () => { showSuccess(t('admin.avatars.rejected')); queryClient.invalidateQueries({ queryKey: ['admin-avatars'] }) },
  })

  const avatars = data?.data?.avatars ?? []
  const total = data?.data?.pagination?.total ?? 0
  const totalPages = Math.ceil(total / perPage) || 1

  const resetPage = () => setPage(1)

  return (
    <AdminLayout>
      <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.3 }}>
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-base-content">{t('admin.avatars.title')}</h1>
          <p className="text-sm text-neutral/60">{t('admin.avatars.manage_desc', 'Manage Discord avatar submissions')}</p>
        </div>

        {/* Filters */}
        <Card className="mb-4">
          <CardContent className="p-4">
            <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
              <div className="relative sm:col-span-2">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-neutral/50" />
                <Input value={search} onChange={(e) => { setSearch(e.target.value); resetPage() }} placeholder={t('admin.avatars.search')} className="pl-10" />
              </div>
              <select value={statusFilter} onChange={(e) => { setStatusFilter(e.target.value); resetPage() }}
                className="h-10 rounded-lg border border-neutral/20 bg-base-200 px-3 text-sm text-base-content focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary">
                <option value="">{t('admin.avatars.all_statuses')}</option>
                <option value="pending">{t('admin.avatars.pending')}</option>
                <option value="approved">{t('admin.avatars.approved')}</option>
                <option value="rejected">{t('admin.avatars.rejected')}</option>
              </select>
              <div className="flex items-end gap-2">
                <label className="text-sm text-neutral/60 whitespace-nowrap">{t('admin.avatars.per_page')}</label>
                <select value={perPage} onChange={(e) => { setPerPage(Number(e.target.value)); resetPage() }}
                  className="h-10 w-20 rounded-lg border border-neutral/20 bg-base-200 px-2 text-sm text-base-content focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary">
                  <option value={25}>25</option><option value={50}>50</option><option value={75}>75</option>
                </select>
              </div>
            </div>
            <div className="mt-3 flex flex-wrap items-center gap-3">
              <div className="flex items-center gap-2">
                <span className="text-sm text-neutral/60">{t('admin.avatars.sort_by')}:</span>
                <select value={sortBy} onChange={(e) => setSortBy(e.target.value)}
                  className="h-8 rounded border border-neutral/20 bg-base-200 px-2 text-sm text-base-content focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary">
                  <option value="status">{t('admin.avatars.table.status')}</option>
                  <option value="created_at">{t('admin.avatars.table.date')}</option>
                  <option value="username">{t('admin.avatars.table.user')}</option>
                </select>
              </div>
              <div className="flex items-center gap-2">
                <span className="text-sm text-neutral/60">{t('admin.avatars.sort_order')}:</span>
                <select value={sortOrder} onChange={(e) => setSortOrder(e.target.value)}
                  className="h-8 rounded border border-neutral/20 bg-base-200 px-2 text-sm text-base-content focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary">
                  <option value="desc">{t('admin.avatars.desc', 'Descending')}</option>
                  <option value="asc">{t('admin.avatars.asc', 'Ascending')}</option>
                </select>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Content */}
        <Card>
          <CardContent className="p-0">
            {isLoading ? (
              <div className="p-8 text-center"><LoadingSpinner size="md" /><p className="text-neutral/60 mt-2">{t('admin.avatars.loading', 'Loading avatars...')}</p></div>
            ) : avatars.length === 0 ? (
              <div className="p-8 text-center text-neutral/60">{t('admin.avatars.no_data', 'No avatars found')}</div>
            ) : (
              <>
                {/* Desktop table */}
                <div className="hidden overflow-x-auto md:block">
                  <table className="w-full">
                    <thead><tr className="border-b border-base-300">
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.avatars.table.user')}</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.avatars.table.avatar')}</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.avatars.table.status')}</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.avatars.table.date')}</th>
                      <th className="text-right p-4 text-sm font-medium text-neutral/60">{t('admin.avatars.table.actions')}</th>
                    </tr></thead>
                    <tbody>
                      {avatars.map((a) => (
                        <tr key={a.id} className="border-b border-base-300 hover:bg-base-200/50 transition-colors">
                          <td className="p-4 font-medium text-base-content">{a.user?.username || a.username}</td>
                          <td className="p-4">
                            <img src={a.url} alt={a.username} className="w-10 h-10 rounded-full object-cover" onError={(e) => { (e.target as HTMLImageElement).style.display = 'none' }} />
                          </td>
                          <td className="p-4">{getStatusBadge(a.status)}</td>
                          <td className="p-4 text-neutral/60 text-sm">{new Date(a.created_at).toLocaleDateString()}</td>
                          <td className="p-4">
                            <div className="flex justify-end gap-2">
                              <Button variant="ghost" size="sm" onClick={() => setSelected(a)}><Eye className="w-4 h-4" /></Button>
                            </div>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>

                {/* Mobile cards */}
                <div className="md:hidden divide-y divide-base-300">
                  {avatars.map((a) => (
                    <div key={a.id} className="p-4 space-y-3">
                      <div className="flex items-center gap-3">
                        <img src={a.url} alt={a.username} className="w-12 h-12 rounded-full object-cover" onError={(e) => { (e.target as HTMLImageElement).style.display = 'none' }} />
                        <div className="flex-1 min-w-0">
                          <p className="font-medium text-base-content truncate">{a.user?.username || a.username}</p>
                          <p className="text-xs text-neutral/60">{new Date(a.created_at).toLocaleDateString()}</p>
                        </div>
                        {getStatusBadge(a.status)}
                      </div>
                      <Button variant="ghost" size="sm" className="w-full" onClick={() => setSelected(a)}>
                        <Eye className="w-4 h-4 mr-2" />{t('admin.avatars.view')}
                      </Button>
                    </div>
                  ))}
                </div>
              </>
            )}

            {/* Pagination */}
            {totalPages > 1 && (
              <div className="p-4 flex items-center justify-between border-t border-base-300">
                <p className="text-sm text-neutral/60">{t('admin.avatars.showing', 'Showing')} {avatars.length} / {total}</p>
                <div className="flex items-center gap-2">
                  <Button variant="outline" size="sm" onClick={() => setPage(Math.max(1, page - 1))} disabled={page === 1}>
                    {t('admin.previous', 'Prev')}
                  </Button>
                  <span className="text-neutral/60 text-sm px-2">{page} / {totalPages}</span>
                  <Button variant="outline" size="sm" onClick={() => setPage(Math.min(totalPages, page + 1))} disabled={page === totalPages}>
                    {t('admin.next', 'Next')}
                  </Button>
                </div>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Preview Modal */}
        <Modal isOpen={!!selected} onClose={() => setSelected(null)} title={t('admin.avatars.view')} size="lg">
          {selected && (
            <div className="space-y-6">
              <div className="flex flex-col items-center">
                <img src={selected.url} alt={selected.username} className="w-32 h-32 rounded-full object-cover border-4 border-base-200" />
                <p className="mt-4 text-lg font-bold text-base-content">{selected.user?.username || selected.username}</p>
                <div className="mt-2">{getStatusBadge(selected.status)}</div>
                <p className="mt-2 text-sm text-neutral/60">{new Date(selected.created_at).toLocaleString()}</p>
              </div>
              <div className="flex gap-3">
                <Button className="flex-1" onClick={() => approve.mutate(selected.id)} isLoading={approve.isPending}>
                  <Check className="w-4 h-4 mr-2" />{t('admin.avatars.approve')}
                </Button>
                <Button variant="destructive" className="flex-1" onClick={() => reject.mutate(selected.id)} isLoading={reject.isPending}>
                  <X className="w-4 h-4 mr-2" />{t('admin.avatars.reject')}
                </Button>
                <Button variant="outline" className="flex-1" onClick={() => setSelected(null)}>
                  {t('admin.avatars.close')}
                </Button>
              </div>
            </div>
          )}
        </Modal>
      </motion.div>
    </AdminLayout>
  )
}

export default AdminAvatars
