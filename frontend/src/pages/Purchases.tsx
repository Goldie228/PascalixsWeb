import { useQuery } from '@tanstack/react-query'
import api from '@/services/api'
import { Card } from '@/components/ui/Card'
import { Button } from '@/components/ui/Button'
import { Badge } from '@/components/ui/Badge'
import { Modal } from '@/components/ui/Modal'
import { ShoppingBag } from 'lucide-react'
import { useState } from 'react'

interface Purchase {
  id: number
  product_name: string
  amount: number
  status: string
  created_at: string
  expires_at?: string
}

export default function Purchases() {
  const [selectedPurchase, setSelectedPurchase] = useState<Purchase | null>(null)

  const { data: purchasesData, isLoading } = useQuery({
    queryKey: ['purchases'],
    queryFn: () => api.get('/purchases'),
    staleTime: 1000 * 60 * 5,
  })

  const purchases = purchasesData?.data?.purchases || []

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'completed':
        return <Badge variant="success">Completed</Badge>
      case 'pending':
        return <Badge variant="warning">Pending</Badge>
      case 'expired':
        return <Badge variant="error">Expired</Badge>
      case 'refunded':
        return <Badge variant="default">Refunded</Badge>
      default:
        return <Badge variant="default">{status}</Badge>
    }
  }

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-white text-lg">Loading purchases...</div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 p-4 md:p-8">
      <div className="max-w-4xl mx-auto">
        <div className="flex items-center justify-between mb-8">
          <div>
            <h1 className="text-3xl font-bold text-white mb-2">Purchases</h1>
            <p className="text-gray-400">Your purchase history and active passes</p>
          </div>
          <Button variant="outline" onClick={() => (window.location.href = '/donate')}>
            <ShoppingBag className="w-4 h-4 mr-2" />
            Buy Now
          </Button>
        </div>

        <div className="space-y-4">
          {purchases.map((purchase: Purchase) => (
            <Card
              key={purchase.id}
              className="bg-gray-800/50 backdrop-blur-sm border-gray-700 cursor-pointer hover:border-gray-600 transition-colors"
              onClick={() => setSelectedPurchase(purchase)}
            >
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-4">
                  <div className="w-12 h-12 rounded-lg bg-gray-700 flex items-center justify-center">
                    <ShoppingBag className="w-6 h-6 text-gray-400" />
                  </div>
                  <div>
                    <h3 className="text-lg font-semibold text-white">{purchase.product_name}</h3>
                    <p className="text-gray-400 text-sm">
                      {new Date(purchase.created_at).toLocaleDateString()}
                    </p>
                  </div>
                </div>
                <div className="flex items-center gap-4">
                  <span className="text-white font-bold">${purchase.amount}</span>
                  {getStatusBadge(purchase.status)}
                </div>
              </div>
            </Card>
          ))}
        </div>

        {purchases.length === 0 && (
          <div className="text-center py-12">
            <ShoppingBag className="w-16 h-16 text-gray-600 mx-auto mb-4" />
            <p className="text-gray-400 text-lg">No purchases yet</p>
            <p className="text-gray-500 text-sm mt-2">Browse our store to get started</p>
          </div>
        )}
      </div>

      {/* Purchase Detail Modal */}
      <Modal
        isOpen={!!selectedPurchase}
        onClose={() => setSelectedPurchase(null)}
        title="Purchase Details"
      >
        {selectedPurchase && (
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="text-xl font-bold text-white">{selectedPurchase.product_name}</h3>
              {getStatusBadge(selectedPurchase.status)}
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div className="p-3 bg-gray-700/50 rounded">
                <p className="text-gray-400 text-sm">Amount</p>
                <p className="text-white font-bold">${selectedPurchase.amount}</p>
              </div>
              <div className="p-3 bg-gray-700/50 rounded">
                <p className="text-gray-400 text-sm">Status</p>
                <p className="text-white">{selectedPurchase.status}</p>
              </div>
              <div className="p-3 bg-gray-700/50 rounded">
                <p className="text-gray-400 text-sm">Purchased</p>
                <p className="text-white">{new Date(selectedPurchase.created_at).toLocaleDateString()}</p>
              </div>
              {selectedPurchase.expires_at && (
                <div className="p-3 bg-gray-700/50 rounded">
                  <p className="text-gray-400 text-sm">Expires</p>
                  <p className="text-white">{new Date(selectedPurchase.expires_at).toLocaleDateString()}</p>
                </div>
              )}
            </div>
          </div>
        )}
      </Modal>
    </div>
  )
}
