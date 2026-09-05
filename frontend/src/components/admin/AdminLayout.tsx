import { useState } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { Button } from '@/components/ui/Button';
import { Avatar } from '@/components/ui/Avatar';
import { api } from '@/services/api';

interface AdminLayoutProps {
  children: React.ReactNode;
}

function AdminLayout({ children }: AdminLayoutProps) {
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const location = useLocation();
  const navigate = useNavigate();

  const handleLogout = async () => {
    try {
      await api.post('/auth/logout');
      localStorage.removeItem('token');
      navigate('/login');
    } catch (error) {
      console.error('Logout failed:', error);
      navigate('/login');
    }
  };

  const menuItems = [
    { path: '/admin', label: 'Overview', icon: '\uD83D\uDCCA' },
    { path: '/admin/users', label: 'Users', icon: '\uD83D\uDC65' },
    { path: '/admin/punishments', label: 'Punishments', icon: '\u2696\uFE0F' },
    { path: '/admin/appeals', label: 'Appeals', icon: '\uD83D\uDCDD' },
    { path: '/admin/stats', label: 'Statistics', icon: '\uD83D\uDCC8' },
  ];

  return (
    <div className="flex h-screen bg-base-200">
      {/* Sidebar */}
      <motion.aside
        initial={false}
        animate={{ width: sidebarOpen ? 256 : 64 }}
        transition={{ type: 'tween', duration: 0.2 }}
        className="flex flex-col border-r border-base-300 bg-base-100"
      >
        {/* Logo */}
        <div className="flex h-16 items-center justify-center border-b border-base-300">
          <h1 className="text-xl font-bold text-primary">Admin Panel</h1>
        </div>

        {/* Menu */}
        <nav className="flex-1 space-y-1 p-4">
          {menuItems.map((item) => {
            const isActive = location.pathname === item.path;
            return (
              <Link
                key={item.path}
                to={item.path}
                className={`flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors ${
                  isActive
                    ? 'bg-primary/10 text-primary'
                    : 'text-neutral/70 hover:bg-base-200 hover:text-base-content'
                }`}
              >
                <span className="text-lg">{item.icon}</span>
                {sidebarOpen && <span>{item.label}</span>}
              </Link>
            );
          })}
        </nav>

        {/* User */}
        <div className="border-t border-base-300 p-4">
          <div className="flex items-center gap-3">
            <Avatar fallback="A" size="sm" />
            {sidebarOpen && (
              <div className="flex-1">
                <p className="text-sm font-medium text-base-content">Admin</p>
                <p className="text-xs text-neutral/60">admin@pascalixs.ru</p>
              </div>
            )}
          </div>
          <Button variant="ghost" size="sm" className="mt-2 w-full" onClick={handleLogout}>
            Logout
          </Button>
        </div>
      </motion.aside>

      {/* Main Content */}
      <div className="flex flex-1 flex-col">
        {/* Header */}
        <header className="flex h-16 items-center justify-between border-b border-base-300 bg-base-100 px-6">
          <Button variant="ghost" size="sm" onClick={() => setSidebarOpen(!sidebarOpen)}>
            {sidebarOpen ? '\u25C0' : '\u25B6'}
          </Button>
          <div className="flex items-center gap-4">
            <Button variant="outline" size="sm" asChild>
              <Link to="/">Back to Site</Link>
            </Button>
          </div>
        </header>

        {/* Content */}
        <main className="flex-1 overflow-auto p-6">{children}</main>
      </div>
    </div>
  );
}

export default AdminLayout;
