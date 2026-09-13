import { useQuery } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'
import api from '@/services/api'
import { Card } from '@/components/ui/Card'
import { Button } from '@/components/ui/Button'
import { Badge } from '@/components/ui/Badge'
import { Modal } from '@/components/ui/Modal'
import { Input } from '@/components/ui/Input'
import { Alert, AlertContent } from '@/components/ui/Alert'
import { ShoppingBag, MessageSquare, AlertCircle } from 'lucide-react'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'

const disputeSchema = z.object({
  reason: z.string().min(10, 'Reason must be at least 10 characters').max(500, 'Reason must be at most 500 characters'),
  details: z.string().min(20, 'Details must be at least 20 characters').max(1000, 'Details must be at most 1000 characters'),
})

type DisputeFormData = z.infer<typeof disputeSchema>

interface Purchase {
  id: number
  product_name: string
  amount: number
  status: string
  created_at: string
  expires_at?: string
  disputed?: boolean
}

export default function Purchases() {
  const { t } = useTranslation()
  const [selectedPurchase, setSelectedPurchase] = useState<Purchase | null>(null)
  const [showDisputeModal, setShowDisputeModal] = useState(false)
  const [disputeSuccess, setDisputeSuccess] = useState(false)

  const { data: purchasesData, isLoading } = useQuery({
    queryKey: ['purchases'],
    queryFn: () => api.get('/purchases'),
    staleTime: 1000 * 60 * 5,
  })

  const purchases = purchasesData?.data?.purchases || []

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'completed':
        return <Badge variant="success">{t('purchases.completed')}</Badge>
      case 'pending':
        return <Badge variant="default">{t('purchases.pending')}</Badge>
      case 'expired':
        return <Badge variant="default">{t('purchases.expired')}</Badge>
      case 'refunded':
        return <Badge variant="default">{t('purchases.refunded')}</Badge>
      case 'disputed':
        return <Badge variant="default">{t('purchases.disputed')}</Badge>
      default:
        return <Badge variant="default">{status}</Badge>
    }
  }

  const canDispute = (purchase: Purchase) => {
    return purchase.status === 'completed' && !purchase.disputed
  }

  const {
    register: registerDispute,
    handleSubmit: handleDisputeSubmit,
    formState: { errors: disputeErrors, isSubmitting: disputeSubmitting },
    reset: resetDispute,
  } = useForm<DisputeFormData>({
    resolver: zodResolver(disputeSchema),
  })

  const onSubmitDispute = async (data: DisputeFormData) => {
    if (!selectedPurchase) return
    try {
      await api.post(`/purchases/${selectedPurchase.id}/dispute`, {
        reason: data.reason,
        details: data.details,
      })
      setDisputeSuccess(true)
      resetDispute()
      setTimeout(() => {
        setShowDisputeModal(false)
        setSelectedPurchase(null)
        setDisputeSuccess(false)
      }, 2000)
    } catch (error) {
      console.error('Dispute failed:', error)
    }
  }

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-white text-lg">{t('purchases.loading')}</div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-base-100 py-8">
      <div className="container mx-auto max-w-4xl px-4">
        <div className="flex items-center justify-between mb-8">
          <div>
            <h1 className="text-3xl font-bold text-base-content mb-2">{t('purchases.title')}</h1>
            <p className="text-base-content/70">{t('purchases.subtitle')}</p>
          </div>
          <Button variant="outline" onClick={() => (window.location.href = '/donate')}>
            <ShoppingBag className="w-4 h-4 mr-2" />
            {t('purchases.buy_now')}
          </Button>
        </div>

        <div className="space-y-4">
          {purchases.map((purchase: Purchase) => (
            <Card
              key={purchase.id}
              className="bg-base-200 border-base-300 cursor-pointer hover:border-primary/50 transition-colors"
              onClick={() => setSelectedPurchase(purchase)}
            >
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-4">
                  <div className="w-12 h-12 rounded-lg bg-primary/10 flex items-center justify-center">
                    <ShoppingBag className="w-6 h-6 text-primary" />
                  </div>
                  <div>
                    <h3 className="text-lg font-semibold text-base-content">{purchase.product_name}</h3>
                    <p className="text-base-content/50 text-sm">
                      {new Date(purchase.created_at).toLocaleDateString()}
                    </p>
                  </div>
                </div>
                <div className="flex items-center gap-4">
                  <span className="text-base-content font-bold">${purchase.amount}</span>
                  {getStatusBadge(purchase.status)}
                </div>
              </div>
            </Card>
          ))}
        </div>

        {purchases.length === 0 && (
          <div className="text-center py-12">
            <ShoppingBag className="w-16 h-16 text-base-content/30 mx-auto mb-4" />
            <p className="text-base-content/70 text-lg">{t('purchases.no_purchases')}</p>
            <p className="text-base-content/50 text-sm mt-2">{t('purchases.browse_store')}</p>
          </div>
        )}
      </div>

      {/* Purchase Detail Modal */}
      <Modal
        isOpen={!!selectedPurchase}
        onClose={() => setSelectedPurchase(null)}
        title={t('purchases.purchase_details')}
      >
        {selectedPurchase && (
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="text-xl font-bold text-base-content">{selectedPurchase.product_name}</h3>
              {getStatusBadge(selectedPurchase.status)}
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div className="p-3 bg-base-300 rounded">
                <p className="text-base-content/50 text-sm">{t('purchases.amount')}</p>
                <p className="text-base-content font-bold">${selectedPurchase.amount}</p>
              </div>
              <div className="p-3 bg-base-300 rounded">
                <p className="text-base-content/50 text-sm">{t('common.status')}</p>
                <p className="text-base-content">{selectedPurchase.status}</p>
              </div>
              <div className="p-3 bg-base-300 rounded">
                <p className="text-base-content/50 text-sm">{t('purchases.purchased')}</p>
                <p className="text-base-content">{new Date(selectedPurchase.created_at).toLocaleDateString()}</p>
              </div>
              {selectedPurchase.expires_at && (
                <div className="p-3 bg-base-300 rounded">
                  <p className="text-base-content/50 text-sm">{t('purchases.expires')}</p>
                  <p className="text-base-content">{new Date(selectedPurchase.expires_at).toLocaleDateString()}</p>
                </div>
              )}
            </div>

            {canDispute(selectedPurchase) && (
              <div className="pt-4 border-t border-base-300">
                <Alert variant="warning">
                  <AlertContent>
                    <AlertCircle className="w-4 h-4 mr-2" />
                    {t('purchases.dispute_info')}
                  </AlertContent>
                </Alert>
                <Button
                  className="w-full mt-4"
                  onClick={() => {
                    setShowDisputeModal(true)
                  }}
                >
                  <MessageSquare className="w-4 h-4 mr-2" />
                  {t('purchases.dispute')}
                </Button>
              </div>
            )}

            {selectedPurchase.status === 'disputed' && (
              <div className="pt-4 border-t border-base-300">
                <Alert variant="info">
                  <AlertContent>
                    {t('purchases.dispute_pending')}
                  </AlertContent>
                </Alert>
              </div>
            )}
          </div>
        )}
      </Modal>

      {/* Dispute Modal */}
      <Modal
        isOpen={showDisputeModal}
        onClose={() => {
          setShowDisputeModal(false)
          resetDispute()
        }}
        title={t('purchases.dispute_title')}
      >
        {disputeSuccess ? (
          <div className="text-center py-8">
            <Badge variant="success" className="mb-4">{t('purchases.dispute_submitted')}</Badge>
            <p className="text-base-content/70">{t('purchases.dispute_submitted_message')}</p>
          </div>
        ) : (
          <form onSubmit={handleDisputeSubmit(onSubmitDispute)} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-base-content/70 mb-1">
                {t('purchases.dispute_reason')}
              </label>
              <Input
                {...registerDispute('reason')}
                placeholder={t('purchases.dispute_reason_placeholder')}
                error={disputeErrors.reason?.message ? String(disputeErrors.reason.message) : undefined}
                disabled={disputeSubmitting}
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-base-content/70 mb-1">
                {t('purchases.dispute_details')}
              </label>
              <textarea
                {...registerDispute('details')}
                className="textarea textarea-bordered w-full bg-base-200 text-base-content border-base-300 focus:border-primary focus:outline-none"
                rows={4}
                placeholder={t('purchases.dispute_details_placeholder')}
                disabled={disputeSubmitting}
              />
              {disputeErrors.details && (
                <p className="mt-1 text-sm text-error">{String(disputeErrors.details.message)}</p>
              )}
            </div>
            <div className="flex gap-2">
              <Button
                type="submit"
                className="flex-1"
                isLoading={disputeSubmitting}
                disabled={disputeSubmitting}
              >
                {t('purchases.submit_dispute')}
              </Button>
              <Button
                type="button"
                variant="outline"
                className="flex-1"
                onClick={() => {
                  setShowDisputeModal(false)
                  resetDispute()
                }}
              >
                {t('common.cancel')}
              </Button>
            </div>
          </form>
        )}
      </Modal>
    </div>
  )
}
