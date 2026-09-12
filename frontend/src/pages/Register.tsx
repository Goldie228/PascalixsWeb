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

const registerSchema = z
  .object({
    username: z
      .string()
      .min(3, 'Username must be at least 3 characters')
      .max(16, 'Username must be at most 16 characters'),
    email: z.string().email('Invalid email address'),
    password: z
      .string()
      .min(8, 'Password must be at least 8 characters')
      .regex(/[A-Z]/, 'Password must contain an uppercase letter')
      .regex(/[0-9]/, 'Password must contain a number'),
    passwordConfirmation: z.string(),
  })
  .refine((data) => data.password === data.passwordConfirmation, {
    message: "Passwords don't match",
    path: ['passwordConfirmation'],
  })

type RegisterFormData = z.infer<typeof registerSchema>

export default function Register() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const { success: toastSuccess } = useToast()
  const { register: registerUser, error, isLoading } = useAuthStore((s) => ({
    register: s.register,
    error: s.error,
    isLoading: s.isLoading,
  }))

  const {
    register: formRegister,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<RegisterFormData>({
    resolver: zodResolver(registerSchema),
    defaultValues: {
      username: '',
      email: '',
      password: '',
      passwordConfirmation: '',
    },
  })

  const onSubmit = async (data: RegisterFormData) => {
    try {
      await registerUser({
        username: data.username,
        email: data.email,
        password: data.password,
        passwordConfirmation: data.passwordConfirmation,
      })
      toastSuccess(t('auth.register_button'))
      navigate('/login')
    } catch {
      // Error is handled by the auth store
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-base-100 px-4 py-8">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="w-full max-w-md"
      >
        <Card>
          <CardHeader>
            <CardTitle className="text-center text-2xl">{t('auth.register_title')}</CardTitle>
          </CardHeader>
          <CardContent>
            {error && (
              <div className="mb-4 p-3 bg-error/10 border border-error/20 rounded-lg text-error text-sm">
                {error}
              </div>
            )}

            <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
              <Input
                {...formRegister('username')}
                label={t('auth.register_username')}
                placeholder={t('auth.register_placeholder_username')}
                error={errors.username?.message}
                disabled={isSubmitting || isLoading}
                autoComplete="username"
              />

              <Input
                {...formRegister('email')}
                label={t('auth.register_email')}
                type="email"
                placeholder={t('auth.register_placeholder_email')}
                error={errors.email?.message}
                disabled={isSubmitting || isLoading}
                autoComplete="email"
              />

              <Input
                {...formRegister('password')}
                label={t('auth.register_password')}
                type="password"
                placeholder={t('auth.register_placeholder_password')}
                error={errors.password?.message}
                disabled={isSubmitting || isLoading}
                autoComplete="new-password"
              />

              <Input
                {...formRegister('passwordConfirmation')}
                label={t('auth.register_confirm')}
                type="password"
                placeholder={t('auth.register_placeholder_confirm')}
                error={errors.passwordConfirmation?.message}
                disabled={isSubmitting || isLoading}
                autoComplete="new-password"
              />

              <Button
                type="submit"
                className="w-full"
                isLoading={isSubmitting || isLoading}
                disabled={isSubmitting || isLoading}
              >
                {t('auth.register_button')}
              </Button>
            </form>

            <div className="mt-4 text-center text-sm">
              <span className="text-neutral/60">{t('auth.register_have_account')}</span>
              <Link to="/login" className="text-primary hover:underline">
                {t('auth.register_login_link')}
              </Link>
            </div>
          </CardContent>
        </Card>
      </motion.div>
    </div>
  )
}
