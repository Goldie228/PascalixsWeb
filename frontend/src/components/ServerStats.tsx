import { useServerStats } from '@/hooks/useQueries'

export default function ServerStats() {
  const { data, isLoading } = useServerStats()

  if (isLoading) {
    return (
      <div className="stats stats-vertical bg-base-200 w-full">
        <div className="stat">
          <div className="stat-title">Загрузка...</div>
        </div>
      </div>
    )
  }

  const stats = data?.data

  return (
    <div className="stats stats-vertical bg-base-200 w-full">
      <div className="stat">
        <div className="stat-title">Онлайн</div>
        <div className="stat-value text-primary">
          {stats?.onlinePlayers ?? 0}
        </div>
        <div className="stat-desc">
          из {stats?.maxPlayers ?? 0} возможных
        </div>
      </div>
      <div className="stat">
        <div className="stat-title">Аптайм</div>
        <div className="stat-value text-secondary">{stats?.uptime ?? '-'}</div>
      </div>
      <div className="stat">
        <div className="stat-title">Версия</div>
        <div className="stat-value text-accent">{stats?.version ?? '-'}</div>
      </div>
    </div>
  )
}
