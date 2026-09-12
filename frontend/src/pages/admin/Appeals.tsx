import { useState } from 'react'
import { motion } from 'framer-motion'
import { useTranslation } from 'react-i18next'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { Search, Check, X, Eye } from 'lucide-react'
import { useAppeals, useApproveAppeal, useRejectAppeal } from '@/hooks/useAppeals'
import { Card, CardContent } from '@/components/ui/Card'
import { Button } from '@/components/ui/Button'
import { Badge } from '@/components/ui/Badge'
import { Modal } from '@/components/ui/Modal'
import { Input } from '@/components/ui/Input'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import AdminLayout from '@/components/admin/AdminLayout'
import type { Appeal as AppealType } from '@/types'

const rejectSchema = z.object({
  reason: z.string().min(1, 'Rejection reason is required'),
})

type RejectFormData = z.infer<typeof rejectSchema>

function AdminAppeals() {
  const { t } = useTranslation()
  const [search, setSearch] = useState('')
  const [selectedAppeal, setSelectedAppeal] = useState<AppealType | null>(null)
  const [isDetailModalOpen, setIsDetailModalOpen] = useState(false)
  const [isRejectModalOpen, setIsRejectModalOpen] = useState(false)
  const [page, setPage] = useState(1)

  const { data, isLoading, refetch } = useAppeals({ page, per_page: 20 })
  const approveAppeal = useApproveAppeal()
  const rejectAppeal = useRejectAppeal()

  // API response: { appeals: Appeal[], total: number, page: number }
  const appeals = (data?.data as { appeals: AppealType[]; total: number } | undefined)?.appeals || []
  const total = (data?.data as { total: number } | undefined)?.total || 0
  const totalPages = Math.ceil(total / 20)

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
    reset,
  } = useForm<RejectFormData>({
    resolver: zodResolver(rejectSchema),
  })

  const onReject = async (formData: RejectFormData) => {
    if (!selectedAppeal) return
    await rejectAppeal.mutateAsync({
      appealId: selectedAppeal.id,
      reason: formData.reason,
    })
    setIsRejectModalOpen(false)
    reset()
    refetch()
  }

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'pending':
        return <Badge variant="warning">{t('common.pending')}</Badge>
      case 'approved':
        return <Badge variant="success">{t('admin.approved')}</Badge>
      case 'rejected':
        return <Badge variant="error">{t('admin.rejected')}</Badge>
      default:
        return <Badge variant="default">{status}</Badge>
    }
  }

  return (
    <AdminLayout>
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3 }}
      >
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-base-content">{t('admin.appeals_title')}</h1>
          <p className="text-sm text-neutral/60">{t('admin.appeals_subtitle')}</p>
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
                  placeholder={t('admin.search_appeals')}
                  className="pl-10"
                  onKeyDown={(e) => e.key === 'Enter' && refetch()}
                />
              </div>
            </div>

            {/* Appeals table */}
            {isLoading ? (
              <div className="p-8 text-center">
                <LoadingSpinner size="md" />
                <p className="text-neutral/60 mt-2">{t('admin.loading_appeals')}</p>
              </div>
            ) : appeals.length === 0 ? (
              <div className="p-8 text-center text-neutral/60">{t('admin.no_appeals_found')}</div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="border-b border-base-300">
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.player')}</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.punishment')}</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.reason')}</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.date')}</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.status')}</th>
                      <th className="text-right p-4 text-sm font-medium text-neutral/60">{t('admin.actions')}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {appeals.map((appeal) => (
                      <tr
                        key={appeal.id}
                        className="border-b border-base-300 transition-colors hover:bg-base-200/50"
                      >
                        <td className="p-4">
                          <p className="font-medium text-base-content">
                            {appeal.player?.username || `${t('common.unknown')} #${appeal.user_id}`}
                          </p>
                        </td>
                        <td className="p-4">
                          <p className="text-base-content">{appeal.punishment?.type || 'N/A'}</p>
                          <p className="text-neutral/60 text-xs">{appeal.punishment?.reason}</p>
                        </td>
                        <td className="p-4 max-w-xs">
                          <p className="text-base-content truncate">{appeal.reason}</p>
                        </td>
                        <td className="p-4 text-neutral/60">
                          {new Date(appeal.created_at).toLocaleDateString()}
                        </td>
                        <td className="p-4">{getStatusBadge(appeal.status)}</td>
                        <td className="p-4">
                          <div className="flex items-center justify-end gap-2">
                            <Button
                              variant="ghost"
                              size="sm"
                              onClick={() => {
                                setSelectedAppeal(appeal)
                                setIsDetailModalOpen(true)
                              }}
                            >
                              <Eye className="w-4 h-4" />
                            </Button>
                            {appeal.status === 'pending' && (
                              <>
                                <Button
                                  variant="success"
                                  size="sm"
                                  onClick={() => {
                                    setSelectedAppeal(appeal)
                                    approveAppeal.mutate(appeal.id)
                                  }}
                                  isLoading={approveAppeal.isPending}
                                >
                                  <Check className="w-4 h-4" />
                                </Button>
                                <Button
                                  variant="destructive"
                                  size="sm"
                                  onClick={() => {
                                    setSelectedAppeal(appeal)
                                    setIsRejectModalOpen(true)
                                  }}
                                >
                                  <X className="w-4 h-4" />
                                </Button>
                              </>
                            )}
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
                  {t('admin.showing_text')} {appeals.length} {t('admin.of')} {total} {t('admin.appeals')}
                </p>
                <div className="flex items-center gap-2">
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setPage(Math.max(1, page - 1))}
                    disabled={page === 1}
                  >
                    {t('admin.previous')}
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
                    {t('admin.next')}
                  </Button>
                </div>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Appeal Detail Modal */}
        <Modal
          isOpen={isDetailModalOpen}
          onClose={() => setIsDetailModalOpen(false)}
          title={t('admin.appeal_details')}
        >
          {selectedAppeal && (
            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="p-3 bg-base-200 rounded-lg">
                  <p className="text-neutral/60 text-sm">{t('admin.player')}</p>
                  <p className="font-bold text-base-content">
                    {selectedAppeal.player?.username || `${t('common.unknown')} #${selectedAppeal.user_id}`}
                  </p>
                </div>
                <div className="p-3 bg-base-200 rounded-lg">
                  <p className="text-neutral/60 text-sm">{t('admin.status')}</p>
                  {getStatusBadge(selectedAppeal.status)}
                </div>
                <div className="p-3 bg-base-200 rounded-lg">
                  <p className="text-neutral/60 text-sm">{t('admin.submitted')}</p>
                  <p className="text-base-content">{new Date(selectedAppeal.created_at).toLocaleString()}</p>
                </div>
                <div className="p-3 bg-base-200 rounded-lg">
                  <p className="text-neutral/60 text-sm">{t('admin.punishment')}</p>
                  <p className="text-base-content">{selectedAppeal.punishment?.type || 'N/A'}</p>
                </div>
              </div>
              <div className="p-3 bg-base-200 rounded-lg">
                <p className="text-neutral/60 text-sm mb-1">{t('admin.original_punishment_reason')}</p>
                <p className="text-base-content">{selectedAppeal.punishment?.reason || 'N/A'}</p>
              </div>
              <div className="p-3 bg-base-200 rounded-lg">
                <p className="text-neutral/60 text-sm mb-1">{t('admin.appeal_reason')}</p>
                <p className="text-base-content">{selectedAppeal.reason}</p>
              </div>
              {selectedAppeal.admin_answer && (
                <div className="p-3 bg-info/10 border border-info/20 rounded-lg">
                  <p className="text-info text-sm mb-1">{t('admin.admin_answer')}</p>
                  <p className="text-base-content">{selectedAppeal.admin_answer}</p>
                </div>
              )}
            </div>
          )}
        </Modal>

        {/* Reject Modal */}
        <Modal
          isOpen={isRejectModalOpen}
          onClose={() => setIsRejectModalOpen(false)}
          title={t('admin.reject_appeal')}
        >
          <form onSubmit={handleSubmit(onReject)} className="space-y-4">
            <div className="p-4 bg-error/10 border border-error/20 rounded-lg">
              <p className="text-error font-medium">
                {t('admin.rejection_notification')}
              </p>
            </div>

            <Input
              {...register('reason')}
              label={t('admin.rejection_reason')}
              placeholder={t('admin.rejection_reason_placeholder')}
              error={errors.reason?.message}
              disabled={isSubmitting}
            />

            <div className="flex gap-2 pt-4">
              <Button
                type="submit"
                variant="destructive"
                className="flex-1"
                isLoading={isSubmitting}
              >
                <X className="w-4 h-4 mr-2" />
                {t('admin.reject_appeal')}
              </Button>
              <Button
                variant="outline"
                className="flex-1"
                onClick={() => setIsRejectModalOpen(false)}
              >
                {t('common.cancel')}
              </Button>
            </div>
          </form>
        </Modal>
      </motion.div>
    </AdminLayout>
  )
}

export default AdminAppeals
