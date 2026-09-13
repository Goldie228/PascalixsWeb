import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { useNavigate, Link } from 'react-router-dom'
import { motion } from 'framer-motion'
import { useTranslation } from 'react-i18next'
import { useAuthStore } from '@/store/auth'
import { useToast } from '@/components/ui/Toast'
import { Button } from '@/components/ui/Button'
import { Input } from '@/components/ui/Input'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { Mail } from 'lucide-react'

const loginSchema = z.object({
  username: z.string().min(3, 'Username must be at least 3 characters'),
  password: z.string().min(1, 'Password is required'),
})

type LoginFormData = z.infer<typeof loginSchema>

export default function Login() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const { success: toastSuccess } = useToast()
  const { login, error, isLoading } = useAuthStore((s) => ({
    login: s.login,
    error: s.error,
    isLoading: s.isLoading,
  }))

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<LoginFormData>({
    resolver: zodResolver(loginSchema),
    defaultValues: { username: '', password: '' },
  })

  const onSubmit = async (data: LoginFormData) => {
    try {
      await login(data.username, data.password)
      toastSuccess(t('auth.login_button'))
      navigate('/')
    } catch {
      // Error is handled by the auth store
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-base-100 px-4">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="w-full max-w-md"
      >
        <Card>
          <CardHeader>
            <CardTitle className="text-center text-2xl">{t('auth.login_title')}</CardTitle>
          </CardHeader>
          <CardContent>
            {error && (
              <div className="mb-4 p-3 bg-error/10 border border-error/20 rounded-lg text-error text-sm">
                {error}
              </div>
            )}

            <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
              <Input
                {...register('username')}
                label={t('auth.login_username')}
                placeholder={t('auth.login_placeholder_username')}
                error={errors.username?.message}
                disabled={isSubmitting || isLoading}
                autoComplete="username"
              />

              <Input
                {...register('password')}
                label={t('auth.login_password')}
                type="password"
                placeholder={t('auth.login_placeholder_password')}
                error={errors.password?.message}
                disabled={isSubmitting || isLoading}
                autoComplete="current-password"
              />

              <Button
                type="submit"
                className="w-full"
                isLoading={isSubmitting || isLoading}
                disabled={isSubmitting || isLoading}
              >
                {t('auth.login_button')}
              </Button>
            </form>

            <div className="my-4 flex items-center gap-2">
              <div className="h-px flex-1 bg-neutral/20" />
              <span className="text-xs text-neutral/50">{t('auth.or')}</span>
              <div className="h-px flex-1 bg-neutral/20" />
            </div>

            <Button
              variant="outline"
              className="w-full"
              onClick={() => navigate('/email_login')}
            >
              <Mail className="w-4 h-4 mr-2" />
              {t('auth.login_via_email')}
            </Button>

            <div className="mt-4 text-center text-sm">
              <span className="text-neutral/60">{t('auth.login_no_account')}</span>
              <Link to="/register" className="text-primary hover:underline">
                {t('auth.login_register_link')}
              </Link>
            </div>
          </CardContent>
        </Card>
      </motion.div>
    </div>
  )
}
