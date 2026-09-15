import { useTranslation } from 'react-i18next'
import { useEffect, useState } from 'react'
import { Card } from '@/components/ui/Card'
import { Button } from '@/components/ui/Button'
import { Badge } from '@/components/ui/Badge'
import { Modal } from '@/components/ui/Modal'
import { Input } from '@/components/ui/Input'
import { Alert, AlertContent } from '@/components/ui/Alert'
import { Avatar } from '@/components/ui/Avatar'
import { useToast } from '@/components/ui/Toast'
import { useAuthStore } from '@/store/auth'
import {
  useUnbanPrice,
  useUnmutePrice,
  useProductPrice,
  useSearchUsers,
  useCreatePurchase,
} from '@/hooks/useDonations'
import {
  Heart,
  Star,
  Crown,
  Gift,
  DollarSign,
  Check,
  Bitcoin,
  CreditCard,
  Wallet,
  Ban,
  Megaphone,
  Search,
  UserPlus,
  Upload,
  X,
  Eye,
  Download,
  Trash2,
  Replace,
  AlertTriangle,
  ExternalLink,
  Loader2,
  Server,
  Coins,
} from 'lucide-react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import type { PurchaseType, SearchUser } from '@/types'

interface DonationTier {
  id: string
  name: string
  price: number
  description: string
  icon: React.ReactNode
  features: string[]
  recommended?: boolean
}

const tiers: DonationTier[] = [
  {
    id: 'gift-pass',
    name: 'Gift Pass',
    price: 4.99,
    description: 'Support the server with a gift pass',
    icon: <Gift className="w-8 h-8" />,
    features: ['Gift Pass for friends', 'Supporter badge', 'Thank you in Discord'],
  },
  {
    id: 'sponsor',
    name: 'Sponsor',
    price: 9.99,
    description: 'Become a project sponsor',
    icon: <Star className="w-8 h-8" />,
    features: ['Sponsor badge in chat', 'Mention in Discord', 'Priority support', 'Special role'],
    recommended: true,
  },
  {
    id: 'vip',
    name: 'VIP',
    price: 19.99,
    description: 'Premium VIP status',
    icon: <Crown className="w-8 h-8" />,
    features: ['VIP badge', 'Custom nickname color', 'Private Discord channel', 'Early access to features'],
  },
]

const cryptoOptions = [
  { id: 'btc', name: 'Bitcoin', icon: <Bitcoin className="w-5 h-5" />, symbol: 'BTC' },
  { id: 'eth', name: 'Ethereum', icon: <span className="text-lg">Ξ</span>, symbol: 'ETH' },
  { id: 'usdt', name: 'USDT', icon: <span className="text-lg font-bold text-green-500">₮</span>, symbol: 'USDT' },
]

// --- Debounced search hook ---
function useDebouncedValue<T>(value: T, delay: number): T {
  const [debounced, setDebounced] = useState(value)
  useEffect(() => {
    const timer = setTimeout(() => setDebounced(value), delay)
    return () => clearTimeout(timer)
  }, [value, delay])
  return debounced
}

// --- Receipt viewer modal ---
function ReceiptViewerModal({
  isOpen,
  onClose,
  imageUrl,
}: {
  isOpen: boolean
  onClose: () => void
  imageUrl: string
}) {
  const { t } = useTranslation()
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(false)

  useEffect(() => {
    if (isOpen) {
      setLoading(true)
      setError(false)
    }
  }, [isOpen, imageUrl])

  const handleLoad = () => {
    setLoading(false)
  }

  const handleError = () => {
    setLoading(false)
    setError(true)
  }

  const handleDownload = async () => {
    try {
      const response = await fetch(imageUrl, { credentials: 'include' })
      const blob = await response.blob()
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = 'receipt.png'
      document.body.appendChild(a)
      a.click()
      document.body.removeChild(a)
      URL.revokeObjectURL(url)
    } catch {
      // fallback: open in new tab
      window.open(imageUrl, '_blank')
    }
  }

  return (
    <Modal isOpen={isOpen} onClose={onClose} title={t('donate.payment_receipt_viewer_title')} size="lg">
      <div className="flex flex-col items-center gap-4">
        {loading && (
          <div className="flex flex-col items-center gap-3 py-12">
            <Loader2 className="w-10 h-10 text-amber-400 animate-spin" />
            <p className="text-base-content/60">{t('donate.loading')}</p>
          </div>
        )}
        {error ? (
          <div className="text-center py-12">
            <AlertTriangle className="w-12 h-12 text-amber-400 mx-auto mb-4" />
            <h3 className="text-xl font-bold text-white mb-2">{t('donate.payment_error_loading')}</h3>
            <p className="text-amber-400/70">{t('donate.payment_error_loading_retry')}</p>
          </div>
        ) : (
          <>
            <img
              src={imageUrl}
              alt={t('donate.payment_info')}
              className="max-w-full max-h-[60vh] object-contain rounded-lg"
              onLoad={handleLoad}
              onError={handleError}
            />
            <Button variant="outline" onClick={handleDownload} className="gap-2">
              <Download className="w-4 h-4" />
              {t('donate.payment_download')}
            </Button>
          </>
        )}
      </div>
    </Modal>
  )
}

