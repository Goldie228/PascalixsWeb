import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Link, useNavigate } from 'react-router-dom'
import { motion, AnimatePresence } from 'framer-motion'
import { useToast } from '@/components/ui/Toast'
import { Button } from '@/components/ui/Button'
import { Input } from '@/components/ui/Input'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { Alert, AlertContent, AlertHeader, AlertTitle } from '@/components/ui/Alert'
import { userApi } from '@/services/userApi'
import {
  AlertTriangle,
  ShieldAlert,
  LogOut,
  ArrowLeft,
  CheckCircle2,
  Loader2,
} from 'lucide-react'

function Goodbye() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const { success: toastSuccess, error: toastError } = useToast()

  const [step, setStep] = useState<'confirm' | 'processing' | 'success'>('confirm')
  const [password, setPassword] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const handleDelete = async (e: React.FormEvent) => {
    e.preventDefault()
    setError(null)
    setIsSubmitting(true)
    setStep('processing')

    try {
      await userApi.deleteAccount(password)
      setStep('success')
      toastSuccess(t('goodbye_page.success_title'))

      // Clear auth state
      localStorage.removeItem('token')

      setTimeout(() => {
        navigate('/')
      }, 3000)
    } catch (err: any) {
      setStep('confirm')
      const message =
        err.response?.data?.error ||
        err.response?.data?.message ||
        t('goodbye_page.error_delete_failed')
      toastError(message)
      setError(message)
      setIsSubmitting(false)
    }
  }

  const handleCancel = () => {
    navigate(-1)
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-base-100 py-8 px-4">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="w-full max-w-lg"
      >
        <AnimatePresence mode="wait">
          {/* Confirmation Step */}
          {step === 'confirm' && (
            <motion.div
              key="confirm"
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: 20 }}
            >
              <Card className="border-error/30">
                <CardHeader className="text-center">
                  <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-error/10">
                    <ShieldAlert className="h-8 w-8 text-error" />
                  </div>
                  <CardTitle className="text-2xl text-error">
                    {t('goodbye_page.heading')}
                  </CardTitle>
                  <p className="text-sm text-base-content/60">
                    {t('goodbye_page.subtitle')}
                  </p>
                </CardHeader>
                <CardContent className="space-y-6">
                  {/* Warning Alert */}
                  <Alert variant="error">
                    <AlertHeader className="flex items-center gap-2">
                      <AlertTriangle className="h-5 w-5 text-error" />
                      <AlertTitle>{t('goodbye_page.warning_title')}</AlertTitle>
                    </AlertHeader>
                    <AlertContent className="space-y-2 text-sm">
                      <p>{t('goodbye_page.warning_data_loss')}</p>
                      <p>{t('goodbye_page.warning_no_undo')}</p>
                      <p>{t('goodbye_page.warning_third_party')}</p>
                    </AlertContent>
                  </Alert>

                  {/* Password Input */}
                  <form onSubmit={handleDelete} className="space-y-4">
                    <Input
                      type="password"
                      label={t('goodbye_page.enter_password')}
                      placeholder={t('goodbye_page.password_placeholder')}
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      required
                      disabled={isSubmitting}
                    />

                    {error && (
                      <p className="text-xs text-error">{error}</p>
                    )}

                    <div className="flex flex-col gap-3 sm:flex-row">
                      <Button
                        type="submit"
                        variant="error"
                        className="flex-1"
                        isLoading={isSubmitting}
                        disabled={isSubmitting || !password.trim()}
                        icon={isSubmitting ? undefined : <LogOut className="mr-2 h-4 w-4" />}
                      >
                        {isSubmitting
                          ? t('goodbye_page.deleting')
                          : t('goodbye_page.delete_button')}
                      </Button>
                      <Button
                        type="button"
                        variant="ghost"
                        onClick={handleCancel}
                        disabled={isSubmitting}
                        icon={<ArrowLeft className="mr-2 h-4 w-4" />}
                      >
                        {t('goodbye_page.cancel_button')}
                      </Button>
                    </div>
                  </form>
                </CardContent>
              </Card>
            </motion.div>
          )}

          {/* Processing Step */}
          {step === 'processing' && (
            <motion.div
              key="processing"
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.95 }}
            >
              <Card>
                <CardContent className="flex flex-col items-center justify-center py-12 text-center">
                  <Loader2 className="mb-4 h-12 w-12 animate-spin text-error" />
                  <h3 className="mb-2 text-lg font-semibold">
                    {t('goodbye_page.deleting')}
                  </h3>
                  <p className="text-sm text-base-content/60">
                    {t('common.loading')}
                  </p>
                </CardContent>
              </Card>
            </motion.div>
          )}

          {/* Success Step */}
          {step === 'success' && (
            <motion.div
              key="success"
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
            >
              <Card className="border-success/30">
                <CardContent className="flex flex-col items-center justify-center py-12 text-center">
                  <motion.div
                    initial={{ scale: 0 }}
                    animate={{ scale: 1 }}
                    transition={{ type: 'spring', stiffness: 200, damping: 15 }}
                    className="mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-success/10"
                  >
                    <CheckCircle2 className="h-8 w-8 text-success" />
                  </motion.div>
                  <h3 className="mb-2 text-2xl font-bold text-success">
                    {t('goodbye_page.success_title')}
                  </h3>
                  <p className="mb-6 max-w-sm text-base-content/80">
                    {t('goodbye_page.success_message')}
                  </p>
                  <Link to="/">
                    <Button icon={<ArrowLeft className="mr-2 h-4 w-4" />}>
                      {t('goodbye_page.back_to_home')}
                    </Button>
                  </Link>
                </CardContent>
              </Card>
            </motion.div>
          )}
        </AnimatePresence>
      </motion.div>
    </div>
  )
}

export default Goodbye
