import { useParams } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { useTranslation } from 'react-i18next'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { Avatar } from '@/components/ui/Avatar'
import { Badge } from '@/components/ui/Badge'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import { userApi } from '@/services/userApi'
import api from '@/services/api'
import type { Punishment } from '@/types'

function PublicProfile() {
  const { nickname } = useParams<{ nickname: string }>()
  const { t } = useTranslation()

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
      const response = await api.get(`/players/${nickname}/integrations`)
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

  if (isLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <LoadingSpinner size="lg" />
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-base-100 py-8">
      <div className="container mx-auto max-w-4xl px-4">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
        >
          {/* Profile Header */}
          <Card>
            <CardHeader className="flex flex-row items-center gap-4">
              <Avatar
                src={undefined}
                fallback={profileUser?.username}
                size="xl"
              />
              <div className="flex-1">
                <CardTitle className="text-2xl">{profileUser?.username}</CardTitle>
                <div className="mt-1 flex gap-2">
                  <Badge
                    variant={
                      profileUser?.role === 'admin'
                        ? 'error'
                        : profileUser?.role === 'moderator'
                          ? 'warning'
                          : 'info'
                    }
                  >
                    {profileUser?.role}
                  </Badge>
                  {profileUser?.is_sponsor && (
                    <Badge variant="warning">{t('nav.sponsor')}</Badge>
                  )}
                </div>
              </div>
            </CardHeader>
            <CardContent className="space-y-6">
              {/* About Me */}
              <div>
                <h3 className="mb-2 text-lg font-semibold">{t('profile.about_me')}</h3>
                <p className="text-base-content/80">
                  {profileUser?.about_me || t('profile.no_about')}
                </p>
              </div>

              {/* Integrations */}
              <div>
                <h3 className="mb-2 text-lg font-semibold">{t('profile.integrations')}</h3>
                {integrations?.youtube || integrations?.twitch || integrations?.tiktok ? (
                  <div className="space-y-2">
                    {integrations?.youtube && (
                      <a
                        href={integrations.youtube}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="flex items-center gap-2 text-primary hover:underline"
                      >
                        <span>{t('profile.youtube')}:</span>
                        <span className="truncate">{integrations.youtube}</span>
                      </a>
                    )}
                    {integrations?.twitch && (
                      <a
                        href={integrations.twitch}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="flex items-center gap-2 text-primary hover:underline"
                      >
                        <span>{t('profile.twitch')}:</span>
                        <span className="truncate">{integrations.twitch}</span>
                      </a>
                    )}
                    {integrations?.tiktok && (
                      <a
                        href={integrations.tiktok}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="flex items-center gap-2 text-primary hover:underline"
                      >
                        <span>{t('profile.tiktok')}:</span>
                        <span className="truncate">{integrations.tiktok}</span>
                      </a>
                    )}
                  </div>
                ) : (
                  <p className="text-neutral/60">{t('profile.no_integrations')}</p>
                )}
              </div>

              {/* Bank Account */}
              <div>
                <h3 className="mb-2 text-lg font-semibold">{t('profile.bank_account')}</h3>
                {bankAccount ? (
                  <div className="space-y-1">
                    <p className="text-base-content">
                      <span className="text-neutral/60">{t('profile.bank_name')}:</span> {bankAccount.bank_name}
                    </p>
                    <p className="text-base-content">
                      <span className="text-neutral/60">{t('profile.card_number')}:</span> {bankAccount.card_number}
                    </p>
                  </div>
                ) : (
                  <p className="text-neutral/60">{t('profile.no_bank_account')}</p>
                )}
              </div>

              {/* Stats */}
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div>
                  <h3 className="text-sm font-medium text-neutral/60">{t('profile.member_since')}</h3>
                  <p className="text-base-content">
                    {profileUser?.created_at
                      ? new Date(profileUser.created_at).toLocaleDateString()
                      : '-'}
                  </p>
                </div>
                <div>
                  <h3 className="text-sm font-medium text-neutral/60">{t('profile.last_seen')}</h3>
                  <p className="text-base-content">
                    {profileUser?.last_login_at
                      ? new Date(profileUser.last_login_at).toLocaleDateString()
                      : t('common.never')}
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Punishment History */}
          <Card className="mt-6">
            <CardHeader>
              <CardTitle>{t('public_profile.punishment_history')}</CardTitle>
            </CardHeader>
            <CardContent>
              {punishments?.length === 0 || !punishments?.length ? (
                <p className="text-neutral/60">{t('public_profile.no_punishments')}</p>
              ) : (
                <div className="space-y-2">
                  {punishments.map((p: Punishment) => (
                    <div
                      key={p.id}
                      className="flex items-center justify-between rounded-lg bg-base-200 p-2"
                    >
                      <div>
                        <span className="font-medium text-base-content capitalize">
                          {p.type.replace(/_/g, ' ')}
                        </span>
                        <span className="ml-2 text-sm text-neutral/60">{p.reason}</span>
                      </div>
                      <Badge variant={p.active ? 'error' : 'success'}>
                        {p.active ? t('common.active') : t('common.resolved')}
                      </Badge>
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>
        </motion.div>
      </div>
    </div>
  )
}

export default PublicProfile
