import { Suspense, lazy, type ReactNode } from 'react'
import { Routes, Route } from 'react-router-dom'
import { ErrorBoundary } from '@/components/ErrorBoundary'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import Layout from '@/components/Layout'

// Lazy-loaded pages for code splitting
const Home = lazy(() => import('@/pages/Home'))
const Login = lazy(() => import('@/pages/Login'))
const Register = lazy(() => import('@/pages/Register'))
const Dashboard = lazy(() => import('@/pages/Dashboard'))
const Profile = lazy(() => import('@/pages/Profile'))
const Settings = lazy(() => import('@/pages/Settings'))
const Gallery = lazy(() => import('@/pages/Gallery'))
const Purchases = lazy(() => import('@/pages/Purchases'))
const Donate = lazy(() => import('@/pages/Donate'))
const TwoFactorVerify = lazy(() => import('@/pages/TwoFactorVerify'))
const Account = lazy(() => import('@/pages/Account'))
const ChangeEmail = lazy(() => import('@/pages/ChangeEmail'))
const ResetPassword = lazy(() => import('@/pages/ResetPassword'))
const NotFound = lazy(() => import('@/pages/NotFound'))

// New pages for web-portal parity
const Players = lazy(() => import('@/pages/Players'))
const Sponsors = lazy(() => import('@/pages/Sponsors'))
const MyDonates = lazy(() => import('@/pages/MyDonates'))
const EmailLogin = lazy(() => import('@/pages/EmailLogin'))
const PendingEmailLogin = lazy(() => import('@/pages/PendingEmailLogin'))
const PendingEmailVerification = lazy(() => import('@/pages/PendingEmailVerification'))
const PendingPasswordReset = lazy(() => import('@/pages/PendingPasswordReset'))
const Goodbye = lazy(() => import('@/pages/Goodbye'))
const MinecraftRegistration = lazy(() => import('@/pages/MinecraftRegistration'))
const PublicProfile = lazy(() => import('@/pages/PublicProfile'))
const ConfirmEmail = lazy(() => import('@/pages/ConfirmEmail'))

// Lazy-loaded admin pages
const AdminOverview = lazy(() => import('@/pages/admin/Overview'))
const AdminUsers = lazy(() => import('@/pages/admin/Users'))
const AdminPunishments = lazy(() => import('@/pages/admin/Punishments'))
const AdminAppeals = lazy(() => import('@/pages/admin/Appeals'))
const AdminStats = lazy(() => import('@/pages/admin/Stats'))
const AdminAvatars = lazy(() => import('@/pages/admin/AdminAvatars'))
const AdminComplaints = lazy(() => import('@/pages/admin/AdminComplaints'))
const AdminProducts = lazy(() => import('@/pages/admin/AdminProducts'))
const AdminPunishmentReasons = lazy(() => import('@/pages/admin/AdminPunishmentReasons'))
const AdminPurchases = lazy(() => import('@/pages/admin/AdminPurchases'))
const AdminRemovedPlayers = lazy(() => import('@/pages/admin/AdminRemovedPlayers'))
const AdminGallery = lazy(() => import('@/pages/admin/AdminGallery'))
const AdminPlayers = lazy(() => import('@/pages/admin/AdminPlayers'))

// Shared Suspense fallback
function PageLoader({ children }: { children: ReactNode }) {
  return (
    <Suspense
      fallback={
        <div className="flex items-center justify-center min-h-[60vh]">
          <LoadingSpinner size="lg" />
        </div>
      }
    >
      {children}
    </Suspense>
  )
}

function App() {
  return (
    <ErrorBoundary>
      <Routes>
        <Route path="/" element={<Layout />}>
          <Route index element={<PageLoader><Home /></PageLoader>} />
          <Route path="login" element={<PageLoader><Login /></PageLoader>} />
          <Route path="register" element={<PageLoader><Register /></PageLoader>} />
          <Route path="dashboard" element={<PageLoader><Dashboard /></PageLoader>} />
          <Route path="profile" element={<PageLoader><Profile /></PageLoader>} />
          <Route path="settings" element={<PageLoader><Settings /></PageLoader>} />
          <Route path="gallery" element={<PageLoader><Gallery /></PageLoader>} />
          <Route path="purchases" element={<PageLoader><Purchases /></PageLoader>} />
          <Route path="donate" element={<PageLoader><Donate /></PageLoader>} />
          <Route path="account" element={<PageLoader><Account /></PageLoader>} />
          <Route path="account/change-email" element={<PageLoader><ChangeEmail /></PageLoader>} />
          <Route path="account/reset-password" element={<PageLoader><ResetPassword /></PageLoader>} />
          <Route path="account/2fa/:step" element={<PageLoader><TwoFactorVerify /></PageLoader>} />
          <Route path="account/change-email/pending-email-verification" element={<PageLoader><PendingEmailVerification /></PageLoader>} />
          <Route path="account/reset-password/pending-password-reset" element={<PageLoader><PendingPasswordReset /></PageLoader>} />
          <Route path="email_login" element={<PageLoader><EmailLogin /></PageLoader>} />
          <Route path="email_login/pending" element={<PageLoader><PendingEmailLogin /></PageLoader>} />
          <Route path="players" element={<PageLoader><Players /></PageLoader>} />
          <Route path="players/:nickname" element={<PageLoader><PublicProfile /></PageLoader>} />
          <Route path="sponsors" element={<PageLoader><Sponsors /></PageLoader>} />
          <Route path="my_donates" element={<PageLoader><MyDonates /></PageLoader>} />
          <Route path="auth/register_minecraft" element={<PageLoader><MinecraftRegistration /></PageLoader>} />
          <Route path="goodbye" element={<PageLoader><Goodbye /></PageLoader>} />
          <Route path="confirm-email/:token" element={<PageLoader><ConfirmEmail /></PageLoader>} />
        </Route>

        {/* Admin routes */}
        <Route path="/admin" element={<PageLoader><AdminOverview /></PageLoader>} />
        <Route path="/admin/users" element={<PageLoader><AdminUsers /></PageLoader>} />
        <Route path="/admin/punishments" element={<PageLoader><AdminPunishments /></PageLoader>} />
        <Route path="/admin/appeals" element={<PageLoader><AdminAppeals /></PageLoader>} />
        <Route path="/admin/stats" element={<PageLoader><AdminStats /></PageLoader>} />
        <Route path="/admin/avatars" element={<PageLoader><AdminAvatars /></PageLoader>} />
        <Route path="/admin/complaints" element={<PageLoader><AdminComplaints /></PageLoader>} />
        <Route path="/admin/products" element={<PageLoader><AdminProducts /></PageLoader>} />
        <Route path="/admin/punishment_reasons" element={<PageLoader><AdminPunishmentReasons /></PageLoader>} />
        <Route path="/admin/purchases" element={<PageLoader><AdminPurchases /></PageLoader>} />
        <Route path="/admin/removed_players" element={<PageLoader><AdminRemovedPlayers /></PageLoader>} />
        <Route path="/admin/gallery" element={<PageLoader><AdminGallery /></PageLoader>} />
        <Route path="/admin/players" element={<PageLoader><AdminPlayers /></PageLoader>} />

        <Route path="*" element={<PageLoader><NotFound /></PageLoader>} />
      </Routes>
    </ErrorBoundary>
  )
}

export default App
