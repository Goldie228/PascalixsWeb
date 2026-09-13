import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useQuery } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { Badge } from '@/components/ui/Badge'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import { Input } from '@/components/ui/Input'
import { playersApi, type Player } from '@/services/playersApi'

function Players() {
  const { t } = useTranslation()
  const [search, setSearch] = useState('')
  const [debouncedSearch, setDebouncedSearch] = useState('')

  useState(() => {
    const timer = setTimeout(() => setDebouncedSearch(search), 300)
    return () => clearTimeout(timer)
  })

  const { data, isLoading } = useQuery({
    queryKey: ['players', debouncedSearch],
    queryFn: async () => {
      const response = await playersApi.list({ search: debouncedSearch || undefined })
      return response.data
    },
    staleTime: 1000 * 60,
  })

  return (
    <div className="min-h-screen bg-base-100 py-8">
      <div className="container mx-auto max-w-4xl px-4">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
        >
          <div className="mb-6">
            <h1 className="text-3xl font-bold">{t('players.title')}</h1>
            <p className="mt-1 text-neutral/70">{t('players.subtitle')}</p>
          </div>

          <Card>
            <CardContent className="pt-6">
              <Input
                placeholder={t('players.search_placeholder')}
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
            </CardContent>
          </Card>

          <Card className="mt-6">
            <CardHeader>
              <CardTitle>{t('players.title')}</CardTitle>
            </CardHeader>
            <CardContent>
              {isLoading ? (
                <div className="flex justify-center py-8">
                  <LoadingSpinner size="lg" />
                </div>
              ) : (
                <div className="space-y-2">
                  {data?.players?.length === 0 ? (
                    <p className="text-neutral/60">{t('players.no_players')}</p>
                  ) : (
                    data?.players?.map((player: Player) => (
                      <div
                        key={player.id}
                        className="flex items-center justify-between rounded-lg bg-base-200 p-3"
                      >
                        <div>
                          <span className="font-medium text-base-content">
                            {player.username}
                          </span>
                          <span className="ml-2 text-sm text-neutral/60">
                            ({player.email})
                          </span>
                        </div>
                        <div className="flex gap-2">
                          <Badge variant={player.role === 'admin' ? 'error' : player.role === 'moderator' ? 'warning' : 'info'}>
                            {player.role}
                          </Badge>
                          <Badge variant={player.is_added ? 'success' : 'default'}>
                            {player.is_added ? t('players.added') : t('players.not_added')}
                          </Badge>
                        </div>
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

export default Players
