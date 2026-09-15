import { useState, useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import { useQuery } from '@tanstack/react-query'
import { motion, AnimatePresence } from 'framer-motion'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { Badge } from '@/components/ui/Badge'
import { Avatar } from '@/components/ui/Avatar'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import { sponsorsApi, type Sponsor, type SponsorsFilters } from '@/services/sponsorsApi'
import {
  Users,
  Search,
  Grid3X3,
  List,
  Star,
  Crown,
  Award,
  Shield,
  ChevronUp,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  User,
} from 'lucide-react'

const tierConfig = {
  gold: {
    icon: Crown,
    color: 'bg-amber-500/20 text-amber-400 border-amber-500/30',
    badge: 'warning' as const,
    label: 'Gold Sponsor',
  },
  silver: {
    icon: Star,
    color: 'bg-gray-300/20 text-gray-300 border-gray-300/30',
    badge: 'default' as const,
    label: 'Silver Sponsor',
  },
  bronze: {
    icon: Award,
    color: 'bg-orange-700/20 text-orange-400 border-orange-700/30',
    badge: 'warning' as const,
    label: 'Bronze Sponsor',
  },
  none: {
    icon: Shield,
    color: 'bg-neutral/10 text-neutral/40 border-neutral/20',
    badge: 'neutral' as const,
    label: 'Player',
  },
}

function Sponsors() {
  const { t } = useTranslation()
  const [search, setSearch] = useState('')
  const [sortBy, setSortBy] = useState<'minecraft_nickname' | 'discord_username' | 'created_at'>('minecraft_nickname')
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc')
  const [viewMode, setViewMode] = useState<'grid' | 'list'>('grid')
  const [perPage, setPerPage] = useState(24)
  const [page, setPage] = useState(1)
  const [showSearch, setShowSearch] = useState(false)

  const { data, isLoading } = useQuery({
    queryKey: ['sponsors', search, sortBy, sortOrder, perPage, page],
    queryFn: async () => {
      const filters: SponsorsFilters = {
        search: search || undefined,
        sort: sortBy,
        order: sortOrder,
        page,
        per_page: perPage,
      }
      const response = await sponsorsApi.list(filters)
      return response.data
    },
    staleTime: 1000 * 60,
  })

  const sponsors = useMemo(() => {
    const list = data?.sponsors || []
    return list.map((s: Sponsor) => {
      const tier = tierConfig[s.sponsor_level] || tierConfig.none
      return { ...s, tierLabel: tier.label, tierColor: tier.color, tierBadge: tier.badge, tierIcon: tier.icon }
    })
  }, [data])

  const totalSponsors = sponsors.filter((s) => s.is_sponsor).length
  const totalPages = data?.total_pages || 0

  const formatCurrency = (amount: number, currency: string) => {
    return new Intl.NumberFormat('en-US', { style: 'currency', currency }).format(amount)
  }

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
              <h1 className="text-3xl font-bold text-primary">{t('sponsors.title')}</h1>
              <p className="mt-1 text-neutral/70">{t('sponsors.subtitle')}</p>
            </div>
            <div className="flex items-center gap-2">
              <button
                onClick={() => setShowSearch(!showSearch)}
                className={`rounded-lg p-2 hover:bg-base-200 ${showSearch ? 'text-primary' : 'text-neutral/60'}`}
                title={t('sponsors.search')}
              >
                <Search className="h-5 w-5" />
              </button>
              <div className="flex rounded-lg border border-neutral/20 overflow-hidden">
                <button
                  onClick={() => setViewMode('grid')}
                  className={`p-2 ${viewMode === 'grid' ? 'bg-primary text-primary-foreground' : 'text-neutral/60 hover:bg-base-200'}`}
                  title={t('sponsors.grid_view')}
                >
                  <Grid3X3 className="h-4 w-4" />
                </button>
                <button
                  onClick={() => setViewMode('list')}
                  className={`p-2 ${viewMode === 'list' ? 'bg-primary text-primary-foreground' : 'text-neutral/60 hover:bg-base-200'}`}
                  title={t('sponsors.list_view')}
                >
                  <List className="h-4 w-4" />
                </button>
              </div>
            </div>
          </div>

          {/* Search Bar */}
          <AnimatePresence>
            {showSearch && (
              <motion.div
                initial={{ height: 0, opacity: 0 }}
                animate={{ height: 'auto', opacity: 1 }}
                exit={{ height: 0, opacity: 0 }}
                transition={{ duration: 0.2 }}
              >
                <Card className="mb-6">
                  <CardContent className="pt-6">
                    <div className="relative">
                      <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-neutral/40" />
                      <input
                        type="text"
                        value={search}
                        onChange={(e) => { setSearch(e.target.value); setPage(1) }}
                        placeholder={t('sponsors.search_placeholder')}
                        className="w-full rounded-lg border border-neutral/20 bg-base-200 pl-10 pr-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
                      />
                    </div>
                  </CardContent>
                </Card>
              </motion.div>
            )}
          </AnimatePresence>

          {/* Stats */}
          <div className="mb-6 grid grid-cols-2 gap-4 md:grid-cols-4">
            <Card className="border-primary/20">
              <CardContent className="pt-6">
                <div className="flex items-center gap-3">
                  <div className="rounded-lg bg-primary/10 p-2">
                    <Users className="h-5 w-5 text-primary" />
                  </div>
                  <div>
                    <p className="text-xs text-neutral/60">{t('sponsors.total_sponsors')}</p>
                    <p className="text-lg font-bold">{totalSponsors}</p>
                  </div>
                </div>
              </CardContent>
            </Card>
            <Card className="border-amber-500/20">
              <CardContent className="pt-6">
                <div className="flex items-center gap-3">
                  <div className="rounded-lg bg-amber-500/10 p-2">
                    <Crown className="h-5 w-5 text-amber-400" />
                  </div>
                  <div>
                    <p className="text-xs text-neutral/60">{t('sponsors.gold_sponsors')}</p>
                    <p className="text-lg font-bold">
                      {sponsors.filter((s) => s.sponsor_level === 'gold').length}
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>
            <Card className="border-gray-300/20">
              <CardContent className="pt-6">
                <div className="flex items-center gap-3">
                  <div className="rounded-lg bg-gray-300/10 p-2">
                    <Star className="h-5 w-5 text-gray-300" />
                  </div>
                  <div>
                    <p className="text-xs text-neutral/60">{t('sponsors.silver_sponsors')}</p>
                    <p className="text-lg font-bold">
                      {sponsors.filter((s) => s.sponsor_level === 'silver').length}
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>
            <Card className="border-orange-700/20">
              <CardContent className="pt-6">
                <div className="flex items-center gap-3">
                  <div className="rounded-lg bg-orange-700/10 p-2">
                    <Award className="h-5 w-5 text-orange-400" />
                  </div>
                  <div>
                    <p className="text-xs text-neutral/60">{t('sponsors.bronze_sponsors')}</p>
                    <p className="text-lg font-bold">
                      {sponsors.filter((s) => s.sponsor_level === 'bronze').length}
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Sort Controls */}
          <Card className="mb-6">
            <CardContent className="pt-4">
              <div className="flex flex-wrap items-center gap-4">
                <span className="text-sm font-medium text-neutral/60">{t('sponsors.sort_by')}:</span>
                <div className="flex items-center gap-1">
                  {(['minecraft_nickname', 'discord_username', 'created_at'] as const).map((field) => (
                    <button
                      key={field}
                      onClick={() => setSortBy(field)}
                      className={`rounded-lg px-3 py-1.5 text-xs font-medium transition-colors ${
                        sortBy === field
                          ? 'bg-primary text-primary-foreground'
                          : 'bg-base-200 text-neutral/60 hover:bg-base-300'
                      }`}
                    >
                      {t(`sponsors.sort_${field}`)}
                    </button>
                  ))}
                </div>
                <button
                  onClick={() => setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc')}
                  className="ml-auto flex items-center gap-1 rounded-lg bg-base-200 px-3 py-1.5 text-xs font-medium hover:bg-base-300"
                >
                  {sortOrder === 'asc' ? (
                    <>
                      <ChevronUp className="h-3 w-3" /> {t('sponsors.ascending')}
                    </>
                  ) : (
                    <>
                      <ChevronDown className="h-3 w-3" /> {t('sponsors.descending')}
                    </>
                  )}
                </button>
                <select
                  value={perPage}
                  onChange={(e) => { setPerPage(Number(e.target.value)); setPage(1) }}
                  className="ml-auto rounded-lg border border-neutral/20 bg-base-200 px-3 py-1.5 text-xs focus:outline-none focus:ring-2 focus:ring-primary"
                >
                  {[12, 24, 48].map((n) => (
                    <option key={n} value={n}>{n} {t('sponsors.per_page')}</option>
                  ))}
                </select>
              </div>
            </CardContent>
          </Card>

          {/* Sponsors Grid/List */}
          <Card>
            <CardContent className="p-0">
              {isLoading ? (
                <div className="flex justify-center py-12">
                  <LoadingSpinner size="lg" />
                </div>
              ) : sponsors.length === 0 ? (
                <div className="flex flex-col items-center justify-center py-16">
                  <User className="mb-4 h-12 w-12 text-neutral/30" />
                  <p className="text-lg font-medium text-neutral/50">{t('sponsors.no_sponsors')}</p>
                  <p className="text-sm text-neutral/40">{t('sponsors.no_sponsors_desc')}</p>
                </div>
              ) : viewMode === 'grid' ? (
                <div className="grid grid-cols-1 gap-4 p-4 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
                  {sponsors.map((sponsor: Sponsor & { tierLabel: string; tierColor: string; tierBadge: string; tierIcon: typeof User }) => {
                    const TierIcon = sponsor.tierIcon
                    return (
                      <motion.div
                        key={sponsor.id}
                        initial={{ opacity: 0, scale: 0.95 }}
                        animate={{ opacity: 1, scale: 1 }}
                        whileHover={{ scale: 1.02 }}
                        className={`rounded-xl border p-4 ${sponsor.tierColor} transition-all hover:shadow-lg`}
                      >
                        <div className="flex items-start gap-3">
                          <Avatar
                            src={sponsor.discord_avatar_url}
                            alt={sponsor.minecraft_nickname}
                            size="md"
                          />
                          <div className="flex-1 min-w-0">
                            <div className="flex items-center gap-2">
                              <p className="font-semibold truncate">{sponsor.minecraft_nickname}</p>
                              {sponsor.is_sponsor && (
                                <Badge variant={sponsor.tierBadge as any} className="gap-1">
                                  <TierIcon className="h-3 w-3" />
                                  {sponsor.tierLabel}
                                </Badge>
                              )}
                            </div>
                            <p className="text-xs text-neutral/60 truncate">{sponsor.discord_username}</p>
                            <p className="mt-2 text-xs text-neutral/50">
                              {new Date(sponsor.created_at).toLocaleDateString()}
                            </p>
                          </div>
                        </div>
                      </motion.div>
                    )
                  })}
                </div>
              ) : (
                <div className="divide-y divide-neutral/10">
                  {sponsors.map((sponsor: Sponsor & { tierLabel: string; tierColor: string; tierBadge: string; tierIcon: typeof User }) => {
                    const TierIcon = sponsor.tierIcon
                    return (
                      <motion.div
                        key={sponsor.id}
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                        className="flex items-center gap-4 p-4 hover:bg-base-200/50"
                      >
                        <Avatar
                          src={sponsor.discord_avatar_url}
                          alt={sponsor.minecraft_nickname}
                          size="md"
                        />
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center gap-2">
                            <p className="font-semibold truncate">{sponsor.minecraft_nickname}</p>
                            {sponsor.is_sponsor && (
                              <Badge variant={sponsor.tierBadge as any} className="gap-1">
                                <TierIcon className="h-3 w-3" />
                                {sponsor.tierLabel}
                              </Badge>
                            )}
                          </div>
                          <p className="text-xs text-neutral/60 truncate">{sponsor.discord_username}</p>
                        </div>
                        <div className="text-right">
                          <p className="text-xs text-neutral/50">
                            {new Date(sponsor.created_at).toLocaleDateString()}
                          </p>
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
                  {t('sponsors.showing')} {((page - 1) * perPage) + 1}-{Math.min(page * perPage, data?.total || 0)} {t('sponsors.of')} {data?.total || 0}
                </p>
                <div className="flex items-center gap-1">
                  <button
                    onClick={() => setPage((p) => Math.max(1, p - 1))}
                    disabled={page <= 1}
                    className="flex items-center gap-1 rounded-lg px-2 py-1 text-sm disabled:opacity-50 hover:bg-base-200"
                  >
                    <ChevronLeft className="h-4 w-4" /> {t('sponsors.previous')}
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
                    {t('sponsors.next')} <ChevronRight className="h-4 w-4" />
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

export default Sponsors
