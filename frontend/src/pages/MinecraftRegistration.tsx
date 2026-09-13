import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { motion } from 'framer-motion'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { Input } from '@/components/ui/Input'
import { Button } from '@/components/ui/Button'
import { Alert, AlertContent } from '@/components/ui/Alert'
import { minecraftApi } from '@/services/minecraftApi'

function MinecraftRegistration() {
  const { t } = useTranslation()
  const [username, setUsername] = useState('')
  const [loading, setLoading] = useState(false)
  const [success, setSuccess] = useState(false)
  const [error, setError] = useState('')

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError('')
    setSuccess(false)

    try {
      await minecraftApi.verify(username)
      setSuccess(true)
    } catch (err: any) {
      setError(err.message || t('minecraft.error'))
    } finally {
      setLoading(false)
    }
  }

  if (success) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-base-100 py-8">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="w-full max-w-md"
        >
          <Card>
            <CardHeader className="text-center">
              <CardTitle className="text-2xl">{t('minecraft.success')}</CardTitle>
            </CardHeader>
            <CardContent className="text-center">
              <p className="mb-4 text-base-content/80">
                {t('minecraft.success')}
              </p>
              <Button variant="default" onClick={() => window.location.reload()}>
                {t('common.success')}
              </Button>
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
            <CardTitle className="text-2xl">{t('minecraft.title')}</CardTitle>
            <p className="mt-1 text-neutral/70">{t('minecraft.subtitle')}</p>
          </CardHeader>
          <CardContent>
            {error && (
              <Alert variant="error" className="mb-4">
                <AlertContent>{error}</AlertContent>
              </Alert>
            )}
            <form onSubmit={handleSubmit} className="space-y-4">
              <Input
                label={t('minecraft.username')}
                type="text"
                placeholder={t('minecraft.username_placeholder')}
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                required
                maxLength={16}
              />
              <Button type="submit" variant="default" className="w-full" disabled={loading}>
                {loading ? t('minecraft.checking') : t('minecraft.verify')}
              </Button>
            </form>
          </CardContent>
        </Card>
      </motion.div>
    </div>
  )
}

export default MinecraftRegistration
