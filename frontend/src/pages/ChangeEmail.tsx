import { useState, useEffect } from 'react'
import { useTranslation } from 'react-i18next'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { useMutation, useQuery } from '@tanstack/react-query'
import { motion, AnimatePresence } from 'framer-motion'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { Input } from '@/components/ui/Input'
import { Button } from '@/components/ui/Button'
import { Badge } from '@/components/ui/Badge'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import { useToast } from '@/hooks/useToast'
import { userApi } from '@/services/userApi'
import { useAuthStore } from '@/store/auth'
import {
  Mail,
  Lock,
  CheckCircle2,
  XCircle,
  Loader2,
  ArrowLeft,
  Shield,
  AlertTriangle,
} from 'lucide-react'

const changeEmailSchema = z
  .object({
    currentPassword: z.string().min(1, 'Password is required'),
    newEmail: z.string().email('Invalid email address'),
  })
  .refine(
    (data) => {
      // Basic email validation - same as new email
      return data.newEmail.length >= 5 && data.newEmail.length <= 254
    },
    { message: 'Email must be between 5 and 254 characters', path: ['newEmail'] }
  )

type ChangeEmailFormData = z.infer<typeof changeEmailSchema>

function ChangeEmail() {
  const { t } = useTranslation()
  const { toast } = useToast()
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated)
  const [step, setStep] = useState<'verify' | 'confirm' | 'success'>('verify')
  const [verificationEmail, setVerificationEmail] = useState('')

  const { data: profile, isLoading: profileLoading } = useQuery({
    queryKey: ['user-profile'],
    queryFn: async () => {
      const response = await userApi.getUserData(0)
      return response.data
    },
    enabled: isAuthenticated,
  })

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
    reset,
  } = useForm<ChangeEmailFormData>({
    resolver: zodResolver(changeEmailSchema),
    defaultValues: {
      currentPassword: '',
      newEmail: '',
    },
  })

  const verifyMutation = useMutation({
    mutationFn: async (data: ChangeEmailFormData) => {
      const response = await userApi.requestChangeEmail(data)
      return response.data
    },
    onSuccess: (data) => {
      setVerificationEmail(data.email || '')
      setStep('confirm')
      toast({
        title: t('change_email.verification_sent'),
        description: t('change_email.verification_sent_desc'),
        variant: 'success',
      })
    },
    onError: (error: any) => {
      toast({
        title: t('change_email.error'),
        description: error.response?.data?.error || t('change_email.verification_failed'),
        variant: 'error',
      })
    },
  })

  const onSubmit = (data: ChangeEmailFormData) => {
    verifyMutation.mutate(data)
  }

  const handleBack = () => {
    if (step === 'confirm') {
      setStep('verify')
    }
  }

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
              onClick={handleBack}
              className="mb-4 gap-2"
            >
              <ArrowLeft className="h-4 w-4" />
              {t('change_email.back')}
            </Button>
            <h1 className="text-3xl font-bold text-primary">{t('change_email.title')}</h1>
            <p className="mt-1 text-neutral/70">{t('change_email.subtitle')}</p>
          </div>

          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Mail className="h-5 w-5" />
                {step === 'verify' && t('change_email.verify_step')}
                {step === 'confirm' && t('change_email.confirm_step')}
                {step === 'success' && t('change_email.success_step')}
              </CardTitle>
            </CardHeader>
            <CardContent>
              {/* Current Email Display */}
              <div className="mb-6 rounded-lg border border-neutral/20 p-4">
                <p className="text-xs font-medium text-neutral/60">{t('change_email.current_email')}</p>
                <div className="mt-1 flex items-center gap-2">
                  <Mail className="h-4 w-4 text-neutral/40" />
                  <p className="font-medium">{profile?.email || '—'}</p>
                </div>
              </div>

              <AnimatePresence mode="wait">
                {step === 'verify' && (
                  <motion.div
                    key="verify"
                    initial={{ opacity: 0, x: 20 }}
                    animate={{ opacity: 1, x: 0 }}
                    exit={{ opacity: 0, x: -20 }}
                  >
                    <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
                      <div>
                        <label className="mb-1 block text-sm font-medium text-neutral/70">
                          {t('change_email.current_password')}
                        </label>
                        <Input
                          type="password"
                          placeholder={t('change_email.password_placeholder')}
                          error={errors.currentPassword?.message}
                          {...register('currentPassword')}
                        />
                      </div>
                      <div>
                        <label className="mb-1 block text-sm font-medium text-neutral/70">
                          {t('change_email.new_email')}
                        </label>
                        <Input
                          type="email"
                          placeholder="new.email@example.com"
                          error={errors.newEmail?.message}
                          {...register('newEmail')}
                        />
                      </div>
                      <Button
                        type="submit"
                        disabled={isSubmitting}
                        className="w-full"
                      >
                        {isSubmitting ? (
                          <>
                            <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                            {t('change_email.verifying')}
                          </>
                        ) : (
                          t('change_email.send_verification')
                        )}
                      </Button>
                    </form>
                  </motion.div>
                )}

                {step === 'confirm' && (
                  <motion.div
                    key="confirm"
                    initial={{ opacity: 0, x: 20 }}
                    animate={{ opacity: 1, x: 0 }}
                    exit={{ opacity: 0, x: -20 }}
                  >
                    <div className="mb-6 rounded-lg border border-warning/30 bg-warning/10 p-4">
                      <div className="flex items-start gap-3">
                        <AlertTriangle className="mt-0.5 h-5 w-5 text-warning" />
                        <div>
                          <p className="font-medium text-warning">{t('change_email.verification_sent')}</p>
                          <p className="text-sm text-warning/80">
                            {t('change_email.verification_sent_desc')}
                          </p>
                        </div>
                      </div>
                    </div>

                    <div className="mb-6 rounded-lg border border-neutral/20 p-4">
                      <p className="text-xs font-medium text-neutral/60">{t('change_email.new_email')}</p>
                      <p className="mt-1 font-medium">{verificationEmail}</p>
                    </div>

                    <div className="flex gap-3">
                      <Button
                        variant="outline"
                        onClick={handleBack}
                        className="flex-1"
                      >
                        {t('change_email.cancel')}
                      </Button>
                      <Button
                        className="flex-1"
                        onClick={() => setStep('success')}
                      >
                        {t('change_email.confirm')}
                      </Button>
                    </div>
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
                      {t('change_email.success')}
                    </h3>
                    <p className="mb-6 text-neutral/70">
                      {t('change_email.success_desc')}
                    </p>
                    <Button
                      variant="outline"
                      onClick={() => setStep('verify')}
                      className="gap-2"
                    >
                      <ArrowLeft className="h-4 w-4" />
                      {t('change_email.back_to_form')}
                    </Button>
                  </motion.div>
                )}
              </AnimatePresence>

              {/* Loading State */}
              {verifyMutation.isPending && (
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

export default ChangeEmail
