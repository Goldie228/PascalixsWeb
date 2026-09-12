import { useTranslation } from 'react-i18next'
import { useAuthStore } from '@/store/auth'
import { Card } from '@/components/ui/Card'
import { Button } from '@/components/ui/Button'
import { Badge } from '@/components/ui/Badge'
import { User, Mail, Shield, Calendar, Trophy, AlertTriangle } from 'lucide-react'
import { Link } from 'react-router-dom'

export default function Account() {
  const { t } = useTranslation()
  const { user } = useAuthStore()

  if (!user) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-white text-lg">{t('common.loading')}</div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 p-4 md:p-8">
      <div className="max-w-4xl mx-auto">
        <h1 className="text-3xl font-bold text-white mb-8">{t('account.title')}</h1>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* Profile Card */}
          <Card className="bg-gray-800/50 backdrop-blur-sm border-gray-700">
            <div className="flex items-center gap-4 mb-4">
              <div className="w-16 h-16 rounded-full bg-gray-700 flex items-center justify-center">
                <User className="w-8 h-8 text-gray-400" />
              </div>
              <div>
                <h2 className="text-xl font-bold text-white">{user.username}</h2>
                <Badge variant={user.role === 'admin' ? 'error' : 'default'}>
                  {user.role || 'player'}
                </Badge>
              </div>
            </div>
            <div className="space-y-3">
              <div className="flex items-center gap-2 text-gray-300">
                <Mail className="w-4 h-4 text-gray-500" />
                <span>{user.email || t('account.not_set')}</span>
              </div>
              <div className="flex items-center gap-2 text-gray-300">
                <Calendar className="w-4 h-4 text-gray-500" />
                <span>{t('account.joined')} {new Date(user.createdAt).toLocaleDateString()}</span>
              </div>
            </div>
          </Card>

          {/* Security Card */}
          <Card className="bg-gray-800/50 backdrop-blur-sm border-gray-700">
            <div className="flex items-center gap-2 mb-4">
              <Shield className="w-5 h-5 text-blue-400" />
              <h3 className="text-lg font-semibold text-white">{t('account.security')}</h3>
            </div>
            <div className="space-y-3">
              <div className="flex items-center justify-between p-3 bg-gray-700/50 rounded-lg">
                <span className="text-gray-300">Password</span>
                <span className="text-green-400 text-sm">{t('account.password_set')}</span>
              </div>
              <div className="flex items-center justify-between p-3 bg-gray-700/50 rounded-lg">
                <span className="text-gray-300">2FA</span>
                <span className="text-gray-400 text-sm">{t('account.2fa_disabled')}</span>
              </div>
            </div>
            <div className="mt-4 space-y-2">
              <Link to="/account/change-email">
                <Button variant="outline" className="w-full">
                  {t('account.change_email')}
                </Button>
              </Link>
              <Link to="/account/reset-password">
                <Button variant="outline" className="w-full">
                  {t('account.reset_password')}
                </Button>
              </Link>
              <Link to="/account/2fa/setup">
                <Button variant="outline" className="w-full">
                  {t('account.setup_2fa')}
                </Button>
              </Link>
            </div>
          </Card>

          {/* Stats Card */}
          <Card className="bg-gray-800/50 backdrop-blur-sm border-gray-700">
            <div className="flex items-center gap-2 mb-4">
              <Trophy className="w-5 h-5 text-amber-400" />
              <h3 className="text-lg font-semibold text-white">{t('account.statistics')}</h3>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="p-3 bg-gray-700/50 rounded-lg text-center">
                <p className="text-2xl font-bold text-white">0</p>
                <p className="text-gray-400 text-xs">{t('account.punishments')}</p>
              </div>
              <div className="p-3 bg-gray-700/50 rounded-lg text-center">
                <p className="text-2xl font-bold text-white">0</p>
                <p className="text-gray-400 text-xs">{t('account.appeals')}</p>
              </div>
              <div className="p-3 bg-gray-700/50 rounded-lg text-center">
                <p className="text-2xl font-bold text-white">0</p>
                <p className="text-gray-400 text-xs">{t('account.reports')}</p>
              </div>
              <div className="p-3 bg-gray-700/50 rounded-lg text-center">
                <p className="text-2xl font-bold text-white">0</p>
                <p className="text-gray-400 text-xs">{t('account.purchases')}</p>
              </div>
            </div>
          </Card>

          {/* Danger Zone */}
          <Card className="bg-gray-800/50 backdrop-blur-sm border-red-500/20">
            <div className="flex items-center gap-2 mb-4">
              <AlertTriangle className="w-5 h-5 text-red-400" />
              <h3 className="text-lg font-semibold text-red-400">{t('account.danger_zone')}</h3>
            </div>
            <p className="text-gray-400 text-sm mb-4">
              {t('account.delete_warning')}
            </p>
            <Button variant="destructive" className="w-full">
              {t('account.delete_account')}
            </Button>
          </Card>
        </div>
      </div>
    </div>
  )
}
