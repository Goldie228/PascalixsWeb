import { useState } from 'react'
import { motion } from 'framer-motion'
import { useTranslation } from 'react-i18next'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { Search, Edit2, Check, X } from 'lucide-react'
import { Card, CardContent } from '@/components/ui/Card'
import { Button } from '@/components/ui/Button'
import { Badge } from '@/components/ui/Badge'
import { Modal } from '@/components/ui/Modal'
import { Input } from '@/components/ui/Input'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import { useToast } from '@/components/ui/Toast'
import AdminLayout from '@/components/admin/AdminLayout'
import { adminApi } from '@/services/adminApi'
import type { Product } from '@/types'

function AdminProducts() {
  const { t } = useTranslation()
  const { success: showSuccess } = useToast()
  const queryClient = useQueryClient()

  const [page, setPage] = useState(1)
  const [perPage, setPerPage] = useState(50)
  const [search, setSearch] = useState('')
  const [selected, setSelected] = useState<Product | null>(null)
  const [newPrice, setNewPrice] = useState('')

  const { data, isLoading } = useQuery({
    queryKey: ['admin-products', page, perPage, search],
    queryFn: () => adminApi.getProducts({ page, per_page: perPage, search: search || undefined }),
    staleTime: 1000 * 60 * 5,
  })

  const updatePrice = useMutation({
    mutationFn: ({ id, price }: { id: number; price: number }) => adminApi.updateProductPrice(id, price),
    onSuccess: () => { showSuccess(t('admin.products.price_updated', 'Price updated')); queryClient.invalidateQueries({ queryKey: ['admin-products'] }) },
  })

  const products = data?.data?.products ?? []
  const total = data?.data?.total ?? 0
  const totalPages = Math.ceil(total / perPage) || 1

  const resetPage = () => setPage(1)

  const openEdit = (p: Product) => { setSelected(p); setNewPrice(String(p.price)) }

  const handleSave = () => {
    if (!selected || isNaN(Number(newPrice))) return
    updatePrice.mutate({ id: selected.id, price: Number(newPrice) })
    setSelected(null)
  }

  return (
    <AdminLayout>
      <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.3 }}>
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-base-content">{t('admin.products.title')}</h1>
          <p className="text-sm text-neutral/60">{t('admin.products.manage_desc', 'Manage shop products')}</p>
        </div>

        {/* Filters */}
        <Card className="mb-4">
          <CardContent className="p-4">
            <div className="flex flex-wrap items-end gap-3">
              <div className="relative flex-1 min-w-[200px]">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-neutral/50" />
                <Input value={search} onChange={(e) => { setSearch(e.target.value); resetPage() }} placeholder={t('admin.products.search')} className="pl-10" />
              </div>
              <div className="flex items-end gap-2">
                <label className="text-sm text-neutral/60 whitespace-nowrap">{t('admin.products.per_page')}</label>
                <select value={perPage} onChange={(e) => { setPerPage(Number(e.target.value)); resetPage() }}
                  className="h-10 w-20 rounded-lg border border-neutral/20 bg-base-200 px-2 text-sm text-base-content focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary">
                  <option value={25}>25</option><option value={50}>50</option><option value={100}>100</option>
                </select>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Content */}
        <Card>
          <CardContent className="p-0">
            {isLoading ? (
              <div className="p-8 text-center"><LoadingSpinner size="md" /><p className="text-neutral/60 mt-2">{t('admin.products.loading', 'Loading products...')}</p></div>
            ) : products.length === 0 ? (
              <div className="p-8 text-center text-neutral/60">{t('admin.products.no_data', 'No products found')}</div>
            ) : (
              <>
                {/* Desktop table */}
                <div className="hidden overflow-x-auto md:block">
                  <table className="w-full">
                    <thead><tr className="border-b border-base-300">
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.products.table.id')}</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.products.table.name')}</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.products.table.description')}</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.products.table.price')}</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.products.table.currency')}</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.products.table.status')}</th>
                      <th className="text-right p-4 text-sm font-medium text-neutral/60">{t('admin.products.table.actions')}</th>
                    </tr></thead>
                    <tbody>
                      {products.map((p) => (
                        <tr key={p.id} className="border-b border-base-300 hover:bg-base-200/50 transition-colors">
                          <td className="p-4 text-neutral/60 text-sm">{p.id}</td>
                          <td className="p-4 font-medium text-base-content">{p.name}</td>
                          <td className="p-4 text-sm text-neutral/60 max-w-[200px] truncate">{p.description}</td>
                          <td className="p-4 font-medium">{p.price.toFixed(2)}</td>
                          <td className="p-4 text-sm text-neutral/60">{p.currency}</td>
                          <td className="p-4">
                            <Badge variant={p.active ? 'success' : 'error'}>{p.active ? t('admin.products.active') : t('admin.products.inactive')}</Badge>
                          </td>
                          <td className="p-4">
                            <div className="flex justify-end gap-2">
                              <Button variant="ghost" size="sm" onClick={() => openEdit(p)}><Edit2 className="w-4 h-4" /></Button>
                            </div>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>

                {/* Mobile cards */}
                <div className="md:hidden divide-y divide-base-300">
                  {products.map((p) => (
                    <div key={p.id} className="p-4 space-y-3">
                      <div className="flex items-center justify-between">
                        <div>
                          <p className="font-medium text-base-content">{p.name}</p>
                          <p className="text-xs text-neutral/60">ID: {p.id}</p>
                        </div>
                        <Badge variant={p.active ? 'success' : 'error'}>{p.active ? t('admin.products.active') : t('admin.products.inactive')}</Badge>
                      </div>
                      <p className="text-sm text-neutral/60 line-clamp-2">{p.description}</p>
                      <div className="flex items-center justify-between">
                        <span className="font-bold text-base-content">{p.price.toFixed(2)} {p.currency}</span>
                        <Button variant="ghost" size="sm" onClick={() => openEdit(p)}>
                          <Edit2 className="w-4 h-4 mr-1" />{t('admin.products.edit_price')}
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
                <p className="text-sm text-neutral/60">{t('admin.products.showing', 'Showing')} {products.length} / {total}</p>
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

        {/* Edit Price Modal */}
        <Modal isOpen={!!selected} onClose={() => setSelected(null)} title={t('admin.products.edit_price')} size="sm">
          {selected && (
            <div className="space-y-4">
              <div>
                <p className="text-sm font-medium text-base-content mb-1">{selected.name}</p>
                <p className="text-xs text-neutral/60">{selected.description}</p>
              </div>
              <div>
                <label className="block text-sm text-neutral/60 mb-1">{t('admin.products.new_price')}</label>
                <Input type="number" step="0.01" value={newPrice} onChange={(e) => setNewPrice(e.target.value)} className="w-full" />
              </div>
              <div className="flex gap-3">
                <Button className="flex-1" onClick={handleSave} isLoading={updatePrice.isPending}>
                  <Check className="w-4 h-4 mr-2" />{t('admin.products.save')}
                </Button>
                <Button variant="outline" className="flex-1" onClick={() => setSelected(null)}>
                  <X className="w-4 h-4 mr-2" />{t('admin.products.cancel')}
                </Button>
              </div>
            </div>
          )}
        </Modal>
      </motion.div>
    </AdminLayout>
  )
}

export default AdminProducts
