import { useState, useEffect, useCallback } from 'react'
import { useTranslation } from 'react-i18next'
import { Link, useNavigate, useSearchParams } from 'react-router-dom'
import { motion } from 'framer-motion'
import { useToast } from '@/components/ui/Toast'
import { Button } from '@/components/ui/Button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { Alert, AlertContent, AlertHeader, AlertTitle } from '@/components/ui/Alert'
import { userApi } from '@/services/userApi'
import {
  CheckCircle,
  Loader2,
  RefreshCw,
  ArrowLeft,
  CheckCircle2,
  Mail,
  Clock,
} from 'lucide-react'

function PendingEmailVerification() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const { success: toastSuccess, error: toastError } = useToast()

  const [email, setEmail] = useState<string | null>(null)
  const [isResending, setIsResending] = useState(false)
  const [autoCheckCount, setAutoCheckCount] = useState(0)
  const [isChecking, setIsChecking] = useState(false)
  const [verified, setVerified] = useState(false)

  // Extract email from URL params if available
  useEffect(() => {
    const emailParam = searchParams.get('email')
    if (emailParam) {
      setEmail(emailParam)
    }
  }, [searchParams])

  // Auto-check for verification status (polling)
  const checkVerificationStatus = useCallback(async () => {
    if (!email || verified) return

    setIsChecking(true)
    try {
      const response = await userApi.checkEmailVerificationStatus(email)
      if (response.data?.success || response.data?.verified) {
        setVerified(true)
        toastSuccess(t('pending_pages.auto_check_success'))
        setTimeout(() => navigate('/account'), 1500)
      }
    } catch {
      // Polling is silent - don't show errors during auto-check
    } finally {
      setIsChecking(false)
    }
  }, [email, verified, navigate, toastSuccess, t])

  // Auto-check every 5 seconds, up to 12 checks (60 seconds)
  useEffect(() => {
    if (!email) return

    const interval = setInterval(() => {
      setAutoCheckCount((prev) => {
        if (prev >= 12) {
          clearInterval(interval)
          return prev
        }
        return prev + 1
      })
      checkVerificationStatus()
    }, 5000)

    return () => clearInterval(interval)
  }, [email, checkVerificationStatus])

  const handleResend = async () => {
    if (!email || isResending) return

    setIsResending(true)
    try {
      await userApi.resendEmailVerification(email)
      toastSuccess(t('pending_pages.resend_verification_success'))
      // Reset auto-check counter
      setAutoCheckCount(0)
    } catch (err: any) {
      const message =
        err.response?.data?.message ||
        err.response?.data?.error ||
        t('pending_pages.resend_verification_error')
      toastError(message)
    } finally {
      setIsResending(false)
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-base-100 py-8 px-4">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="w-full max-w-lg"
      >
        <Card>
          <CardHeader className="text-center">
            <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-success/10">
              <CheckCircle className="h-8 w-8 text-success" />
            </div>
            <CardTitle className="text-2xl">
              {t('pending_pages.verification_sent')}
            </CardTitle>
            {email && (
              <p className="mt-1 text-sm text-base-content/60">
                {email}
              </p>
            )}
          </CardHeader>
          <CardContent className="space-y-6">
            {/* Main Message */}
            <Alert variant="info">
              <AlertHeader className="flex items-center gap-2">
                <Mail className="h-5 w-5 text-info" />
                <AlertTitle>{t('pending_pages.check_email')}</AlertTitle>
              </AlertHeader>
              <AlertContent className="text-sm">
                <p>{t('pending_pages.verification_sent_message')}</p>
              </AlertContent>
            </Alert>

            {/* Next Steps */}
            <div className="rounded-lg bg-base-200 p-4">
              <div className="mb-3 flex items-center gap-2 text-success">
                <Clock className="h-4 w-4" />
                <h4 className="font-medium">
                  {t('pending_pages.verification_steps_title')}
                </h4>
              </div>
              <div className="space-y-2 text-sm text-base-content/80">
                <div className="flex items-start gap-2">
                  <span className="flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-success/10 text-xs font-medium text-success">
                    1
                  </span>
                  <span>{t('pending_pages.verification_step1')}</span>
                </div>
                <div className="flex items-start gap-2">
                  <span className="flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-success/10 text-xs font-medium text-success">
                    2
                  </span>
                  <span>{t('pending_pages.verification_step2')}</span>
                </div>
                <div className="flex items-start gap-2">
                  <span className="flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-success/10 text-xs font-medium text-success">
                    3
                  </span>
                  <span>{t('pending_pages.verification_step3')}</span>
                </div>
              </div>
            </div>

            {/* Auto-check status */}
            <div className="flex items-center justify-center gap-2 text-sm text-base-content/50">
              {isChecking ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin" />
                  <span>{t('pending_pages.auto_check_status')}</span>
                </>
              ) : verified ? (
                <>
                  <CheckCircle2 className="h-4 w-4 text-success" />
                  <span className="text-success">
                    {t('pending_pages.auto_check_success')}
                  </span>
                </>
              ) : (
                <>
                  <Loader2 className="h-4 w-4 animate-spin" />
                  <span>
                    {t('pending_pages.auto_check_status')} ({Math.min(autoCheckCount * 5, 60)}s)
                  </span>
                </>
              )}
            </div>

            {/* Resend Button */}
            <div className="text-center">
              <Button
                variant="outline"
                onClick={handleResend}
                disabled={isResending || !email}
                icon={
                  isResending ? (
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  ) : (
                    <RefreshCw className="mr-2 h-4 w-4" />
                  )
                }
              >
                {isResending
                  ? t('pending_pages.resend_verification')
                  : t('pending_pages.resend_verification')}
              </Button>
            </div>

            {/* Account Button */}
            <div className="text-center">
              <Link to="/account">
                <Button variant="ghost" icon={<ArrowLeft className="mr-2 h-4 w-4" />}>
                  {t('pending_pages.back_to_home')}
                </Button>
              </Link>
            </div>
          </CardContent>
        </Card>
      </motion.div>
    </div>
  )
}

export default PendingEmailVerification
