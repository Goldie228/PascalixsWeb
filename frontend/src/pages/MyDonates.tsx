import { useState, useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import { useQuery } from '@tanstack/react-query'
import { motion, AnimatePresence } from 'framer-motion'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { Badge } from '@/components/ui/Badge'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import { donatesApi, type Donation, type DonationFilters } from '@/services/donatesApi'
import { useAuthStore } from '@/store/auth'
import {
  DollarSign,
  Calendar,
  Filter,
  TrendingUp,
  TrendingDown,
  CheckCircle2,
  Clock,
  XCircle,
  Package,
  Gift,
  Star,
  Ban,
  VolumeX,
  ChevronLeft,
  ChevronRight,
} from 'lucide-react'

const purchaseTypeIcons: Record<string, { icon: typeof Package; color: string; label: string }> = {
  pass_purchase: { icon: Package, color: 'bg-blue-500/20 text-blue-400', label: 'pass_purchase' },
  pass_gift: { icon: Gift, color: 'bg-pink-500/20 text-pink-400', label: 'pass_gift' },
  sponsor: { icon: Star, color: 'bg-amber-500/20 text-amber-400', label: 'sponsor' },
  unban: { icon: Ban, color: 'bg-red-500/20 text-red-400', label: 'unban' },
  unmute: { icon: VolumeX, color: 'bg-orange-500/20 text-orange-400', label: 'unmute' },
}

const statusConfig: Record<string, { variant: 'success' | 'warning' | 'error'; icon: typeof CheckCircle2; label: string }> = {
  approved: { variant: 'success', icon: CheckCircle2, label: 'completed' },
  pending: { variant: 'warning', icon: Clock, label: 'pending' },
  rejected: { variant: 'error', icon: XCircle, label: 'failed' },
}

const statusFilters = [
  { value: '', labelKey: 'donates.all_statuses' },
  { value: 'approved', labelKey: 'donates.completed' },
  { value: 'pending', labelKey: 'donates.pending' },
  { value: 'rejected', labelKey: 'donates.failed' },
]

const purchaseTypeFilters = [
  { value: '', labelKey: 'donates.all_types' },
  { value: 'pass_purchase', labelKey: 'donates.pass_purchase' },
  { value: 'pass_gift', labelKey: 'donates.pass_gift' },
  { value: 'sponsor', labelKey: 'donates.sponsor' },
  { value: 'unban', labelKey: 'donates.unban' },
  { value: 'unmute', labelKey: 'donates.unmute' },
]

function MyDonates() {
  const { t } = useTranslation()
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated)

  const [statusFilter, setStatusFilter] = useState('')
  const [purchaseTypeFilter, setPurchaseTypeFilter] = useState('')
  const [sortBy, setSortBy] = useState<'created_at' | 'amount' | 'status' | 'purchase_type'>('created_at')
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc')
  const [perPage, setPerPage] = useState(25)
  const [page, setPage] = useState(1)
  const [showFilters, setShowFilters] = useState(false)

  const { data, isLoading } = useQuery({
    queryKey: ['my-donates', statusFilter, purchaseTypeFilter, sortBy, sortOrder, perPage, page],
    queryFn: async () => {
      const filters: DonationFilters = {
        status: statusFilter || undefined,
        purchase_type: purchaseTypeFilter || undefined,
        sort_by: sortBy,
        sort_order: sortOrder,
        page,
        per_page: perPage,
      }
      const response = await donatesApi.list(filters)
      return response.data
    },
    enabled: isAuthenticated,
    staleTime: 1000 * 60,
  })

  const donations = useMemo(() => {
    const list = data?.donates || []
    return list.map((d: Donation) => {
      const status = statusConfig[d.status] || { variant: 'default' as const, label: d.status }
      const typeInfo = purchaseTypeIcons[d.purchase_type] || { icon: Package, color: 'bg-gray-500/20 text-gray-400' }
      return { ...d, statusLabel: status.label, typeLabel: typeInfo.label, typeColor: typeInfo.color }
    })
  }, [data])

  const totalPages = data?.total_pages || 0

  if (!isAuthenticated) {
    return (
      <div className="flex min-h-[60vh] items-center justify-center">
        <Card className="w-full max-w-md">
          <CardHeader>
            <CardTitle className="text-center text-xl">{t('profile.access_required')}</CardTitle>
          </CardHeader>
          <CardContent className="text-center">
            <p className="mb-4 text-neutral/70">{t('profile.please_login')}</p>
          </CardContent>
        </Card>
      </div>
    )
  }

  const formatCurrency = (amount: number, currency: string) => {
    return new Intl.NumberFormat('en-US', { style: 'currency', currency }).format(amount)
  }

  const formatDate = (dateStr: string) => {
    return new Date(dateStr).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    })
  }

  return (
    <div className="min-h-screen bg-base-100 py-8">
      <div className="container mx-auto max-w-5xl px-4">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
        >
          {/* Header */}
          <div className="mb-6">
            <h1 className="text-3xl font-bold text-primary">{t('donates.title')}</h1>
            <p className="mt-1 text-neutral/70">{t('donates.subtitle')}</p>
          </div>

          {/* Stats Cards */}
          <div className="mb-6 grid grid-cols-2 gap-4 md:grid-cols-4">
            <Card className="border-primary/20">
              <CardContent className="pt-6">
                <div className="flex items-center gap-3">
                  <div className="rounded-lg bg-primary/10 p-2">
                    <DollarSign className="h-5 w-5 text-primary" />
                  </div>
                  <div>
                    <p className="text-xs text-neutral/60">{t('donates.total_spent')}</p>
                    <p className="text-lg font-bold">
                      {formatCurrency(
                        (data?.donates || []).reduce((sum, d) => sum + d.amount, 0),
                        'USD'
                      )}
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>
            <Card className="border-success/20">
              <CardContent className="pt-6">
                <div className="flex items-center gap-3">
                  <div className="rounded-lg bg-success/10 p-2">
                    <CheckCircle2 className="h-5 w-5 text-success" />
                  </div>
                  <div>
                    <p className="text-xs text-neutral/60">{t('donates.completed')}</p>
                    <p className="text-lg font-bold">
                      {(data?.donates || []).filter((d) => d.status === 'approved').length}
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>
            <Card className="border-warning/20">
              <CardContent className="pt-6">
                <div className="flex items-center gap-3">
                  <div className="rounded-lg bg-warning/10 p-2">
                    <Clock className="h-5 w-5 text-warning" />
                  </div>
                  <div>
                    <p className="text-xs text-neutral/60">{t('donates.pending')}</p>
                    <p className="text-lg font-bold">
                      {(data?.donates || []).filter((d) => d.status === 'pending').length}
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>
            <Card className="border-error/20">
              <CardContent className="pt-6">
                <div className="flex items-center gap-3">
                  <div className="rounded-lg bg-error/10 p-2">
                    <XCircle className="h-5 w-5 text-error" />
                  </div>
                  <div>
                    <p className="text-xs text-neutral/60">{t('donates.failed')}</p>
                    <p className="text-lg font-bold">
                      {(data?.donates || []).filter((d) => d.status === 'rejected').length}
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Filters Card */}
          <Card className="mb-6">
            <CardHeader className="pb-3">
              <div className="flex items-center justify-between">
                <CardTitle className="text-base">{t('donates.filters')}</CardTitle>
                <button
                  onClick={() => setShowFilters(!showFilters)}
                  className="flex items-center gap-1 text-sm text-neutral/70 hover:text-primary"
                >
                  <Filter className="h-4 w-4" />
                  <span>{showFilters ? t('donates.hide_filters') : t('donates.show_filters')}</span>
                </button>
              </div>
            </CardHeader>
            <AnimatePresence>
              {showFilters && (
                <motion.div
                  initial={{ height: 0, opacity: 0 }}
                  animate={{ height: 'auto', opacity: 1 }}
                  exit={{ height: 0, opacity: 0 }}
                  transition={{ duration: 0.2 }}
                >
                  <CardContent className="pt-0">
                    <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-4">
                      <div>
                        <label className="mb-1 block text-xs font-medium text-neutral/60">
                          {t('donates.filter_by_status')}
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
                          {t('donates.filter_by_type')}
                        </label>
                        <select
                          value={purchaseTypeFilter}
                          onChange={(e) => { setPurchaseTypeFilter(e.target.value); setPage(1) }}
                          className="w-full rounded-lg border border-neutral/20 bg-base-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
                        >
                          {purchaseTypeFilters.map((f) => (
                            <option key={f.value} value={f.value}>{t(f.labelKey)}</option>
                          ))}
                        </select>
                      </div>
                      <div>
                        <label className="mb-1 block text-xs font-medium text-neutral/60">
                          {t('donates.sort_by')}
                        </label>
                        <select
                          value={sortBy}
                          onChange={(e) => setSortBy(e.target.value as DonationFilters['sort_by'])}
                          className="w-full rounded-lg border border-neutral/20 bg-base-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
                        >
                          <option value="created_at">{t('donates.sort_date')}</option>
                          <option value="amount">{t('donates.sort_amount')}</option>
                          <option value="status">{t('donates.sort_status')}</option>
                          <option value="purchase_type">{t('donates.sort_type')}</option>
                        </select>
                      </div>
                      <div>
                        <label className="mb-1 block text-xs font-medium text-neutral/60">
                          {t('donates.per_page')}
                        </label>
                        <select
                          value={perPage}
                          onChange={(e) => { setPerPage(Number(e.target.value)); setPage(1) }}
                          className="w-full rounded-lg border border-neutral/20 bg-base-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
                        >
                          {[25, 50, 75].map((n) => (
                            <option key={n} value={n}>{n} {t('donates.records')}</option>
                          ))}
                        </select>
                      </div>
                    </div>
                    {/* Sort order toggle */}
                    <div className="mt-4 flex items-center gap-2">
                      <span className="text-xs text-neutral/60">{t('donates.sort_order')}:</span>
                      <button
                        onClick={() => setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc')}
                        className="flex items-center gap-1 rounded-lg bg-base-200 px-3 py-1.5 text-xs font-medium hover:bg-base-300"
                      >
                        {sortOrder === 'asc' ? (
                          <>
                            <TrendingUp className="h-3 w-3" /> {t('donates.ascending')}
                          </>
                        ) : (
                          <>
                            <TrendingDown className="h-3 w-3" /> {t('donates.descending')}
                          </>
                        )}
                      </button>
                    </div>
                  </CardContent>
                </motion.div>
              )}
            </AnimatePresence>
          </Card>

          {/* Donations List */}
          <Card>
            <CardContent className="p-0">
              {isLoading ? (
                <div className="flex justify-center py-12">
                  <LoadingSpinner size="lg" />
                </div>
              ) : donations.length === 0 ? (
                <div className="flex flex-col items-center justify-center py-16">
                  <DollarSign className="mb-4 h-12 w-12 text-neutral/30" />
                  <p className="text-lg font-medium text-neutral/50">{t('donates.no_donates')}</p>
                  <p className="text-sm text-neutral/40">{t('donates.no_donates_desc')}</p>
                </div>
              ) : (
                <div className="divide-y divide-neutral/10">
                  {donations.map((donation: Donation & { statusLabel: string; typeLabel: string; typeColor: string }) => {
                    const status = statusConfig[donation.status]
                    const typeInfo = purchaseTypeIcons[donation.purchase_type]
                    const Icon = typeInfo?.icon || Package
                    const StatusIcon = status?.icon || Clock

                    return (
                      <motion.div
                        key={donation.id}
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                        className="flex items-center justify-between p-4 hover:bg-base-200/50"
                      >
                        <div className="flex items-center gap-4">
                          <div className={`flex h-10 w-10 items-center justify-center rounded-lg ${typeInfo?.color || 'bg-gray-500/20 text-gray-400'}`}>
                            <Icon className="h-5 w-5" />
                          </div>
                          <div>
                            <p className="font-medium">{t(`donates.${typeInfo?.label || donation.purchase_type}`)}</p>
                            <div className="flex items-center gap-2 text-xs text-neutral/50">
                              <Calendar className="h-3 w-3" />
                              <span>{formatDate(donation.created_at)}</span>
                            </div>
                          </div>
                        </div>
                        <div className="flex items-center gap-4">
                          <div className="text-right">
                            <p className="font-bold text-primary">{formatCurrency(donation.amount, donation.currency)}</p>
                          </div>
                          {status && (
                            <Badge variant={status.variant} className="gap-1">
                              <StatusIcon className="h-3 w-3" />
                              {t(`donates.${status.label}`)}
                            </Badge>
                          )}
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
                  {t('donates.showing')} {((page - 1) * perPage) + 1}-{Math.min(page * perPage, data?.total || 0)} {t('donates.of')} {data?.total || 0}
                </p>
                <div className="flex items-center gap-1">
                  <button
                    onClick={() => setPage((p) => Math.max(1, p - 1))}
                    disabled={page <= 1}
                    className="flex items-center gap-1 rounded-lg px-2 py-1 text-sm disabled:opacity-50 hover:bg-base-200"
                  >
                    <ChevronLeft className="h-4 w-4" /> {t('donates.previous')}
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
                    {t('donates.next')} <ChevronRight className="h-4 w-4" />
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

export default MyDonates
