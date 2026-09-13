import { useTranslation } from 'react-i18next'
import { Link } from 'react-router-dom'
import { motion } from 'framer-motion'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { Button } from '@/components/ui/Button'

function Goodbye() {
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
            <CardTitle className="text-2xl">{t('pending_pages.goodbye_title')}</CardTitle>
            <p className="text-neutral/70">{t('pending_pages.goodbye_subtitle')}</p>
          </CardHeader>
          <CardContent className="text-center">
            <p className="mb-6 text-base-content/80">{t('pending_pages.goodbye_message')}</p>
            <Link to="/">
              <Button variant="default">{t('pending_pages.back_to_home')}</Button>
            </Link>
          </CardContent>
        </Card>
      </motion.div>
    </div>
  )
}

export default Goodbye
