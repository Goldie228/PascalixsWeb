import { Outlet, Link, useNavigate } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { useAuthStore } from '@/store/auth'
import { Button } from '@/components/ui/Button'
import { Avatar } from '@/components/ui/Avatar'
import { NotificationBell } from '@/components/NotificationBell'
import { LanguageSwitcher } from '@/components/LanguageSwitcher'
import { GlobalLoading } from '@/components/GlobalLoading'
import { useState } from 'react'

export default function Layout() {
  const { t } = useTranslation()
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated)
  const user = useAuthStore((state) => state.user)
  const logout = useAuthStore((state) => state.logout)
  const isLoading = useAuthStore((state) => state.isLoading)
  const navigate = useNavigate()

  const isAdmin = user?.role === 'admin'

  const handleLogout = async () => {
    await logout()
    navigate('/')
  }

  const navLinks = [
    { to: '/', label: t('nav.home') },
    { to: '/dashboard', label: t('nav.dashboard') },
    { to: '/gallery', label: t('nav.gallery') },
    { to: '/purchases', label: t('nav.purchases') },
    { to: '/donate', label: t('nav.donate') },
  ]

  const authLinks = [
    { to: '/profile', label: t('nav.profile') },
    { to: '/settings', label: t('nav.settings') },
  ]

  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)

  return (
    <div className="min-h-screen bg-base-100">
      <GlobalLoading isLoading={isLoading} message={t('common.loading')} />

      <nav className="border-b border-neutral/10 bg-base-200/80 px-4 backdrop-blur-sm">
        <div className="container mx-auto flex h-16 items-center justify-between">
          {/* Logo and primary nav */}
          <div className="flex items-center gap-4">
            <Link to="/" className="text-xl font-bold text-primary hover:text-primary/80 transition-colors">
              Pascalixs
            </Link>

            {/* Desktop nav links */}
            <div className="hidden gap-1 lg:flex">
              {navLinks.map((link) => (
                <Link key={link.to} to={link.to}>
                  <Button variant="ghost" size="sm">
                    {link.label}
                  </Button>
                </Link>
              ))}
            </div>

            {/* Auth links (authenticated only) */}
            {isAuthenticated && (
              <div className="hidden gap-1 sm:flex">
                {authLinks.map((link) => (
                  <Link key={link.to} to={link.to}>
                    <Button variant="ghost" size="sm">
                      {link.label}
                    </Button>
                  </Link>
                ))}
                {isAdmin && (
                  <Link to="/admin">
                    <Button variant="ghost" size="sm" className="text-warning">
                      {t('nav.admin')}
                    </Button>
                  </Link>
                )}
              </div>
            )}
          </div>

          {/* Right side: notifications + auth */}
          <div className="flex items-center gap-2">
            {isAuthenticated && (
              <NotificationBell />
            )}

            <LanguageSwitcher />

            {/* Mobile menu button */}
            <button
              className="lg:hidden p-2 text-gray-400 hover:text-white transition-colors"
              onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
              aria-label={t('nav.toggle_menu')}
            >
              <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d={mobileMenuOpen ? "M6 18L18 6M6 6l12 12" : "M4 6h16M4 12h16M4 18h16"} />
              </svg>
            </button>

            {/* Desktop auth buttons */}
            <div className="hidden lg:flex items-center gap-2">
              {isAuthenticated ? (
                <>
                  <Avatar
                    src={undefined}
                    fallback={user?.username}
                    size="sm"
                  />
                  <Button variant="destructive" size="sm" onClick={handleLogout}>
                    {t('nav.logout')}
                  </Button>
                </>
              ) : (
                <>
                  <Button variant="ghost" size="sm" onClick={() => navigate('/login')}>
                    {t('nav.login')}
                  </Button>
                  <Button size="sm" onClick={() => navigate('/register')}>
                    {t('nav.register')}
                  </Button>
                </>
              )}
            </div>
          </div>
        </div>

        {/* Mobile menu */}
        {mobileMenuOpen && (
          <div className="border-t border-neutral/10 py-4 lg:hidden">
            <div className="flex flex-col gap-2">
              {navLinks.map((link) => (
                <Link
                  key={link.to}
                  to={link.to}
                  onClick={() => setMobileMenuOpen(false)}
                >
                  <Button variant="ghost" size="sm" className="w-full justify-start">
                    {link.label}
                  </Button>
                </Link>
              ))}
              {isAuthenticated && (
                <>
                  {authLinks.map((link) => (
                    <Link
                      key={link.to}
                      to={link.to}
                      onClick={() => setMobileMenuOpen(false)}
                    >
                      <Button variant="ghost" size="sm" className="w-full justify-start">
                        {link.label}
                      </Button>
                    </Link>
                  ))}
                  {isAdmin && (
                    <Link
                      to="/admin"
                      onClick={() => setMobileMenuOpen(false)}
                    >
                      <Button variant="ghost" size="sm" className="w-full justify-start text-warning">
                        {t('nav.admin')}
                      </Button>
                    </Link>
                  )}
                </>
              )}
              {isAuthenticated ? (
                <Button variant="destructive" size="sm" className="w-full justify-start" onClick={handleLogout}>
                  {t('nav.logout')}
                </Button>
              ) : (
                <>
                  <Button variant="ghost" size="sm" className="w-full justify-start" onClick={() => { navigate('/login'); setMobileMenuOpen(false); }}>
                    {t('nav.login')}
                  </Button>
                  <Button size="sm" className="w-full justify-start" onClick={() => { navigate('/register'); setMobileMenuOpen(false); }}>
                    {t('nav.register')}
                  </Button>
                </>
              )}
            </div>
          </div>
        )}
      </nav>

      <main className="container mx-auto px-4 py-8">
        <Outlet />
      </main>
    </div>
  )
}
