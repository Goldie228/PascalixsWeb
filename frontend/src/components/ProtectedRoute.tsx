import { useAuthStore } from '@/store/auth'
import { useEffect } from 'react'
import { Navigate, useLocation } from 'react-router-dom'

interface ProtectedRouteProps {
  children: React.ReactNode
}

export default function ProtectedRoute({ children }: ProtectedRouteProps) {
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated)
  const fetchUser = useAuthStore((state) => state.fetchUser)
  const location = useLocation()

  useEffect(() => {
    if (!isAuthenticated) {
      fetchUser()
    }
  }, [isAuthenticated, fetchUser])

  if (!isAuthenticated) {
    return <Navigate to="/login" state={{ from: location }} replace />
  }

  return <>{children}</>
}