// --- Sponsor modal ---
function SponsorModal({
  isOpen,
  onClose,
  onOpenPayment,
}: {
  isOpen: boolean
  onClose: () => void
  onOpenPayment: (type: PurchaseType, amount: number) => void
}) {
  const { t } = useTranslation()
  const priceQuery = useProductPrice('sponsor', true)
  const price = priceQuery.data?.price ?? 0

  useEffect(() => {
    if (isOpen) {
      priceQuery.refetch?.()
    }
  }, [isOpen])

  const handlePay = () => {
    if (price > 0) {
      onOpenPayment('sponsor', price)
    } else {
      onClose()
    }
  }

  return (
    <Modal isOpen={isOpen} onClose={onClose} title={t('donate.sponsor_title')} size="lg">
      <div className="space-y-6">
        {/* Benefits */}
        <div className="bg-base-300 rounded-lg p-5">
          <h3 className="text-lg font-semibold text-amber-400 mb-3">{t('donate.sponsor_benefits_title')}</h3>
          <div className="flex items-start gap-4 mb-4">
            <Star className="w-12 h-12 text-amber-400 flex-shrink-0 mt-1" />
            <div>
              <p className="text-white font-medium">{t('donate.sponsor_benefits_main')}</p>
              <p className="text-base-content/70 text-sm">{t('donate.sponsor_benefits_sub')}</p>
            </div>
          </div>
          <ul className="space-y-3 text-base-content/80">
            <li className="flex items-start gap-3">
              <div className="mt-1 w-5 h-5 rounded-full bg-amber-400/20 flex items-center justify-center flex-shrink-0">
                <Check className="w-3 h-3 text-amber-400" />
              </div>
              <span>
                <span className="font-medium text-white">{t('donate.sponsor_special_status')}</span>{' '}
                {t('donate.sponsor_special_status_location')}
              </span>
            </li>
            <li className="flex items-start gap-3">
              <div className="mt-1 w-5 h-5 rounded-full bg-amber-400/20 flex items-center justify-center flex-shrink-0">
                <Check className="w-3 h-3 text-amber-400" />
              </div>
              <span>
                <span className="font-medium text-white">{t('donate.sponsor_mention')}</span>{' '}
                {t('donate.sponsor_mention_location')}
              </span>
            </li>
          </ul>
        </div>

        {/* Funds info */}
        <div className="bg-gradient-to-br from-[#1f1f1f] to-[#0a0a0a] p-5 rounded-xl border border-amber-400/30">
          <h3 className="text-lg font-semibold text-amber-400 mb-3">{t('donate.sponsor_funds_title')}</h3>
          <p className="text-base-content/70 mb-4 text-sm">
            {t('donate.sponsor_funds_description')}
          </p>
          <div className="grid grid-cols-2 gap-3">
            <div className="flex items-center gap-3 p-3 bg-base-300 rounded-lg">
              <div className="w-10 h-10 rounded-full bg-amber-400/20 flex items-center justify-center flex-shrink-0">
                <Server className="w-5 h-5 text-amber-400" />
              </div>
              <span className="text-white text-sm">{t('donate.sponsor_server_upgrade')}</span>
            </div>
            <div className="flex items-center gap-3 p-3 bg-base-300 rounded-lg">
              <div className="w-10 h-10 rounded-full bg-amber-400/20 flex items-center justify-center flex-shrink-0">
                <Coins className="w-5 h-5 text-amber-400" />
              </div>
              <span className="text-white text-sm">{t('donate.sponsor_new_features')}</span>
            </div>
          </div>
        </div>

        {/* Price and CTA */}
        <div className="text-center">
          <div className="text-3xl font-bold text-amber-400 mb-4">
            {priceQuery.isLoading ? (
              <Loader2 className="w-8 h-8 animate-spin mx-auto" />
            ) : price > 0 ? (
              `$${price}`
            ) : (
              <span className="text-red-400 text-lg">{t('donate.payment_price_unavailable')}</span>
            )}
          </div>
          <Button
            className="w-full py-3 text-lg font-semibold gap-2"
            onClick={handlePay}
            disabled={priceQuery.isLoading || price <= 0}
            isLoading={priceQuery.isLoading}
          >
            <Heart className="w-5 h-5" />
            {t('donate.sponsor_become')}
          </Button>
        </div>
      </div>
    </Modal>
  )
}

// --- Donation modal with DonationAlerts link ---
function DonationModal({
  isOpen,
  onClose,
  onOpenPayment,
}: {
  isOpen: boolean
  onClose: () => void
  onOpenPayment: (type: PurchaseType, amount: number) => void
}) {
  const { t } = useTranslation()
  const [amount, setAmount] = useState('10')

  const presetAmounts = [5, 10, 25, 50, 100]

  const handleSubmit = () => {
    const num = parseFloat(amount)
    if (!isNaN(num) && num > 0) {
      onOpenPayment('donation', num)
    }
  }

  return (
    <Modal isOpen={isOpen} onClose={onClose} title={t('donate.donation_title')} size="lg">
      <div className="space-y-6">
        {/* Header */}
        <div className="text-center">
          <div className="flex items-center gap-4 mb-4 justify-center">
            <img src="/assets/donate/donate.png" alt="Donate" className="w-16 h-16" onError={(e) => { (e.target as HTMLImageElement).style.display = 'none' }} />
            <div className="text-left">
              <p className="text-white font-medium">{t('donate.donation_importance')}</p>
              <p className="text-base-content/70 text-sm">{t('donate.donation_any_amount')}</p>
            </div>
          </div>

          <ul className="space-y-3 text-base-content/80 text-left max-w-md mx-auto">
            <li className="flex items-start gap-3">
              <div className="mt-1 w-5 h-5 rounded-full bg-amber-400/20 flex items-center justify-center flex-shrink-0">
                <Check className="w-3 h-3 text-amber-400" />
              </div>
              <span>{t('donate.donation_server_infrastructure')}</span>
            </li>
            <li className="flex items-start gap-3">
              <div className="mt-1 w-5 h-5 rounded-full bg-amber-400/20 flex items-center justify-center flex-shrink-0">
                <Check className="w-3 h-3 text-amber-400" />
              </div>
              <span>{t('donate.donation_new_mechanics')}</span>
            </li>
            <li className="flex items-start gap-3">
              <div className="mt-1 w-5 h-5 rounded-full bg-amber-400/20 flex items-center justify-center flex-shrink-0">
                <Check className="w-3 h-3 text-amber-400" />
              </div>
              <span>{t('donate.donation_unique_content')}</span>
            </li>
          </ul>
        </div>

        {/* Amount input */}
        <div className="space-y-3">
          <label className="text-sm text-base-content/70 font-medium">{t('donate.payment_amount')}</label>
          <div className="flex gap-2 flex-wrap">
            {presetAmounts.map((a) => (
              <Button
                key={a}
                variant={amount === String(a) ? 'default' : 'outline'}
                onClick={() => setAmount(String(a))}
                className="px-4"
              >
                ${a}
              </Button>
            ))}
          </div>
          <div className="relative">
            <DollarSign className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-base-content/50" />
            <Input
              type="number"
              min="1"
              step="0.01"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              className="pl-10"
              placeholder="Custom amount"
            />
          </div>
        </div>

        {/* DonationAlerts link */}
        <a
          href="https://www.donationalerts.com/r/realtapok"
          target="_blank"
          rel="noopener noreferrer"
          className="flex items-center justify-center gap-2 w-full py-3 text-lg font-semibold bg-amber-500 text-[#1A1A1A] rounded-lg hover:bg-amber-600 transition cursor-pointer"
        >
          <ExternalLink className="w-5 h-5" />
          {t('donate.donation_donation_alerts')}
        </a>

        {/* Alternative: direct payment */}
        <Button
          className="w-full py-3 text-lg font-semibold gap-2"
          onClick={handleSubmit}
          disabled={parseFloat(amount) <= 0}
        >
          <Heart className="w-5 h-5" />
          {t('donate.donate')}
        </Button>

        <p className="text-center text-xs text-base-content/50">
          {t('donate.donation_redirection_notice')}
        </p>
      </div>
    </Modal>
  )
}

