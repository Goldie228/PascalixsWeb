import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { useMutation } from '@tanstack/react-query'
import { motion, AnimatePresence } from 'framer-motion'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { Input } from '@/components/ui/Input'
import { Button } from '@/components/ui/Button'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import { useToast } from '@/hooks/useToast'
import { userApi } from '@/services/userApi'
import {
  Lock,
  Mail,
  CheckCircle2,
  XCircle,
  Loader2,
  ArrowLeft,
  Shield,
  Eye,
  EyeOff,
} from 'lucide-react'

const resetPasswordSchema = z
  .object({
    email: z.string().email('Invalid email address').optional(),
    currentPassword: z.string().min(1, 'Current password is required'),
    newPassword: z.string()
      .min(8, 'Password must be at least 8 characters')
      .regex(/[A-Z]/, 'Password must contain at least one uppercase letter')
      .regex(/[a-z]/, 'Password must contain at least one lowercase letter')
      .regex(/[0-9]/, 'Password must contain at least one number')
      .regex(/[^A-Za-z0-9]/, 'Password must contain at least one special character'),
    confirmPassword: z.string(),
  })
  .refine((data) => data.newPassword === data.confirmPassword, {
    message: 'Passwords do not match',
    path: ['confirmPassword'],
  })

type ResetPasswordFormData = z.infer<typeof resetPasswordSchema>

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

