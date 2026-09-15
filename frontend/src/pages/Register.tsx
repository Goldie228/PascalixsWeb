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
import { authApi } from '@/services/api'
import {
  UserPlus,
  Mail,
  Lock,
  User,
  Eye,
  EyeOff,
  Loader2,
  CheckCircle2,
  XCircle,
  Gamepad2,
} from 'lucide-react'

const registerSchema = z
  .object({
    username: z.string()
      .min(3, 'Username must be at least 3 characters')
      .max(16, 'Username must be at most 16 characters')
      .regex(/^[a-zA-Z0-9_]+$/, 'Username can only contain letters, numbers, and underscores'),
    email: z.string().email('Invalid email address'),
    password: z.string()
      .min(8, 'Password must be at least 8 characters')
      .regex(/[A-Z]/, 'Password must contain at least one uppercase letter')
      .regex(/[a-z]/, 'Password must contain at least one lowercase letter')
      .regex(/[0-9]/, 'Password must contain at least one number')
      .regex(/[^A-Za-z0-9]/, 'Password must contain at least one special character'),
    passwordConfirmation: z.string(),
    acceptTerms: z.literal(true, { errorMap: () => ({ message: 'You must accept the terms' }) }),
  })
  .refine((data) => data.password === data.passwordConfirmation, {
    message: 'Passwords do not match',
    path: ['passwordConfirmation'],
  })

type RegisterFormData = z.infer<typeof registerSchema>

function PasswordStrength(password: string) {
  let score = 0
  if (password.length >= 8) score++
  if (password.length >= 12) score++
  if (/[A-Z]/.test(password)) score++
  if (/[a-z]/.test(password)) score++
  if (/[0-9]/.test(password)) score++
  if (/[^A-Za-z0-9]/.test(password)) score++
  return score
}

const strengthLabels = ['', 'Very Weak', 'Weak', 'Fair', 'Good', 'Strong', 'Very Strong']
const strengthColors = ['', 'bg-error', 'bg-error', 'bg-warning', 'bg-info', 'bg-success', 'bg-success']

