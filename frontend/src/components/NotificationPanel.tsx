import { useQuery, useMutation } from '@tanstack/react-query'
import { Check, CheckCheck } from 'lucide-react'
import notificationApi from '@/services/notificationApi'
import { Modal } from '@/components/ui/Modal'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import type { Notification } from '@/types'

interface NotificationPanelProps {
  isOpen: boolean
  onClose: () => void
}

interface ApiNotification extends Omit<Notification, 'title'> {
  title?: string
}

export function NotificationPanel({ isOpen, onClose }: NotificationPanelProps) {
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

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={
        <div className="flex items-center justify-between w-full">
          <span>Notifications</span>
          <span className="text-sm text-gray-400">{unreadCount} unread</span>
        </div>
      }
      size="lg"
    >
      <div className="space-y-2 max-h-[60vh] overflow-y-auto">
        {isLoading ? (
          <div className="text-center py-8 text-gray-400">Loading...</div>
        ) : notifications.length === 0 ? (
          <div className="text-center py-8 text-gray-400">
            <p>No notifications</p>
          </div>
        ) : (
          notifications.map((notification: ApiNotification) => (
            <div
              key={notification.id}
              className={`p-3 rounded-lg transition-colors ${
                !notification.read ? 'bg-gray-700/50 border border-gray-600' : 'bg-gray-800/30'
              }`}
            >
              <div className="flex items-start justify-between">
                <div className="flex-1">
                  <p className="text-white text-sm">{notification.title}</p>
                  <p className="text-gray-400 text-xs mt-1">{notification.message}</p>
                  <p className="text-gray-500 text-xs mt-1">
                    {new Date(notification.createdAt).toLocaleString()}
                  </p>
                </div>
                {!notification.read && (
                  <button
                    onClick={() => markAsReadMutation.mutate(notification.id)}
                    className="p-1 text-gray-400 hover:text-white transition-colors"
                    aria-label="Mark as read"
                  >
                    <Check className="w-4 h-4" />
                  </button>
                )}
              </div>
            </div>
          ))
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
            Mark all as read
          </Button>
        </div>
      )}
    </Modal>
  )
}
