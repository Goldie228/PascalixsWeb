import { useState, useEffect } from 'react'
import { useTranslation } from 'react-i18next'
import { motion, AnimatePresence } from 'framer-motion'
import { Cookie } from 'lucide-react'
import { useToast } from '@/components/ui/Toast'

const COOKIE_STORAGE_KEY = 'cookieAccepted'

export function CookieToast() {
  const { t } = useTranslation()
  const { toast } = useToast()
  const [isVisible, setIsVisible] = useState(false)

  useEffect(() => {
    const accepted = localStorage.getItem(COOKIE_STORAGE_KEY)
    if (!accepted) {
      // Show after 5 seconds, matching Rails behavior
      const timer = setTimeout(() => setIsVisible(true), 5000)
      return () => clearTimeout(timer)
    }
  }, [])

  const handleAccept = async () => {
    localStorage.setItem(COOKIE_STORAGE_KEY, 'true')
    setIsVisible(false)
    // Show confirmation toast
    toast(t('cookie.notification_message'), 'success', 3000)
  }

  return (
    <AnimatePresence>
      {isVisible && (
        <motion.div
          initial={{ opacity: 0, y: 40, scale: 0.95 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          exit={{ opacity: 0, y: 40, scale: 0.95 }}
          transition={{ duration: 0.3 }}
          className="fixed bottom-6 left-1/2 transform -translate-x-1/2 z-50 w-[95vw] md:w-[50%] bg-[#262626] text-white rounded-lg shadow-lg p-4 flex flex-col md:flex-row items-center justify-between gap-4"
        >
          {/* Left: icon + message */}
          <div className="flex flex-col md:flex-row items-center gap-3 text-center md:text-left flex-1">
            <Cookie className="w-12 h-12 text-amber-400 flex-shrink-0" />
            <span className="text-sm">
              {t('cookie.usage_text')}
            </span>
          </div>

          {/* Right: accept button */}
          <button
            onClick={handleAccept}
            className="btn btn-outline btn-warning rounded-lg px-4 py-2 md:px-6 md:py-3 text-sm md:text-base hover:text-[#1A1A1A] shadow-lg hover:shadow-xl transition duration-200 ease-in-out flex-shrink-0"
          >
            {t('cookie.accept_button')}
          </button>
        </motion.div>
      )}
    </AnimatePresence>
  )
}
