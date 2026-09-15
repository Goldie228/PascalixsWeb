import { useQuery } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'
import { Bell } from 'lucide-react'
import notificationApi from '@/services/notificationApi'

interface NotificationBellProps {
  onClick?: () => void
}

export function NotificationBell({ onClick }: NotificationBellProps) {
  const { t } = useTranslation()
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
      className="relative p-2 md:p-3 text-[#FFD700] hover:text-[#FFAA00] transition-colors duration-200 active:scale-95"
      aria-label={t('notification.bell_label', { count: unreadCount })}
    >
      <Bell className="w-8 h-8 md:w-10 md:h-10" />
      {unreadCount > 0 && (
        <span className="absolute -top-0.5 -right-0.5 w-5 h-5 bg-red-500 text-white text-xs rounded-full flex items-center justify-center font-bold border-2 border-[#0A0A0A]">
          {unreadCount > 99 ? '99+' : unreadCount}
        </span>
      )}
    </button>
  )
}
