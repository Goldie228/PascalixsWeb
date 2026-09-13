import { useTranslation } from 'react-i18next'
import { Card } from '@/components/ui/Card'
import { Button } from '@/components/ui/Button'
import { Badge } from '@/components/ui/Badge'
import { Modal } from '@/components/ui/Modal'
import { Input } from '@/components/ui/Input'
import { Alert, AlertContent } from '@/components/ui/Alert'
import { Heart, Star, Crown, Gift, DollarSign, Check, Bitcoin, CreditCard, Wallet } from 'lucide-react'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'

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

const customAmountSchema = z.object({
  amount: z.string().min(1, 'Amount is required').refine((val) => {
    const num = parseFloat(val)
    return !isNaN(num) && num >= 1 && num <= 10000
  }, 'Amount must be between $1 and $10,000'),
})

type CustomAmountFormData = z.infer<typeof customAmountSchema>

export default function Donate() {
  const { t } = useTranslation()
  const [selectedTier, setSelectedTier] = useState<DonationTier | null>(null)
  const [selectedCrypto, setSelectedCrypto] = useState<string | null>(null)
  const [showCryptoPayment, setShowCryptoPayment] = useState(false)
  const [customAmountSubmitted, setCustomAmountSubmitted] = useState(false)

  const {
    register: registerCustom,
    handleSubmit: handleCustomSubmit,
    formState: { errors: customErrors, isSubmitting: customSubmitting },
    reset: resetCustom,
  } = useForm<CustomAmountFormData>({
    resolver: zodResolver(customAmountSchema),
  })

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

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-12">
          {tiers.map((tier) => (
            <div key={tier.id} className={`relative ${tier.recommended ? '' : ''}`}>
              {tier.recommended && (
                <div className="absolute -top-3 left-1/2 -translate-x-1/2">
                  <Badge variant="default">{t('donate.recommended')}</Badge>
                </div>
              )}
              <Card
                className={`bg-base-200 border-base-300 ${
                  tier.recommended ? 'border-amber-400/50 shadow-lg shadow-amber-400/10' : ''
                }`}
              >
                <div className="text-center pt-4">
                  <div className="w-16 h-16 rounded-full bg-primary/10 flex items-center justify-center mx-auto mb-4 text-primary">
                    {tier.icon}
                  </div>
                  <h3 className="text-2xl font-bold text-base-content mb-2">{tier.name}</h3>
                  <div className="flex items-center justify-center gap-1 mb-4">
                    <DollarSign className="w-5 h-5 text-base-content/50" />
                    <span className="text-3xl font-bold text-base-content">{tier.price}</span>
                    <span className="text-base-content/50">/month</span>
                  </div>
                  <p className="text-base-content/70 mb-6">{descMap[tier.id]}</p>
                  <ul className="space-y-3 mb-6">
                    {featureMap[tier.id].map((feature, index) => (
                      <li key={index} className="flex items-center gap-2 text-base-content/80">
                        <Check className="w-4 h-4 text-success flex-shrink-0" />
                        <span className="text-sm">{feature}</span>
                      </li>
                    ))}
                  </ul>
                  <Button
                    className="w-full"
                    onClick={() => setSelectedTier(tier)}
                    variant={tier.recommended ? 'success' : 'default'}
                  >
                    {t('donate.donate_now')}
                  </Button>
                </div>
              </Card>
            </div>
          ))}
        </div>

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
    </div>
  )
}
