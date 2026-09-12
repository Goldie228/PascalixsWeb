import { useState } from 'react'
import { motion } from 'framer-motion'
import { useTranslation } from 'react-i18next'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { Search, Shield, AlertTriangle, Check, Eye } from 'lucide-react'
import { usePunishments, useCreatePunishment, useResolvePunishment } from '@/hooks/usePunishments'
import { Card, CardContent } from '@/components/ui/Card'
import { Button } from '@/components/ui/Button'
import { Badge } from '@/components/ui/Badge'
import { Modal } from '@/components/ui/Modal'
import { Input } from '@/components/ui/Input'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import AdminLayout from '@/components/admin/AdminLayout'
import type { Punishment as PunishmentType } from '@/types'

const createPunishmentSchema = z.object({
  userId: z.string().min(1, 'User ID is required'),
  type: z.enum(['warning', 'mute', 'kick', 'ban', 'tempban']),
  reason: z.string().min(1, 'Reason is required'),
  duration: z.string().optional(),
})

type CreatePunishmentFormData = z.infer<typeof createPunishmentSchema>

function AdminPunishments() {
  const { t } = useTranslation()
  const [search, setSearch] = useState('')
  const [selectedPunishment, setSelectedPunishment] = useState<PunishmentType | null>(null)
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false)
  const [isDetailModalOpen, setIsDetailModalOpen] = useState(false)
  const [page, setPage] = useState(1)

  const { data, isLoading, refetch } = usePunishments({ page, per_page: 20 })
  const createPunishment = useCreatePunishment()
  const resolvePunishment = useResolvePunishment()

  // API response: { punishments: Punishment[], total: number, page: number }
  const punishments = (data?.data as { punishments: PunishmentType[]; total: number } | undefined)?.punishments || []
  const total = (data?.data as { total: number } | undefined)?.total || 0
  const totalPages = Math.ceil(total / 20)

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
    reset,
  } = useForm<CreatePunishmentFormData>({
    resolver: zodResolver(createPunishmentSchema),
  })

  const onCreatePunishment = async (formData: CreatePunishmentFormData) => {
    await createPunishment.mutateAsync({
      user_id: parseInt(formData.userId),
      type: formData.type,
      reason: formData.reason,
      duration: formData.duration || undefined,
    })
    setIsCreateModalOpen(false)
    reset()
    refetch()
  }

  const onResolve = async (punishmentId: number) => {
    await resolvePunishment.mutateAsync(punishmentId)
    refetch()
  }

  const getTypeBadge = (type: string) => {
    switch (type) {
      case 'warning':
        return <Badge variant="default">{t('admin.warning')}</Badge>
      case 'mute':
        return <Badge variant="warning">{t('admin.mute')}</Badge>
      case 'kick':
        return <Badge variant="warning">{t('admin.kick')}</Badge>
      case 'ban':
        return <Badge variant="error">{t('admin.ban')}</Badge>
      case 'tempban':
        return <Badge variant="error">{t('admin.temp_ban')}</Badge>
      default:
        return <Badge variant="default">{type}</Badge>
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
            <h1 className="text-2xl font-bold text-base-content">{t('admin.punishments_title')}</h1>
            <p className="text-sm text-neutral/60">{t('admin.manage_punishments_desc')}</p>
          </div>
          <Button onClick={() => setIsCreateModalOpen(true)}>
            <Shield className="w-4 h-4 mr-2" />
            {t('admin.create_punishment')}
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
                  placeholder={t('admin.search_punishments')}
                  className="pl-10"
                  onKeyDown={(e) => e.key === 'Enter' && refetch()}
                />
              </div>
            </div>

            {/* Punishments table */}
            {isLoading ? (
              <div className="p-8 text-center">
                <LoadingSpinner size="md" />
                <p className="text-neutral/60 mt-2">{t('admin.loading_punishments')}</p>
              </div>
            ) : punishments.length === 0 ? (
              <div className="p-8 text-center text-neutral/60">{t('admin.no_punishments_found')}</div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="border-b border-base-300">
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.user')}</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.type')}</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.reason')}</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.date')}</th>
                      <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.status')}</th>
                      <th className="text-right p-4 text-sm font-medium text-neutral/60">{t('admin.actions')}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {punishments.map((punishment) => (
                      <tr
                        key={punishment.id}
                        className="border-b border-base-300 transition-colors hover:bg-base-200/50"
                      >
                        <td className="p-4">
                          <p className="font-medium text-base-content">
                            {punishment.user?.username || punishment.user?.discord_username || `${t('common.unknown')} #${punishment.user_id}`}
                          </p>
                          <p className="text-neutral/60 text-sm">ID: {punishment.user_id}</p>
                        </td>
                        <td className="p-4">{getTypeBadge(punishment.type)}</td>
                        <td className="p-4 max-w-xs">
                          <p className="text-base-content truncate">{punishment.reason}</p>
                        </td>
                        <td className="p-4 text-neutral/60">
                          {new Date(punishment.issued_at).toLocaleDateString()}
                        </td>
                        <td className="p-4">
                          <Badge variant={punishment.resolved ? 'success' : 'warning'}>
                            {punishment.resolved ? t('common.resolved') : t('common.active')}
                          </Badge>
                        </td>
                        <td className="p-4">
                          <div className="flex items-center justify-end gap-2">
                            <Button
                              variant="ghost"
                              size="sm"
                              onClick={() => {
                                setSelectedPunishment(punishment)
                                setIsDetailModalOpen(true)
                              }}
                            >
                              <Eye className="w-4 h-4" />
                            </Button>
                            {!punishment.resolved && (
                              <Button
                                variant="success"
                                size="sm"
                                onClick={() => onResolve(punishment.id)}
                                isLoading={resolvePunishment.isPending}
                              >
                                <Check className="w-4 h-4" />
                              </Button>
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
                  {t('admin.showing_text')} {punishments.length} {t('admin.of')} {total} {t('admin.punishments')}
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

        {/* Create Punishment Modal */}
        <Modal
          isOpen={isCreateModalOpen}
          onClose={() => setIsCreateModalOpen(false)}
          title={t('admin.create_punishment')}
        >
          <form onSubmit={handleSubmit(onCreatePunishment)} className="space-y-4">
            <Input
              {...register('userId')}
              label={t('admin.user_id')}
              placeholder={t('admin.user_id_placeholder')}
              error={errors.userId?.message}
              disabled={isSubmitting}
            />

            <div>
              <label className="block text-sm font-medium text-base-content mb-1">{t('admin.type')}</label>
              <select
                {...register('type')}
                className="w-full h-10 rounded-lg border border-neutral/20 bg-base-200 px-3 py-2 text-sm text-base-content focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
              >
                <option value="warning">{t('admin.warning')}</option>
                <option value="mute">{t('admin.mute')}</option>
                <option value="kick">{t('admin.kick')}</option>
                <option value="ban">{t('admin.ban')}</option>
                <option value="tempban">{t('admin.temp_ban')}</option>
              </select>
              {errors.type && <p className="text-xs text-error">{errors.type.message}</p>}
            </div>

            <Input
              {...register('reason')}
              label={t('admin.reason')}
              placeholder={t('admin.reason_placeholder')}
              error={errors.reason?.message}
              disabled={isSubmitting}
            />

            <Input
              {...register('duration')}
              label={t('admin.duration')}
              placeholder={t('admin.duration_placeholder')}
              disabled={isSubmitting}
            />

            <div className="flex gap-2 pt-4">
              <Button
                type="submit"
                className="flex-1"
                isLoading={isSubmitting}
              >
                <AlertTriangle className="w-4 h-4 mr-2" />
                {t('admin.create_punishment')}
              </Button>
              <Button
                variant="outline"
                className="flex-1"
                onClick={() => setIsCreateModalOpen(false)}
              >
                {t('common.cancel')}
              </Button>
            </div>
          </form>
        </Modal>

        {/* Punishment Detail Modal */}
        <Modal
          isOpen={isDetailModalOpen}
          onClose={() => setIsDetailModalOpen(false)}
          title={t('admin.punishment_details')}
        >
          {selectedPunishment && (
            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="p-3 bg-base-200 rounded-lg">
                  <p className="text-neutral/60 text-sm">{t('admin.user')}</p>
                  <p className="font-bold text-base-content">
                    {selectedPunishment.user?.username || selectedPunishment.user?.discord_username || t('common.unknown')}
                  </p>
                </div>
                <div className="p-3 bg-base-200 rounded-lg">
                  <p className="text-neutral/60 text-sm">{t('admin.type')}</p>
                  {getTypeBadge(selectedPunishment.type)}
                </div>
                <div className="p-3 bg-base-200 rounded-lg">
                  <p className="text-neutral/60 text-sm">{t('admin.created')}</p>
                  <p className="text-base-content">{new Date(selectedPunishment.issued_at).toLocaleString()}</p>
                </div>
                <div className="p-3 bg-base-200 rounded-lg">
                  <p className="text-neutral/60 text-sm">{t('admin.status')}</p>
                  <Badge variant={selectedPunishment.resolved ? 'success' : 'warning'}>
                    {selectedPunishment.resolved ? t('common.resolved') : t('common.active')}
                  </Badge>
                </div>
              </div>
              <div className="p-3 bg-base-200 rounded-lg">
                <p className="text-neutral/60 text-sm mb-1">{t('admin.reason')}</p>
                <p className="text-base-content">{selectedPunishment.reason}</p>
              </div>
            </div>
          )}
        </Modal>
      </motion.div>
    </AdminLayout>
  )
}

export default AdminPunishments
