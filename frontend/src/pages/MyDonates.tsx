import { useTranslation } from 'react-i18next'
import { useQuery } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { Badge } from '@/components/ui/Badge'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import { donatesApi, type Donation } from '@/services/donatesApi'
import { useAuthStore } from '@/store/auth'

function MyDonates() {
  const { t } = useTranslation()
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated)

  const { data, isLoading } = useQuery({
    queryKey: ['my-donates'],
    queryFn: async () => {
      const response = await donatesApi.list()
      return response.data
    },
    enabled: isAuthenticated,
    staleTime: 1000 * 60,
  })

  if (!isAuthenticated) {
    return (
      <div className="flex min-h-[60vh] items-center justify-center">
        <Card className="w-full max-w-md">
          <CardHeader>
            <CardTitle className="text-center text-xl">{t('profile.access_required')}</CardTitle>
          </CardHeader>
          <CardContent className="text-center">
            <p className="mb-4 text-neutral/70">{t('profile.please_login')}</p>
          </CardContent>
        </Card>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-base-100 py-8">
      <div className="container mx-auto max-w-4xl px-4">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
        >
          <div className="mb-6">
            <h1 className="text-3xl font-bold">{t('donates.title')}</h1>
            <p className="mt-1 text-neutral/70">{t('donates.subtitle')}</p>
          </div>

          <Card>
            <CardHeader>
              <CardTitle>{t('donates.title')}</CardTitle>
            </CardHeader>
            <CardContent>
              {isLoading ? (
                <div className="flex justify-center py-8">
                  <LoadingSpinner size="lg" />
                </div>
              ) : (
                <div className="space-y-2">
                  {data?.donates?.length === 0 ? (
                    <p className="text-neutral/60">{t('donates.no_donates')}</p>
                  ) : (
                    data?.donates?.map((donation: Donation) => (
                      <div
                        key={donation.id}
                        className="flex items-center justify-between rounded-lg bg-base-200 p-3"
                      >
                        <div>
                          <span className="font-medium text-base-content">
                            {donation.amount} {donation.currency}
                          </span>
                          <span className="ml-2 text-sm text-neutral/60">
                            {new Date(donation.created_at).toLocaleDateString()}
                          </span>
                        </div>
                        <Badge
                          variant={
                            donation.status === 'completed'
                              ? 'success'
                              : donation.status === 'pending'
                                ? 'warning'
                                : 'error'
                          }
                        >
                          {t(`donates.${donation.status}`) || donation.status}
                        </Badge>
                      </div>
                    ))
                  )}
                </div>
              )}
            </CardContent>
          </Card>
        </motion.div>
      </div>
    </div>
  )
}

export default MyDonates
