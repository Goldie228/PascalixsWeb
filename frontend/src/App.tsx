import { Routes, Route } from 'react-router-dom'
import { ErrorBoundary } from '@/components/ErrorBoundary'
import Layout from '@/components/Layout'
import Home from '@/pages/Home'
import Login from '@/pages/Login'
import Register from '@/pages/Register'
import Dashboard from '@/pages/Dashboard'
import Profile from '@/pages/Profile'
import Settings from '@/pages/Settings'
import NotFound from '@/pages/NotFound'
import AdminOverview from '@/pages/admin/Overview'
import AdminUsers from '@/pages/admin/Users'
import AdminPunishments from '@/pages/admin/Punishments'
import AdminAppeals from '@/pages/admin/Appeals'
import AdminStats from '@/pages/admin/Stats'
import Gallery from '@/pages/Gallery'
import Purchases from '@/pages/Purchases'
import Donate from '@/pages/Donate'
import TwoFactorVerify from '@/pages/TwoFactorVerify'
import Account from '@/pages/Account'
import ChangeEmail from '@/pages/ChangeEmail'
import ResetPassword from '@/pages/ResetPassword'

function App() {
  return (
    <ErrorBoundary>
      <Routes>
        <Route path="/" element={<Layout />}>
          <Route index element={<Home />} />
          <Route path="login" element={<Login />} />
          <Route path="register" element={<Register />} />
          <Route path="dashboard" element={<Dashboard />} />
          <Route path="profile" element={<Profile />} />
          <Route path="settings" element={<Settings />} />
          <Route path="gallery" element={<Gallery />} />
          <Route path="purchases" element={<Purchases />} />
          <Route path="donate" element={<Donate />} />
          <Route path="account" element={<Account />} />
          <Route path="account/change-email" element={<ChangeEmail />} />
          <Route path="account/reset-password" element={<ResetPassword />} />
          <Route path="account/2fa/:step" element={<TwoFactorVerify />} />
        </Route>

        {/* Admin routes */}
        <Route path="/admin" element={<AdminOverview />} />
        <Route path="/admin/users" element={<AdminUsers />} />
        <Route path="/admin/punishments" element={<AdminPunishments />} />
        <Route path="/admin/appeals" element={<AdminAppeals />} />
        <Route path="/admin/stats" element={<AdminStats />} />

        <Route path="*" element={<NotFound />} />
      </Routes>
    </ErrorBoundary>
  )
}

export default App
