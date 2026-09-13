import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Link } from 'react-router-dom'
import { motion } from 'framer-motion'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { Input } from '@/components/ui/Input'
import { Button } from '@/components/ui/Button'
import { Alert, AlertContent, AlertHeader, AlertTitle } from '@/components/ui/Alert'
import { emailLoginApi } from '@/services/emailLoginApi'

function EmailLogin() {
  const { t } = useTranslation()
  const [email, setEmail] = useState('')
  const [loading, setLoading] = useState(false)
  const [sent, setSent] = useState(false)
  const [error, setError] = useState('')

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError('')

    try {
      await emailLoginApi.sendLink(email)
      setSent(true)
    } catch (err: any) {
      setError(err.message || t('common.error'))
    } finally {
      setLoading(false)
    }
  }

  if (sent) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-base-100 py-8">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="w-full max-w-md"
        >
          <Card>
            <CardHeader className="text-center">
              <CardTitle className="text-2xl">{t('email_login.link_sent')}</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <Alert variant="info">
                <AlertHeader>
                  <AlertTitle>{t('pending_pages.check_email')}</AlertTitle>
                </AlertHeader>
                <AlertContent>
                  <p className="text-base-content/80">{t('email_login.link_sent_message')}</p>
                </AlertContent>
              </Alert>
              <div className="flex justify-center gap-3">
                <Link to="/login">
                  <Button variant="ghost">{t('email_login.back_to_login')}</Button>
                </Link>
              </div>
            </CardContent>
          </Card>
        </motion.div>
      </div>
    )
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-base-100 py-8">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="w-full max-w-md"
      >
        <Card>
          <CardHeader className="text-center">
            <CardTitle className="text-2xl">{t('email_login.title')}</CardTitle>
            <p className="mt-1 text-neutral/70">{t('email_login.subtitle')}</p>
          </CardHeader>
          <CardContent>
            {error && (
              <Alert variant="error" className="mb-4">
                <AlertContent>{error}</AlertContent>
              </Alert>
            )}
            <form onSubmit={handleSubmit} className="space-y-4">
              <Input
                label={t('email_login.email')}
                type="email"
                placeholder={t('email_login.email_placeholder')}
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
              />
              <Button type="submit" variant="default" className="w-full" disabled={loading}>
                {loading ? t('email_login.loading') : t('email_login.send_link')}
              </Button>
            </form>
            <div className="mt-4 text-center">
              <Link to="/login" className="text-sm text-primary hover:underline">
                {t('email_login.back_to_login')}
              </Link>
            </div>
          </CardContent>
        </Card>
      </motion.div>
    </div>
  )
}

export default EmailLogin
