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
import api from '@/services/api'

const minecraftSchema = z.object({
  minecraftUsername: z
    .string()
    .min(3, 'Minecraft username must be at least 3 characters')
    .max(16, 'Minecraft username must be at most 16 characters')
    .regex(/^[a-zA-Z0-9_]+$/, 'Username can only contain letters, numbers, and underscores'),
  minecraftPassword: z.string().min(1, 'Minecraft password is required'),
})

type MinecraftFormData = z.infer<typeof minecraftSchema>

export default function MinecraftRegistration() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const { success: showSuccess, error: showError } = useToast()
  const { user } = useAuthStore((s) => ({ user: s.user }))

  const [step, setStep] = useState<'register' | 'verify'>('register')
  const [verificationSent, setVerificationSent] = useState(false)

  const {
    register: formRegister,
    handleSubmit: handleFormSubmit,
    formState: { errors: formErrors, isSubmitting: formSubmitting },
  } = useForm<MinecraftFormData>({
    resolver: zodResolver(minecraftSchema),
    defaultValues: {
      minecraftUsername: '',
      minecraftPassword: '',
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

  const registerMinecraft = useMutation({
    mutationFn: async (data: MinecraftFormData) => {
      const response = await api.post('/auth/register-minecraft', {
        minecraft_username: data.minecraftUsername,
        minecraft_password: data.minecraftPassword,
      })
      return response.data
    },
    onSuccess: () => {
      setVerificationSent(true)
      setStep('verify')
      showSuccess(t('minecraft.register_sent'))
    },
    onError: (error: any) => {
      showError(error.response?.data?.message || t('minecraft.register_error'))
    },
  })

  const verifyMinecraft = useMutation({
    mutationFn: async (code: string) => {
      await api.post('/auth/verify-minecraft', {
        minecraft_username: user?.username,
        code,
      })
    },
    onSuccess: () => {
      showSuccess(t('minecraft.verify_success'))
      navigate('/login')
    },
    onError: () => {
      showError(t('minecraft.verify_error'))
    },
  })

  const handleFormSubmitFn = async (data: MinecraftFormData) => {
    await registerMinecraft.mutateAsync(data)
  }

  const handleVerifySubmitFn = async (data: { code: string }) => {
    await verifyMinecraft.mutateAsync(data.code)
  }

  const resendCode = async () => {
    await registerMinecraft.mutateAsync({
      minecraftUsername: user?.username || '',
      minecraftPassword: '',
    })
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
            <CardTitle className="text-center text-2xl">
              {step === 'register' ? t('minecraft.register_title') : t('minecraft.verify_title')}
            </CardTitle>
          </CardHeader>
          <CardContent>
            {step === 'register' && !verificationSent ? (
              <form onSubmit={handleFormSubmit(handleFormSubmitFn)} className="space-y-4">
                <Alert variant="info">
                  <AlertContent>
                    {t('minecraft.register_description')}
                  </AlertContent>
                </Alert>

                <Input
                  {...formRegister('minecraftUsername')}
                  label={t('minecraft.username_label')}
                  placeholder={t('minecraft.username_placeholder')}
                  error={formErrors.minecraftUsername?.message ? String(formErrors.minecraftUsername.message) : undefined}
                  disabled={formSubmitting || registerMinecraft.isPending}
                />

                <Input
                  {...formRegister('minecraftPassword')}
                  label={t('minecraft.password_label')}
                  type="password"
                  placeholder={t('minecraft.password_placeholder')}
                  error={formErrors.minecraftPassword?.message ? String(formErrors.minecraftPassword.message) : undefined}
                  disabled={formSubmitting || registerMinecraft.isPending}
                />

                <Button
                  type="submit"
                  className="w-full"
                  isLoading={formSubmitting || registerMinecraft.isPending}
                  disabled={formSubmitting || registerMinecraft.isPending}
                >
                  {t('minecraft.register_button')}
                </Button>
              </form>
            ) : step === 'verify' ? (
              <form onSubmit={handleVerifySubmit(handleVerifySubmitFn)} className="space-y-4">
                <Alert variant="info">
                  <AlertContent>
                    {t('minecraft.verify_description')}
                  </AlertContent>
                </Alert>

                <Input
                  {...verifyRegister('code')}
                  label={t('minecraft.code_label')}
                  placeholder="123456"
                  error={verifyErrors.code?.message ? String(verifyErrors.code.message) : undefined}
                  disabled={verifySubmitting || verifyMinecraft.isPending}
                />

                <Button
                  type="submit"
                  className="w-full"
                  isLoading={verifySubmitting || verifyMinecraft.isPending}
                  disabled={verifySubmitting || verifyMinecraft.isPending}
                >
                  {t('minecraft.verify_button')}
                </Button>

                <div className="text-center">
                  <button
                    type="button"
                    onClick={resendCode}
                    className="text-sm text-primary hover:underline"
                    disabled={registerMinecraft.isPending}
                  >
                    {t('minecraft.resend_code')}
                  </button>
                </div>
              </form>
            ) : null}

            {registerMinecraft.isError && (
              <div className="mt-4 p-3 bg-error/10 border border-error/20 rounded-lg text-error text-sm">
                {t('minecraft.register_error')}
              </div>
            )}

            <div className="mt-4 text-center text-sm">
              <button
                onClick={() => navigate('/login')}
                className="text-primary hover:underline"
              >
                {t('minecraft.back_to_login')}
              </button>
            </div>
          </CardContent>
        </Card>
      </motion.div>
    </div>
  )
}
