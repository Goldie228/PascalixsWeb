import { useState } from 'react'
import { motion } from 'framer-motion'
import { useTranslation } from 'react-i18next'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { Search, Pencil, Trash2, Plus } from 'lucide-react'
import { Card, CardContent } from '@/components/ui/Card'
import { Button } from '@/components/ui/Button'
import { Badge } from '@/components/ui/Badge'
import { Modal } from '@/components/ui/Modal'
import { Input } from '@/components/ui/Input'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import { useToast } from '@/components/ui/Toast'
import AdminLayout from '@/components/admin/AdminLayout'
import { adminApi } from '@/services/adminApi'
import type { GalleryAlbum } from '@/types'

function AdminGallery() {
  const { t } = useTranslation()
  const { success: toast } = useToast()
  const qc = useQueryClient()
  const [page, setPage] = useState(1)
  const [perPage, setPerPage] = useState(25)
  const [search, setSearch] = useState('')
  const [modal, setModal] = useState<'none' | 'create' | 'edit'>('none')
  const [album, setAlbum] = useState<GalleryAlbum | null>(null)
  const [form, setForm] = useState({ title: '', description: '' })

  const { data, isLoading } = useQuery({
    queryKey: ['admin-gallery', page, perPage],
    queryFn: () => adminApi.getGalleries({ page, per_page: perPage }),
    staleTime: 1000 * 60 * 5,
  })

  const create = useMutation({ mutationFn: adminApi.createGallery, onSuccess: () => { toast(t('admin.gallery.added', 'Album created')); qc.invalidateQueries({ queryKey: ['admin-gallery'] }); setModal('none') } })
  const update = useMutation({ mutationFn: (d: { id: number; title: string; description: string }) => adminApi.updateGallery(d.id, { title: d.title, description: d.description }), onSuccess: () => { toast(t('admin.gallery.updated', 'Album updated')); qc.invalidateQueries({ queryKey: ['admin-gallery'] }); setModal('none') } })
  const remove = useMutation({ mutationFn: adminApi.deleteGallery, onSuccess: () => { toast(t('admin.gallery.deleted', 'Album deleted')); qc.invalidateQueries({ queryKey: ['admin-gallery'] } ) } })

  const galleries = data?.data?.galleries ?? []
  const total = data?.data?.total ?? 0
  const totalPages = Math.ceil(total / perPage) || 1
  const reset = () => setPage(1)

  const openCreate = () => { setForm({ title: '', description: '' }); setAlbum(null); setModal('create') }
  const openEdit = (a: GalleryAlbum) => { setForm({ title: a.title, description: a.description }); setAlbum(a); setModal('edit') }
  const save = () => {
    if (!form.title.trim()) return
    modal === 'create' ? create.mutate({ title: form.title, description: form.description })
      : update.mutate({ id: album!.id, title: form.title, description: form.description })
  }

  const FormFields = () => (
    <div className="space-y-4">
      <div>
        <label className="label-text font-medium text-base-content">{t('admin.gallery.title_label', 'Title')}</label>
        <Input value={form.title} onChange={e => setForm(f => ({ ...f, title: e.target.value }))} className="mt-1" />
      </div>
      <div>
        <label className="label-text font-medium text-base-content">{t('admin.gallery.description', 'Description')}</label>
        <textarea value={form.description} onChange={e => setForm(f => ({ ...f, description: e.target.value }))}
          className="mt-1 w-full min-h-[80px] rounded-lg border border-neutral/20 bg-base-200 px-3 py-2 text-sm text-base-content focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary" />
      </div>
      <div className="flex gap-3 pt-2">
        <Button className="flex-1" onClick={save} isLoading={create.isPending || update.isPending}>
          <Pencil className="w-4 h-4 mr-2" />{t('admin.gallery.save', 'Save')}
        </Button>
        <Button variant="outline" className="flex-1" onClick={() => setModal('none')}>
          {t('admin.gallery.cancel', 'Cancel')}
        </Button>
      </div>
    </div>
  )

  return (
    <AdminLayout>
      <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.3 }}>
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-base-content">{t('admin.gallery.title', 'Gallery')}</h1>
        </div>

        {/* Filters */}
        <Card className="mb-4">
          <CardContent className="p-4">
            <div className="flex flex-wrap items-center gap-3">
              <div className="relative flex-1 min-w-[200px]">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-neutral/50" />
                <Input value={search} onChange={e => { setSearch(e.target.value); reset() }} placeholder={t('admin.gallery.search', 'Search albums...')} className="pl-10" />
              </div>
              <div className="flex items-end gap-2">
                <label className="text-sm text-neutral/60">{t('admin.gallery.per_page', 'Records per page')}</label>
                <select value={perPage} onChange={e => { setPerPage(Number(e.target.value)); reset() }}
                  className="h-10 w-20 rounded-lg border border-neutral/20 bg-base-200 px-2 text-sm text-base-content focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary">
                  <option value={10}>10</option><option value={25}>25</option><option value={50}>50</option><option value={100}>100</option>
                </select>
              </div>
              <Button onClick={openCreate}>
                <Plus className="w-4 h-4 mr-2" />{t('admin.gallery.add', 'Add Album')}
              </Button>
            </div>
          </CardContent>
        </Card>

        {/* Content */}
        <Card>
          <CardContent className="p-0">
            {isLoading ? (
              <div className="p-8 text-center"><LoadingSpinner size="md" /><p className="text-neutral/60 mt-2">{t('admin.gallery.loading', 'Loading galleries...')}</p></div>
            ) : galleries.length === 0 ? (
              <div className="p-8 text-center text-neutral/60">{t('admin.gallery.no_data', 'No albums found')}</div>
            ) : (
              <>
                {/* Desktop table */}
                <div className="hidden overflow-x-auto md:block">
                  <table className="w-full">
                    <thead><tr className="border-b border-base-300">
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.gallery.table.id', 'ID')}</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.gallery.table.title', 'Title')}</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.gallery.table.photos', 'Photos')}</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.gallery.table.date', 'Created')}</th>
                      <th className="text-right p-4 text-sm font-medium text-neutral/60">{t('admin.gallery.table.actions', 'Actions')}</th>
                    </tr></thead>
                    <tbody>
                      {galleries.map(a => (
                        <tr key={a.id} className="border-b border-base-300 hover:bg-base-200/50 transition-colors">
                          <td className="p-4 text-sm text-neutral/60">#{a.id}</td>
                          <td className="p-4 font-medium text-base-content">{a.title}</td>
                          <td className="p-4"><Badge variant="default">{a.photos_count}</Badge></td>
                          <td className="p-4 text-sm text-neutral/60">{new Date(a.created_at).toLocaleDateString()}</td>
                          <td className="p-4">
                            <div className="flex justify-end gap-2">
                              <Button variant="ghost" size="sm" onClick={() => openEdit(a)}><Pencil className="w-4 h-4" /></Button>
                              <Button variant="ghost" size="sm" className="text-error hover:text-error" onClick={() => { if (window.confirm(t('admin.gallery.confirm_delete', 'Are you sure you want to delete this album?'))) remove.mutate(a.id) }}>
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
                  {galleries.map(a => (
                    <div key={a.id} className="p-4 space-y-3">
                      <div className="flex items-center justify-between">
                        <div>
                          <p className="font-medium text-base-content">{a.title}</p>
                          <p className="text-xs text-neutral/60">#{a.id} · {new Date(a.created_at).toLocaleDateString()}</p>
                        </div>
                        <Badge variant="default">{a.photos_count}</Badge>
                      </div>
                      <div className="flex gap-2">
                        <Button variant="ghost" size="sm" className="flex-1" onClick={() => openEdit(a)}>
                          <Pencil className="w-4 h-4 mr-2" />{t('admin.gallery.edit', 'Edit')}
                        </Button>
                        <Button variant="ghost" size="sm" className="text-error hover:text-error flex-1"
                          onClick={() => { if (window.confirm(t('admin.gallery.confirm_delete', 'Are you sure you want to delete this album?'))) remove.mutate(a.id) }}>
                          <Trash2 className="w-4 h-4 mr-2" />{t('admin.gallery.delete', 'Delete')}
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
                <p className="text-sm text-neutral/60">{galleries.length} / {total}</p>
                <div className="flex items-center gap-2">
                  <Button variant="outline" size="sm" onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1}>
                    {t('admin.previous', 'Prev')}
                  </Button>
                  <span className="text-neutral/60 text-sm px-2">{page} / {totalPages}</span>
                  <Button variant="outline" size="sm" onClick={() => setPage(p => Math.min(totalPages, p + 1))} disabled={page === totalPages}>
                    {t('admin.next', 'Next')}
                  </Button>
                </div>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Create/Edit Modal */}
        <Modal isOpen={modal !== 'none'} onClose={() => setModal('none')} title={modal === 'create' ? t('admin.gallery.add', 'Add Album') : t('admin.gallery.edit', 'Edit Album')}>
          <FormFields />
        </Modal>
      </motion.div>
    </AdminLayout>
  )
}

export default AdminGallery
