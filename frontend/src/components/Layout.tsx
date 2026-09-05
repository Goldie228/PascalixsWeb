import { Outlet, Link, useNavigate } from 'react-router-dom';
import { useAuthStore } from '@/store/auth';
import { Button } from '@/components/ui/Button';
import { Avatar } from '@/components/ui/Avatar';

export default function Layout() {
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);
  const user = useAuthStore((state) => state.user);
  const logout = useAuthStore((state) => state.logout);
  const navigate = useNavigate();

  const handleLogout = async () => {
    await logout();
    navigate('/');
  };

  return (
    <div className="min-h-screen bg-base-100">
      <nav className="border-b border-neutral/10 bg-base-200/80 px-4 backdrop-blur-sm">
        <div className="container mx-auto flex h-16 items-center justify-between">
          <div className="flex items-center gap-6">
            <Link to="/" className="text-xl font-bold text-primary hover:text-primary/80 transition-colors">
              Pascalixs
            </Link>
            {isAuthenticated && (
              <div className="hidden gap-2 sm:flex">
                <Button variant="ghost" size="sm" onClick={() => navigate('/dashboard')}>
                  Dashboard
                </Button>
                <Button variant="ghost" size="sm" onClick={() => navigate('/profile')}>
                  Profile
                </Button>
                <Button variant="ghost" size="sm" onClick={() => navigate('/settings')}>
                  Settings
                </Button>
              </div>
            )}
          </div>
          <div className="flex items-center gap-2">
            {isAuthenticated ? (
              <>
                <Avatar
                  src={undefined}
                  fallback={user?.username}
                  size="sm"
                />
                <Button variant="destructive" size="sm" onClick={handleLogout}>
                  Logout
                </Button>
              </>
            )             : (
              <>
                <Button variant="ghost" size="sm" onClick={() => navigate('/login')}>
                  Login
                </Button>
                <Button size="sm" onClick={() => navigate('/register')}>
                  Register
                </Button>
              </>
            )}
          </div>
        </div>
      </nav>
      <main className="container mx-auto px-4 py-8">
        <Outlet />
      </main>
    </div>
  );
}
