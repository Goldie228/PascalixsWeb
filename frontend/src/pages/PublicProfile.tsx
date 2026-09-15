import { useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { useQuery, useMutation } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { useTranslation } from 'react-i18next'
import { useToast } from '@/components/ui/Toast'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { Avatar } from '@/components/ui/Avatar'
import { Badge } from '@/components/ui/Badge'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import { Button } from '@/components/ui/Button'
import { Input } from '@/components/ui/Input'
import { userApi } from '@/services/userApi'
import api from '@/services/api'
import type { Punishment, IntegrationBinding } from '@/types'
import {
  User,
  Mail,
  Shield,
  Calendar,
  Clock,
  Gamepad2,
  Report,
  Banknote,
  ExternalLink,
  AlertTriangle,
  CheckCircle2,
  Loader2,
  Youtube,
  Twitch,
  Tiktok,
  X,
  Flag,
} from 'lucide-react'

function PublicProfile() {
  const { nickname } = useParams<{ nickname: string }>()
  const navigate = useNavigate()
  const { t } = useTranslation()
  const { success: toastSuccess, error: toastError } = useToast()

  const [showReportModal, setShowReportModal] = useState(false)
  const [reportReason, setReportReason] = useState('')
  const [reportDescription, setReportDescription] = useState('')
  const [isSubmittingReport, setIsSubmittingReport] = useState(false)

  const { data: profileUser, isLoading } = useQuery({
    queryKey: ['public-profile', nickname],
    queryFn: async () => {
      const response = await userApi.getPublicProfile(nickname!)
      return response.data
    },
    enabled: !!nickname,
    staleTime: 1000 * 60 * 5,
  })

  const { data: punishments } = useQuery({
    queryKey: ['user-punishments', nickname],
    queryFn: async () => {
      const response = await userApi.getPunishments(nickname!)
      return response.data
    },
    enabled: !!nickname,
    staleTime: 1000 * 60 * 5,
  })

  const { data: integrations } = useQuery({
    queryKey: ['user-integrations', nickname],
    queryFn: async () => {
      const response = await api.get<IntegrationBinding>(`/players/${nickname}/integrations`)
      return response.data
    },
    enabled: !!nickname,
    staleTime: 1000 * 60 * 5,
  })

  const { data: bankAccount } = useQuery({
    queryKey: ['user-bank', nickname],
    queryFn: async () => {
      const response = await api.get(`/players/${nickname}/bank_account`)
      return response.data
    },
    enabled: !!nickname,
    staleTime: 1000 * 60 * 5,
  })

  // Report user mutation
  const reportUserMutation = useMutation({
    mutationFn: async (data: { reason: string; description: string }) => {
      const formData = new FormData()
      formData.append('reason', data.reason)
      formData.append('description', data.description)
      formData.append('reported_user_id', String(profileUser?.id || ''))
      return api.post('/user/add_report', formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
      })
    },
    onSuccess: () => {
      toastSuccess(t('public_profile.report_success'))
      setShowReportModal(false)
      setReportReason('')
      setReportDescription('')
    },
    onError: () => {
      toastError(t('public_profile.report_error'))
    },
  })

  const handleReportSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!reportReason.trim() || !reportDescription.trim()) return

    setIsSubmittingReport(true)
    reportUserMutation.mutate({
      reason: reportReason,
      description: reportDescription,
    })
    setIsSubmittingReport(false)
  }

  if (isLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <LoadingSpinner size="lg" />
      </div>
    )
  }

  const user = profileUser

  // Determine role badge
  const getRoleVariant = (role?: string) => {
    switch (role) {
      case 'admin':
        return 'error'
      case 'moderator':
        return 'warning'
      case 'sponsor':
        return 'info'
      default:
        return 'default'
    }
  }

  // Get avatar URL
  const avatarUrl = user?.is_added && user?.id
    ? `/discord_avatar/${user.id}`
    : undefined

  return (
    <div className="min-h-screen bg-base-100 py-8">
      <div className="container mx-auto max-w-4xl px-4">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
        >
          {/* Profile Header */}
          <Card>
            <CardHeader className="flex flex-row items-start gap-4">
              <Avatar
                src={avatarUrl}
                fallback={user?.username}
                size="xl"
              />
              <div className="flex-1">
                <div className="flex items-center gap-3 flex-wrap">
                  <CardTitle className="text-2xl">{user?.username}</CardTitle>
                  {/* Ban/Mute badges */}
                  {user?.is_banned && (
                    <Badge variant="error">
                      {t('public_profile.ban_badge')}
                    </Badge>
                  )}
                  {user?.ban_reason && (
                    <span className="text-xs text-error/80 italic">
                      {user.ban_reason}
                    </span>
                  )}
                </div>
                <div className="mt-2 flex flex-wrap gap-2">
                  <Badge variant={getRoleVariant(user?.role)}>
                    {user?.role?.toUpperCase() || 'PLAYER'}
                  </Badge>
                  {user?.is_sponsor && (
                    <Badge variant="warning">{t('nav.sponsor')}</Badge>
                  )}
                  {user?.is_youtube_bound && (
                    <Badge variant="default" className="bg-red-500/10 text-red-400">
                      <Youtube className="mr-1 h-3 w-3" />
                      YOUTUBER
                    </Badge>
                  )}
                  {user?.is_twitch_bound && (
                    <Badge variant="default" className="bg-purple-500/10 text-purple-400">
                      <Twitch className="mr-1 h-3 w-3" />
                      TWITCHER
                    </Badge>
                  )}
                  {user?.is_tiktok_bound && (
                    <Badge variant="default" className="bg-pink-500/10 text-pink-400">
                      <Tiktok className="mr-1 h-3 w-3" />
                      TIKTOKER
                    </Badge>
                  )}
                </div>
              </div>
              {/* Report Button */}
              <Button
                variant="outline"
                size="sm"
                onClick={() => setShowReportModal(true)}
              >
                <Flag className="mr-2 h-4 w-4" />
                {t('public_profile.report_player')}
              </Button>
            </CardHeader>
            <CardContent className="space-y-6">
              {/* About Me */}
              <div>
                <h3 className="mb-2 flex items-center gap-2 text-lg font-semibold">
                  <User className="h-5 w-5 text-primary" />
                  {t('public_profile.about_me')}
                </h3>
                <p className="rounded-lg bg-base-200 p-3 text-base-content/80">
                  {user?.about_me || t('public_profile.no_about')}
                </p>
              </div>

              {/* Social Integrations */}
              <div>
                <h3 className="mb-2 flex items-center gap-2 text-lg font-semibold">
                  <Gamepad2 className="h-5 w-5 text-primary" />
                  {t('public_profile.integrations')}
                </h3>
                {integrations?.youtube_url || integrations?.twitch_url || integrations?.tiktok_url ? (
                  <div className="space-y-2">
                    {integrations?.youtube_url && (
                      <a
                        href={integrations.youtube_url}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="flex items-center gap-2 rounded-lg bg-base-200 p-3 text-primary hover:bg-base-300 transition-colors"
                      >
                        <Youtube className="h-5 w-5" />
                        <span className="flex-1 truncate">{integrations.youtube_channel_name || integrations.youtube_url}</span>
                        <ExternalLink className="h-4 w-4 shrink-0 opacity-50" />
                      </a>
                    )}
                    {integrations?.twitch_url && (
                      <a
                        href={integrations.twitch_url}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="flex items-center gap-2 rounded-lg bg-base-200 p-3 text-purple-400 hover:bg-base-300 transition-colors"
                      >
                        <Twitch className="h-5 w-5" />
                        <span className="flex-1 truncate">{integrations.twitch_channel_name || integrations.twitch_url}</span>
                        <ExternalLink className="h-4 w-4 shrink-0 opacity-50" />
                      </a>
                    )}
                    {integrations?.tiktok_url && (
                      <a
                        href={integrations.tiktok_url}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="flex items-center gap-2 rounded-lg bg-base-200 p-3 text-pink-400 hover:bg-base-300 transition-colors"
                      >
                        <Tiktok className="h-5 w-5" />
                        <span className="flex-1 truncate">{integrations.tiktok_channel_name || integrations.tiktok_url}</span>
                        <ExternalLink className="h-4 w-4 shrink-0 opacity-50" />
                      </a>
                    )}
                  </div>
                ) : (
                  <p className="rounded-lg bg-base-200 p-3 text-base-content/50">
                    {t('public_profile.no_integrations')}
                  </p>
                )}
              </div>

              {/* Bank Account */}
              <div>
                <h3 className="mb-2 flex items-center gap-2 text-lg font-semibold">
                  <Banknote className="h-5 w-5 text-primary" />
                  {t('public_profile.bank_account')}
                </h3>
                {bankAccount ? (
                  <div className="rounded-lg bg-base-200 p-3 space-y-1">
                    <div className="flex justify-between text-sm">
                      <span className="text-base-content/60">{t('public_profile.bank_name')}:</span>
                      <span className="font-medium">{bankAccount.bank_name}</span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span className="text-base-content/60">{t('public_profile.card_number')}:</span>
                      <span className="font-mono font-medium">
                        {bankAccount.card_number?.replace(/.(?=.{4})/g, '*')}
                      </span>
                    </div>
                  </div>
                ) : (
                  <p className="rounded-lg bg-base-200 p-3 text-base-content/50">
                    {t('public_profile.no_bank_account')}
                  </p>
                )}
              </div>

              {/* Stats */}
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div className="rounded-lg bg-base-200 p-3">
                  <div className="flex items-center gap-2 text-sm text-base-content/60">
                    <Calendar className="h-4 w-4" />
                    <span>{t('public_profile.member_since')}</span>
                  </div>
                  <p className="mt-1 font-medium">
                    {user?.created_at
                      ? new Date(user.created_at).toLocaleDateString()
                      : '-'}
                  </p>
                </div>
                <div className="rounded-lg bg-base-200 p-3">
                  <div className="flex items-center gap-2 text-sm text-base-content/60">
                    <Clock className="h-4 w-4" />
                    <span>{t('public_profile.last_seen')}</span>
                  </div>
                  <p className="mt-1 font-medium">
                    {user?.last_login_at
                      ? new Date(user.last_login_at).toLocaleDateString()
                      : t('common.never')}
                  </p>
                </div>
              </div>

              {/* Mail */}
              {user?.email && (
                <div className="flex items-center gap-2 rounded-lg bg-base-200 p-3">
                  <Mail className="h-5 w-5 text-primary" />
                  <span className="text-sm">{user.email}</span>
                </div>
              )}
            </CardContent>
          </Card>

          {/* Punishment History */}
          <Card className="mt-6">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Shield className="h-5 w-5 text-warning" />
                {t('public_profile.punishment_history')}
              </CardTitle>
            </CardHeader>
            <CardContent>
              {punishments?.length === 0 || !punishments?.length ? (
                <p className="text-base-content/50">
                  {t('public_profile.no_punishments')}
                </p>
              ) : (
                <div className="space-y-2">
                  {punishments.map((p: Punishment) => (
                    <div
                      key={p.id}
                      className="flex items-center justify-between rounded-lg bg-base-200 p-3"
                    >
                      <div className="flex-1">
                        <div className="flex items-center gap-2">
                          <span className="font-medium text-base-content capitalize">
                            {p.type.replace(/_/g, ' ')}
                          </span>
                          <Badge variant={p.active ? 'error' : 'success'}>
                            {p.active ? t('common.active') : t('common.resolved')}
                          </Badge>
                        </div>
                        {p.reason && (
                          <p className="mt-1 text-sm text-base-content/60">
                            {p.reason}
                          </p>
                        )}
                      </div>
                      <div className="ml-4 text-right text-xs text-base-content/40">
                        {p.issued_at && (
                          <div>{new Date(p.issued_at).toLocaleDateString()}</div>
                        )}
                        {p.expires_at && (
                          <div>{new Date(p.expires_at).toLocaleDateString()}</div>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>
        </motion.div>
      </div>

      {/* Report Player Modal */}
      {showReportModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            className="w-full max-w-md"
          >
            <Card>
              <CardHeader>
                <div className="flex items-center justify-between">
                  <CardTitle className="flex items-center gap-2">
                    <Report className="h-5 w-5 text-error" />
                    {t('public_profile.report_title')}
                  </CardTitle>
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => setShowReportModal(false)}
                  >
                    <X className="h-4 w-4" />
                  </Button>
                </div>
              </CardHeader>
              <CardContent>
                <form onSubmit={handleReportSubmit} className="space-y-4">
                  <div>
                    <label className="mb-1 block text-sm font-medium">
                      {t('public_profile.report_reason_label')}
                    </label>
                    <select
                      value={reportReason}
                      onChange={(e) => setReportReason(e.target.value)}
                      className="w-full rounded-lg border border-neutral/20 bg-base-200 px-3 py-2 text-sm text-base-content focus:outline-none focus:ring-2 focus:ring-primary"
                      required
                    >
                      <option value="">Select a reason...</option>
                      <option value="cheating">Cheating/Hacking</option>
                      <option value="toxic_behavior">Toxic Behavior</option>
                      <option value="scamming">Scamming</option>
                      <option value="inappropriate_name">Inappropriate Name</option>
                      <option value="other">Other</option>
                    </select>
                  </div>

                  <div>
                    <label className="mb-1 block text-sm font-medium">
                      {t('public_profile.report_description_label')}
                    </label>
                    <textarea
                      value={reportDescription}
                      onChange={(e) => setReportDescription(e.target.value)}
                      placeholder={t('public_profile.report_description_placeholder')}
                      rows={4}
                      className="w-full rounded-lg border border-neutral/20 bg-base-200 px-3 py-2 text-sm text-base-content placeholder:text-neutral/50 focus:outline-none focus:ring-2 focus:ring-primary resize-none"
                      required
                    />
                  </div>

                  <div className="flex gap-3">
                    <Button
                      type="submit"
                      variant="destructive"
                      className="flex-1"
                      disabled={isSubmittingReport || !reportReason || !reportDescription}
                      isLoading={isSubmittingReport}
                    >
                      {isSubmittingReport ? (
                        <>
                          <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                          {t('public_profile.report_loading')}
                        </>
                      ) : (
                        <>
                          <Flag className="mr-2 h-4 w-4" />
                          {t('public_profile.report_submit')}
                        </>
                      )}
                    </Button>
                    <Button
                      type="button"
                      variant="ghost"
                      onClick={() => setShowReportModal(false)}
                      disabled={isSubmittingReport}
                    >
                      {t('public_profile.report_cancel')}
                    </Button>
                  </div>
                </form>
              </CardContent>
            </Card>
          </motion.div>
        </div>
      )}
    </div>
  )
}

export default PublicProfile