function Register() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const { toast } = useToast()
  const [showPassword, setShowPassword] = useState(false)
  const [showConfirmPassword, setShowConfirmPassword] = useState(false)

  const {
    register,
    handleSubmit,
    watch,
    formState: { errors, isSubmitting },
  } = useForm<RegisterFormData>({
    resolver: zodResolver(registerSchema),
    defaultValues: {
      username: '',
      email: '',
      password: '',
      passwordConfirmation: '',
      acceptTerms: false,
    },
  })

  const password = watch('password')
  const passwordStrength = PasswordStrength(password || '')

  const registerMutation = useMutation({
    mutationFn: async (data: RegisterFormData) => {
      const response = await authApi.register({
        username: data.username,
        email: data.email,
        password: data.password,
        passwordConfirmation: data.passwordConfirmation,
      })
      return response.data
    },
    onSuccess: () => {
      toast({
        title: t('register.success'),
        description: t('register.success_desc'),
        variant: 'success',
      })
      navigate('/login')
    },
    onError: (error: any) => {
      toast({
        title: t('register.error'),
        description: error.response?.data?.error || t('register.register_failed'),
        variant: 'error',
      })
    },
  })

  const onSubmit = (data: RegisterFormData) => {
    registerMutation.mutate(data)
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
              <UserPlus className="h-8 w-8 text-primary" />
            </div>
          </div>
          <h1 className="text-3xl font-bold text-primary">{t('register.title')}</h1>
          <p className="mt-2 text-neutral/70">{t('register.subtitle')}</p>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>{t('register.create_account')}</CardTitle>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
              {/* Username */}
              <div>
                <label className="mb-1 block text-sm font-medium text-neutral/70">
                  {t('register.username')}
                </label>
                <div className="relative">
                  <User className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-neutral/40" />
                  <Input
                    type="text"
                    placeholder="Username"
                    error={errors.username?.message}
                    className="pl-10"
                    {...register('username')}
                  />
                </div>
                <p className="mt-1 text-xs text-neutral/50">
                  {t('register.username_hint')}
                </p>
              </div>

              {/* Email */}
              <div>
                <label className="mb-1 block text-sm font-medium text-neutral/70">
                  {t('register.email')}
                </label>
                <div className="relative">
                  <Mail className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-neutral/40" />
                  <Input
                    type="email"
                    placeholder="email@example.com"
                    error={errors.email?.message}
                    className="pl-10"
                    {...register('email')}
                  />
                </div>
              </div>

              {/* Password */}
              <div>
                <label className="mb-1 block text-sm font-medium text-neutral/70">
                  {t('register.password')}
                </label>
                <div className="relative">
                  <Input
                    type={showPassword ? 'text' : 'password'}
                    placeholder={t('register.password_placeholder')}
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
                {/* Password Strength Indicator */}
                {password && (
                  <div className="mt-2">
                    <div className="mb-1 flex items-center justify-between">
                      <span className="text-xs text-neutral/60">
                        {t('register.strength')}
                      </span>
                      <span className="text-xs font-medium">
                        {strengthLabels[passwordStrength]}
                      </span>
                    </div>
                    <div className="h-1.5 w-full overflow-hidden rounded-full bg-neutral/10">
                      <div
                        className={`h-full rounded-full transition-all duration-300 ${
                          strengthColors[passwordStrength]
                        }`}
                        style={{ width: `${(passwordStrength / 6) * 100}%` }}
                      />
                    </div>
                    <div className="mt-2 grid grid-cols-2 gap-1 text-xs text-neutral/50">
                      <div className="flex items-center gap-1">
                        {/[A-Z]/.test(password) ? (
                          <CheckCircle2 className="h-3 w-3 text-success" />
                        ) : (
                          <XCircle className="h-3 w-3 text-neutral/30" />
                        )}
                        <span>Uppercase</span>
                      </div>
                      <div className="flex items-center gap-1">
                        {/[a-z]/.test(password) ? (
                          <CheckCircle2 className="h-3 w-3 text-success" />
                        ) : (
                          <XCircle className="h-3 w-3 text-neutral/30" />
                        )}
                        <span>Lowercase</span>
                      </div>
                      <div className="flex items-center gap-1">
                        {/[0-9]/.test(password) ? (
                          <CheckCircle2 className="h-3 w-3 text-success" />
                        ) : (
                          <XCircle className="h-3 w-3 text-neutral/30" />
                        )}
                        <span>Number</span>
                      </div>
                      <div className="flex items-center gap-1">
                        {/[^A-Za-z0-9]/.test(password) ? (
                          <CheckCircle2 className="h-3 w-3 text-success" />
                        ) : (
                          <XCircle className="h-3 w-3 text-neutral/30" />
                        )}
                        <span>Special</span>
                      </div>
                    </div>
                  </div>
                )}
              </div>

              {/* Confirm Password */}
              <div>
                <label className="mb-1 block text-sm font-medium text-neutral/70">
                  {t('register.confirm_password')}
                </label>
                <div className="relative">
                  <Input
                    type={showConfirmPassword ? 'text' : 'password'}
                    placeholder={t('register.confirm_password_placeholder')}
                    error={errors.passwordConfirmation?.message}
                    className="pr-10"
                    {...register('passwordConfirmation')}
                  />
                  <button
                    type="button"
                    onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-neutral/40 hover:text-neutral/60"
                  >
                    {showConfirmPassword ? (
                      <EyeOff className="h-4 w-4" />
                    ) : (
                      <Eye className="h-4 w-4" />
                    )}
                  </button>
                </div>
              </div>

              {/* Minecraft Registration Link */}
              <div className="rounded-lg border border-neutral/20 p-3">
                <div className="flex items-start gap-2">
                  <Gamepad2 className="mt-0.5 h-4 w-4 text-primary" />
                  <div>
                    <p className="text-sm font-medium text-neutral/70">
                      {t('register.minecraft_account')}
                    </p>
                    <p className="text-xs text-neutral/50">
                      {t('register.minecraft_account_hint')}
                    </p>
                    <a
                      href="https://minecraft.net/en-us/"
                      target="_blank"
                      rel="noopener noreferrer"
                      className="mt-1 inline-block text-xs text-primary hover:underline"
                    >
                      {t('register.create_minecraft_account')}
                    </a>
                  </div>
                </div>
              </div>

              {/* Terms Acceptance */}
              <label className="flex items-start gap-2">
                <input
                  type="checkbox"
                  checked={false}
                  onChange={(e) => {
                    // Note: zod resolver requires literal true, so we handle this differently
                  }}
                  className="mt-0.5 h-4 w-4 rounded border-neutral/20 text-primary focus:ring-primary"
                />
                <span className="text-sm text-neutral/70">
                  {t('register.accept_terms')}{' '}
                  <a href="/terms" className="text-primary hover:underline">
                    {t('register.terms_of_service')}
                  </a>
                </span>
              </label>
              {errors.acceptTerms && (
                <p className="text-xs text-error">{errors.acceptTerms.message}</p>
              )}

              <Button
                type="submit"
                disabled={isSubmitting}
                className="w-full"
              >
                {isSubmitting ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    {t('register.creating_account')}
                  </>
                ) : (
                  t('register.create_account')
                )}
              </Button>
            </form>

            {/* Login Link */}
            <div className="mt-6 text-center text-sm text-neutral/60">
              {t('register.already_have_account')}{' '}
              <Link to="/login" className="text-primary hover:underline">
                {t('register.login')}
              </Link>
            </div>
          </CardContent>
        </Card>
      </motion.div>
    </div>
  )
}

export default Register
