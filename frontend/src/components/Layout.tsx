import { Outlet, Link, useNavigate } from 'react-router-dom'
import { useAuthStore } from '@/store/auth'

export default function Layout() {
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated)
  const logout = useAuthStore((state) => state.logout)
  const navigate = useNavigate()

  const handleLogout = async () => {
    await logout()
    navigate('/')
  }

  return (
    <div className="min-h-screen bg-base-100">
      <nav className="navbar bg-base-200 px-4">
        <div className="flex-1">
          <Link to="/" className="btn btn-ghost text-xl">
            Pascalixs
          </Link>
        </div>
        <div className="flex-none gap-2">
          {isAuthenticated ? (
            <>
              <Link to="/dashboard" className="btn btn-ghost">
                Dashboard
              </Link>
              <Link to="/profile" className="btn btn-ghost">
                Profile
              </Link>
              <button className="btn btn-error btn-sm" onClick={handleLogout}>
                Logout
              </button>
            </>
          ) : (
            <>
              <Link to="/login" className="btn btn-ghost">
                Login
              </Link>
              <Link to="/register" className="btn btn-primary btn-sm">
                Register
              </Link>
            </>
          )}
        </div>
      </nav>
      <main className="container mx-auto px-4 py-8">
        <Outlet />
      </main>
    </div>
  )
}
