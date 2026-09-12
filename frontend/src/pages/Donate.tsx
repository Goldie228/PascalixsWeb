import { Card } from '@/components/ui/Card'
import { Button } from '@/components/ui/Button'
import { Badge } from '@/components/ui/Badge'
import { Modal } from '@/components/ui/Modal'
import { Heart, Star, Crown, Gift, DollarSign, Check } from 'lucide-react'
import { useState } from 'react'

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

export default function Donate() {
  const [selectedTier, setSelectedTier] = useState<DonationTier | null>(null)

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 p-4 md:p-8">
      <div className="max-w-6xl mx-auto">
        <div className="text-center mb-12">
          <h1 className="text-4xl font-bold text-white mb-4">Support Pascalixs</h1>
          <p className="text-gray-400 text-lg max-w-2xl mx-auto">
            Your donations help us maintain servers, develop new features, and keep the community thriving.
            Every contribution makes a difference!
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-12">
          {tiers.map((tier) => (
            <div key={tier.id} className={`relative ${tier.recommended ? '' : ''}`}>
              {tier.recommended && (
                <div className="absolute -top-3 left-1/2 -translate-x-1/2">
                  <Badge variant="warning">Recommended</Badge>
                </div>
              )}
              <Card
                className={`bg-gray-800/50 backdrop-blur-sm border-gray-700 ${
                  tier.recommended ? 'border-amber-400/50 shadow-lg shadow-amber-400/10' : ''
                }`}
              >
                <div className="text-center pt-4">
                  <div className="w-16 h-16 rounded-full bg-gray-700 flex items-center justify-center mx-auto mb-4 text-amber-400">
                    {tier.icon}
                  </div>
                  <h3 className="text-2xl font-bold text-white mb-2">{tier.name}</h3>
                  <div className="flex items-center justify-center gap-1 mb-4">
                    <DollarSign className="w-5 h-5 text-gray-400" />
                    <span className="text-3xl font-bold text-white">{tier.price}</span>
                    <span className="text-gray-400">/month</span>
                  </div>
                  <p className="text-gray-400 mb-6">{tier.description}</p>
                  <ul className="space-y-3 mb-6">
                    {tier.features.map((feature, index) => (
                      <li key={index} className="flex items-center gap-2 text-gray-300">
                        <Check className="w-4 h-4 text-green-400 flex-shrink-0" />
                        <span className="text-sm">{feature}</span>
                      </li>
                    ))}
                  </ul>
                  <Button
                    className="w-full"
                    onClick={() => setSelectedTier(tier)}
                    variant={tier.recommended ? 'success' : 'default'}
                  >
                    Donate Now
                  </Button>
                </div>
              </Card>
            </div>
          ))}
        </div>

        <Card className="bg-gray-800/50 backdrop-blur-sm border-gray-700 p-8">
          <div className="flex items-start gap-4">
            <Heart className="w-8 h-8 text-red-400 flex-shrink-0 mt-1" />
            <div>
              <h3 className="text-xl font-bold text-white mb-2">Where does the money go?</h3>
              <p className="text-gray-400 mb-4">
                100% of donations go directly to server costs, development, and community events.
                We believe in transparency and want you to know exactly where your support goes.
              </p>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div className="p-4 bg-gray-700/50 rounded-lg">
                  <p className="text-2xl font-bold text-white mb-1">60%</p>
                  <p className="text-gray-400 text-sm">Server Costs</p>
                </div>
                <div className="p-4 bg-gray-700/50 rounded-lg">
                  <p className="text-2xl font-bold text-white mb-1">30%</p>
                  <p className="text-gray-400 text-sm">Development</p>
                </div>
                <div className="p-4 bg-gray-700/50 rounded-lg">
                  <p className="text-2xl font-bold text-white mb-1">10%</p>
                  <p className="text-gray-400 text-sm">Community Events</p>
                </div>
              </div>
            </div>
          </div>
        </Card>
      </div>

      {/* Donation Modal */}
      <Modal
        isOpen={!!selectedTier}
        onClose={() => setSelectedTier(null)}
        title={`${selectedTier?.name} - $${selectedTier?.price}`}
      >
        {selectedTier && (
          <div className="space-y-4">
            <p className="text-gray-400">{selectedTier.description}</p>
            <div className="space-y-2">
              {selectedTier.features.map((feature, index) => (
                <div key={index} className="flex items-center gap-2 text-gray-300">
                  <Check className="w-4 h-4 text-green-400" />
                  <span>{feature}</span>
                </div>
              ))}
            </div>
            <div className="pt-4 border-t border-gray-700">
              <Button className="w-full" variant="success">
                Proceed to Payment
              </Button>
            </div>
          </div>
        )}
      </Modal>
    </div>
  )
}
