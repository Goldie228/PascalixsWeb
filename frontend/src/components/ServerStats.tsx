import { useTranslation } from 'react-i18next'
import { useServerStats } from '@/hooks/useQueries'

export default function ServerStats() {
  const { t } = useTranslation()
  const { data, isLoading } = useServerStats()

  if (isLoading) {
    return (
      <div className="stats stats-vertical bg-base-200 w-full">
        <div className="stat">
          <div className="stat-title">{t('server.loading')}</div>
        </div>
      </div>
    )
  }

  const stats = data?.data

  return (
    <div className="stats stats-vertical bg-base-200 w-full">
      <div className="stat">
        <div className="stat-title">{t('server.online')}</div>
        <div className="stat-value text-primary">
          {stats?.onlinePlayers ?? 0}
        </div>
        <div className="stat-desc">
          {t('server.out_of', { max: stats?.maxPlayers ?? 0 })}
        </div>
      </div>
      <div className="stat">
        <div className="stat-title">{t('server.uptime')}</div>
        <div className="stat-value text-secondary">{stats?.uptime ?? '-'}</div>
      </div>
      <div className="stat">
        <div className="stat-title">{t('server.version')}</div>
        <div className="stat-value text-accent">{stats?.version ?? '-'}</div>
      </div>
    </div>
  )
}
