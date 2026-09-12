import { useQuery } from '@tanstack/react-query'
import { Bell } from 'lucide-react'
import notificationApi from '@/services/notificationApi'

interface NotificationBellProps {
  onClick?: () => void
}

export function NotificationBell({ onClick }: NotificationBellProps) {
  const { data } = useQuery({
    queryKey: ['notifications-unread'],
    queryFn: () => notificationApi.getUnreadCount(),
    staleTime: 1000 * 30,
    refetchInterval: 30000,
  })

  const unreadCount = data?.data?.count || 0

  return (
    <button
      onClick={onClick}
      className="relative p-2 text-gray-400 hover:text-white transition-colors"
      aria-label={`Notifications${unreadCount > 0 ? `, ${unreadCount} unread` : ''}`}
    >
      <Bell className="w-5 h-5" />
      {unreadCount > 0 && (
        <span className="absolute -top-1 -right-1 w-5 h-5 bg-red-500 text-white text-xs rounded-full flex items-center justify-center font-bold">
          {unreadCount > 99 ? '99+' : unreadCount}
        </span>
      )}
    </button>
  )
}
