import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { useNavigate, Link } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { useToast } from '@/components/ui/Toast'
import { Button } from '@/components/ui/Button'
import { Input } from '@/components/ui/Input'
import { Card } from '@/components/ui/Card'
import { Lock } from 'lucide-react'

const resetPasswordSchema = z.object({
  email: z.string().email('Invalid email address'),
})

const newPasswordSchema = z.object({
  password: z.string()
    .min(8, 'Password must be at least 8 characters')
    .regex(/[A-Z]/, 'Password must contain an uppercase letter')
    .regex(/[0-9]/, 'Password must contain a number'),
  confirmPassword: z.string(),
}).refine((data) => data.password === data.confirmPassword, {
  message: "Passwords don't match",
  path: ['confirmPassword'],
})

type ResetPasswordFormData = z.infer<typeof resetPasswordSchema>
type NewPasswordFormData = z.infer<typeof newPasswordSchema>

export default function ResetPassword() {
  const { t } = useTranslation()
  const { success: toastSuccess } = useToast()
  const navigate = useNavigate()
  const [step, setStep] = useState<'email' | 'new-password'>('email')
  const [_isSent, setIsSent] = useState(false)

  const {
    register: registerEmail,
    handleSubmit: handleSubmitEmail,
    formState: { errors: emailErrors, isSubmitting: emailSubmitting },
  } = useForm<ResetPasswordFormData>({
    resolver: zodResolver(resetPasswordSchema),
  })

  const {
    register: registerPassword,
    handleSubmit: handleSubmitPassword,
    formState: { errors: passwordErrors, isSubmitting: passwordSubmitting },
  } = useForm<NewPasswordFormData>({
    resolver: zodResolver(newPasswordSchema),
  })

  const onSendEmail = async (data: ResetPasswordFormData) => {
    // TODO: Implement send reset email API call
    console.log('Sending reset email:', data.email)
    setIsSent(true)
    setStep('new-password')
    toastSuccess(t('reset_password.send_reset_link'))
  }

  const onResetPassword = async (_data: NewPasswordFormData) => {
    // TODO: Implement reset password API call
    toastSuccess(t('reset_password.reset_password_btn'))
    navigate('/login')
  }

  if (step === 'email') {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 p-4">
        <Card className="w-full max-w-md bg-gray-800/50 backdrop-blur-sm border-gray-700">
          <div className="text-center mb-8">
            <div className="w-16 h-16 rounded-full bg-gray-700 flex items-center justify-center mx-auto mb-4">
              <Lock className="w-8 h-8 text-blue-400" />
            </div>
            <h1 className="text-2xl font-bold text-white mb-2">{t('reset_password.title')}</h1>
            <p className="text-gray-400">{t('reset_password.subtitle')}</p>
          </div>

          <form onSubmit={handleSubmitEmail(onSendEmail)} className="space-y-4">
            <div>
              <Input
                {...registerEmail('email')}
                label={t('reset_password.email')}
                type="email"
                error={emailErrors.email?.message}
                disabled={emailSubmitting}
              />
            </div>
            <Button type="submit" isLoading={emailSubmitting} disabled={emailSubmitting}>
              {t('reset_password.send_reset_link')}
            </Button>
          </form>

          <div className="mt-4 text-center">
            <Link to="/login" className="text-gray-400 hover:text-white text-sm transition-colors">
              {t('reset_password.back_to_login')}
            </Link>
          </div>
        </Card>
      </div>
    )
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 p-4">
      <Card className="w-full max-w-md bg-gray-800/50 backdrop-blur-sm border-gray-700">
        <div className="text-center mb-8">
          <div className="w-16 h-16 rounded-full bg-gray-700 flex items-center justify-center mx-auto mb-4">
            <Lock className="w-8 h-8 text-blue-400" />
          </div>
          <h1 className="text-2xl font-bold text-white mb-2">{t('reset_password.new_password')}</h1>
          <p className="text-gray-400">{t('reset_password.new_password_subtitle')}</p>
        </div>

        <form onSubmit={handleSubmitPassword(onResetPassword)} className="space-y-4">
          <div>
            <Input
              {...registerPassword('password')}
              label={t('reset_password.new_password')}
              type="password"
              error={passwordErrors.password?.message}
              disabled={passwordSubmitting}
            />
          </div>
          <div>
            <Input
              {...registerPassword('confirmPassword')}
              label={t('reset_password.confirm_new_password')}
              type="password"
              error={passwordErrors.confirmPassword?.message}
              disabled={passwordSubmitting}
            />
          </div>
          <Button type="submit" isLoading={passwordSubmitting} disabled={passwordSubmitting}>
            {t('reset_password.reset_password_btn')}
          </Button>
        </form>

        <div className="mt-4 text-center">
          <Link to="/login" className="text-gray-400 hover:text-white text-sm transition-colors">
            {t('reset_password.back_to_login')}
          </Link>
        </div>
      </Card>
    </div>
  )
}
