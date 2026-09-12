import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { useNavigate, useParams, Link } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { useToast } from '@/components/ui/Toast'
import { Button } from '@/components/ui/Button'
import { Input } from '@/components/ui/Input'
import { Card } from '@/components/ui/Card'
import { Shield, RefreshCw } from 'lucide-react'

const verifySchema = z.object({
  code: z.string().length(6, 'Code must be 6 digits').regex(/^\d{6}$/, 'Code must contain only numbers'),
})

type VerifyFormData = z.infer<typeof verifySchema>

export default function TwoFactorVerify() {
  const { t } = useTranslation()
  const { success: toastSuccess } = useToast()
  const navigate = useNavigate()
  const { step } = useParams() // 'setup' or 'verify'
  const [isResending, setIsResending] = useState(false)
  const [countdown, setCountdown] = useState(0)

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<VerifyFormData>({
    resolver: zodResolver(verifySchema),
    defaultValues: { code: '' },
  })

  const onSubmit = async (data: VerifyFormData) => {
    // TODO: Implement 2FA verification API call
    console.log('Verifying code:', data.code)
    toastSuccess(t('two_factor.verify_button'))
    navigate('/dashboard')
  }

  const handleResend = async () => {
    setIsResending(true)
    // TODO: Implement resend code API call
    setCountdown(30)
    setTimeout(() => {
      setCountdown(0)
      setIsResending(false)
    }, 30000)
  }

  const title = step === 'setup' ? t('two_factor.setup_title') : t('two_factor.verify_title')
  const subtitle = step === 'setup' ? t('two_factor.setup_subtitle') : t('two_factor.verify_subtitle')
  const submitText = step === 'setup' ? t('two_factor.verify_enable') : t('two_factor.verify_button')

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 p-4">
      <Card className="w-full max-w-md bg-gray-800/50 backdrop-blur-sm border-gray-700">
        <div className="text-center mb-8">
          <div className="w-16 h-16 rounded-full bg-gray-700 flex items-center justify-center mx-auto mb-4">
            <Shield className="w-8 h-8 text-blue-400" />
          </div>
          <h1 className="text-2xl font-bold text-white mb-2">
            {title}
          </h1>
          <p className="text-gray-400">
            {subtitle}
          </p>
        </div>

        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
          <div>
            <Input
              {...register('code')}
              label={t('two_factor.code_label')}
              placeholder={t('two_factor.code_placeholder')}
              error={errors.code?.message}
              disabled={isSubmitting}
              maxLength={6}
            />
          </div>

          <Button
            type="submit"
            className="w-full"
            isLoading={isSubmitting}
            disabled={isSubmitting}
          >
            {submitText}
          </Button>
        </form>

        <div className="mt-6 text-center">
          <p className="text-gray-400 text-sm mb-2">
            {t('two_factor.no_code')}
          </p>
          <Button
            variant="outline"
            onClick={handleResend}
            disabled={isResending || countdown > 0}
            isLoading={isResending}
          >
            <RefreshCw className="w-4 h-4 mr-2" />
            {countdown > 0 ? t('two_factor.resending', { seconds: countdown }) : t('two_factor.resend_code')}
          </Button>
        </div>

        <div className="mt-4 text-center">
          <Link to="/account" className="text-gray-400 hover:text-white text-sm transition-colors">
            {t('two_factor.cancel')}
          </Link>
        </div>
      </Card>
    </div>
  )
}