function ResetPassword() {
  const { t } = useTranslation()
  const { toast } = useToast()
  const [showPassword, setShowPassword] = useState(false)
  const [showConfirmPassword, setShowConfirmPassword] = useState(false)
  const [step, setStep] = useState<'email' | 'reset' | 'success'>('reset')

  const {
    register,
    handleSubmit,
    watch,
    formState: { errors, isSubmitting },
    reset,
  } = useForm<ResetPasswordFormData>({
    resolver: zodResolver(resetPasswordSchema),
    defaultValues: {
      email: '',
      currentPassword: '',
      newPassword: '',
      confirmPassword: '',
    },
  })

  const newPassword = watch('newPassword')
  const passwordStrength = PasswordStrength(newPassword || '')

  const resetMutation = useMutation({
    mutationFn: async (data: ResetPasswordFormData) => {
      const response = await userApi.resetPassword({
        current_password: data.currentPassword,
        new_password: data.newPassword,
        password_confirmation: data.confirmPassword,
      })
      return response.data
    },
    onSuccess: () => {
      setStep('success')
      reset()
      toast({
        title: t('reset_password.success'),
        description: t('reset_password.success_desc'),
        variant: 'success',
      })
    },
    onError: (error: any) => {
      toast({
        title: t('reset_password.error'),
        description: error.response?.data?.error || t('reset_password.reset_failed'),
        variant: 'error',
      })
    },
  })

  const onSubmit = (data: ResetPasswordFormData) => {
    resetMutation.mutate(data)
  }

  return (
    <div className="min-h-screen bg-base-100 py-8">
      <div className="container mx-auto max-w-lg px-4">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
        >
          {/* Header */}
          <div className="mb-6">
            <Button
              variant="ghost"
              size="sm"
              className="mb-4 gap-2"
            >
              <ArrowLeft className="h-4 w-4" />
              {t('reset_password.back')}
            </Button>
            <h1 className="text-3xl font-bold text-primary">{t('reset_password.title')}</h1>
            <p className="mt-1 text-neutral/70">{t('reset_password.subtitle')}</p>
          </div>

          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Lock className="h-5 w-5" />
                {step === 'reset' && t('reset_password.reset_step')}
                {step === 'success' && t('reset_password.success_step')}
              </CardTitle>
            </CardHeader>
            <CardContent>
              <AnimatePresence mode="wait">
                {step === 'reset' && (
                  <motion.div
                    key="reset"
                    initial={{ opacity: 0, x: 20 }}
                    animate={{ opacity: 1, x: 0 }}
                    exit={{ opacity: 0, x: -20 }}
                  >
                    <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
                      <div>
                        <label className="mb-1 block text-sm font-medium text-neutral/70">
                          {t('reset_password.current_password')}
                        </label>
                        <div className="relative">
                          <Input
                            type={showPassword ? 'text' : 'password'}
                            placeholder={t('reset_password.password_placeholder')}
                            error={errors.currentPassword?.message}
                            {...register('currentPassword')}
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

                      <div>
                        <label className="mb-1 block text-sm font-medium text-neutral/70">
                          {t('reset_password.new_password')}
                        </label>
                        <div className="relative">
                          <Input
                            type={showPassword ? 'text' : 'password'}
                            placeholder={t('reset_password.new_password_placeholder')}
                            error={errors.newPassword?.message}
                            {...register('newPassword')}
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
                        {newPassword && (
                          <div className="mt-2">
                            <div className="mb-1 flex items-center justify-between">
                              <span className="text-xs text-neutral/60">
                                {t('reset_password.strength')}
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
                                {/[A-Z]/.test(newPassword) ? (
                                  <CheckCircle2 className="h-3 w-3 text-success" />
                                ) : (
                                  <XCircle className="h-3 w-3 text-neutral/30" />
                                )}
                                <span>Uppercase</span>
                              </div>
                              <div className="flex items-center gap-1">
                                {/[a-z]/.test(newPassword) ? (
                                  <CheckCircle2 className="h-3 w-3 text-success" />
                                ) : (
                                  <XCircle className="h-3 w-3 text-neutral/30" />
                                )}
                                <span>Lowercase</span>
                              </div>
                              <div className="flex items-center gap-1">
                                {/[0-9]/.test(newPassword) ? (
                                  <CheckCircle2 className="h-3 w-3 text-success" />
                                ) : (
                                  <XCircle className="h-3 w-3 text-neutral/30" />
                                )}
                                <span>Number</span>
                              </div>
                              <div className="flex items-center gap-1">
                                {/[^A-Za-z0-9]/.test(newPassword) ? (
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

                      <div>
                        <label className="mb-1 block text-sm font-medium text-neutral/70">
                          {t('reset_password.confirm_password')}
                        </label>
                        <div className="relative">
                          <Input
                            type={showConfirmPassword ? 'text' : 'password'}
                            placeholder={t('reset_password.confirm_password_placeholder')}
                            error={errors.confirmPassword?.message}
                            {...register('confirmPassword')}
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

                      <Button
                        type="submit"
                        disabled={isSubmitting}
                        className="w-full"
                      >
                        {isSubmitting ? (
                          <>
                            <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                            {t('reset_password.resetting')}
                          </>
                        ) : (
                          t('reset_password.reset_password')
                        )}
                      </Button>
                    </form>
                  </motion.div>
                )}

                {step === 'success' && (
                  <motion.div
                    key="success"
                    initial={{ opacity: 0, scale: 0.95 }}
                    animate={{ opacity: 1, scale: 1 }}
                    className="text-center"
                  >
                    <div className="mb-4 flex justify-center">
                      <div className="rounded-full bg-success/20 p-4">
                        <CheckCircle2 className="h-12 w-12 text-success" />
                      </div>
                    </div>
                    <h3 className="mb-2 text-xl font-bold text-success">
                      {t('reset_password.success')}
                    </h3>
                    <p className="mb-6 text-neutral/70">
                      {t('reset_password.success_desc')}
                    </p>
                    <Button
                      variant="outline"
                      onClick={() => setStep('reset')}
                      className="gap-2"
                    >
                      <ArrowLeft className="h-4 w-4" />
                      {t('reset_password.back_to_form')}
                    </Button>
                  </motion.div>
                )}
              </AnimatePresence>

              {/* Loading State */}
              {resetMutation.isPending && (
                <div className="mt-4 flex justify-center">
                  <LoadingSpinner size="md" />
                </div>
              )}
            </CardContent>
          </Card>
        </motion.div>
      </div>
    </div>
  )
}

export default ResetPassword
