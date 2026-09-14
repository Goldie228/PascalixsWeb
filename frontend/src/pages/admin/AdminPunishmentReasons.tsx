import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { Search, Plus, Pencil, Trash2, AlertTriangle } from 'lucide-react'
import { Card, CardContent } from '@/components/ui/Card'
import { Button } from '@/components/ui/Button'
import { Badge } from '@/components/ui/Badge'
import { Modal } from '@/components/ui/Modal'
import { Input } from '@/components/ui/Input'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import { useToast } from '@/components/ui/Toast'
import AdminLayout from '@/components/admin/AdminLayout'
import { adminApi } from '@/services/adminApi'
import type { PunishmentReason } from '@/types'

function getStatusBadge(active: boolean) {
  return <Badge variant={active ? 'success' : 'error'}>{active ? 'active' : 'inactive'}</Badge>
}

function ReasonForm({ reason, onSave, onCancel }: {
  reason?: PunishmentReason | null
  onSave: (data: { name: string; description: string; active: boolean }) => void
  onCancel: () => void
}) {
  const { t } = useTranslation()
  const [name, setName] = useState(reason?.name ?? '')
  const [description, setDescription] = useState(reason?.description ?? '')
  const [active, setActive] = useState(reason?.active ?? true)
  const save = () => onSave({ name, description, active })

  return (
    <div className="space-y-4">
      <Input value={name} onChange={(e) => setName(e.target.value)} label={t('admin.punishment_reasons.name')} placeholder={t('admin.punishment_reasons.name')} />
      <Input value={description} onChange={(e) => setDescription(e.target.value)} label={t('admin.punishment_reasons.description')} placeholder={t('admin.punishment_reasons.description')} />
      <label className="flex items-center gap-2 text-sm text-base-content cursor-pointer">
        <input type="checkbox" checked={active} onChange={(e) => setActive(e.target.checked)} className="checkbox checkbox-primary checkbox-sm" />
        {t('admin.punishment_reasons.active')}
      </label>
      <div className="flex gap-3 pt-2">
        <Button className="flex-1" onClick={save}>{t('admin.punishment_reasons.save')}</Button>
        <Button variant="outline" className="flex-1" onClick={onCancel}>{t('admin.punishment_reasons.cancel')}</Button>
      </div>
    </div>
  )
}

