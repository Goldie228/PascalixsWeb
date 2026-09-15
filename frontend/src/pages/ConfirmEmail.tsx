import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useParams, Link } from 'react-router-dom'
import { useMutation } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { Alert, AlertContent, AlertHeader, AlertTitle } from '@/components/ui/Alert'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import { useToast } from '@/components/ui/Toast'
import api from '@/services/api'
import {
  CheckCircle2,
  XCircle,
  Mail,
} from 'lucide-react'

function ConfirmEmail() {
  const { t } = useTranslation()
  const { token } = useParams<{ token: string }>()
  const { success: toastSuccess, error: toastError } = useToast()
  const [status, setStatus] = useState<'loading' | 'success' | 'error'>('loading')

  const confirmMutation = useMutation({
    mutationFn: async (tok: string) => {
      const response = await api.get('/users/confirm_email', { params: { token: tok } })
      return response.data
    },
    onSuccess: () => {
      setStatus('success')
      toastSuccess(t('email_confirmations.success_desc'))
    },
    onError: () => {
      setStatus('error')
      toastError(t('email_confirmations.error_desc'))
    },
  })

  useEffect(() => {
    if (token) {
      confirmMutation.mutate(token)
    }
  }, [token])

  return (
    <div className="min-h-screen bg-base-100 flex flex-col items-center justify-center p-6">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="max-w-md w-full"
      >
        <Card>
          <CardHeader className="text-center pb-2">
            <CardTitle className="text-xl">
              {status === 'loading' && t('email_confirmations.confirming')}
              {status === 'success' && t('email_confirmations.success')}
              {status === 'error' && t('email_confirmations.error')}
            </CardTitle>
          </CardHeader>
          <CardContent className="pt-2">
            {/* Loading State */}
            {status === 'loading' && (
              <div className="text-center py-8">
                <LoadingSpinner size="lg" />
              </div>
            )}

            {/* Success State */}
            {status === 'success' && (
              <motion.div
                initial={{ opacity: 0, scale: 0.95 }}
                animate={{ opacity: 1, scale: 1 }}
                className="text-center py-6"
              >
                <div className="mb-4 flex justify-center">
                  <div className="rounded-full bg-success/10 p-4">
                    <CheckCircle2 className="h-12 w-12 text-success" />
                  </div>
                </div>
                <p className="text-base-content/70 text-sm mb-6">
                  {t('email_confirmations.success_desc')}
                </p>
                <Link to="/account">
                  <button className="btn btn-primary w-full">
                    {t('email_confirmations.back_to_account')}
                  </button>
                </Link>
              </motion.div>
            )}

            {/* Error State */}
            {status === 'error' && (
              <motion.div
                initial={{ opacity: 0, scale: 0.95 }}
                animate={{ opacity: 1, scale: 1 }}
                className="text-center py-6"
              >
                <div className="mb-4 flex justify-center">
                  <div className="rounded-full bg-error/10 p-4">
                    <XCircle className="h-12 w-12 text-error" />
                  </div>
                </div>
                <Alert variant="error">
                  <AlertHeader className="flex items-center gap-2">
                    <Mail className="h-5 w-5 text-error" />
                    <AlertTitle>{t('email_confirmations.error')}</AlertTitle>
                  </AlertHeader>
                  <AlertContent className="text-sm">
                    <p>{t('email_confirmations.error_desc')}</p>
                  </AlertContent>
                </Alert>
              </motion.div>
            )}
          </CardContent>
        </Card>

        {/* Back to Home Link */}
        <div className="mt-8 text-center">
          <Link to="/" className="text-primary hover:text-primary/80 underline text-sm">
            {t('email_confirmations.back_to_home')}
          </Link>
        </div>
      </motion.div>
    </div>
  )
}

export default ConfirmEmail