// --- Enhanced Payment modal with receipt viewer, replace/revoke ---
function PaymentModal({
  isOpen,
  onClose,
  purchaseType,
  amount,
  currency = 'USD',
  targetUserId,
  punishmentId,
  existingPurchase,
}: {
  isOpen: boolean
  onClose: () => void
  purchaseType: PurchaseType
  amount: number
  currency?: string
  targetUserId?: number | string
  punishmentId?: string
  existingPurchase?: {
    id: string
    status: string
    receiptUrl?: string
  }
}) {
  const { t } = useTranslation()
  const { success: toastSuccess, error: toastError } = useToast()
  const { user } = useAuthStore()
  const createPurchase = useCreatePurchase()
  const [file, setFile] = useState<File | null>(null)
  const [preview, setPreview] = useState<string | null>(null)
  const [dragOver, setDragOver] = useState(false)
  const [showViewer, setShowViewer] = useState(false)
  const [viewerUrl, setViewerUrl] = useState('')
  const [isReplacing, setIsReplacing] = useState(false)
  const [isRevoking, setIsRevoking] = useState(false)
  const [removeExisting, setRemoveExisting] = useState(false)

  const typeName = t(`donate.payment_type_${purchaseType}`)

  const validateAndSetFile = (f: File | undefined) => {
    if (!f) return
    if (!['image/jpeg', 'image/png'].includes(f.type)) {
      toastError(t('donate.payment_select_image'))
      return
    }
    if (f.size > 5 * 1024 * 1024) {
      toastError(t('donate.payment_size_exceeded'))
      return
    }
    setFile(f)
    setPreview(URL.createObjectURL(f))
    setRemoveExisting(false)
  }

  const handleOpenViewer = (url: string) => {
    setViewerUrl(url)
    setShowViewer(true)
  }

  const handleReplace = () => {
    setIsReplacing(true)
    setRemoveExisting(true)
    document.getElementById('receipt-input')?.click()
  }

  const handleRevoke = async () => {
    if (!existingPurchase?.id) {
      toastError(t('donate.payment_error_no_receipt'))
      return
    }
    setIsRevoking(true)
    try {
      const response = await fetch(`/api/v1/purchases/${existingPurchase.id}`, {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
      })
      if (response.ok) {
        toastSuccess(t('donate.payment_revoke_success'))
        setRemoveExisting(true)
        setFile(null)
        setPreview(null)
        onClose()
      } else {
        toastError(t('donate.payment_error_revoking_retry'))
      }
    } catch {
      toastError(t('donate.payment_error_revoking_retry'))
    } finally {
      setIsRevoking(false)
    }
  }

  const onSubmit = () => {
    if (!file && !removeExisting) {
      toastError(t('donate.payment_please_upload'))
      return
    }
    createPurchase.mutate(
      {
        actorUserId: user?.id ?? 0,
        input: {
          purchase_type: purchaseType,
          amount,
          currency,
          receipt: file ?? undefined,
          purchaser_user_id: user?.id,
          ...(targetUserId ? { target_user_id: targetUserId } : {}),
          ...(punishmentId ? { punishment_id: punishmentId } : {}),
        },
      },
      {
        onSuccess: () => {
          toastSuccess(t('donate.payment_submitted_for_review'))
          onClose()
        },
        onError: () => toastError(t('donate.payment_error_submitting_retry')),
      },
    )
  }

  const hasExistingReceipt = !!existingPurchase?.receiptUrl
  const isPending = existingPurchase?.status === 'pending'

  // Reset state when modal opens
  useEffect(() => {
    if (isOpen) {
      setFile(null)
      setPreview(null)
      setRemoveExisting(false)
      setIsReplacing(false)
      setIsRevoking(false)
    }
  }, [isOpen])

  return (
    <>
      <Modal isOpen={isOpen} onClose={onClose} title={t('donate.payment_title')} size="md">
        <div className="space-y-4">
          <Alert variant="info">
            <AlertContent>{t('donate.payment_desc')}</AlertContent>
          </Alert>

          {/* Payment details */}
          <div className="bg-base-300 rounded-lg p-4 space-y-2 text-sm">
            <div className="flex justify-between">
              <span className="text-base-content/70">{t('donate.payment_type')}</span>
              <span className="font-medium">{typeName}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-base-content/70">{t('donate.payment_amount')}</span>
              <span className="font-medium">
                ${amount} {currency}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-base-content/70">{t('donate.payment_status')}</span>
              <Badge variant="warning">{t('donate.payment_pending')}</Badge>
            </div>
          </div>

          <p className="text-sm text-base-content/60">{t('donate.payment_admin_note')}</p>

          {/* Existing receipt preview with replace/revoke */}
          {hasExistingReceipt && !file && (
            <div className="space-y-3">
              <div className="relative rounded-lg border border-base-300 overflow-hidden cursor-pointer" onClick={() => handleOpenViewer(existingPurchase.receiptUrl!)}>
                <img
                  src={existingPurchase.receiptUrl}
                  alt="receipt"
                  className="w-full h-auto object-contain max-h-64"
                />
                <div className="absolute inset-0 bg-black/0 hover:bg-black/20 transition flex items-center justify-center">
                  <Eye className="w-8 h-8 text-white opacity-0 hover:opacity-100 transition" />
                </div>
              </div>
              <div className="flex gap-2">
                <Button variant="outline" onClick={handleReplace} className="flex-1 gap-2" disabled={isRevoking}>
                  <Replace className="w-4 h-4" />
                  {t('donate.payment_replace')}
                </Button>
                <Button variant="outline" onClick={handleRevoke} className="flex-1 gap-2" disabled={isRevoking || isReplacing}>
                  <Trash2 className="w-4 h-4" />
                  {isRevoking ? t('donate.payment_deleting') : t('donate.payment_revoke')}
                </Button>
              </div>
            </div>
          )}

          {/* New receipt upload */}
          {preview ? (
            <div className="space-y-3">
              <div className="relative rounded-lg border border-base-300 overflow-hidden">
                <img src={preview} alt="receipt" className="w-full h-auto object-contain max-h-64" />
              </div>
              <Button variant="outline" onClick={() => { setFile(null); setPreview(null); }} className="w-full gap-2">
                <X className="w-4 h-4" />
                {t('common.cancel')}
              </Button>
            </div>
          ) : (
            <button
              type="button"
              onClick={() => document.getElementById('receipt-input')?.click()}
              onDragOver={(e) => {
                e.preventDefault()
                setDragOver(true)
              }}
              onDragLeave={() => setDragOver(false)}
              onDrop={(e) => {
                e.preventDefault()
                setDragOver(false)
                validateAndSetFile(e.dataTransfer.files[0])
              }}
              className={`flex flex-col items-center justify-center gap-3 p-8 border-2 border-dashed rounded-lg transition ${
                dragOver ? 'border-amber-400 bg-amber-400/5' : 'border-base-300'
              }`}
            >
              <Upload className="w-8 h-8 text-base-content/40" />
              <p className="text-sm text-base-content/70">
                {t('donate.payment_drag_here')}{' '}
                <span className="text-amber-400">{t('donate.payment_choose_file')}</span>
              </p>
              <p className="text-xs text-base-content/40">{t('donate.payment_supported')}</p>
              <input
                id="receipt-input"
                type="file"
                accept="image/jpeg,image/png"
                className="hidden"
                onChange={(e) => validateAndSetFile(e.target.files?.[0])}
              />
            </button>
          )}

          {/* Actions */}
          <div className="flex gap-2 pt-2">
            <Button variant="outline" onClick={onClose} disabled={createPurchase.isSubmitting}>
              {t('donate.payment_cancel')}
            </Button>
            <Button
              className="flex-1"
              onClick={onSubmit}
              disabled={(!file && !removeExisting) || createPurchase.isSubmitting}
              isLoading={createPurchase.isSubmitting}
            >
              {createPurchase.isSubmitting ? t('donate.payment_sending') : t('donate.payment_submit')}
            </Button>
          </div>
        </div>
      </Modal>

      <ReceiptViewerModal
        isOpen={showViewer}
        onClose={() => setShowViewer(false)}
        imageUrl={viewerUrl}
      />
    </>
  )
}

