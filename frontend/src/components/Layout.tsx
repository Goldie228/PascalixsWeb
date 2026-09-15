import { Outlet, Link, useNavigate, useLocation } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { useAuthStore } from '@/store/auth'
import { NotificationBell } from '@/components/NotificationBell'
import { NotificationPanel } from '@/components/NotificationPanel'
import { LanguageSwitcher } from '@/components/LanguageSwitcher'
import { AccountDrawer } from '@/components/AccountDrawer'
import { CookieToast } from '@/components/CookieToast'
import { Footer } from '@/components/ui/Footer'
import { GlobalLoading } from '@/components/GlobalLoading'
import { Avatar } from '@/components/ui/Avatar'
import { useState, useEffect, useCallback } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { cn } from '@/lib/utils'
import {
  Home,
  LayoutDashboard,
  Users,
  Image,
  ShoppingCart,
  Heart,
  HeartHandshake,
  User,
  Settings,
  Wallet,
  Mail,
  Shield,
} from 'lucide-react'
import { useQuery } from '@tanstack/react-query'
import api from '@/services/api'

// Server stats query key
const serverStatsKey = ['server-stats']

interface MenuItem {
  to: string
  label: string
  icon: React.ComponentType<{ className?: string }>
}

export default function Layout() {
  const { t } = useTranslation()
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated)
  const user = useAuthStore((state) => state.user)
  const logout = useAuthStore((state) => state.logout)
  const isLoading = useAuthStore((state) => state.isLoading)
  const navigate = useNavigate()
  const location = useLocation()

  const isAdmin = user?.role === 'admin' || user?.role === 'DEV' || user?.role === 'OWNER'

  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)
  const [accountDrawerOpen, setAccountDrawerOpen] = useState(false)
  const [notificationOpen, setNotificationOpen] = useState(false)
  const [scrolled, setScrolled] = useState(false)

  // Fetch server stats for online players count
  const { data: serverStats } = useQuery({
    queryKey: serverStatsKey,
    queryFn: () => api.get('/servers/stats'),
    staleTime: 10000,
    refetchInterval: 15000,
    retry: 1,
  })

  const onlinePlayers = serverStats?.data?.onlinePlayers ?? 0

  // Handle scroll for sticky navbar styling
  useEffect(() => {
    const handleScroll = () => {
      setScrolled(window.scrollY > 10)
    }
    window.addEventListener('scroll', handleScroll, { passive: true })
    return () => window.removeEventListener('scroll', handleScroll)
  }, [])

  // Close mobile menu on route change
  useEffect(() => {
    setMobileMenuOpen(false)
  }, [location.pathname])

  const handleLogout = useCallback(async () => {
    await logout()
    navigate('/')
  }, [logout, navigate])

  // Main navigation links
  const navLinks: MenuItem[] = [
    { to: '/', label: t('nav.home'), icon: Home },
    { to: '/dashboard', label: t('nav.dashboard'), icon: LayoutDashboard },
    { to: '/players', label: t('nav.players'), icon: Users },
    { to: '/gallery', label: t('nav.gallery'), icon: Image },
    { to: '/purchases', label: t('nav.purchases'), icon: ShoppingCart },
    { to: '/sponsors', label: t('nav.sponsors'), icon: HeartHandshake },
    { to: '/donate', label: t('nav.donate'), icon: Heart },
  ]

  // Authenticated navigation links
  const authLinks: MenuItem[] = [
    { to: '/profile', label: t('nav.profile'), icon: User },
    { to: '/settings', label: t('nav.settings'), icon: Settings },
    { to: '/account', label: t('nav.account'), icon: Settings },
    { to: '/my_donates', label: t('nav.my_donates'), icon: Wallet },
    { to: '/email_login', label: t('nav.email_login'), icon: Mail },
  ]

  const isActive = (path: string) => location.pathname === path

  return (
    <div className="min-h-screen flex flex-col bg-[#0A0A0A]">
      <GlobalLoading isLoading={isLoading} message={t('common.loading')} />

      {/* ========== NAVBAR ========== */}
      <nav
        className={cn(
          'sticky top-0 left-0 w-full z-50 px-4 md:px-8 py-3 md:py-4 transition-all duration-300',
          scrolled
            ? 'bg-[#0A0A0A]/95 backdrop-blur-sm shadow-lg'
            : 'bg-[#0A0A0A] shadow-lg'
        )}
      >
        <div className="flex items-center justify-between gap-4">
          {/* ===== LEFT: Logo + Nav Links ===== */}
          <div className="flex items-center gap-2 md:gap-4 flex-1 min-w-0">
            {/* Mobile hamburger */}
            <button
              className="2xl:hidden btn !border-0 bg-transparent hover:bg-[#1a1a1a] text-white text-lg p-2"
              onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
              aria-label={t('layout.toggle_menu')}
            >
              <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
              </svg>
            </button>

            {/* Logo */}
            <Link to="/" className="flex items-center ml-2 md:ml-4 flex-shrink-0">
              {/* Logo image */}
              <div className="h-12 w-12 md:h-16 md:w-16">
                <img
                  src="/logo.png"
                  alt="Pascalixs"
                  className="h-full w-full object-contain"
                  onError={(e) => {
                    // Fallback if logo doesn't exist
                    const target = e.target as HTMLImageElement
                    target.style.display = 'none'
                  }}
                />
              </div>

              {/* Server name */}
              <div className="flex flex-col items-center ml-2 md:ml-4 relative">
                <span className="font-bold text-lg sm:text-xl md:text-3xl lg:text-4xl whitespace-nowrap text-[#FFD700]">
                  Pascalixs
                </span>
                <span className="text-[6px] sm:text-xs md:text-sm whitespace-nowrap text-[#F5DEB3]">
                  {t('home.subtitle')}
                </span>
              </div>
            </Link>

            {/* Server status indicator (inline, small) */}
            {onlinePlayers > 0 && (
              <div className="hidden lg:flex items-center gap-1.5 text-xs text-gray-400 ml-2 flex-shrink-0">
                <span className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
                <span>{onlinePlayers} {t('navbar.online_players')}</span>
              </div>
            )}

            {/* Admin link */}
            {isAuthenticated && isAdmin && (
              <Link
                to="/admin"
                className="text-[#FFD700] font-bold text-sm sm:text-base md:text-lg lg:text-xl ml-2 hover:underline transition-colors whitespace-nowrap flex-shrink-0"
              >
                ADMIN
              </Link>
            )}

            {/* Desktop nav links */}
            <div className="hidden 2xl:flex flex-1 items-center gap-1 ml-4 min-w-0">
              {navLinks.map((link) => {
                const Icon = link.icon
                const active = isActive(link.to)
                return (
                  <Link
                    key={link.to}
                    to={link.to}
                    className={cn(
                      'flex items-center gap-1.5 px-3 py-2 rounded-md transition-colors duration-200 text-base whitespace-nowrap',
                      active
                        ? 'text-[#FFD700]'
                        : 'text-[#A0A0A0] hover:text-[#FFD700]'
                    )}
                  >
                    <Icon className="w-4 h-4" />
                    <span>{link.label}</span>
                  </Link>
                )
              })}

              {/* Auth links (authenticated only) */}
              {isAuthenticated && (
                <>
                  <div className="w-px h-6 bg-gray-700 mx-1" />
                  {authLinks.map((link) => {
                    const Icon = link.icon
                    const active = isActive(link.to)
                    return (
                      <Link
                        key={link.to}
                        to={link.to}
                        className={cn(
                          'flex items-center gap-1.5 px-3 py-2 rounded-md transition-colors duration-200 text-base whitespace-nowrap',
                          active
                            ? 'text-[#FFD700]'
                            : 'text-[#A0A0A0] hover:text-[#FFD700]'
                        )}
                      >
                        <Icon className="w-4 h-4" />
                        <span>{link.label}</span>
                      </Link>
                    )
                  })}
                  {isAdmin && (
                    <Link
                      to="/admin"
                      className="flex items-center gap-1.5 px-3 py-2 rounded-md transition-colors duration-200 text-[#FFD700] hover:text-[#FFC400] whitespace-nowrap"
                    >
                      <Shield className="w-4 h-4" />
                      <span>{t('nav.admin')}</span>
                    </Link>
                  )}
                </>
              )}
            </div>
          </div>

          {/* ===== RIGHT: Notification + Language + Auth ===== */}
          <div className="flex justify-end items-center gap-2 md:gap-4 ml-auto flex-shrink-0">
            {/* Notification bell */}
            {isAuthenticated && (
              <NotificationBell onClick={() => setNotificationOpen(true)} />
            )}

            {/* Language switcher */}
            <LanguageSwitcher />

            {/* Auth section */}
            {isAuthenticated ? (
              <>
                {/* Avatar trigger for account drawer */}
                <button
                  className="cursor-pointer rounded-full transition-transform hover:scale-110 active:scale-95"
                  onClick={() => setAccountDrawerOpen(!accountDrawerOpen)}
                  aria-label={t('navbar.open_user_menu')}
                >
                  <Avatar
                    src={undefined}
                    fallback={user?.nickname || user?.username}
                    size="md"
                    className="w-10 h-10 md:w-14 md:h-14"
                  />
                </button>
              </>
            ) : (
              <Link to="/login">
                <button className="btn px-4 py-1 md:px-6 md:py-2 text-[#0A0A0A] bg-[#FFAA1D] hover:bg-[#FFC400] rounded-full font-bold text-sm md:text-base transition-colors">
                  {t('nav.login')}
                </button>
              </Link>
            )}
          </div>
        </div>

        {/* ===== MOBILE MENU ===== */}
        <AnimatePresence>
          {mobileMenuOpen && (
            <motion.div
              initial={{ height: 0, opacity: 0 }}
              animate={{ height: 'auto', opacity: 1 }}
              exit={{ height: 0, opacity: 0 }}
              transition={{ duration: 0.2 }}
              className="2xl:hidden overflow-hidden"
            >
              <div className="py-4 border-t border-gray-800 mt-2">
                <div className="flex flex-col gap-1 max-h-[60vh] overflow-y-auto">
                  {/* Main nav links */}
                  {navLinks.map((link) => {
                    const Icon = link.icon
                    return (
                      <Link
                        key={link.to}
                        to={link.to}
                        onClick={() => setMobileMenuOpen(false)}
                        className={cn(
                          'flex items-center gap-3 px-4 py-3 rounded-lg transition-colors text-base',
                          isActive(link.to)
                            ? 'text-[#FFD700] bg-[#1a1a1a]'
                            : 'text-[#A0A0A0] hover:bg-[#333333]'
                        )}
                      >
                        <Icon className="w-5 h-5" />
                        <span>{link.label}</span>
                      </Link>
                    )
                  })}

                  {/* Auth links */}
                  {isAuthenticated && (
                    <>
                      <div className="h-px bg-gray-800 my-2" />
                      {authLinks.map((link) => {
                        const Icon = link.icon
                        return (
                          <Link
                            key={link.to}
                            to={link.to}
                            onClick={() => setMobileMenuOpen(false)}
                            className={cn(
                              'flex items-center gap-3 px-4 py-3 rounded-lg transition-colors text-base',
                              isActive(link.to)
                                ? 'text-[#FFD700] bg-[#1a1a1a]'
                                : 'text-[#A0A0A0] hover:bg-[#333333]'
                            )}
                          >
                            <Icon className="w-5 h-5" />
                            <span>{link.label}</span>
                          </Link>
                        )
                      })}
                      {isAdmin && (
                        <Link
                          to="/admin"
                          onClick={() => setMobileMenuOpen(false)}
                          className="flex items-center gap-3 px-4 py-3 rounded-lg transition-colors text-[#FFD700] hover:bg-[#333333]"
                        >
                          <Shield className="w-5 h-5" />
                          <span>{t('nav.admin')}</span>
                        </Link>
                      )}
                      <div className="h-px bg-gray-800 my-2" />
                      <button
                        onClick={() => { handleLogout(); setMobileMenuOpen(false) }}
                        className="flex items-center gap-3 px-4 py-3 rounded-lg transition-colors text-base text-red-400 hover:bg-[#333333]"
                      >
                        <svg xmlns="http://www.w3.org/2000/svg" className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
                        </svg>
                        <span>{t('nav.logout')}</span>
                      </button>
                    </>
                  )}

                  {/* Guest links */}
                  {!isAuthenticated && (
                    <>
                      <div className="h-px bg-gray-800 my-2" />
                      <Link
                        to="/login"
                        onClick={() => setMobileMenuOpen(false)}
                        className="flex items-center gap-3 px-4 py-3 rounded-lg transition-colors text-base text-[#A0A0A0] hover:bg-[#333333]"
                      >
                        <span>{t('nav.login')}</span>
                      </Link>
                      <Link
                        to="/register"
                        onClick={() => setMobileMenuOpen(false)}
                        className="flex items-center gap-3 px-4 py-3 rounded-lg transition-colors text-base text-[#A0A0A0] hover:bg-[#333333]"
                      >
                        <span>{t('nav.register')}</span>
                      </Link>
                    </>
                  )}
                </div>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </nav>

      {/* ===== ACCOUNT DRAWER ===== */}
      <AccountDrawer
        isOpen={accountDrawerOpen}
        onClose={() => setAccountDrawerOpen(false)}
      />

      {/* ===== NOTIFICATION PANEL ===== */}
      <NotificationPanel
        isOpen={notificationOpen}
        onClose={() => setNotificationOpen(false)}
      />

      {/* ===== COOKIE TOAST ===== */}
      <CookieToast />

      {/* ===== MAIN CONTENT ===== */}
      <main className="flex-1">
        <Outlet />
      </main>

      {/* ===== FOOTER ===== */}
      <Footer />
    </div>
  )
}
