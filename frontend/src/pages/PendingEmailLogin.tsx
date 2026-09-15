import { useState, useEffect, useCallback } from 'react'
import { useTranslation } from 'react-i18next'
import { Link, useNavigate, useSearchParams } from 'react-router-dom'
import { motion } from 'framer-motion'
import { useToast } from '@/components/ui/Toast'
import { Button } from '@/components/ui/Button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { Alert, AlertContent, AlertHeader, AlertTitle } from '@/components/ui/Alert'
import { emailLoginApi } from '@/services/emailLoginApi'
import {
  Mail,
  Loader2,
  RefreshCw,
  ArrowLeft,
  CheckCircle2,
  Clock,
} from 'lucide-react'

function PendingEmailLogin() {
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

  // Auto-check for login response (polling)
  const checkLoginStatus = useCallback(async () => {
    if (!email || verified) return

    setIsChecking(true)
    try {
      // Try to verify the email login status
      // The backend should return a redirect or success if the user clicked the link
      const response = await emailLoginApi.verifyLink('pending')
      if (response.data?.status === 'success') {
        setVerified(true)
        toastSuccess(t('email_login.auto_check_success'))
        setTimeout(() => navigate('/login'), 1500)
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
      checkLoginStatus()
    }, 5000)

    return () => clearInterval(interval)
  }, [email, checkLoginStatus])

  const handleResend = async () => {
    if (!email || isResending) return

    setIsResending(true)
    try {
      await emailLoginApi.resendLink(email)
      toastSuccess(t('email_login.resend_success'))
      // Reset auto-check counter to give another 60 seconds
      setAutoCheckCount(0)
    } catch (err: any) {
      const message =
        err.response?.data?.message ||
        err.response?.data?.error ||
        t('email_login.resend_error')
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
            <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-primary/10">
              <Mail className="h-8 w-8 text-primary" />
            </div>
            <CardTitle className="text-2xl">
              {t('email_login.pending_title')}
            </CardTitle>
            {email && (
              <p className="mt-1 text-sm text-base-content/60">
                {t('email_login.pending_subtitle')}{' '}
                <span className="font-medium text-primary">{email}</span>
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
                <p>{t('email_login.pending_message')}</p>
              </AlertContent>
            </Alert>

            {/* Next Steps */}
            <div className="rounded-lg bg-base-200 p-4">
              <div className="mb-3 flex items-center gap-2 text-primary">
                <Clock className="h-4 w-4" />
                <h4 className="font-medium">
                  {t('email_login.pending_steps_title')}
                </h4>
              </div>
              <div className="space-y-2 text-sm text-base-content/80">
                <div className="flex items-start gap-2">
                  <span className="flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-primary/10 text-xs font-medium text-primary">
                    1
                  </span>
                  <span>{t('email_login.pending_step1')}</span>
                </div>
                <div className="flex items-start gap-2">
                  <span className="flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-primary/10 text-xs font-medium text-primary">
                    2
                  </span>
                  <span>{t('email_login.pending_step2')}</span>
                </div>
                <div className="flex items-start gap-2">
                  <span className="flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-primary/10 text-xs font-medium text-primary">
                    3
                  </span>
                  <span>{t('email_login.pending_step3')}</span>
                </div>
                <div className="flex items-start gap-2">
                  <span className="flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-primary/10 text-xs font-medium text-primary">
                    4
                  </span>
                  <span>{t('email_login.pending_step4')}</span>
                </div>
              </div>
            </div>

            {/* Auto-check status */}
            <div className="flex items-center justify-center gap-2 text-sm text-base-content/50">
              {isChecking ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin" />
                  <span>{t('email_login.auto_check')}</span>
                </>
              ) : verified ? (
                <>
                  <CheckCircle2 className="h-4 w-4 text-success" />
                  <span className="text-success">
                    {t('email_login.auto_check_success')}
                  </span>
                </>
              ) : (
                <>
                  <Loader2 className="h-4 w-4 animate-spin" />
                  <span>
                    {t('email_login.auto_check')} ({Math.min(autoCheckCount * 5, 60)}s)
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
                  ? t('email_login.resending')
                  : t('email_login.resend_button')}
              </Button>
            </div>

            {/* Home Button */}
            <div className="text-center">
              <Link to="/">
                <Button
                  variant="ghost"
                  icon={<ArrowLeft className="mr-2 h-4 w-4" />}
                >
                  {t('email_login.home_button')}
                </Button>
              </Link>
            </div>
          </CardContent>
        </Card>
      </motion.div>
    </div>
  )
}

export default PendingEmailLogin