// --- Gift pass modal with recipient search ---
function GiftPassModal({
  isOpen,
  onClose,
  onOpenPayment,
}: {
  isOpen: boolean
  onClose: () => void
  onOpenPayment: (type: PurchaseType, amount: number, targetUserId?: number | string) => void
}) {
  const { t } = useTranslation()
  const { error: toastError } = useToast()
  const [search, setSearch] = useState('')
  const debouncedSearch = useDebouncedValue(search, 300)
  const [page, setPage] = useState(1)
  const [users, setUsers] = useState<SearchUser[]>([])
  const [hasMore, setHasMore] = useState(false)
  const [loadingMore, setLoadingMore] = useState(false)
  const [selected, setSelected] = useState<SearchUser | null>(null)

  const priceQuery = useProductPrice('pass_gift', true)
  const searchQuery = useSearchUsers({ page, search: debouncedSearch, per_page: 10 })

  useEffect(() => {
    if (!isOpen) return
    setUsers([])
    setPage(1)
    setHasMore(false)
    setLoadingMore(false)
    setSearch('')
    setSelected(null)
  }, [isOpen])

  useEffect(() => {
    if (!isOpen || !searchQuery.data) return
    const users = searchQuery.data.users
    const hasMore = searchQuery.data.has_more
    setUsers((prev) => (page === 1 ? users : [...prev, ...users]))
    setHasMore(hasMore)
  }, [isOpen, page, searchQuery.data])

  const loadMore = () => {
    if (!hasMore || loadingMore) return
    setLoadingMore(true)
    setPage((p) => p + 1)
    const timer = setTimeout(() => setLoadingMore(false), 400)
    return () => clearTimeout(timer)
  }

  const onPay = () => {
    if (!selected) {
      toastError(t('donate.gift_select_player'))
      return
    }
    if (priceQuery.data) {
      onOpenPayment('pass_gift', priceQuery.data.price, selected.uuid)
    } else {
      toastError(t('donate.gift_payment_unavailable'))
    }
  }

  return (
    <Modal isOpen={isOpen} onClose={onClose} title={t('donate.gift_title')} size="lg">
      <div className="space-y-4">
        <p className="text-base-content/70 text-sm">{t('donate.gift_desc')}</p>

        {selected ? (
          <div className="space-y-4">
            <div className="flex items-center gap-4 bg-base-300 rounded-lg p-4">
              <Avatar src={selected.avatar_url} alt={selected.nickname} size="lg" />
              <div className="flex-1">
                <p className="text-sm text-base-content/50">{t('donate.gift_recipient')}</p>
                <p className="font-semibold">{selected.nickname}</p>
                <p className="text-xs text-base-content/40">{t('donate.gift_selected_for_gift')}</p>
              </div>
              <Button variant="ghost" onClick={() => setSelected(null)} size="icon">
                <X className="w-4 h-4" />
              </Button>
            </div>
            <div className="bg-base-300 rounded-lg p-4">
              <p className="text-sm text-base-content/50 mb-1">{t('donate.gift_what_you_gift')}</p>
              <p className="font-semibold">{t('donate.gift_gift_pass')}</p>
              <p className="text-xs text-base-content/40">{t('donate.gift_full_access')}</p>
              <p className="text-lg font-bold text-amber-400 mt-2">
                {priceQuery.data ? `$${priceQuery.data.price}` : '…'}
              </p>
            </div>
            <div className="flex gap-2">
              <Button variant="outline" onClick={() => setSelected(null)} className="flex-1">
                {t('donate.gift_change')}
              </Button>
              <Button
                className="flex-1"
                onClick={onPay}
                disabled={priceQuery.isLoading || !priceQuery.data}
                isLoading={priceQuery.isLoading}
              >
                {t('donate.donate')}
              </Button>
            </div>
          </div>
        ) : (
          <div className="space-y-4">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-base-content/40" />
              <Input
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder={t('donate.gift_search_placeholder')}
                className="pl-10"
                aria-label={t('donate.gift_search_placeholder')}
              />
            </div>
            <p className="text-sm text-base-content/60">{t('donate.gift_who_to_gift')}</p>
            <div className="space-y-2 max-h-80 overflow-y-auto">
              {searchQuery.isLoading && page === 1 && (
                <p className="text-base-content/60 text-center py-6">{t('donate.loading')}</p>
              )}
              {searchQuery.isError && !searchQuery.isLoading && (
                <Alert variant="error">
                  <AlertContent>{t('donate.gift_no_users_found')}</AlertContent>
                </Alert>
              )}
              {!searchQuery.isLoading &&
                !searchQuery.isError &&
                users.map((u) => (
                  <button
                    key={u.uuid}
                    type="button"
                    onClick={() => setSelected(u)}
                    className="w-full flex items-center gap-3 p-3 rounded-lg border border-base-300 hover:border-amber-400 transition text-left hover:bg-base-300/50"
                  >
                    <Avatar src={u.avatar_url} alt={u.nickname} size="md" />
                    <span className="font-medium flex-1">{u.nickname}</span>
                    <UserPlus className="w-5 h-5 text-base-content/40" />
                  </button>
                ))}
              {!searchQuery.isLoading && !searchQuery.isError && users.length === 0 && (
                <p className="text-base-content/60 text-center py-6">{t('donate.gift_no_users_found')}</p>
              )}
            </div>
            {hasMore && (
              <Button variant="outline" onClick={loadMore} disabled={loadingMore} className="w-full">
                {loadingMore ? t('donate.loading') : t('donate.gift_load_more')}
              </Button>
            )}
          </div>
        )}
      </div>
    </Modal>
  )
}

