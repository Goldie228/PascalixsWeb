import { useQuery, useMutation } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'
import { Check, CheckCheck, AlertTriangle, AlertCircle, Info, CheckCircle2 } from 'lucide-react'
import notificationApi from '@/services/notificationApi'
import { Modal } from '@/components/ui/Modal'
import { Button } from '@/components/ui/Button'
import type { Notification } from '@/types'
import { cn } from '@/lib/utils'

interface NotificationPanelProps {
  isOpen: boolean
  onClose: () => void
}

const typeIcons = {
  info: Info,
  warning: AlertTriangle,
  error: AlertCircle,
  success: CheckCircle2,
} as const

const typeColors = {
  info: 'text-blue-400',
  warning: 'text-amber-400',
  error: 'text-red-400',
  success: 'text-green-400',
} as const

export function NotificationPanel({ isOpen, onClose }: NotificationPanelProps) {
  const { t } = useTranslation()
  const { data, isLoading } = useQuery({
    queryKey: ['notifications'],
    queryFn: () => notificationApi.getNotifications({ per_page: 20 }),
    staleTime: 1000 * 30,
    refetchInterval: 30000,
  })

  const markAsReadMutation = useMutation({
    mutationFn: (id: number) => notificationApi.markAsRead(id),
    onSuccess: () => {
      // Query will refetch automatically
    },
  })

  const markAllAsReadMutation = useMutation({
    mutationFn: () => notificationApi.markAllAsRead(),
    onSuccess: () => {
      // Query will refetch automatically
    },
  })

  const notifications = data?.data?.notifications || []
  const unreadCount = data?.data?.unread || 0

  const getRelativeTime = (dateStr: string): string => {
    const date = new Date(dateStr)
    const now = new Date()
    const diffMs = now.getTime() - date.getTime()
    const diffMins = Math.floor(diffMs / 60000)
    const diffHours = Math.floor(diffMins / 60)
    const diffDays = Math.floor(diffHours / 24)

    if (diffMins < 1) return t('common.just_now', { defaultValue: 'Just now' })
    if (diffMins < 60) return `${diffMins}m ago`
    if (diffHours < 24) return `${diffHours}h ago`
    if (diffDays < 7) return `${diffDays}d ago`
    return date.toLocaleDateString()
  }

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={t('notification.panel_title', { count: unreadCount })}
      size="lg"
    >
      <div className="space-y-2 max-h-[60vh] overflow-y-auto pr-1">
        {isLoading ? (
          <div className="text-center py-8 text-gray-400">{t('common.loading')}</div>
        ) : notifications.length === 0 ? (
          <div className="text-center py-8 text-gray-400">
            <p>{t('notification.no_notifications')}</p>
          </div>
        ) : (
          notifications.map((notification: Notification) => {
            const Icon = typeIcons[notification.type] || typeIcons.info
            const colorClass = typeColors[notification.type] || typeColors.info

            return (
              <div
                key={notification.id}
                className={cn(
                  'p-3 rounded-lg transition-colors border',
                  !notification.read
                    ? 'bg-[#2D2D2D] border-[#FFD700]/30'
                    : 'bg-[#1a1a1a] border-transparent'
                )}
              >
                <div className="flex items-start gap-3">
                  {/* Type icon */}
                  <Icon className={cn('w-5 h-5 flex-shrink-0 mt-0.5', colorClass)} />

                  {/* Content */}
                  <div className="flex-1 min-w-0">
                    <p className="text-white text-sm font-medium break-words">
                      {notification.message}
                    </p>
                    <p className="text-gray-500 text-xs mt-1">
                      {getRelativeTime(notification.createdAt)}
                    </p>
                  </div>

                  {/* Mark as read button */}
                  {!notification.read && (
                    <button
                      onClick={() => markAsReadMutation.mutate(notification.id)}
                      className="p-1.5 text-gray-400 hover:text-[#FFD700] transition-colors flex-shrink-0"
                      aria-label={t('notification.mark_read')}
                    >
                      <Check className="w-4 h-4" />
                    </button>
                  )}
                </div>
              </div>
            )
          })
        )}
      </div>

      {unreadCount > 0 && (
        <div className="mt-4 pt-4 border-t border-gray-700">
          <Button
            variant="outline"
            className="w-full"
            onClick={() => markAllAsReadMutation.mutate()}
            isLoading={markAllAsReadMutation.isPending}
          >
            <CheckCheck className="w-4 h-4 mr-2" />
            {t('notification.mark_all_read')}
          </Button>
        </div>
      )}
    </Modal>
  )
}
