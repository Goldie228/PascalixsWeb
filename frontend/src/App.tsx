import { Routes, Route } from 'react-router-dom'
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

function App() {
  return (
    <Routes>
      <Route path="/" element={<Layout />}>
        <Route index element={<Home />} />
        <Route path="login" element={<Login />} />
        <Route path="register" element={<Register />} />
        <Route path="dashboard" element={<Dashboard />} />
        <Route path="profile" element={<Profile />} />
        <Route path="settings" element={<Settings />} />
      </Route>

      {/* Admin routes (standalone, no Layout wrapper) */}
      <Route path="/admin" element={<AdminOverview />} />
      <Route path="/admin/users" element={<AdminUsers />} />
      <Route path="/admin/punishments" element={<AdminPunishments />} />
      <Route path="/admin/appeals" element={<AdminAppeals />} />
      <Route path="/admin/stats" element={<AdminStats />} />

      <Route path="*" element={<NotFound />} />
    </Routes>
  )
}

export default App