// --- Unban modal ---
function UnbanModal({
  isOpen,
  onClose,
  onOpenPayment,
}: {
  isOpen: boolean
  onClose: () => void
  onOpenPayment: (type: PurchaseType, amount: number) => void
}) {
  const { t } = useTranslation()
  const query = useUnbanPrice()
  const data = query.data
  const total = data?.total_price ?? 0

  useEffect(() => {
    if (isOpen) query.refetch?.()
  }, [isOpen])

  return (
    <Modal isOpen={isOpen} onClose={onClose} title={t('donate.unban_title')} size="md">
      <div className="space-y-4">
        <p className="text-base-content/70 text-sm">{t('donate.unban_desc')}</p>

        {query.isLoading && <p className="text-base-content/60">{t('donate.loading')}</p>}
        {query.isError && (
          <Alert variant="error">
            <AlertContent>{t('donate.unban_loading_error')}</AlertContent>
          </Alert>
        )}

        {data && data.punishments.length > 0 && (
          <>
            <div className="space-y-2">
              {data.punishments.map((p) => (
                <div key={p.uuid} className="flex justify-between items-center bg-base-300 rounded-lg p-3">
                  <span className="text-base-content">{p.reason || t('donate.unban_reason_not_specified')}</span>
                  <span className="font-semibold text-amber-400">{p.price} $</span>
                </div>
              ))}
            </div>
            <div className="flex justify-between items-center text-lg font-bold">
              <span>{t('donate.unban_total')}</span>
              <span className="text-amber-400">{total} $</span>
            </div>
            <Button className="w-full" onClick={() => onOpenPayment('unban', total)} disabled={total <= 0}>
              {t('donate.unban_pay')}
            </Button>
          </>
        )}

        {data && data.punishments.length === 0 && !query.isLoading && (
          <p className="text-base-content/60 text-center py-6">{t('donate.unban_no_bans')}</p>
        )}

        {/* Alternative methods */}
        <div className="bg-gradient-to-br from-[#1f1f1f] to-[#0a0a0a] p-5 rounded-xl border border-amber-400/30">
          <h3 className="text-lg font-semibold text-amber-400 mb-3">Other methods</h3>
          <ul className="space-y-3 text-base-content/80">
            <li className="flex items-start gap-3">
              <div className="mt-1 w-5 h-5 rounded-full bg-amber-400/20 flex items-center justify-center flex-shrink-0">
                <Check className="w-3 h-3 text-amber-400" />
              </div>
              <span>{t('donate.unban_wait_ban_end')}</span>
            </li>
            <li className="flex items-start gap-3">
              <div className="mt-1 w-5 h-5 rounded-full bg-amber-400/20 flex items-center justify-center flex-shrink-0">
                <Check className="w-3 h-3 text-amber-400" />
              </div>
              <span>{t('donate.unban_submit_appeal')}</span>
            </li>
          </ul>
        </div>
      </div>
    </Modal>
  )
}

