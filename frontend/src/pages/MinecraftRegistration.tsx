import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { useNavigate } from 'react-router-dom'
import { motion } from 'framer-motion'
import { useTranslation } from 'react-i18next'
import { useAuthStore } from '@/store/auth'
import { useToast } from '@/components/ui/Toast'
import { Button } from '@/components/ui/Button'
import { Input } from '@/components/ui/Input'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { Alert, AlertContent } from '@/components/ui/Alert'
import { useMutation } from '@tanstack/react-query'
import { minecraftApi, type MinecraftRegisterData } from '@/services/minecraftApi'
import {
  Gamepad2,
  Shield,
  Loader2,
  CheckCircle2,
  AlertTriangle,
  Eye,
  EyeOff,
  ArrowLeft,
} from 'lucide-react'

// Validation schemas
const minecraftSchema = z.object({
  nickname: z
    .string()
    .min(3, 'Minecraft username must be at least 3 characters')
    .max(16, 'Minecraft username must be at most 16 characters')
    .regex(/^[a-zA-Z0-9_]+$/, 'Username can only contain letters, numbers, and underscores'),
  password: z.string().min(1, 'Minecraft password is required'),
  passwordConfirmation: z.string().min(1, 'Please confirm your password'),
}).refine((data) => data.password === data.passwordConfirmation, {
  message: "Passwords don't match",
  path: ['passwordConfirmation'],
})

type MinecraftFormData = z.infer<typeof minecraftSchema>

