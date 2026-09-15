import { useState, useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import { useQuery } from '@tanstack/react-query'
import { motion, AnimatePresence } from 'framer-motion'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { Badge } from '@/components/ui/Badge'
import { Avatar } from '@/components/ui/Avatar'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import { playersApi, type Player, type PlayersFilters } from '@/services/playersApi'
import {
  Users,
  Search,
  Shield,
  Crown,
  Star,
  Ban,
  VolumeX,
  Wifi,
  WifiOff,
  ChevronLeft,
  ChevronRight,
  User,
  ExternalLink,
  Filter,
  ChevronUp,
  ChevronDown,
} from 'lucide-react'

const roleIcons: Record<string, typeof Shield> = {
  owner: Crown,
  admin: Shield,
  moderator: Star,
  sponsor: Star,
  default: User,
}

const punishmentConfig = {
  0: { label: 'none', color: 'success' as const, icon: null },
  1: { label: 'none', color: 'success' as const, icon: null },
  2: { label: 'muted', color: 'warning' as const, icon: VolumeX },
  3: { label: 'banned', color: 'error' as const, icon: Ban },
}

const roleFilters = [
  { value: '', labelKey: 'players.all_roles' },
  { value: 'owner', labelKey: 'players.owner' },
  { value: 'admin', labelKey: 'players.admin' },
  { value: 'moderator', labelKey: 'players.moderator' },
  { value: 'sponsor', labelKey: 'players.sponsor' },
]

const statusFilters = [
  { value: '', labelKey: 'players.all_statuses' },
  { value: 'online', labelKey: 'players.online' },
  { value: 'offline', labelKey: 'players.offline' },
]

function Players() {
  const { t } = useTranslation()
  const [search, setSearch] = useState('')
  const [roleFilter, setRoleFilter] = useState('')
  const [statusFilter, setStatusFilter] = useState('')
  const [sortBy, setSortBy] = useState<'minecraft_nickname' | 'discord_username' | 'role_weight'>('minecraft_nickname')
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc')
  const [perPage, setPerPage] = useState(24)
  const [page, setPage] = useState(1)
  const [showFilters, setShowFilters] = useState(false)

  const { data, isLoading } = useQuery({
    queryKey: ['players', search, roleFilter, statusFilter, sortBy, sortOrder, perPage, page],
    queryFn: async () => {
      const filters: PlayersFilters = {
        search: search || undefined,
        role: roleFilter || undefined,
        filters: statusFilter ? [statusFilter] : undefined,
        sort: sortBy,
        order: sortOrder,
        page,
        per_page: perPage,
      }
      const response = await playersApi.list(filters)
      return response.data
    },
    staleTime: 1000 * 60 * 30,
  })

  const players = useMemo(() => {
    const list = data?.players || []
    return list.map((p: Player) => {
      const punishment = punishmentConfig[p.punishment_status] || punishmentConfig[0]
      const Icon = roleIcons[p.role_name.toLowerCase()] || User
      return {
        ...p,
        punishmentLabel: punishment.label,
        punishmentColor: punishment.color,
        punishmentIcon: punishment.icon,
        roleIcon: Icon,
      }
    })
  }, [data])

  const totalPlayers = data?.total || 0
  const onlinePlayers = players.filter((p) => p.is_online).length
  const totalPages = data?.total_pages || 0

  return (
    <div className="min-h-screen bg-base-100 py-8">
      <div className="container mx-auto max-w-6xl px-4">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
        >
          {/* Header */}
          <div className="mb-6 flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
            <div>
              <h1 className="text-3xl font-bold text-primary">{t('players.title')}</h1>
              <p className="mt-1 text-neutral/70">{t('players.subtitle')}</p>
            </div>
            <button
              onClick={() => setShowFilters(!showFilters)}
              className="flex items-center gap-2 rounded-lg border border-neutral/20 px-4 py-2 text-sm hover:bg-base-200"
            >
              <Filter className="h-4 w-4" />
              <span>{showFilters ? t('players.hide_filters') : t('players.show_filters')}</span>
            </button>
          </div>

          {/* Stats */}
          <div className="mb-6 grid grid-cols-2 gap-4 md:grid-cols-4">
            <Card className="border-primary/20">
              <CardContent className="pt-6">
                <div className="flex items-center gap-3">
                  <div className="rounded-lg bg-primary/10 p-2">
                    <Users className="h-5 w-5 text-primary" />
                  </div>
                  <div>
                    <p className="text-xs text-neutral/60">{t('players.total_players')}</p>
                    <p className="text-lg font-bold">{totalPlayers}</p>
                  </div>
                </div>
              </CardContent>
            </Card>
            <Card className="border-success/20">
              <CardContent className="pt-6">
                <div className="flex items-center gap-3">
                  <div className="rounded-lg bg-success/10 p-2">
                    <Wifi className="h-5 w-5 text-success" />
                  </div>
                  <div>
                    <p className="text-xs text-neutral/60">{t('players.online')}</p>
                    <p className="text-lg font-bold">{onlinePlayers}</p>
                  </div>
                </div>
              </CardContent>
            </Card>
            <Card className="border-warning/20">
              <CardContent className="pt-6">
                <div className="flex items-center gap-3">
                  <div className="rounded-lg bg-warning/10 p-2">
                    <VolumeX className="h-5 w-5 text-warning" />
                  </div>
                  <div>
                    <p className="text-xs text-neutral/60">{t('players.muted')}</p>
                    <p className="text-lg font-bold">
                      {players.filter((p) => p.punishment_status === 2).length}
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>
            <Card className="border-error/20">
              <CardContent className="pt-6">
                <div className="flex items-center gap-3">
                  <div className="rounded-lg bg-error/10 p-2">
                    <Ban className="h-5 w-5 text-error" />
                  </div>
                  <div>
                    <p className="text-xs text-neutral/60">{t('players.banned')}</p>
                    <p className="text-lg font-bold">
                      {players.filter((p) => p.punishment_status === 3).length}
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Filters */}
          <AnimatePresence>
            {showFilters && (
              <motion.div
                initial={{ height: 0, opacity: 0 }}
                animate={{ height: 'auto', opacity: 1 }}
                exit={{ height: 0, opacity: 0 }}
                transition={{ duration: 0.2 }}
              >
                <Card className="mb-6">
                  <CardContent className="pt-6">
                    <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-4">
                      <div>
                        <label className="mb-1 block text-xs font-medium text-neutral/60">
                          {t('players.search')}
                        </label>
                        <div className="relative">
                          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-neutral/40" />
                          <input
                            type="text"
                            value={search}
                            onChange={(e) => { setSearch(e.target.value); setPage(1) }}
                            placeholder={t('players.search_placeholder')}
                            className="w-full rounded-lg border border-neutral/20 bg-base-200 pl-10 pr-4 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
                          />
                        </div>
                      </div>
                      <div>
                        <label className="mb-1 block text-xs font-medium text-neutral/60">
                          {t('players.filter_by_role')}
                        </label>
                        <select
                          value={roleFilter}
                          onChange={(e) => { setRoleFilter(e.target.value); setPage(1) }}
                          className="w-full rounded-lg border border-neutral/20 bg-base-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
                        >
                          {roleFilters.map((f) => (
                            <option key={f.value} value={f.value}>{t(f.labelKey)}</option>
                          ))}
                        </select>
                      </div>
                      <div>
                        <label className="mb-1 block text-xs font-medium text-neutral/60">
                          {t('players.filter_by_status')}
                        </label>
                        <select
                          value={statusFilter}
                          onChange={(e) => { setStatusFilter(e.target.value); setPage(1) }}
                          className="w-full rounded-lg border border-neutral/20 bg-base-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
                        >
                          {statusFilters.map((f) => (
                            <option key={f.value} value={f.value}>{t(f.labelKey)}</option>
                          ))}
                        </select>
                      </div>
                      <div>
                        <label className="mb-1 block text-xs font-medium text-neutral/60">
                          {t('players.per_page')}
                        </label>
                        <select
                          value={perPage}
                          onChange={(e) => { setPerPage(Number(e.target.value)); setPage(1) }}
                          className="w-full rounded-lg border border-neutral/20 bg-base-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
                        >
                          {[12, 24, 48].map((n) => (
                            <option key={n} value={n}>{n} {t('players.per_page')}</option>
                          ))}
                        </select>
                      </div>
                    </div>
                    <div className="mt-4 flex items-center gap-4">
                      <span className="text-sm font-medium text-neutral/60">{t('players.sort_by')}:</span>
                      <div className="flex items-center gap-1">
                        {(['minecraft_nickname', 'discord_username', 'role_weight'] as const).map((field) => (
                          <button
                            key={field}
                            onClick={() => setSortBy(field)}
                            className={`rounded-lg px-3 py-1.5 text-xs font-medium transition-colors ${
                              sortBy === field
                                ? 'bg-primary text-primary-foreground'
                                : 'bg-base-200 text-neutral/60 hover:bg-base-300'
                            }`}
                          >
                            {t(`players.sort_${field}`)}
                          </button>
                        ))}
                      </div>
                      <button
                        onClick={() => setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc')}
                        className="ml-auto flex items-center gap-1 rounded-lg bg-base-200 px-3 py-1.5 text-xs font-medium hover:bg-base-300"
                      >
                        {sortOrder === 'asc' ? (
                          <>
                            <ChevronUp className="h-3 w-3" /> {t('players.ascending')}
                          </>
                        ) : (
                          <>
                            <ChevronDown className="h-3 w-3" /> {t('players.descending')}
                          </>
                        )}
                      </button>
                    </div>
                  </CardContent>
                </Card>
              </motion.div>
            )}
          </AnimatePresence>

          {/* Players List */}
          <Card>
            <CardContent className="p-0">
              {isLoading ? (
                <div className="flex justify-center py-12">
                  <LoadingSpinner size="lg" />
                </div>
              ) : players.length === 0 ? (
                <div className="flex flex-col items-center justify-center py-16">
                  <User className="mb-4 h-12 w-12 text-neutral/30" />
                  <p className="text-lg font-medium text-neutral/50">{t('players.no_players')}</p>
                  <p className="text-sm text-neutral/40">{t('players.no_players_desc')}</p>
                </div>
              ) : (
                <div className="divide-y divide-neutral/10">
                  {players.map((player: Player & { punishmentLabel: string; punishmentColor: string; punishmentIcon: typeof VolumeX | null; roleIcon: typeof User }) => {
                    const PunishmentIcon = player.punishmentIcon
                    const RoleIcon = player.roleIcon

                    return (
                      <motion.div
                        key={player.id}
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                        className="flex items-center gap-4 p-4 hover:bg-base-200/50"
                      >
                        {/* Online Status Indicator */}
                        <div className="relative">
                          <Avatar
                            src={player.discord_avatar_url}
                            alt={player.minecraft_nickname}
                            size="md"
                          />
                          <div
                            className={`absolute -bottom-1 -right-1 h-4 w-4 rounded-full border-2 border-base-100 ${
                              player.is_online ? 'bg-success' : 'bg-neutral/40'
                            }`}
                          />
                        </div>

                        {/* Player Info */}
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center gap-2">
                            <p className="font-semibold truncate">
                              {player.minecraft_nickname}
                            </p>
                            <Badge
                              variant={player.punishmentColor}
                              className="gap-1"
                            >
                              {PunishmentIcon && <PunishmentIcon className="h-3 w-3" />}
                              {t(`players.${player.punishmentLabel}`)}
                            </Badge>
                          </div>
                          <div className="flex items-center gap-2 text-xs text-neutral/60">
                            <RoleIcon className="h-3 w-3" />
                            <span>{player.role_name}</span>
                            <span className="text-neutral/40">•</span>
                            <span className="truncate">{player.discord_username}</span>
                          </div>
                        </div>

                        {/* Social Links */}
                        <div className="flex items-center gap-2">
                          {player.has_tiktok && (
                            <Badge variant="neutral" className="gap-1">
                              TikTok
                            </Badge>
                          )}
                          {player.has_twitch && (
                            <Badge variant="neutral" className="gap-1">
                              Twitch
                            </Badge>
                          )}
                          {player.has_youtube && (
                            <Badge variant="neutral" className="gap-1">
                              YouTube
                            </Badge>
                          )}
                          <a
                            href={`/profile/${player.minecraft_nickname}`}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="rounded-lg p-2 text-neutral/60 hover:text-primary"
                            title={t('players.view_profile')}
                          >
                            <ExternalLink className="h-4 w-4" />
                          </a>
                        </div>
                      </motion.div>
                    )
                  })}
                </div>
              )}
            </CardContent>

            {/* Pagination */}
            {totalPages > 1 && (
              <div className="flex items-center justify-between border-t border-neutral/10 px-4 py-3">
                <p className="text-sm text-neutral/60">
                  {t('players.showing')} {((page - 1) * perPage) + 1}-{Math.min(page * perPage, data?.total || 0)} {t('players.of')} {data?.total || 0}
                </p>
                <div className="flex items-center gap-1">
                  <button
                    onClick={() => setPage((p) => Math.max(1, p - 1))}
                    disabled={page <= 1}
                    className="flex items-center gap-1 rounded-lg px-2 py-1 text-sm disabled:opacity-50 hover:bg-base-200"
                  >
                    <ChevronLeft className="h-4 w-4" /> {t('players.previous')}
                  </button>
                  {Array.from({ length: Math.min(5, totalPages) }, (_, i) => {
                    let pageNum: number
                    if (totalPages <= 5) {
                      pageNum = i + 1
                    } else if (page <= 3) {
                      pageNum = i + 1
                    } else if (page >= totalPages - 2) {
                      pageNum = totalPages - 4 + i
                    } else {
                      pageNum = page - 2 + i
                    }
                    return (
                      <button
                        key={pageNum}
                        onClick={() => setPage(pageNum)}
                        className={`flex h-8 w-8 items-center justify-center rounded-lg text-sm ${
                          pageNum === page
                            ? 'bg-primary text-primary-foreground font-semibold'
                            : 'hover:bg-base-200'
                        }`}
                      >
                        {pageNum}
                      </button>
                    )
                  })}
                  <button
                    onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                    disabled={page >= totalPages}
                    className="flex items-center gap-1 rounded-lg px-2 py-1 text-sm disabled:opacity-50 hover:bg-base-200"
                  >
                    {t('players.next')} <ChevronRight className="h-4 w-4" />
                  </button>
                </div>
              </div>
            )}
          </Card>
        </motion.div>
      </div>
    </div>
  )
}

export default Players