// --- Unmute modal ---
function UnmuteModal({
  isOpen,
  onClose,
  onOpenPayment,
}: {
  isOpen: boolean
  onClose: () => void
  onOpenPayment: (type: PurchaseType, amount: number) => void
}) {
  const { t } = useTranslation()
  const query = useUnmutePrice()
  const data = query.data
  const total = data?.total_price ?? 0

  useEffect(() => {
    if (isOpen) query.refetch?.()
  }, [isOpen])

  return (
    <Modal isOpen={isOpen} onClose={onClose} title={t('donate.unmute_title')} size="md">
      <div className="space-y-4">
        <p className="text-base-content/70 text-sm">{t('donate.unmute_desc')}</p>

        {query.isLoading && <p className="text-base-content/60">{t('donate.loading')}</p>}
        {query.isError && (
          <Alert variant="error">
            <AlertContent>{t('donate.unmute_loading_error')}</AlertContent>
          </Alert>
        )}

        {data && data.punishments.length > 0 && (
          <>
            <div className="space-y-2">
              {data.punishments.map((p) => (
                <div key={p.uuid} className="flex justify-between items-center bg-base-300 rounded-lg p-3">
                  <span className="text-base-content">{p.reason || t('donate.unmute_reason_not_specified')}</span>
                  <span className="font-semibold text-amber-400">{p.price} $</span>
                </div>
              ))}
            </div>
            <div className="flex justify-between items-center text-lg font-bold">
              <span>{t('donate.unmute_total')}</span>
              <span className="text-amber-400">{total} $</span>
            </div>
            <Button className="w-full" onClick={() => onOpenPayment('unmute', total)} disabled={total <= 0}>
              {t('donate.unmute_pay')}
            </Button>
          </>
        )}

        {data && data.punishments.length === 0 && !query.isLoading && (
          <p className="text-base-content/60 text-center py-6">{t('donate.unmute_no_mutes')}</p>
        )}

        {/* Alternative methods */}
        <div className="bg-gradient-to-br from-[#1f1f1f] to-[#0a0a0a] p-5 rounded-xl border border-amber-400/30">
          <h3 className="text-lg font-semibold text-amber-400 mb-3">Other methods</h3>
          <ul className="space-y-3 text-base-content/80">
            <li className="flex items-start gap-3">
              <div className="mt-1 w-5 h-5 rounded-full bg-amber-400/20 flex items-center justify-center flex-shrink-0">
                <Check className="w-3 h-3 text-amber-400" />
              </div>
              <span>{t('donate.unmute_wait_method')}</span>
            </li>
            <li className="flex items-start gap-3">
              <div className="mt-1 w-5 h-5 rounded-full bg-amber-400/20 flex items-center justify-center flex-shrink-0">
                <Check className="w-3 h-3 text-amber-400" />
              </div>
              <span>{t('donate.unmute_appeal_method')}</span>
            </li>
          </ul>
        </div>
      </div>
    </Modal>
  )
}

const customAmountSchema = z.object({
  amount: z.string().min(1, 'Amount is required').refine((val) => {
    const num = parseFloat(val)
    return !isNaN(num) && num >= 1 && num <= 10000
  }, 'Amount must be between $1 and $10,000'),
})

type CustomAmountFormData = z.infer<typeof customAmountSchema>

// --- Donation card for main page ---
function DonationCard({
  title,
  description,
  icon,
  imageAlt,
  onOpen,
  disabled,
}: {
  title: string
  description: string
  icon: React.ReactNode
  imageAlt: string
  onOpen: () => void
  disabled?: boolean
}) {
  return (
    <div
      className={`bg-[#1A1A1A] border border-[#2D2D2D] rounded-xl p-4 shadow-md flex flex-col items-center hover:border-amber-400 transition hover:shadow-[0_0_12px_4px_#FF8F00] hover:scale-[1.015] ${
        disabled ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'
      }`}
      onClick={!disabled ? onOpen : undefined}
    >
      <div className="w-full aspect-square flex justify-center items-center mb-4">
        <div className="w-[60%] h-[60%] flex items-center justify-center text-amber-400">
          {icon}
        </div>
      </div>
      <h3 className="text-white text-lg font-semibold mb-2 text-center">{title}</h3>
      <p className="text-[#BBBBBB] text-sm leading-relaxed mb-4 text-center">{description}</p>
      <button
        className={`w-full px-4 py-2 rounded-md font-semibold text-sm transition ${
          disabled
            ? 'bg-gray-500 text-white cursor-not-allowed'
            : 'bg-amber-500 text-[#1A1A1A] hover:bg-amber-600'
        }`}
        disabled={disabled}
        onClick={(e) => {
          e.stopPropagation()
          if (!disabled) onOpen()
        }}
      >
        Details
      </button>
    </div>
  )
}

