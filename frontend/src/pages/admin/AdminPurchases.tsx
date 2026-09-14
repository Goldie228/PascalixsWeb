import { useState } from 'react'
import { motion } from 'framer-motion'
import { useTranslation } from 'react-i18next'
import { useQuery } from '@tanstack/react-query'
import { Search, Eye } from 'lucide-react'
import { Card, CardContent } from '@/components/ui/Card'
import { Button } from '@/components/ui/Button'
import { Badge } from '@/components/ui/Badge'
import { Modal } from '@/components/ui/Modal'
import { Input } from '@/components/ui/Input'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import AdminLayout from '@/components/admin/AdminLayout'
import { adminApi } from '@/services/adminApi'
import type { Purchase } from '@/types'

function getStatusColor(status: Purchase['status']) {
  const map = { pending: 'warning' as const, completed: 'success' as const, failed: 'error' as const, refunded: 'info' as const }
  return map[status]
}

function AdminPurchases() {
  const { t } = useTranslation()

  const [page, setPage] = useState(1)
  const [perPage, setPerPage] = useState(50)
  const [statusFilter, setStatusFilter] = useState('')
  const [search, setSearch] = useState('')
  const [selected, setSelected] = useState<Purchase | null>(null)

  const { data, isLoading } = useQuery({
    queryKey: ['admin-purchases', page, perPage, statusFilter, search],
    queryFn: () => adminApi.getPurchases({ page, per: perPage, search: search || undefined, status: statusFilter || undefined }),
    staleTime: 1000 * 60 * 5,
  })

  const purchases = data?.data?.purchases ?? []
  const total = data?.data?.pagination?.total ?? 0
  const totalPages = Math.ceil(total / perPage) || 1
  const resetPage = () => setPage(1)

  return (
    <AdminLayout>
      <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.3 }}>
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-base-content">{t('admin.purchases.title')}</h1>
          <p className="text-sm text-neutral/60">{t('admin.purchases.manage_desc', 'Manage server purchases')}</p>
        </div>

        {/* Filters */}
        <Card className="mb-4">
          <CardContent className="p-4">
            <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
              <div className="relative sm:col-span-2">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-neutral/50" />
                <Input value={search} onChange={(e) => { setSearch(e.target.value); resetPage() }} placeholder={t('admin.purchases.search')} className="pl-10" />
              </div>
              <select value={statusFilter} onChange={(e) => { setStatusFilter(e.target.value); resetPage() }}
                className="h-10 rounded-lg border border-neutral/20 bg-base-200 px-3 text-sm text-base-content focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary">
                <option value="">{t('admin.purchases.all_statuses')}</option>
                <option value="pending">{t('admin.purchases.pending')}</option>
                <option value="completed">{t('admin.purchases.completed')}</option>
                <option value="failed">{t('admin.purchases.failed')}</option>
                <option value="refunded">{t('admin.purchases.refunded')}</option>
              </select>
              <div className="flex items-end gap-2">
                <label className="text-sm text-neutral/60 whitespace-nowrap">{t('admin.purchases.per_page')}</label>
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
              <div className="p-8 text-center"><LoadingSpinner size="md" /><p className="text-neutral/60 mt-2">{t('admin.purchases.loading', 'Loading purchases...')}</p></div>
            ) : purchases.length === 0 ? (
              <div className="p-8 text-center text-neutral/60">{t('admin.purchases.no_data', 'No purchases found')}</div>
            ) : (
              <>
                {/* Desktop table */}
                <div className="hidden overflow-x-auto md:block">
                  <table className="w-full">
                    <thead><tr className="border-b border-base-300">
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.purchases.table.id')}</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.purchases.table.user')}</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.purchases.table.product')}</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.purchases.table.amount')}</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.purchases.table.currency')}</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.purchases.table.status')}</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.purchases.table.payment')}</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.purchases.table.date')}</th>
                      <th className="text-right p-4 text-sm font-medium text-neutral/60">{t('admin.purchases.table.actions')}</th>
                    </tr></thead>
                    <tbody>
                      {purchases.map((p) => (
                        <tr key={p.id} className="border-b border-base-300 hover:bg-base-200/50 transition-colors">
                          <td className="p-4 text-neutral/60 text-sm">#{p.id}</td>
                          <td className="p-4 font-medium text-base-content">{p.username}</td>
                          <td className="p-4 text-base-content">{p.product_name}</td>
                          <td className="p-4 font-medium text-base-content">{p.amount}</td>
                          <td className="p-4 text-neutral/60 text-sm">{p.currency}</td>
                          <td className="p-4"><Badge variant={getStatusColor(p.status)}>{t(`admin.purchases.${p.status}`)}</Badge></td>
                          <td className="p-4 text-neutral/60 text-sm">{p.payment_method}</td>
                          <td className="p-4 text-neutral/60 text-sm">{new Date(p.created_at).toLocaleDateString()}</td>
                          <td className="p-4">
                            <div className="flex justify-end">
                              <Button variant="ghost" size="sm" onClick={() => setSelected(p)}><Eye className="w-4 h-4" /></Button>
                            </div>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>

                {/* Mobile cards */}
                <div className="md:hidden divide-y divide-base-300">
                  {purchases.map((p) => (
                    <div key={p.id} className="p-4 space-y-3">
                      <div className="flex items-center justify-between">
                        <div>
                          <p className="font-medium text-base-content">#{p.id} — {p.username}</p>
                          <p className="text-xs text-neutral/60">{p.product_name}</p>
                        </div>
                        <Badge variant={getStatusColor(p.status)}>{t(`admin.purchases.${p.status}`)}</Badge>
                      </div>
                      <div className="grid grid-cols-2 gap-2 text-sm">
                        <p><span className="text-neutral/60">{t('admin.purchases.table.amount')}:</span> {p.amount} {p.currency}</p>
                        <p><span className="text-neutral/60">{t('admin.purchases.table.payment')}:</span> {p.payment_method}</p>
                        <p><span className="text-neutral/60">{t('admin.purchases.table.date')}:</span> {new Date(p.created_at).toLocaleDateString()}</p>
                      </div>
                      <Button variant="ghost" size="sm" className="w-full" onClick={() => setSelected(p)}>
                        <Eye className="w-4 h-4 mr-2" />{t('admin.purchases.view')}
                      </Button>
                    </div>
                  ))}
                </div>
              </>
            )}

            {/* Pagination */}
            {totalPages > 1 && (
              <div className="p-4 flex items-center justify-between border-t border-base-300">
                <p className="text-sm text-neutral/60">{t('admin.purchases.showing', 'Showing')} {purchases.length} / {total}</p>
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

        {/* Detail Modal */}
        <Modal isOpen={!!selected} onClose={() => setSelected(null)} title={t('admin.purchases.details')} size="lg">
          {selected && (
            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-4 text-sm">
                <div><span className="text-neutral/60">{t('admin.purchases.table.id')}:</span> <span className="font-medium">#{selected.id}</span></div>
                <div><span className="text-neutral/60">{t('admin.purchases.username')}:</span> <span className="font-medium">{selected.username}</span></div>
                <div><span className="text-neutral/60">{t('admin.purchases.table.product')}:</span> <span className="font-medium">{selected.product_name}</span></div>
                <div><span className="text-neutral/60">{t('admin.purchases.table.amount')}:</span> <span className="font-medium">{selected.amount} {selected.currency}</span></div>
                <div><span className="text-neutral/60">{t('admin.purchases.table.status')}:</span> <Badge variant={getStatusColor(selected.status)}>{t(`admin.purchases.${selected.status}`)}</Badge></div>
                <div><span className="text-neutral/60">{t('admin.purchases.payment_method')}:</span> <span className="font-medium">{selected.payment_method}</span></div>
                <div><span className="text-neutral/60">{t('admin.purchases.table.date')}:</span> <span className="font-medium">{new Date(selected.created_at).toLocaleString()}</span></div>
                <div><span className="text-neutral/60">{t('admin.purchases.updated_at', 'Updated')}:</span> <span className="font-medium">{new Date(selected.updated_at).toLocaleString()}</span></div>
              </div>
              <Button variant="outline" className="w-full" onClick={() => setSelected(null)}>
                {t('admin.purchases.close')}
              </Button>
            </div>
          )}
        </Modal>
      </motion.div>
    </AdminLayout>
  )
}

export default AdminPurchases
