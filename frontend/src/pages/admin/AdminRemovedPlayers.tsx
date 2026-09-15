import { useState } from 'react'
import { motion } from 'framer-motion'
import { useTranslation } from 'react-i18next'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { Search, RotateCcw, Plus } from 'lucide-react'
import { Card, CardContent } from '@/components/ui/Card'
import { Button } from '@/components/ui/Button'
import { Badge } from '@/components/ui/Badge'
import { Modal } from '@/components/ui/Modal'
import { Input } from '@/components/ui/Input'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import { useToast } from '@/components/ui/Toast'
import AdminLayout from '@/components/admin/AdminLayout'
import { adminApi } from '@/services/adminApi'
import type { RemovedPlayer } from '@/types'

function AdminRemovedPlayers() {
  const { t } = useTranslation()
  const { success: showSuccess, error: showError } = useToast()
  const queryClient = useQueryClient()

  const [page, setPage] = useState(1)
  const [perPage, setPerPage] = useState(50)
  const [search, setSearch] = useState('')
  const [selected, setSelected] = useState<RemovedPlayer | null>(null)
  const [addModal, setAddModal] = useState(false)
  const [addForm, setAddForm] = useState({ nickname: '', reason: '' })

  const resetPage = () => setPage(1)

  const { data, isLoading } = useQuery({
    queryKey: ['admin-removed-players', page, perPage, search],
    queryFn: () => adminApi.getRemovedPlayers({ page, per_page: perPage, search: search || undefined }),
    staleTime: 1000 * 60 * 5,
  })

  const restore = useMutation({
    mutationFn: (nickname: string) => adminApi.restorePlayer(nickname),
    onSuccess: (_, nickname) => {
      showSuccess(t('admin.removed_players.restore_success', { nickname }))
      queryClient.invalidateQueries({ queryKey: ['admin-removed-players'] })
      setSelected(null)
    },
    onError: () => showError(t('admin.removed_players.restore_error')),
  })

  const addRemovedPlayer = useMutation({
    mutationFn: (data: { nickname: string; reason: string }) => adminApi.addRemovedPlayer(data),
    onSuccess: () => {
      showSuccess(t('admin.removed_players.added', 'Player added to removed list'))
      queryClient.invalidateQueries({ queryKey: ['admin-removed-players'] })
      setAddModal(false)
      setAddForm({ nickname: '', reason: '' })
    },
    onError: () => showError(t('admin.removed_players.add_error', 'Failed to add player')),
  })

  const players = data?.data?.removed_players ?? []
  const total = data?.data?.total ?? 0
  const totalPages = Math.ceil(total / perPage) || 1

  return (
    <AdminLayout>
      <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.3 }}>
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-base-content">{t('admin.removed_players.title')}</h1>
        </div>

        {/* Filters */}
        <Card className="mb-4">
          <CardContent className="p-4">
            <div className="flex flex-wrap items-end gap-3">
              <div className="flex-1 min-w-[200px] relative">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-neutral/50" />
                <Input value={search} onChange={(e) => { setSearch(e.target.value); resetPage() }} placeholder={t('admin.removed_players.search')} className="pl-10" />
              </div>
              <div className="flex items-end gap-2">
                <label className="text-sm text-neutral/60 whitespace-nowrap">{t('admin.removed_players.per_page')}</label>
                <select value={perPage} onChange={(e) => { setPerPage(Number(e.target.value)); resetPage() }}
                  className="h-10 w-20 rounded-lg border border-neutral/20 bg-base-200 px-2 text-sm text-base-content focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary">
                  <option value={25}>25</option><option value={50}>50</option><option value={100}>100</option>
                </select>
              </div>
              <Button onClick={() => setAddModal(true)}>
                <Plus className="w-4 h-4 mr-2" />{t('admin.removed_players.add', 'Add Player')}
              </Button>
            </div>
          </CardContent>
        </Card>

        {/* Content */}
        <Card>
          <CardContent className="p-0">
            {isLoading ? (
              <div className="p-8 text-center"><LoadingSpinner size="md" /><p className="text-neutral/60 mt-2">{t('admin.removed_players.loading', 'Loading...')}</p></div>
            ) : players.length === 0 ? (
              <div className="p-8 text-center text-neutral/60">{t('admin.removed_players.no_data', 'No removed players found')}</div>
            ) : (
              <>
                {/* Desktop table */}
                <div className="hidden overflow-x-auto md:block">
                  <table className="w-full">
                    <thead><tr className="border-b border-base-300">
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.removed_players.table.nickname')}</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.removed_players.table.reason')}</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.removed_players.table.banned_date')}</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.removed_players.table.restored_date')}</th>
                      <th className="text-right p-4 text-sm font-medium text-neutral/60">{t('admin.removed_players.table.actions')}</th>
                    </tr></thead>
                    <tbody>
                      {players.map((p) => (
                        <tr key={p.id} className="border-b border-base-300 hover:bg-base-200/50 transition-colors">
                          <td className="p-4 font-medium text-base-content">{p.nickname}</td>
                          <td className="p-4 text-sm text-neutral/60 max-w-xs truncate">{p.reason}</td>
                          <td className="p-4 text-sm text-neutral/60">{new Date(p.banned_at).toLocaleDateString()}</td>
                          <td className="p-4">
                            {p.restored_at
                              ? <Badge variant="success">{new Date(p.restored_at).toLocaleDateString()}</Badge>
                              : <Badge variant="error">{t('admin.removed_players.active', 'Active')}</Badge>}
                          </td>
                          <td className="p-4">
                            <div className="flex justify-end">
                              {!p.restored_at && (
                                <Button variant="ghost" size="sm" onClick={() => setSelected(p)}>
                                  <RotateCcw className="w-4 h-4 mr-1" />{t('admin.removed_players.restore')}
                                </Button>
                              )}
                            </div>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>

                {/* Mobile cards */}
                <div className="md:hidden divide-y divide-base-300">
                  {players.map((p) => (
                    <div key={p.id} className="p-4 space-y-2">
                      <div className="flex items-center justify-between">
                        <span className="font-medium text-base-content">{p.nickname}</span>
                        {!p.restored_at && (
                          <Button variant="ghost" size="sm" onClick={() => setSelected(p)}>
                            <RotateCcw className="w-4 h-4 mr-1" />{t('admin.removed_players.restore')}
                          </Button>
                        )}
                      </div>
                      <p className="text-sm text-neutral/60">{p.reason}</p>
                      <div className="flex items-center gap-2 text-xs text-neutral/50">
                        <span>Banned: {new Date(p.banned_at).toLocaleDateString()}</span>
                        {p.restored_at && <span>• Restored: {new Date(p.restored_at).toLocaleDateString()}</span>}
                      </div>
                    </div>
                  ))}
                </div>
              </>
            )}

            {/* Pagination */}
            {totalPages > 1 && (
              <div className="p-4 flex items-center justify-between border-t border-base-300">
                <p className="text-sm text-neutral/60">{t('admin.removed_players.showing', 'Showing')} {players.length} / {total}</p>
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

        {/* Restore Confirmation Modal */}
        <Modal isOpen={!!selected} onClose={() => !restore.isPending && setSelected(null)} title={t('admin.removed_players.confirm_restore', { nickname: selected?.nickname })} size="sm">
          {selected && (
            <div className="space-y-4">
              <div className="space-y-2 text-sm text-neutral/70">
                <p><strong>{t('admin.removed_players.table.nickname')}:</strong> {selected.nickname}</p>
                <p><strong>{t('admin.removed_players.table.reason')}:</strong> {selected.reason}</p>
                <p><strong>{t('admin.removed_players.table.banned_date')}:</strong> {new Date(selected.banned_at).toLocaleString()}</p>
              </div>
              <div className="flex gap-3">
                <Button className="flex-1" onClick={() => restore.mutate(selected.nickname)} isLoading={restore.isPending}>
                  {t('admin.removed_players.yes')}
                </Button>
                <Button variant="outline" className="flex-1" onClick={() => setSelected(null)} disabled={restore.isPending}>
                  {t('admin.removed_players.cancel')}
                </Button>
              </div>
            </div>
          )}
        </Modal>

        {/* Add Removed Player Modal */}
        <Modal isOpen={addModal} onClose={() => !addRemovedPlayer.isPending && setAddModal(false)} title={t('admin.removed_players.add_title', 'Add Removed Player')} size="sm">
          <div className="space-y-4">
            <Input
              label={t('admin.removed_players.table.nickname')}
              value={addForm.nickname}
              onChange={(e) => setAddForm(f => ({ ...f, nickname: e.target.value }))}
              placeholder={t('admin.removed_players.add_nickname_placeholder', 'Enter nickname')}
              disabled={addRemovedPlayer.isPending}
            />
            <div>
              <label className="text-sm font-medium text-base-content">{t('admin.removed_players.table.reason')}</label>
              <textarea
                value={addForm.reason}
                onChange={(e) => setAddForm(f => ({ ...f, reason: e.target.value }))}
                placeholder={t('admin.removed_players.add_reason_placeholder', 'Reason for removal')}
                className="mt-1 w-full min-h-[80px] rounded-lg border border-neutral/20 bg-base-200 px-3 py-2 text-sm text-base-content focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
                disabled={addRemovedPlayer.isPending}
              />
            </div>
            <div className="flex gap-3">
              <Button
                className="flex-1"
                onClick={() => addRemovedPlayer.mutate({ nickname: addForm.nickname, reason: addForm.reason })}
                isLoading={addRemovedPlayer.isPending}
                disabled={!addForm.nickname.trim() || !addForm.reason.trim()}
              >
                {t('admin.removed_players.add', 'Add')}
              </Button>
              <Button variant="outline" className="flex-1" onClick={() => setAddModal(false)} disabled={addRemovedPlayer.isPending}>
                {t('admin.removed_players.cancel')}
              </Button>
            </div>
          </div>
        </Modal>
      </motion.div>
    </AdminLayout>
  )
}

export default AdminRemovedPlayers