export default function Donate() {
  const { t } = useTranslation()
  const [selectedTier, setSelectedTier] = useState<DonationTier | null>(null)
  const [selectedCrypto, setSelectedCrypto] = useState<string | null>(null)
  const [showCryptoPayment, setShowCryptoPayment] = useState(false)
  const [customAmountSubmitted, setCustomAmountSubmitted] = useState(false)
  const { user } = useAuthStore()
  const isBanned = user?.is_banned
  const isMuted = false // TODO: get from auth store

  const {
    register: registerCustom,
    handleSubmit: handleCustomSubmit,
    formState: { errors: customErrors, isSubmitting: customSubmitting },
    reset: resetCustom,
  } = useForm<CustomAmountFormData>({
    resolver: zodResolver(customAmountSchema),
  })

  // Payment modal state
  const [paymentOpen, setPaymentOpen] = useState(false)
  const [paymentType, setPaymentType] = useState<PurchaseType>('donation')
  const [paymentAmount, setPaymentAmount] = useState(0)
  const [paymentTargetUserId, setPaymentTargetUserId] = useState<number | string | undefined>(undefined)
  const [paymentPunishmentId, setPaymentPunishmentId] = useState<string | undefined>(undefined)
  const [paymentRemountKey, setPaymentRemountKey] = useState(0)

  // Modal visibility
  const [donationOpen, setDonationOpen] = useState(false)
  const [sponsorOpen, setSponsorOpen] = useState(false)
  const [giftOpen, setGiftOpen] = useState(false)
  const [unbanOpen, setUnbanOpen] = useState(false)
  const [unmuteOpen, setUnmuteOpen] = useState(false)

  // Open the shared payment modal
  const openPayment = (
    type: PurchaseType,
    amount: number,
    targetUserId?: number | string,
    punishmentId?: string,
  ) => {
    setPaymentType(type)
    setPaymentAmount(amount)
    setPaymentTargetUserId(targetUserId)
    setPaymentPunishmentId(punishmentId)
    setPaymentRemountKey((k) => k + 1)
    setPaymentOpen(true)
  }

  const featureMap: Record<string, string[]> = {
    'gift-pass': [
      t('donate.gift_pass_feature_1'),
      t('donate.gift_pass_feature_2'),
      t('donate.gift_pass_feature_3'),
    ],
    'sponsor': [
      t('donate.sponsor_feature_1'),
      t('donate.sponsor_feature_2'),
      t('donate.sponsor_feature_3'),
      t('donate.sponsor_feature_4'),
    ],
    'vip': [
      t('donate.vip_feature_1'),
      t('donate.vip_feature_2'),
      t('donate.vip_feature_3'),
      t('donate.vip_feature_4'),
    ],
  }

  const descMap: Record<string, string> = {
    'gift-pass': t('donate.gift_pass_desc'),
    'sponsor': t('donate.sponsor_desc'),
    'vip': t('donate.vip_desc'),
  }

  const onSubmitCustomAmount = async (data: CustomAmountFormData) => {
    const amount = parseFloat(data.amount)
    setSelectedTier({
      id: 'custom',
      name: t('donate.custom_amount'),
      price: amount,
      description: t('donate.custom_description'),
      icon: <DollarSign className="w-8 h-8" />,
      features: [t('donate.custom_feature')],
    })
    resetCustom()
    setCustomAmountSubmitted(true)
  }

  return (
    <div className="min-h-screen bg-base-100 py-8">
      <div className="container mx-auto max-w-6xl px-4">
        <div className="text-center mb-12">
          <h1 className="text-4xl font-bold text-base-content mb-4">{t('donate.title')}</h1>
          <p className="text-base-content/70 text-lg max-w-2xl mx-auto">
            {t('donate.subtitle')}
          </p>
        </div>

        {/* Rails-style donation cards */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6 mb-12">
          <DonationCard
            title={t('donate.gift_title')}
            description={t('donate.gift_desc')}
            icon={<Gift className="w-16 h-16" />}
            imageAlt="Gift"
            onOpen={() => setGiftOpen(true)}
          />
          {!user?.is_sponsor && (
            <DonationCard
              title={t('donate.sponsor')}
              description={t('donate.sponsor_desc')}
              icon={<Star className="w-16 h-16" />}
              imageAlt="Sponsor"
              onOpen={() => setSponsorOpen(true)}
            />
          )}
          <DonationCard
            title={t('donate.donation_title')}
            description={t('donate.donation_description')}
            icon={<Heart className="w-16 h-16" />}
            imageAlt="Donate"
            onOpen={() => setDonationOpen(true)}
          />
          {isBanned && (
            <DonationCard
              title={t('donate.unban_title')}
              description={t('donate.unban_desc')}
              icon={<Ban className="w-16 h-16" />}
              imageAlt="Unban"
              onOpen={() => setUnbanOpen(true)}
            />
          )}
          {isMuted && (
            <DonationCard
              title={t('donate.unmute_title')}
              description={t('donate.unmute_desc')}
              icon={<Megaphone className="w-16 h-16" />}
              imageAlt="Unmute"
              onOpen={() => setUnmuteOpen(true)}
            />
          )}
        </div>

        {/* Subscribed user message */}
        {user?.is_sponsor && (
          <Card className="bg-base-200 border-base-300 p-6 mb-12">
            <div className="text-center">
              <Check className="w-12 h-12 text-amber-400 mx-auto mb-4" />
              <h3 className="text-xl font-bold text-base-content mb-2">You are a Sponsor!</h3>
              <p className="text-base-content/70">Thank you for your support. Enjoy your sponsor benefits.</p>
            </div>
          </Card>
        )}

        {/* Actions: remove penalties and gift passes */}
        <Card className="bg-base-200 border-base-300 p-8 mb-12">
          <div className="text-center mb-6">
            <h3 className="text-2xl font-bold text-base-content mb-2">{t('donate.actions_title')}</h3>
            <p className="text-base-content/70">{t('donate.actions_desc')}</p>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <Button
              variant="outline"
              className="h-auto py-6 flex-col gap-2"
              onClick={() => setUnbanOpen(true)}
            >
              <Ban className="w-6 h-6" />
              <span className="font-semibold">{t('donate.unban_title')}</span>
            </Button>
            <Button
              variant="outline"
              className="h-auto py-6 flex-col gap-2"
              onClick={() => setUnmuteOpen(true)}
            >
              <Megaphone className="w-6 h-6" />
              <span className="font-semibold">{t('donate.unmute_title')}</span>
            </Button>
            <Button
              variant="outline"
              className="h-auto py-6 flex-col gap-2"
              onClick={() => setGiftOpen(true)}
            >
              <Gift className="w-6 h-6" />
              <span className="font-semibold">{t('donate.gift_title')}</span>
            </Button>
          </div>
        </Card>

        {/* Custom Amount Section */}
        <Card className="bg-base-200 border-base-300 p-8 mb-12">
          <div className="text-center">
            <h3 className="text-2xl font-bold text-base-content mb-4">{t('donate.custom_amount_title')}</h3>
            <p className="text-base-content/70 mb-6">{t('donate.custom_amount_desc')}</p>
            <form onSubmit={handleCustomSubmit(onSubmitCustomAmount)} className="flex gap-4 justify-center items-center">
              <div className="relative">
                <DollarSign className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-base-content/50" />
                <Input
                  {...registerCustom('amount')}
                  type="number"
                  step="0.01"
                  min="1"
                  max="10000"
                  placeholder="0.00"
                  className="pl-10 w-40"
                  error={customErrors.amount?.message ? String(customErrors.amount.message) : undefined}
                  disabled={customSubmitting}
                />
              </div>
              <Button type="submit" isLoading={customSubmitting} disabled={customSubmitting}>
                {t('donate.donate')}
              </Button>
            </form>
          </div>
        </Card>

        {/* Crypto Payment Section */}
        <Card className="bg-base-200 border-base-300 p-8 mb-12">
          <div className="text-center mb-6">
            <h3 className="text-2xl font-bold text-base-content mb-2">{t('donate.crypto_title')}</h3>
            <p className="text-base-content/70">{t('donate.crypto_desc')}</p>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {cryptoOptions.map((crypto) => (
              <Button
                key={crypto.id}
                variant={selectedCrypto === crypto.id ? 'default' : 'outline'}
                className="h-auto py-6 flex-col gap-2"
                onClick={() => {
                  setSelectedCrypto(crypto.id)
                  setShowCryptoPayment(true)
                }}
              >
                {crypto.icon}
                <span className="font-semibold">{crypto.name}</span>
                <span className="text-sm text-base-content/50">{crypto.symbol}</span>
              </Button>
            ))}
          </div>
        </Card>

        <Card className="bg-base-200 border-base-300 p-8">
          <div className="flex items-start gap-4">
            <Heart className="w-8 h-8 text-error flex-shrink-0 mt-1" />
            <div>
              <h3 className="text-xl font-bold text-base-content mb-2">{t('donate.where_money')}</h3>
              <p className="text-base-content/70 mb-4">
                {t('donate.where_money_desc')}
              </p>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div className="p-4 bg-base-300 rounded-lg">
                  <p className="text-2xl font-bold text-base-content mb-1">60%</p>
                  <p className="text-base-content/50 text-sm">{t('donate.server_costs')}</p>
                </div>
                <div className="p-4 bg-base-300 rounded-lg">
                  <p className="text-2xl font-bold text-base-content mb-1">30%</p>
                  <p className="text-base-content/50 text-sm">{t('donate.development')}</p>
                </div>
                <div className="p-4 bg-base-300 rounded-lg">
                  <p className="text-2xl font-bold text-base-content mb-1">10%</p>
                  <p className="text-base-content/50 text-sm">{t('donate.community')}</p>
                </div>
              </div>
            </div>
          </div>
        </Card>
      </div>

      {/* Donation Modal */}
      <Modal
        isOpen={!!selectedTier}
        onClose={() => {
          setSelectedTier(null)
          setCustomAmountSubmitted(false)
        }}
        title={`${selectedTier?.name} - $${selectedTier?.price}`}
      >
        {selectedTier && (
          <div className="space-y-4">
            {customAmountSubmitted ? (
              <div className="text-center py-8">
                <Badge variant="success" className="mb-4">{t('donate.payment_initiated')}</Badge>
                <p className="text-base-content/70 mb-4">{t('donate.payment_initiated_message')}</p>
                <div className="flex gap-2 justify-center">
                  <Button onClick={() => setShowCryptoPayment(true)} variant="outline">
                    <Bitcoin className="w-4 h-4 mr-2" />
                    {t('donate.pay_crypto')}
                  </Button>
                  <Button onClick={() => { setSelectedTier(null); setCustomAmountSubmitted(false); }}>
                    <CreditCard className="w-4 h-4 mr-2" />
                    {t('donate.pay_card')}
                  </Button>
                </div>
              </div>
            ) : (
              <>
                <p className="text-base-content/70">{descMap[selectedTier.id]}</p>
                <div className="space-y-2">
                  {featureMap[selectedTier.id].map((feature, index) => (
                    <div key={index} className="flex items-center gap-2 text-base-content/80">
                      <Check className="w-4 h-4 text-success" />
                      <span>{feature}</span>
                    </div>
                  ))}
                </div>
                <div className="pt-4 border-t border-base-300">
                  <div className="flex gap-2">
                    <Button className="flex-1" variant="success" onClick={() => setShowCryptoPayment(true)}>
                      <Wallet className="w-4 h-4 mr-2" />
                      {t('donate.pay_crypto')}
                    </Button>
                    <Button className="flex-1" onClick={() => { setSelectedTier(null); }}>
                      <CreditCard className="w-4 h-4 mr-2" />
                      {t('donate.pay_card')}
                    </Button>
                  </div>
                </div>
              </>
            )}
          </div>
        )}
      </Modal>

      {/* Crypto Payment Modal */}
      <Modal
        isOpen={showCryptoPayment}
        onClose={() => {
          setShowCryptoPayment(false)
          setSelectedCrypto(null)
        }}
        title={t('donate.crypto_payment')}
      >
        {selectedCrypto && (
          <div className="space-y-4">
            <Alert variant="info">
              <AlertContent>
                {t('donate.crypto_payment_info')}
              </AlertContent>
            </Alert>
            <div className="p-4 bg-base-300 rounded-lg text-center">
              <div className="w-48 h-48 bg-white mx-auto mb-4 flex items-center justify-center">
                <div className="text-6xl">📱</div>
              </div>
              <p className="text-base-content/70 text-sm mb-2">{t('donate.scan_qr')}</p>
              <div className="font-mono text-sm bg-base-200 p-2 rounded">
                {selectedCrypto === 'btc' && 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh'}
                {selectedCrypto === 'eth' && '0x71C7656EC7ab88b098defB751B7401B5f6d8976F'}
                {selectedCrypto === 'usdt' && '0x71C7656EC7ab88b098defB751B7401B5f6d8976F'}
              </div>
            </div>
            <div className="flex gap-2">
              <Button className="flex-1" variant="outline">
                {t('donate.copy_address')}
              </Button>
              <Button className="flex-1" variant="outline">
                {t('donate.verify_payment')}
              </Button>
            </div>
          </div>
        )}
      </Modal>

      {/* Donation Modal (with amount input + DonationAlerts) */}
      <DonationModal
        isOpen={donationOpen}
        onClose={() => setDonationOpen(false)}
        onOpenPayment={openPayment}
      />

      {/* Sponsor Modal */}
      <SponsorModal
        isOpen={sponsorOpen}
        onClose={() => setSponsorOpen(false)}
        onOpenPayment={openPayment}
      />

      {/* Gift Pass Modal */}
      <GiftPassModal
        isOpen={giftOpen}
        onClose={() => setGiftOpen(false)}
        onOpenPayment={openPayment}
      />

      {/* Unban Modal */}
      <UnbanModal
        isOpen={unbanOpen}
        onClose={() => setUnbanOpen(false)}
        onOpenPayment={openPayment}
      />

      {/* Unmute Modal */}
      <UnmuteModal
        isOpen={unmuteOpen}
        onClose={() => setUnmuteOpen(false)}
        onOpenPayment={openPayment}
      />

      {/* Payment Modal (shared receipt flow) */}
      <PaymentModal
        key={paymentRemountKey}
        isOpen={paymentOpen}
        onClose={() => setPaymentOpen(false)}
        purchaseType={paymentType}
        amount={paymentAmount}
        targetUserId={paymentTargetUserId}
        punishmentId={paymentPunishmentId}
      />
    </div>
  )
}
