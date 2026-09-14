import { useState } from 'react'
import { motion } from 'framer-motion'
import { useTranslation } from 'react-i18next'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { Search, Eye, Trash2 } from 'lucide-react'
import { Card, CardContent } from '@/components/ui/Card'
import { Button } from '@/components/ui/Button'
import { Badge } from '@/components/ui/Badge'
import { Modal } from '@/components/ui/Modal'
import { Input } from '@/components/ui/Input'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import { useToast } from '@/components/ui/Toast'
import AdminLayout from '@/components/admin/AdminLayout'
import { adminApi } from '@/services/adminApi'
import type { Complaint } from '@/types'

function getStatusBadge(status: Complaint['status'], t: (k: string) => string) {
  const map = { open: 'warning' as const, resolved: 'success' as const, dismissed: 'neutral' as const }
  return <Badge variant={map[status]}>{t(`admin.complaints.${status}`)}</Badge>
}

function AdminComplaints() {
  const { t } = useTranslation()
  const { success: showSuccess, error: showError } = useToast()
  const queryClient = useQueryClient()

  const [page, setPage] = useState(1)
  const [perPage, setPerPage] = useState(50)
  const [statusFilter, setStatusFilter] = useState('')
  const [search, setSearch] = useState('')
  const [selected, setSelected] = useState<Complaint | null>(null)

  const { data, isLoading } = useQuery({
    queryKey: ['admin-complaints', page, perPage, statusFilter, search],
    queryFn: () => adminApi.getComplaints({ page, per: perPage, status: statusFilter || undefined, search: search || undefined }),
    staleTime: 1000 * 60 * 5,
  })

  const markRead = useMutation({
    mutationFn: (id: number) => adminApi.markComplaintRead(id),
    onSuccess: () => { showSuccess(t('admin.complaints.marked_read', 'Marked as read')); queryClient.invalidateQueries({ queryKey: ['admin-complaints'] }) },
    onError: () => showError(t('admin.complaints.error', 'Failed to update complaint')),
  })
  const remove = useMutation({
    mutationFn: (id: number) => adminApi.deleteComplaint(id),
    onSuccess: () => { showSuccess(t('admin.complaints.deleted', 'Complaint deleted')); queryClient.invalidateQueries({ queryKey: ['admin-complaints'] }) },
    onError: () => showError(t('admin.complaints.error', 'Failed to delete complaint')),
  })

  const complaints = data?.data?.complaints ?? []
  const total = data?.data?.pagination?.total ?? 0
  const totalPages = Math.ceil(total / perPage) || 1
  const resetPage = () => setPage(1)

  return (
    <AdminLayout>
      <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.3 }}>
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-base-content">{t('admin.complaints.title')}</h1>
          <p className="text-sm text-neutral/60">{t('admin.complaints.manage_desc', 'Manage player complaints')}</p>
        </div>

        {/* Filters */}
        <Card className="mb-4">
          <CardContent className="p-4">
            <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
              <div className="relative sm:col-span-2">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-neutral/50" />
                <Input value={search} onChange={(e) => { setSearch(e.target.value); resetPage() }} placeholder={t('admin.complaints.search')} className="pl-10" />
              </div>
              <select value={statusFilter} onChange={(e) => { setStatusFilter(e.target.value); resetPage() }}
                className="h-10 rounded-lg border border-neutral/20 bg-base-200 px-3 text-sm text-base-content focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary">
                <option value="">{t('admin.complaints.all_statuses')}</option>
                <option value="open">{t('admin.complaints.open')}</option>
                <option value="resolved">{t('admin.complaints.resolved')}</option>
                <option value="dismissed">{t('admin.complaints.dismissed')}</option>
              </select>
              <div className="flex items-end gap-2">
                <label className="text-sm text-neutral/60 whitespace-nowrap">{t('admin.complaints.per_page')}</label>
                <select value={perPage} onChange={(e) => { setPerPage(Number(e.target.value)); resetPage() }}
                  className="h-10 w-20 rounded-lg border border-neutral/20 bg-base-200 px-2 text-sm text-base-content focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary">
                  <option value={25}>25</option><option value={50}>50</option><option value={75}>75</option>
                </select>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Content */}
        <Card>
          <CardContent className="p-0">
            {isLoading ? (
              <div className="p-8 text-center"><LoadingSpinner size="md" /><p className="text-neutral/60 mt-2">{t('admin.complaints.loading', 'Loading complaints...')}</p></div>
            ) : complaints.length === 0 ? (
              <div className="p-8 text-center text-neutral/60">{t('admin.complaints.no_data', 'No complaints found')}</div>
            ) : (
              <>
                {/* Desktop table */}
                <div className="hidden overflow-x-auto md:block">
                  <table className="w-full">
                    <thead><tr className="border-b border-base-300">
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.complaints.table.id')}</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.complaints.table.reporter')}</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.complaints.table.reported')}</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.complaints.table.reason')}</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.complaints.table.status')}</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.complaints.table.date')}</th>
                      <th className="text-right p-4 text-sm font-medium text-neutral/60">{t('admin.complaints.table.actions')}</th>
                    </tr></thead>
                    <tbody>
                      {complaints.map((c) => (
                        <tr key={c.id} className="border-b border-base-300 hover:bg-base-200/50 transition-colors">
                          <td className="p-4 text-sm text-neutral/60">#{c.id}</td>
                          <td className="p-4 font-medium text-base-content">{c.reporter_username}</td>
                          <td className="p-4 font-medium text-base-content">{c.reported_username}</td>
                          <td className="p-4 text-sm text-base-content/80 max-w-xs truncate">{c.reason}</td>
                          <td className="p-4"><Badge variant={c.status === 'open' ? 'warning' : c.status === 'resolved' ? 'success' : 'neutral'}>{t(`admin.complaints.${c.status}`)}</Badge></td>
                          <td className="p-4 text-sm text-neutral/60">{new Date(c.created_at).toLocaleDateString()}</td>
                          <td className="p-4"><div className="flex justify-end gap-2"><Button variant="ghost" size="sm" onClick={() => setSelected(c)}><Eye className="w-4 h-4" /></Button></div></td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>

                {/* Mobile cards */}
                <div className="md:hidden divide-y divide-base-300">
                  {complaints.map((c) => (
                    <div key={c.id} className="p-4 space-y-3">
                      <div className="flex items-center justify-between">
                        <span className="text-xs text-neutral/60">#{c.id}</span>
                        <Badge variant={c.status === 'open' ? 'warning' : c.status === 'resolved' ? 'success' : 'neutral'}>{t(`admin.complaints.${c.status}`)}</Badge>
                      </div>
                      <div className="space-y-1">
                        <p><span className="text-neutral/60">{t('admin.complaints.reporter')}:</span> <span className="font-medium">{c.reporter_username}</span></p>
                        <p><span className="text-neutral/60">{t('admin.complaints.reported')}:</span> <span className="font-medium">{c.reported_username}</span></p>
                        <p className="text-sm text-base-content/80">{c.reason}</p>
                        <p className="text-xs text-neutral/60">{new Date(c.created_at).toLocaleDateString()}</p>
                      </div>
                      <Button variant="ghost" size="sm" className="w-full" onClick={() => setSelected(c)}><Eye className="w-4 h-4 mr-2" />{t('admin.complaints.view')}</Button>
                    </div>
                  ))}
                </div>
              </>
            )}

            {/* Pagination */}
            {totalPages > 1 && (
              <div className="p-4 flex items-center justify-between border-t border-base-300">
                <p className="text-sm text-neutral/60">{t('admin.complaints.showing', 'Showing')} {complaints.length} / {total}</p>
                <div className="flex items-center gap-2">
                  <Button variant="outline" size="sm" onClick={() => setPage(Math.max(1, page - 1))} disabled={page === 1}>{t('admin.previous', 'Prev')}</Button>
                  <span className="text-neutral/60 text-sm px-2">{page} / {totalPages}</span>
                  <Button variant="outline" size="sm" onClick={() => setPage(Math.min(totalPages, page + 1))} disabled={page === totalPages}>{t('admin.next', 'Next')}</Button>
                </div>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Detail Modal */}
        <Modal isOpen={!!selected} onClose={() => setSelected(null)} title={t('admin.complaints.view')} size="md">
          {selected && (
            <div className="space-y-4">
              <div className="grid gap-3 text-sm">
                <div className="flex justify-between"><span className="text-neutral/60">{t('admin.complaints.table.id')}:</span><span className="font-medium">#{selected.id}</span></div>
                <div className="flex justify-between"><span className="text-neutral/60">{t('admin.complaints.reporter')}:</span><span className="font-medium">{selected.reporter_username}</span></div>
                <div className="flex justify-between"><span className="text-neutral/60">{t('admin.complaints.reported')}:</span><span className="font-medium">{selected.reported_username}</span></div>
                <div><span className="text-neutral/60 block mb-1">{t('admin.complaints.reason')}:</span><span className="font-medium">{selected.reason}</span></div>
                <div className="flex justify-between"><span className="text-neutral/60">{t('admin.complaints.table.status')}:</span>{getStatusBadge(selected.status, t)}</div>
                <div className="flex justify-between"><span className="text-neutral/60">{t('admin.complaints.table.date')}:</span><span className="font-medium">{new Date(selected.created_at).toLocaleString()}</span></div>
              </div>
              <div className="flex gap-3 pt-2">
                {selected.status === 'open' && <Button className="flex-1" onClick={() => markRead.mutate(selected.id)} isLoading={markRead.isPending}>{t('admin.complaints.mark_read')}</Button>}
                <Button variant="destructive" className="flex-1" onClick={() => remove.mutate(selected.id)} isLoading={remove.isPending}><Trash2 className="w-4 h-4 mr-2" />{t('admin.complaints.delete')}</Button>
                <Button variant="outline" className="flex-1" onClick={() => setSelected(null)}>{t('admin.complaints.close')}</Button>
              </div>
            </div>
          )}
        </Modal>
      </motion.div>
    </AdminLayout>
  )
}

export default AdminComplaints