function AdminPunishmentReasons() {
  const { t } = useTranslation()
  const { success: showSuccess, error: showError } = useToast()
  const queryClient = useQueryClient()
  const [page, setPage] = useState(1)
  const [perPage, setPerPage] = useState(25)
  const [search, setSearch] = useState('')
  const [editing, setEditing] = useState<PunishmentReason | null>(null)
  const [creating, setCreating] = useState(false)
  const [deleting, setDeleting] = useState<PunishmentReason | null>(null)

  const { data, isLoading } = useQuery({
    queryKey: ['admin-punishment-reasons', page, perPage, search],
    queryFn: () => adminApi.getPunishmentReasons({ page, per: perPage, search: search || undefined }),
    staleTime: 1000 * 60 * 5,
  })

  const invalidate = () => queryClient.invalidateQueries({ queryKey: ['admin-punishment-reasons'] })
  const create = useMutation({ mutationFn: (d: { name: string; description: string; active: boolean }) => adminApi.createPunishmentReason(d), onSuccess: () => { showSuccess(t('admin.punishment_reasons.created', 'Reason created')); invalidate(); setCreating(false) }, onError: () => showError(t('admin.punishment_reasons.create_error', 'Failed to create reason')) })
  const update = useMutation({ mutationFn: (d: { id: number; name: string; description: string; active: boolean }) => adminApi.updatePunishmentReason(d.id, { name: d.name, description: d.description, active: d.active }), onSuccess: () => { showSuccess(t('admin.punishment_reasons.updated', 'Reason updated')); invalidate(); setEditing(null) }, onError: () => showError(t('admin.punishment_reasons.update_error', 'Failed to update reason')) })
  const remove = useMutation({ mutationFn: (id: number) => adminApi.deletePunishmentReason(id), onSuccess: () => { showSuccess(t('admin.punishment_reasons.deleted', 'Reason deleted')); invalidate(); setDeleting(null) }, onError: () => showError(t('admin.punishment_reasons.delete_error', 'Failed to delete reason')) })

  const reasons = data?.data?.punishment_reasons ?? []
  const total = data?.data?.total ?? 0
  const totalPages = Math.ceil(total / perPage) || 1
  const resetPage = () => setPage(1)

  return (
    <AdminLayout>
      <div className="space-y-6">
        {/* Title */}
        <div>
          <h1 className="text-2xl font-bold text-base-content">{t('admin.punishment_reasons.title')}</h1>
        </div>

        {/* Filters */}
        <Card>
          <CardContent className="p-4">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
              <div className="flex flex-1 items-center gap-3">
                <div className="relative flex-1">
                  <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-neutral/50" />
                  <Input value={search} onChange={(e) => { setSearch(e.target.value); resetPage() }}
                    placeholder={t('admin.punishment_reasons.search')} className="pl-10" />
                </div>
                <div className="flex items-center gap-2">
                  <label className="text-sm text-neutral/60 whitespace-nowrap">{t('admin.punishment_reasons.per_page')}</label>
                  <select value={perPage} onChange={(e) => { setPerPage(Number(e.target.value)); resetPage() }}
                    className="h-10 w-20 rounded-lg border border-neutral/20 bg-base-200 px-2 text-sm text-base-content focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary">
                    <option value={10}>10</option><option value={25}>25</option><option value={50}>50</option><option value={100}>100</option>
                  </select>
                </div>
              </div>
              <Button onClick={() => setCreating(true)}>
                <Plus className="w-4 h-4 mr-2" />{t('admin.punishment_reasons.add')}
              </Button>
            </div>
          </CardContent>
        </Card>

        {/* Content */}
        <Card>
          <CardContent className="p-0">
            {isLoading ? (
              <div className="p-8 text-center"><LoadingSpinner size="md" /><p className="text-neutral/60 mt-2">{t('admin.punishment_reasons.loading', 'Loading...')}</p></div>
            ) : reasons.length === 0 ? (
              <div className="p-8 text-center text-neutral/60">{t('admin.punishment_reasons.no_data', 'No reasons found')}</div>
            ) : (
              <>
                {/* Desktop table */}
                <div className="hidden overflow-x-auto md:block">
                  <table className="w-full">
                    <thead>
                      <tr className="border-b border-base-300">
                        <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.punishment_reasons.table.id')}</th>
                        <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.punishment_reasons.table.name')}</th>
                        <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.punishment_reasons.table.description')}</th>
                        <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.punishment_reasons.table.status')}</th>
                        <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.punishment_reasons.table.date')}</th>
                        <th className="text-right p-4 text-sm font-medium text-neutral/60">{t('admin.punishment_reasons.table.actions')}</th>
                      </tr>
                    </thead>
                    <tbody>
                      {reasons.map((r) => (
                        <tr key={r.id} className="border-b border-base-300 hover:bg-base-200/50 transition-colors">
                          <td className="p-4 text-sm text-neutral/60">{r.id}</td>
                          <td className="p-4 font-medium text-base-content">{r.name}</td>
                          <td className="p-4 text-sm text-neutral/70 max-w-xs truncate">{r.description}</td>
                          <td className="p-4">{getStatusBadge(r.active)}</td>
                          <td className="p-4 text-sm text-neutral/60">{new Date(r.created_at).toLocaleDateString()}</td>
                          <td className="p-4">
                            <div className="flex justify-end gap-2">
                              <Button variant="ghost" size="sm" onClick={() => setEditing(r)}>
                                <Pencil className="w-4 h-4" />
                              </Button>
                              <Button variant="ghost" size="sm" onClick={() => setDeleting(r)}>
                                <Trash2 className="w-4 h-4" />
                              </Button>
                            </div>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>

                {/* Mobile cards */}
                <div className="md:hidden divide-y divide-base-300">
                  {reasons.map((r) => (
                    <div key={r.id} className="p-4 space-y-3">
                      <div className="flex items-center justify-between">
                        <span className="text-sm text-neutral/60">#{r.id}</span>
                        {getStatusBadge(r.active)}
                      </div>
                      <div>
                        <p className="font-medium text-base-content">{r.name}</p>
                        <p className="text-sm text-neutral/70 line-clamp-2">{r.description}</p>
                      </div>
                      <p className="text-xs text-neutral/60">{new Date(r.created_at).toLocaleDateString()}</p>
                      <div className="flex gap-2">
                        <Button variant="outline" size="sm" className="flex-1" onClick={() => setEditing(r)}>
                          <Pencil className="w-4 h-4 mr-2" />{t('admin.punishment_reasons.edit')}
                        </Button>
                        <Button variant="destructive" size="sm" className="flex-1" onClick={() => setDeleting(r)}>
                          <Trash2 className="w-4 h-4 mr-2" />{t('admin.punishment_reasons.delete')}
                        </Button>
                      </div>
                    </div>
                  ))}
                </div>
              </>
            )}

            {/* Pagination */}
            {totalPages > 1 && (
              <div className="p-4 flex items-center justify-between border-t border-base-300">
                <p className="text-sm text-neutral/60">{t('admin.punishment_reasons.showing', 'Showing')} {reasons.length} / {total}</p>
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

        {/* Create Modal */}
        <Modal isOpen={creating} onClose={() => setCreating(false)} title={t('admin.punishment_reasons.add')}>
          <ReasonForm onSave={(data) => create.mutate(data)} onCancel={() => setCreating(false)} />
        </Modal>

        {/* Edit Modal */}
        <Modal isOpen={!!editing} onClose={() => setEditing(null)} title={t('admin.punishment_reasons.edit')}>
          {editing && (
            <ReasonForm reason={editing} onSave={(data) => update.mutate({ id: editing.id, ...data })} onCancel={() => setEditing(null)} />
          )}
        </Modal>

        {/* Delete Confirmation Modal */}
        <Modal isOpen={!!deleting} onClose={() => setDeleting(null)} title={t('admin.punishment_reasons.delete')}>
          {deleting && (
            <div className="space-y-4">
              <div className="flex items-start gap-3 text-error">
                <AlertTriangle className="w-5 h-5 mt-0.5 flex-shrink-0" />
                <p className="text-sm">{t('admin.punishment_reasons.confirm_delete')}</p>
              </div>
              <div className="p-3 bg-base-200 rounded-lg">
                <p className="font-medium text-base-content">{deleting.name}</p>
                <p className="text-sm text-neutral/60">{deleting.description}</p>
              </div>
              <div className="flex gap-3">
                <Button variant="destructive" className="flex-1" onClick={() => remove.mutate(deleting.id)} isLoading={remove.isPending}>
                  {t('admin.punishment_reasons.delete')}
                </Button>
                <Button variant="outline" className="flex-1" onClick={() => setDeleting(null)}>
                  {t('admin.punishment_reasons.cancel')}
                </Button>
              </div>
            </div>
          )}
        </Modal>
      </div>
    </AdminLayout>
  )
}

export default AdminPunishmentReasons
