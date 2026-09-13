import { useTranslation } from 'react-i18next'
import { Link } from 'react-router-dom'
import { motion } from 'framer-motion'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { Button } from '@/components/ui/Button'
import { Alert, AlertContent, AlertHeader, AlertTitle } from '@/components/ui/Alert'

function PendingEmailVerification() {
  const { t } = useTranslation()

  return (
    <div className="flex min-h-screen items-center justify-center bg-base-100 py-8">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="w-full max-w-md"
      >
        <Card>
          <CardHeader className="text-center">
            <CardTitle className="text-2xl">{t('pending_pages.email_verification')}</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <Alert variant="info">
              <AlertHeader>
                <AlertTitle>{t('pending_pages.check_email')}</AlertTitle>
              </AlertHeader>
              <AlertContent>
                <p className="text-base-content/80">{t('pending_pages.check_email_message')}</p>
              </AlertContent>
            </Alert>
            <div className="flex justify-center gap-3">
              <Link to="/">
                <Button variant="ghost">{t('pending_pages.back_to_home')}</Button>
              </Link>
            </div>
          </CardContent>
        </Card>
      </motion.div>
    </div>
  )
}

export default PendingEmailVerification
