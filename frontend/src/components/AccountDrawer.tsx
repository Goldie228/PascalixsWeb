import { Link, useNavigate } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { motion, AnimatePresence } from 'framer-motion'
import { LogOut, User, Settings, ShoppingBag, Clock } from 'lucide-react'
import { useAuthStore } from '@/store/auth'
import { Avatar } from '@/components/ui/Avatar'
import { cn } from '@/lib/utils'

interface AccountDrawerProps {
  isOpen: boolean
  onClose: () => void
}

export function AccountDrawer({ isOpen, onClose }: AccountDrawerProps) {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const user = useAuthStore((state) => state.user)
  const logout = useAuthStore((state) => state.logout)

  const handleLogout = async () => {
    await logout()
    navigate('/')
    onClose()
  }

  const displayName = user?.nickname || user?.username || ''
  const avatarUrl = undefined // Would come from Discord avatar in full implementation

  const menuItems = [
    { to: '/profile', icon: User, label: t('account_drawer.profile') },
    { to: '/account', icon: Settings, label: t('account_drawer.account') },
    { to: '/purchases', icon: ShoppingBag, label: t('account_drawer.purchases') },
    { to: '/my_donates', icon: Clock, label: t('account_drawer.history') },
  ]

  return (
    <AnimatePresence>
      {isOpen && (
        <>
          {/* Backdrop */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            className="fixed inset-0 z-40 bg-black/30"
          />

          {/* Drawer */}
          <motion.div
            initial={{ x: '100%', opacity: 0 }}
            animate={{ x: 0, opacity: 1 }}
            exit={{ x: '100%', opacity: 0 }}
            transition={{ type: 'spring', damping: 25, stiffness: 200 }}
            className="fixed right-0 top-[72px] sm:top-[120px] z-50 w-72 sm:w-80 bg-[#0A0A0A] border-l-2 border-r-2 border-b-2 border-[#FFD700] rounded-b-lg shadow-xl overflow-y-auto max-h-[calc(100vh-72px)] sm:max-h-[calc(100vh-120px)]"
          >
            <div className="flex flex-col p-2 sm:p-4">
              {/* User profile section */}
              <div className="flex flex-col sm:flex-row sm:items-center gap-3 sm:gap-4 p-4 bg-[#121212] rounded-lg">
                <Link to="/profile" onClick={onClose}>
                  <Avatar
                    src={avatarUrl}
                    fallback={displayName}
                    size="lg"
                    className="w-16 h-16"
                  />
                </Link>
                <div className="flex flex-col overflow-hidden">
                  {user ? (
                    <>
                      <span className="text-xl font-bold text-[#FFD700] truncate">
                        {displayName}
                      </span>
                      <span className="flex items-center gap-1.5 text-sm text-gray-400">
                        {t('account_drawer.balance_label')}
                        <span className="flex items-center gap-1 bg-white/5 px-2 py-0.5 rounded-full border border-white/10">
                          <span className="text-[10px] uppercase tracking-widest font-medium text-amber-200/70">
                            WIP
                          </span>
                        </span>
                      </span>
                    </>
                  ) : (
                    <div className="skeleton w-32 h-4 mt-2" />
                  )}
                </div>
              </div>

              {/* Menu items */}
              <div className="mt-4 flex-1">
                {/* Account section */}
                <div className="pb-4 border-b border-[#333333]">
                  {menuItems.map((item) => {
                    const Icon = item.icon
                    return (
                      <Link
                        key={item.to}
                        to={item.to}
                        onClick={onClose}
                        className={cn(
                          'flex items-center gap-3 p-3 rounded-lg transition-colors text-sm sm:text-base',
                          'hover:bg-[#333333]'
                        )}
                      >
                        <Icon className="w-5 h-5 text-[#FFD700] flex-shrink-0" />
                        <span className="truncate">{item.label}</span>
                      </Link>
                    )
                  })}
                </div>

                {/* Logout */}
                <div className="pt-4">
                  <button
                    onClick={handleLogout}
                    className={cn(
                      'w-full flex items-center gap-3 p-3 rounded-lg transition-colors text-sm sm:text-base',
                      'text-red-400 hover:bg-[#333333]'
                    )}
                  >
                    <LogOut className="w-5 h-5 flex-shrink-0" />
                    <span>{t('buttons.log_out')}</span>
                  </button>
                </div>
              </div>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  )
}
