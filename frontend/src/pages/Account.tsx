import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'
import { useAuthStore } from '@/store/auth'
import { useToast } from '@/components/ui/Toast'
import { Button } from '@/components/ui/Button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { Input } from '@/components/ui/Input'
import { Badge } from '@/components/ui/Badge'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import { User, Mail, Shield, Calendar, Trophy, AlertTriangle, Edit2, X, Check } from 'lucide-react'
import { Link } from 'react-router-dom'
import api from '@/services/api'

const nicknameSchema = z.object({
  nickname: z
    .string()
    .min(3, 'Nickname must be at least 3 characters')
    .max(16, 'Nickname must be at most 16 characters')
    .regex(/^[a-zA-Z0-9_]+$/, 'Nickname can only contain letters, numbers, and underscores'),
})

type NicknameFormData = z.infer<typeof nicknameSchema>

const appealSchema = z.object({
  message: z.string().min(10, 'Appeal must be at least 10 characters').max(500, 'Appeal must be at most 500 characters'),
})

type AppealFormData = z.infer<typeof appealSchema>

interface Punishment {
  id: number
  type: string
  reason: string
  issued_at: string
  expires_at?: string
  status: string
}

export default function Account() {
  const { t } = useTranslation()
  const { user } = useAuthStore()
  const { success: showSuccess, error: showError } = useToast()
  const queryClient = useQueryClient()
  
  const [editingNickname, setEditingNickname] = useState(false)
  const [showAppealModal, setShowAppealModal] = useState(false)
  const [selectedPunishment, setSelectedPunishment] = useState<Punishment | null>(null)

  const { data: _profileUser, isLoading } = useQuery({
    queryKey: ['user-account'],
    queryFn: async () => {
      const response = await api.get('/users/me')
      return response.data
    },
    staleTime: 1000 * 60 * 5,
  })

  const { data: punishments } = useQuery<Punishment[]>({
    queryKey: ['user-punishments'],
    queryFn: async () => {
      const response = await api.get('/users/me/punishments')
      return response.data || []
    },
    staleTime: 1000 * 60 * 5,
  })

  const { data: appeals } = useQuery({
    queryKey: ['user-appeals'],
    queryFn: async () => {
      const response = await api.get('/users/me/appeals')
      return response.data || []
    },
    staleTime: 1000 * 60 * 5,
  })

  const updateNickname = useMutation({
    mutationFn: async (data: NicknameFormData) => {
      await api.put('/users/me/nickname', { nickname: data.nickname })
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['user-account'] })
      queryClient.invalidateQueries({ queryKey: ['user-settings'] })
      showSuccess(t('account.nickname_updated'))
      setEditingNickname(false)
    },
    onError: () => {
      showError(t('account.nickname_error'))
    },
  })

  const handleNicknameSubmit = async (data: NicknameFormData) => {
    await updateNickname.mutateAsync(data)
  }

  const submitAppeal = useMutation({
    mutationFn: async ({ punishmentId, message }: { punishmentId: number; message: string }) => {
      await api.post(`/punishments/${punishmentId}/appeal`, { message })
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['user-punishments'] })
      queryClient.invalidateQueries({ queryKey: ['user-appeals'] })
      showSuccess(t('account.appeal_submitted'))
      setShowAppealModal(false)
      setSelectedPunishment(null)
    },
    onError: () => {
      showError(t('account.appeal_error'))
    },
  })

  const {
    register: registerAppeal,
    handleSubmit: handleAppealSubmit,
    formState: { errors: appealErrors, isSubmitting: appealSubmitting },
  } = useForm<AppealFormData>({
    resolver: zodResolver(appealSchema),
    defaultValues: { message: '' },
  })

  const handleAppealFormSubmit = async (data: AppealFormData) => {
    if (!selectedPunishment) return
    await submitAppeal.mutateAsync({ punishmentId: selectedPunishment.id, message: data.message })
  }

  const openAppealModal = (punishment: Punishment) => {
    setSelectedPunishment(punishment)
    setShowAppealModal(true)
  }

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <LoadingSpinner size="lg" />
      </div>
    )
  }

  if (!user) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-white text-lg">{t('common.loading')}</div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-base-100 py-8">
      <div className="container mx-auto max-w-4xl px-4">
        <h1 className="mb-6 text-3xl font-bold text-base-content">{t('account.title')}</h1>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* Profile Card */}
          <Card>
            <CardHeader>
              <CardTitle className="text-xl flex items-center gap-2">
                <User className="w-5 h-5" />
                {t('account.profile')}
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="flex items-center gap-4">
                <div className="w-16 h-16 rounded-full bg-primary/10 flex items-center justify-center">
                  <User className="w-8 h-8 text-primary" />
                </div>
                <div>
                  <h2 className="text-xl font-bold text-base-content">{user.username}</h2>
                  <Badge variant={user.role === 'admin' ? 'error' : user.role === 'moderator' ? 'warning' : 'default'}>
                    {user.role || 'player'}
                  </Badge>
                  {user.is_sponsor && (
                    <Badge variant="success" className="ml-2">
                      {t('account.sponsor')}
                    </Badge>
                  )}
                </div>
              </div>

              <div className="space-y-2 text-sm">
                <div className="flex items-center gap-2 text-base-content/70">
                  <Mail className="w-4 h-4" />
                  <span>{user.email || t('account.not_set')}</span>
                </div>
                <div className="flex items-center gap-2 text-base-content/70">
                  <Calendar className="w-4 h-4" />
                  <span>
                    {t('account.joined')} {new Date(user.created_at || user.createdAt).toLocaleDateString()}
                  </span>
                </div>
                {user.nickname && (
                  <div className="flex items-center gap-2 text-base-content/70">
                    <Edit2 className="w-4 h-4" />
                    <span>
                      {t('account.nickname')}: {user.nickname}
                    </span>
                  </div>
                )}
              </div>

              {/* Nickname Change */}
              <div className="pt-4 border-t border-base-300">
                {editingNickname ? (
                  <NicknameForm on_submit={handleNicknameSubmit} onCancel={() => setEditingNickname(false)} />
                ) : (
                  <div className="flex items-center justify-between">
                    <span className="text-sm text-base-content/70">{t('account.nickname')}</span>
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => setEditingNickname(true)}
                    >
                      <Edit2 className="w-4 h-4" />
                      {t('account.change_nickname')}
                    </Button>
                  </div>
                )}
              </div>
            </CardContent>
          </Card>

          {/* Security Card */}
          <Card>
            <CardHeader>
              <CardTitle className="text-xl flex items-center gap-2">
                <Shield className="w-5 h-5" />
                {t('account.security')}
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className="flex items-center justify-between p-3 bg-base-200 rounded-lg">
                <span className="text-base-content/70">{t('account.password')}</span>
                <span className="text-success text-sm">{t('account.password_set')}</span>
              </div>
              <div className="flex items-center justify-between p-3 bg-base-200 rounded-lg">
                <span className="text-base-content/70">2FA</span>
                <span className={user.two_factor_enabled ? 'text-success text-sm' : 'text-base-content/50 text-sm'}>
                  {user.two_factor_enabled ? t('account.2fa_enabled') : t('account.2fa_disabled')}
                </span>
              </div>
              <div className="mt-4 space-y-2">
                <Link to="/settings" className="block">
                  <Button variant="outline" className="w-full">
                    {t('account.change_password')}
                  </Button>
                </Link>
                <Link to="/account/change-email" className="block">
                  <Button variant="outline" className="w-full">
                    {t('account.change_email')}
                  </Button>
                </Link>
                <Link to="/account/2fa/setup" className="block">
                  <Button variant="outline" className="w-full">
                    {t('account.setup_2fa')}
                  </Button>
                </Link>
              </div>
            </CardContent>
          </Card>

          {/* Punishments Card */}
          <Card>
            <CardHeader>
              <CardTitle className="text-xl flex items-center gap-2">
                <AlertTriangle className="w-5 h-5" />
                {t('account.punishments')}
              </CardTitle>
            </CardHeader>
            <CardContent>
              {punishments && punishments.length > 0 ? (
                <div className="space-y-2">
                  {punishments.map((punishment: Punishment) => (
                    <div key={punishment.id} className="p-3 bg-base-200 rounded-lg">
                      <div className="flex items-center justify-between mb-2">
                        <span className="font-medium text-base-content">
                          {punishment.type}
                        </span>
                        <Badge variant={punishment.status === 'expired' ? 'default' : 'error'}>
                          {punishment.status}
                        </Badge>
                      </div>
                      <p className="text-sm text-base-content/70 mb-2">{punishment.reason}</p>
                      <div className="flex items-center justify-between text-xs text-base-content/50">
                        <span>{new Date(punishment.issued_at).toLocaleDateString()}</span>
                        {punishment.expires_at && (
                          <span>{new Date(punishment.expires_at).toLocaleDateString()}</span>
                        )}
                      </div>
                      {(punishment.type.toLowerCase() === 'ban' || punishment.type.toLowerCase() === 'mute') &&
                        punishment.status !== 'expired' && (
                          <div className="mt-2 flex gap-2">
                            <Link to="/donate" className="flex-1">
                              <Button variant="success" size="sm" className="w-full">
                                {t('account.buy_out')}
                              </Button>
                            </Link>
                            <Button
                              variant="default"
                              size="sm"
                              className="flex-1"
                              onClick={() => openAppealModal(punishment)}
                            >
                              {t('account.appeal')}
                            </Button>
                          </div>
                        )}
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-base-content/50 text-center py-4">{t('account.no_punishments')}</p>
              )}
            </CardContent>
          </Card>

          {/* Statistics Card */}
          <Card>
            <CardHeader>
              <CardTitle className="text-xl flex items-center gap-2">
                <Trophy className="w-5 h-5" />
                {t('account.statistics')}
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-2 gap-3">
                <div className="p-3 bg-base-200 rounded-lg text-center">
                  <p className="text-2xl font-bold text-base-content">
                    {punishments?.filter((p: Punishment) => p.status !== 'expired').length || 0}
                  </p>
                  <p className="text-base-content/50 text-xs">{t('account.active_punishments')}</p>
                </div>
                <div className="p-3 bg-base-200 rounded-lg text-center">
                  <p className="text-2xl font-bold text-base-content">
                    {appeals?.filter((a: any) => a.status === 'pending').length || 0}
                  </p>
                  <p className="text-base-content/50 text-xs">{t('account.pending_appeals')}</p>
                </div>
                <div className="p-3 bg-base-200 rounded-lg text-center">
                  <p className="text-2xl font-bold text-base-content">0</p>
                  <p className="text-base-content/50 text-xs">{t('account.reports')}</p>
                </div>
                <div className="p-3 bg-base-200 rounded-lg text-center">
                  <p className="text-2xl font-bold text-base-content">0</p>
                  <p className="text-base-content/50 text-xs">{t('account.purchases')}</p>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Danger Zone */}
        <Card className="mt-6 border-error/30">
          <CardHeader>
            <CardTitle className="text-lg text-error flex items-center gap-2">
              <AlertTriangle className="w-5 h-5" />
              {t('account.danger_zone')}
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="mb-4 text-sm text-base-content/70">{t('account.delete_warning')}</p>
            <Button variant="destructive" className="w-full">
              {t('account.delete_account')}
            </Button>
          </CardContent>
        </Card>

        {/* Appeal Modal */}
        {showAppealModal && selectedPunishment && (
          <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
            <div className="bg-base-100 rounded-lg max-w-2xl w-full max-h-[90vh] overflow-y-auto">
              <div className="p-6">
                <div className="flex items-center justify-between mb-6">
                  <h2 className="text-2xl font-bold text-base-content">
                    {t('account.appeal_punishment')}
                  </h2>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setShowAppealModal(false)}
                  >
                    <X className="w-4 h-4" />
                  </Button>
                </div>

                <div className="mb-4 p-3 bg-base-200 rounded-lg">
                  <p className="text-sm text-base-content/70">
                    <strong>{t('account.punishment_type')}:</strong> {selectedPunishment.type}
                  </p>
                  <p className="text-sm text-base-content/70">
                    <strong>{t('account.reason')}:</strong> {selectedPunishment.reason}
                  </p>
                </div>

                <form onSubmit={handleAppealSubmit(handleAppealFormSubmit)} className="space-y-4">
                  <div>
                    <label className="block text-sm font-medium text-base-content mb-2">
                      {t('account.your_message')}
                      <span className="text-base-content/50 ml-1">({t('account.max_chars', { count: 500 })})</span>
                    </label>
                    <textarea
                      {...registerAppeal('message')}
                      className="textarea textarea-bordered w-full min-h-[150px] bg-base-200 text-base-content border-base-300 focus:border-primary focus:outline-none"
                      placeholder={t('account.appeal_placeholder')}
                      maxLength={500}
                      disabled={appealSubmitting || submitAppeal.isPending}
                    />
                    {appealErrors.message && (
                      <p className="mt-1 text-sm text-error">{String(appealErrors.message)}</p>
                    )}
                  </div>

                  <div className="flex justify-end gap-3">
                    <Button
                      type="button"
                      variant="outline"
                      onClick={() => setShowAppealModal(false)}
                    >
                      {t('common.cancel')}
                    </Button>
                    <Button
                      type="submit"
                      isLoading={appealSubmitting || submitAppeal.isPending}
                      disabled={appealSubmitting || submitAppeal.isPending}
                    >
                      {t('account.submit_appeal')}
                    </Button>
                  </div>
                </form>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}

function NicknameForm({ on_submit, onCancel }: { on_submit: (data: NicknameFormData) => Promise<void>; onCancel: () => void }) {
  const { t } = useTranslation()
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
    reset,
  } = useForm<NicknameFormData>({
    resolver: zodResolver(nicknameSchema),
  })

  const onSubmit = async (data: NicknameFormData) => {
    await on_submit(data)
    reset()
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-2">
      <Input
        {...register('nickname')}
        label={t('account.new_nickname')}
        placeholder={t('account.nickname_placeholder')}
        error={errors.nickname?.message ? String(errors.nickname.message) : undefined}
        disabled={isSubmitting}
      />
      <div className="flex gap-2">
        <Button type="submit" size="sm" disabled={isSubmitting}>
          <Check className="w-4 h-4" />
          {t('common.save')}
        </Button>
        <Button type="button" variant="outline" size="sm" onClick={onCancel}>
          <X className="w-4 h-4" />
          {t('common.cancel')}
        </Button>
      </div>
    </form>
  )
}
