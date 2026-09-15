import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { useNavigate, Link } from 'react-router-dom'
import { useMutation } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { Input } from '@/components/ui/Input'
import { Button } from '@/components/ui/Button'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import { useToast } from '@/hooks/useToast'
import { useAuthStore } from '@/store/auth'
import {
  LogIn,
  Mail,
  Lock,
  Eye,
  EyeOff,
  Loader2,
  User,
  Github,
  Discord,
} from 'lucide-react'

const loginSchema = z.object({
  username: z.string().min(1, 'Username is required'),
  password: z.string().min(1, 'Password is required'),
  remember: z.boolean().optional(),
})

type LoginFormData = z.infer<typeof loginSchema>

function Login() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const { toast } = useToast()
  const login = useAuthStore((state) => state.login)
  const [showPassword, setShowPassword] = useState(false)
  const [useEmailLogin, setUseEmailLogin] = useState(false)

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
    setValue,
  } = useForm<LoginFormData>({
    resolver: zodResolver(loginSchema),
    defaultValues: {
      username: '',
      password: '',
      remember: false,
    },
  })

  const onSubmit = async (data: LoginFormData) => {
    try {
      await login(data.username, data.password, data.remember)
      toast({
        title: t('login.success'),
        description: t('login.success_desc'),
        variant: 'success',
      })
      navigate('/dashboard')
    } catch (error) {
      toast({
        title: t('login.error'),
        description: error instanceof Error ? error.message : t('login.login_failed'),
        variant: 'error',
      })
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-base-100 px-4 py-8">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="w-full max-w-md"
      >
        {/* Header */}
        <div className="mb-6 text-center">
          <div className="mb-4 flex justify-center">
            <div className="rounded-full bg-primary/10 p-4">
              <LogIn className="h-8 w-8 text-primary" />
            </div>
          </div>
          <h1 className="text-3xl font-bold text-primary">{t('login.title')}</h1>
          <p className="mt-2 text-neutral/70">{t('login.subtitle')}</p>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>{t('login.login')}</CardTitle>
          </CardHeader>
          <CardContent>
            {/* Social Login Buttons */}
            <div className="mb-6 grid grid-cols-2 gap-3">
              <Button
                variant="outline"
                className="gap-2"
                onClick={() => {
                  // TODO: Implement Discord OAuth
                  toast({
                    title: t('login.coming_soon'),
                    description: t('login.discord_coming_soon'),
                    variant: 'info',
                  })
                }}
              >
                <Discord className="h-4 w-4" />
                Discord
              </Button>
              <Button
                variant="outline"
                className="gap-2"
                onClick={() => {
                  // TODO: Implement GitHub OAuth
                  toast({
                    title: t('login.coming_soon'),
                    description: t('login.github_coming_soon'),
                    variant: 'info',
                  })
                }}
              >
                <Github className="h-4 w-4" />
                GitHub
              </Button>
            </div>

            {/* Divider */}
            <div className="relative mb-6">
              <div className="absolute inset-0 flex items-center">
                <div className="w-full border-t border-neutral/20" />
              </div>
              <div className="relative flex justify-center text-xs">
                <span className="bg-base-100 px-2 text-neutral/50">
                  {t('login.or_continue_with')}
                </span>
              </div>
            </div>

            {/* Login Form */}
            <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
              <div>
                <label className="mb-1 block text-sm font-medium text-neutral/70">
                  {t('login.username_or_email')}
                </label>
                <div className="relative">
                  <User className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-neutral/40" />
                  <Input
                    type="text"
                    placeholder="Username or Email"
                    error={errors.username?.message}
                    className="pl-10"
                    {...register('username')}
                  />
                </div>
              </div>

              <div>
                <label className="mb-1 block text-sm font-medium text-neutral/70">
                  {t('login.password')}
                </label>
                <div className="relative">
                  <Input
                    type={showPassword ? 'text' : 'password'}
                    placeholder={t('login.password_placeholder')}
                    error={errors.password?.message}
                    className="pr-10"
                    {...register('password')}
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-neutral/40 hover:text-neutral/60"
                  >
                    {showPassword ? (
                      <EyeOff className="h-4 w-4" />
                    ) : (
                      <Eye className="h-4 w-4" />
                    )}
                  </button>
                </div>
              </div>

              {/* Remember Me & Forgot Password */}
              <div className="flex items-center justify-between">
                <label className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    checked={false}
                    onChange={(e) => setValue('remember', e.target.checked)}
                    className="h-4 w-4 rounded border-neutral/20 text-primary focus:ring-primary"
                  />
                  <span className="text-sm text-neutral/70">{t('login.remember_me')}</span>
                </label>
                <Link
                  to="/reset-password"
                  className="text-sm text-primary hover:underline"
                >
                  {t('login.forgot_password')}
                </Link>
              </div>

              <Button
                type="submit"
                disabled={isSubmitting}
                className="w-full"
              >
                {isSubmitting ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    {t('login.logging_in')}
                  </>
                ) : (
                  t('login.login')
                )}
              </Button>
            </form>

            {/* Error Display */}
            {errors.username && (
              <div className="mt-4 rounded-lg border border-error/30 bg-error/10 p-3">
                <p className="text-sm text-error">{errors.username.message}</p>
              </div>
            )}
            {errors.password && (
              <div className="mt-4 rounded-lg border border-error/30 bg-error/10 p-3">
                <p className="text-sm text-error">{errors.password.message}</p>
              </div>
            )}

            {/* Register Link */}
            <div className="mt-6 text-center text-sm text-neutral/60">
              {t('login.no_account')}{' '}
              <Link to="/register" className="text-primary hover:underline">
                {t('login.register')}
              </Link>
            </div>
          </CardContent>
        </Card>
      </motion.div>
    </div>
  )
}

export default Login
