import { useState, useEffect, useRef } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { useNavigate, useParams, Link } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { useToast } from '@/components/ui/Toast'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { Shield, RefreshCw, Loader2, CheckCircle2, AlertTriangle } from 'lucide-react'
import { userApi } from '@/services/userApi'
import type { TwoFactorVerifyData } from '@/services/userApi'

const verifySchema = z.object({
  code: z.string().length(6, 'Code must be 6 digits').regex(/^\d{6}$/, 'Code must contain only numbers'),
})

type VerifyFormData = z.infer<typeof verifySchema>

export default function TwoFactorVerify() {
  const { t } = useTranslation()
  const { success: toastSuccess, error: toastError } = useToast()
  const navigate = useNavigate()
  const { step } = useParams() // 'setup' or 'verify'
  const [isResending, setIsResending] = useState(false)
  const [countdown, setCountdown] = useState(120) // 2 minutes
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [isVerified, setIsVerified] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const inputsRef = useRef<(HTMLInputElement | null)[]>([])
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null)

  const {
    handleSubmit,
    setValue,
  } = useForm<VerifyFormData>({
    resolver: zodResolver(verifySchema),
    defaultValues: { code: '' },
  })

  // OTP input handlers
  const handleOtpInput = (index: number, value: string) => {
    const digit = value.replace(/\D/g, '')
    if (!digit) return

    setValue('code', (getValue() || '') + digit, { shouldValidate: true })

    // Auto-focus next input
    if (index < 5 && inputsRef.current[index + 1]) {
      inputsRef.current[index + 1]?.focus()
    }
  }

  const handleOtpKeyDown = (index: number, e: React.KeyboardEvent) => {
    if (e.key === 'Backspace' && !getValue()?.[index]) {
      if (index > 0 && inputsRef.current[index - 1]) {
        inputsRef.current[index - 1]?.focus()
      }
    }
    if (e.key === 'ArrowLeft' && index > 0 && inputsRef.current[index - 1]) {
      inputsRef.current[index - 1]?.focus()
    }
    if (e.key === 'ArrowRight' && index < 5 && inputsRef.current[index + 1]) {
      inputsRef.current[index + 1]?.focus()
    }
  }

  const handleOtpPaste = (e: React.ClipboardEvent) => {
    e.preventDefault()
    const pasted = e.clipboardData.getData('text').replace(/\s/g, '')
    const digits = pasted.replace(/\D/g, '').slice(0, 6)
    if (digits.length === 6) {
      setValue('code', digits, { shouldValidate: true })
      digits.split('').forEach((char, i) => {
        if (inputsRef.current[i]) {
          inputsRef.current[i]!.value = char
        }
      })
      inputsRef.current[5]?.focus()
    }
  }

  const getValue = () => {
    return inputsRef.current.map((input) => input?.value || '').join('')
  }

  // Countdown timer
  useEffect(() => {
    timerRef.current = setInterval(() => {
      setCountdown((prev) => {
        if (prev <= 1) {
          if (timerRef.current) clearInterval(timerRef.current)
          return 0
        }
        return prev - 1
      })
    }, 1000)

    return () => {
      if (timerRef.current) clearInterval(timerRef.current)
    }
  }, [])

  // Handle form submit
  const onSubmit = async (data: VerifyFormData) => {
    setError(null)
    setIsSubmitting(true)

    try {
      const payload: TwoFactorVerifyData = { otp_attempt: data.code }
      const response = await userApi.verify2FA(payload)

      if (response.data?.success) {
        setIsVerified(true)
        toastSuccess(
          step === 'setup'
            ? t('two_factor.setup_success')
            : t('two_factor.verify_success')
        )

        setTimeout(() => {
          navigate('/account')
        }, 1500)
      } else {
        const message =
          response.data?.error ||
          response.data?.message ||
          t('two_factor.invalid_code')
        setError(message)
        toastError(message)
      }
    } catch (err: any) {
      const message =
        err.response?.data?.error ||
        err.response?.data?.message ||
        t('two_factor.invalid_code')
      setError(message)
      toastError(message)
    } finally {
      setIsSubmitting(false)
    }
  }

  // Handle resend
  const handleResend = async () => {
    if (isResending) return

    setIsResending(true)
    setError(null)

    try {
      const response = await userApi.resend2FACode()
      if (response.data?.success) {
        toastSuccess(t('two_factor.resend_code'))
        // Reset countdown
        setCountdown(120)
        // Clear inputs
        inputsRef.current.forEach((input) => {
          input?.focus()
        })
      }
    } catch (err: any) {
      const message =
        err.response?.data?.message ||
        err.response?.data?.error ||
        t('two_factor.resend_code')
      toastError(message)
    } finally {
      setIsResending(false)
    }
  }

  // Format countdown display
  const formatCountdown = (seconds: number) => {
    const mins = Math.floor(seconds / 60)
    const secs = seconds % 60
    return `${mins}:${secs.toString().padStart(2, '0')}`
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

        {isVerified ? (
          /* Success State */
          <div className="flex flex-col items-center justify-center py-8 space-y-4">
            <motion.div
              initial={{ scale: 0 }}
              animate={{ scale: 1 }}
              transition={{ type: 'spring', stiffness: 200, damping: 15 }}
              className="flex h-16 w-16 items-center justify-center rounded-full bg-success/10"
            >
              <CheckCircle2 className="h-8 w-8 text-success" />
            </motion.div>
            <h3 className="text-lg font-semibold text-white">
              {step === 'setup'
                ? t('two_factor.setup_success')
                : t('two_factor.verify_success')}
            </h3>
            <p className="text-sm text-gray-400">
              {t('common.loading')}
            </p>
          </div>
        ) : (
          /* OTP Form */
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
            {/* 6-digit OTP Input */}
            <div className="flex justify-center gap-2">
              {Array.from({ length: 6 }).map((_, i) => (
                <input
                  key={i}
                  id={`otp-digit-${i}`}
                  type="text"
                  inputMode="numeric"
                  maxLength={1}
                  className="w-12 h-14 text-center text-lg font-bold rounded-lg bg-gray-700 border border-gray-600 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-colors"
                  onInput={(e) => handleOtpInput(i, e.currentTarget.value)}
                  onKeyDown={(e) => handleOtpKeyDown(i, e)}
                  onPaste={handleOtpPaste}
                  autoFocus={i === 0}
                />
              ))}
            </div>

            {/* Validation Error */}
            {error && (
              <div className="flex items-center gap-2 rounded-lg bg-error/10 border border-error/20 p-3 text-error text-sm">
                <AlertTriangle className="h-4 w-4 shrink-0" />
                <span>{error}</span>
              </div>
            )}

            {/* Submit Button */}
            <Button
              type="submit"
              className="w-full"
              isLoading={isSubmitting}
              disabled={isSubmitting || getValue().length !== 6}
            >
              {submitText}
            </Button>
          </form>
        )}

        {/* Resend Section */}
        {!isVerified && (
          <div className="mt-6 text-center space-y-3">
            {/* Countdown Timer */}
            <div className="text-sm text-gray-400">
              {countdown > 0 ? (
                <span>
                  {t('two_factor.timer_label')}: <span className="font-mono text-gray-300">{formatCountdown(countdown)}</span>
                </span>
              ) : (
                <span className="text-gray-500">{t('two_factor.no_code')}</span>
              )}
            </div>

            {/* Resend Button */}
            <Button
              variant="outline"
              onClick={handleResend}
              disabled={isResending || countdown > 0}
              isLoading={isResending}
            >
              {isResending ? (
                <>
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  {countdown > 0
                    ? t('two_factor.resending', { seconds: countdown })
                    : t('two_factor.resend_code')}
                </>
              ) : (
                <>
                  <RefreshCw className="w-4 h-4 mr-2" />
                  {countdown > 0
                    ? t('two_factor.resending', { seconds: countdown })
                    : t('two_factor.resend_code')}
                </>
              )}
            </Button>
          </div>
        )}

        {/* Cancel Link */}
        {!isVerified && (
          <div className="mt-4 text-center">
            <Link to="/account" className="text-gray-400 hover:text-white text-sm transition-colors">
              {t('two_factor.cancel')}
            </Link>
          </div>
        )}
      </Card>
    </div>
  )
}