export default function MinecraftRegistration() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const { success: showSuccess, error: showError } = useToast()
  const { user } = useAuthStore((s) => ({ user: s.user }))

  const [step, setStep] = useState<'register' | 'verify' | 'success'>('register')
  const [showPassword, setShowPassword] = useState(false)
  const [showConfirmPassword, setShowConfirmPassword] = useState(false)

  const {
    register: formRegister,
    handleSubmit: handleFormSubmit,
    formState: { errors: formErrors, isSubmitting: formSubmitting },
    reset: resetForm,
  } = useForm<MinecraftFormData>({
    resolver: zodResolver(minecraftSchema),
    defaultValues: {
      nickname: '',
      password: '',
      passwordConfirmation: '',
    },
  })

  const {
    register: verifyRegister,
    handleSubmit: handleVerifySubmit,
    formState: { errors: verifyErrors, isSubmitting: verifySubmitting },
  } = useForm<{ code: string }>({
    resolver: zodResolver(z.object({ code: z.string().min(6, 'Code must be 6 characters') })),
    defaultValues: { code: '' },
  })

  // Step 1: Register Minecraft account
  const registerMinecraft = useMutation({
    mutationFn: async (data: MinecraftRegisterData) => {
      const response = await minecraftApi.register(data)
      return response.data
    },
    onSuccess: (data) => {
      if (data.status === 'pending' || data.status === 'success') {
        setStep('verify')
        showSuccess(data.message || t('minecraft.register_sent'))
      } else {
        showError(data.message || t('minecraft.register_error'))
      }
    },
    onError: (error: any) => {
      const message = error.response?.data?.message || error.response?.data?.error || t('minecraft.register_error')
      showError(message)
    },
  })

  // Step 2: Verify Minecraft account
  const verifyMinecraft = useMutation({
    mutationFn: async (code: string) => {
      const response = await minecraftApi.verify({
        nickname: user?.username || '',
        code,
      })
      return response.data
    },
    onSuccess: (data) => {
      if (data.status === 'success') {
        setStep('success')
        showSuccess(data.message || t('minecraft.verify_success'))
        setTimeout(() => {
          navigate('/login')
        }, 2000)
      } else {
        const message = data.message || t('minecraft.verify_error')
        showError(message)
      }
    },
    onError: (error: any) => {
      const message = error.response?.data?.message || error.response?.data?.error || t('minecraft.verify_error')
      showError(message)
    },
  })

  const handleRegisterSubmit = async (data: MinecraftFormData) => {
    await registerMinecraft.mutateAsync({
      nickname: data.nickname,
      password: data.password,
      password_confirmation: data.passwordConfirmation,
    })
  }

  const handleVerifySubmitFn = async (data: { code: string }) => {
    await verifyMinecraft.mutateAsync(data.code)
  }

  const handleResendCode = async () => {
    if (!user?.username) return
    try {
      await minecraftApi.resendCode(user.username)
      showSuccess(t('minecraft.register_sent'))
    } catch (err: any) {
      const message = err.response?.data?.message || err.response?.data?.error || t('minecraft.register_error')
      showError(message)
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
            <div className="flex items-center justify-center gap-3 mb-2">
              <div className="flex h-12 w-12 items-center justify-center rounded-full bg-primary/10">
                <Gamepad2 className="h-6 w-6 text-primary" />
              </div>
            </div>
            <CardTitle className="text-center text-2xl">
              {step === 'register' && t('minecraft.register_title')}
              {step === 'verify' && t('minecraft.verify_title')}
              {step === 'success' && t('minecraft.verify_success')}
            </CardTitle>
          </CardHeader>
          <CardContent>
            {/* Success State */}
            {step === 'success' && (
              <motion.div
                initial={{ opacity: 0, scale: 0.9 }}
                animate={{ opacity: 1, scale: 1 }}
                className="flex flex-col items-center justify-center py-8 space-y-4"
              >
                <motion.div
                  initial={{ scale: 0 }}
                  animate={{ scale: 1 }}
                  transition={{ type: 'spring', stiffness: 200, damping: 15 }}
                  className="flex h-16 w-16 items-center justify-center rounded-full bg-success/10"
                >
                  <CheckCircle2 className="h-8 w-8 text-success" />
                </motion.div>
                <h3 className="text-lg font-semibold text-success">
                  {t('minecraft.verify_success')}
                </h3>
                <p className="text-sm text-base-content/60">
                  {t('common.loading')}
                </p>
              </motion.div>
            )}

            {/* Registration Form */}
            {step === 'register' && (
              <form onSubmit={handleFormSubmit(handleRegisterSubmit)} className="space-y-4">
                <Alert variant="info">
                  <AlertContent>
                    <div className="flex items-start gap-2">
                      <Shield className="h-5 w-5 shrink-0 text-info mt-0.5" />
                      <span className="text-sm">{t('minecraft.register_description')}</span>
                    </div>
                  </AlertContent>
                </Alert>

                <Input
                  {...formRegister('nickname')}
                  label={t('minecraft.username_label')}
                  placeholder={t('minecraft.username_placeholder')}
                  error={formErrors.nickname?.message ? String(formErrors.nickname.message) : undefined}
                  disabled={formSubmitting || registerMinecraft.isPending}
                />

                {/* Password Field */}
                <div className="space-y-1">
                  <label className="text-sm font-medium text-base-content">
                    {t('minecraft.password_label')}
                  </label>
                  <div className="relative">
                    <Input
                      type={showPassword ? 'text' : 'password'}
                      placeholder={t('minecraft.password_placeholder')}
                      disabled={formSubmitting || registerMinecraft.isPending}
                      className="pr-12"
                      value={formRegister('password').value}
                      onChange={(e) => formRegister('password').onChange(e)}
                      onBlur={formRegister('password').onBlur}
                    />
                    <button
                      type="button"
                      onClick={() => setShowPassword(!showPassword)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-base-content/50 hover:text-base-content transition-colors"
                      tabIndex={-1}
                    >
                      {showPassword ? (
                        <EyeOff className="h-4 w-4" />
                      ) : (
                        <Eye className="h-4 w-4" />
                      )}
                    </button>
                  </div>
                  {formErrors.password?.message && (
                    <p className="text-xs text-error">{String(formErrors.password.message)}</p>
                  )}
                </div>

                {/* Confirm Password Field */}
                <div className="space-y-1">
                  <label className="text-sm font-medium text-base-content">
                    {t('register.confirm')}
                  </label>
                  <div className="relative">
                    <Input
                      type={showConfirmPassword ? 'text' : 'password'}
                      placeholder={t('register_placeholder_confirm')}
                      disabled={formSubmitting || registerMinecraft.isPending}
                      className="pr-12"
                      value={formRegister('passwordConfirmation').value}
                      onChange={(e) => formRegister('passwordConfirmation').onChange(e)}
                      onBlur={formRegister('passwordConfirmation').onBlur}
                    />
                    <button
                      type="button"
                      onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-base-content/50 hover:text-base-content transition-colors"
                      tabIndex={-1}
                    >
                      {showConfirmPassword ? (
                        <EyeOff className="h-4 w-4" />
                      ) : (
                        <Eye className="h-4 w-4" />
                      )}
                    </button>
                  </div>
                  {formErrors.passwordConfirmation?.message && (
                    <p className="text-xs text-error">{String(formErrors.passwordConfirmation.message)}</p>
                  )}
                </div>

                <Button
                  type="submit"
                  className="w-full"
                  isLoading={formSubmitting || registerMinecraft.isPending}
                  disabled={formSubmitting || registerMinecraft.isPending}
                >
                  {t('minecraft.register_button')}
                </Button>
              </form>
            )}

            {/* Verification Form */}
            {step === 'verify' && (
              <form onSubmit={handleVerifySubmit(handleVerifySubmitFn)} className="space-y-4">
                <Alert variant="info">
                  <AlertContent>
                    <div className="flex items-start gap-2">
                      <Shield className="h-5 w-5 shrink-0 text-info mt-0.5" />
                      <span className="text-sm">{t('minecraft.verify_description')}</span>
                    </div>
                  </AlertContent>
                </Alert>

                {/* 6-digit code input */}
                <div className="space-y-1">
                  <label className="text-sm font-medium text-base-content">
                    {t('minecraft.code_label')}
                  </label>
                  <div className="flex justify-center gap-2">
                    {Array.from({ length: 6 }).map((_, i) => (
                      <input
                        key={i}
                        type="text"
                        inputMode="numeric"
                        maxLength={1}
                        className="w-12 h-14 text-center text-lg font-bold rounded-lg bg-base-200 border border-neutral/20 text-base-content placeholder:text-neutral/50 focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 focus:ring-offset-base-100 disabled:cursor-not-allowed disabled:opacity-50 transition-colors"
                        onChange={(e) => {
                          const digit = e.target.value.replace(/\D/g, '')
                          if (digit) {
                            const code = Array.from({ length: 6 }, (_, j) => {
                              const el = document.getElementById(`mc-code-${j}`) as HTMLInputElement | null
                              return el?.value || ''
                            }).join('') + digit
                            // Just focus next
                            if (i < 5) {
                              const next = document.getElementById(`mc-code-${i + 1}`) as HTMLInputElement | null
                              next?.focus()
                            }
                          }
                        }}
                        onKeyDown={(e) => {
                          if (e.key === 'Backspace' && !e.currentTarget.value && i > 0) {
                            const prev = document.getElementById(`mc-code-${i - 1}`) as HTMLInputElement | null
                            prev?.focus()
                          }
                        }}
                        onPaste={(e) => {
                          e.preventDefault()
                          const pasted = e.clipboardData.getData('text').replace(/\D/g, '').slice(0, 6)
                          if (pasted.length === 6) {
                            pasted.split('').forEach((char, j) => {
                              const el = document.getElementById(`mc-code-${j}`) as HTMLInputElement | null
                              el!.value = char
                            })
                            verifyRegister('code').onChange({
                              target: { value: pasted },
                            } as React.ChangeEvent<HTMLInputElement>)
                          }
                        }}
                        autoFocus={i === 0}
                        id={`mc-code-${i}`}
                      />
                    ))}
                  </div>
                  {verifyErrors.code?.message && (
                    <p className="text-xs text-error">{String(verifyErrors.code.message)}</p>
                  )}
                </div>

                <Button
                  type="submit"
                  className="w-full"
                  isLoading={verifySubmitting || verifyMinecraft.isPending}
                  disabled={verifySubmitting || verifyMinecraft.isPending}
                >
                  {t('minecraft.verify_button')}
                </Button>

                {/* Resend Code */}
                <div className="text-center">
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    onClick={handleResendCode}
                    disabled={registerMinecraft.isPending}
                    isLoading={registerMinecraft.isPending}
                  >
                    <RefreshCw className="mr-2 h-4 w-4" />
                    {t('minecraft.resend_code')}
                  </Button>
                </div>
              </form>
            )}

            {/* Errors */}
            {registerMinecraft.isError && step === 'register' && (
              <div className="mt-4 flex items-center gap-2 rounded-lg bg-error/10 border border-error/20 p-3 text-error text-sm">
                <AlertTriangle className="h-4 w-4 shrink-0" />
                <span>{t('minecraft.register_error')}</span>
              </div>
            )}

            {verifyMinecraft.isError && step === 'verify' && (
              <div className="mt-4 flex items-center gap-2 rounded-lg bg-error/10 border border-error/20 p-3 text-error text-sm">
                <AlertTriangle className="h-4 w-4 shrink-0" />
                <span>{t('minecraft.verify_error')}</span>
              </div>
            )}

            {/* Back to Login */}
            <div className="mt-4 text-center text-sm">
              <button
                onClick={() => navigate('/login')}
                className="text-primary hover:underline flex items-center justify-center gap-2 mx-auto"
              >
                <ArrowLeft className="h-3 w-3" />
                {t('minecraft.back_to_login')}
              </button>
            </div>
          </CardContent>
        </Card>
      </motion.div>
    </div>
  )
}
