import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { motion } from 'framer-motion'
import { useTranslation } from 'react-i18next'
import { useToast } from '@/components/ui/Toast'
import { Button } from '@/components/ui/Button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { Input } from '@/components/ui/Input'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import api from '@/services/api'

const passwordSchema = z
  .object({
    currentPassword: z.string().min(1, 'Current password is required'),
    newPassword: z
      .string()
      .min(8, 'Password must be at least 8 characters')
      .regex(/[A-Z]/, 'Password must contain an uppercase letter')
      .regex(/[0-9]/, 'Password must contain a number'),
    confirmPassword: z.string(),
  })
  .refine((data) => data.newPassword === data.confirmPassword, {
    message: "Passwords don't match",
    path: ['confirmPassword'],
  })

type PasswordFormData = z.infer<typeof passwordSchema>

function Settings() {
  const { t } = useTranslation()
  const { success: showSuccess, error: showError } = useToast()
  const queryClient = useQueryClient()
  const [email, setEmail] = useState('')

  const { data: profileUser, isLoading } = useQuery({
    queryKey: ['user-settings'],
    queryFn: async () => {
      const response = await api.get('/users/me')
      setEmail(response.data.email || '')
      return response.data
    },
    staleTime: 1000 * 60 * 5,
  })

  const updateProfile = useMutation({
    mutationFn: async (data: { email: string }) => {
      await api.put('/users/me', data)
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['user-settings'] })
      showSuccess(t('settings.save_success'))
    },
    onError: () => {
      showError(t('settings.save_error'))
    },
  })

  const handleSave = async () => {
    await updateProfile.mutateAsync({ email })
  }

  const {
    register: registerPassword,
    handleSubmit: handlePasswordSubmit,
    formState: { errors: passwordErrors, isSubmitting: passwordSubmitting },
  } = useForm<PasswordFormData>({
    resolver: zodResolver(passwordSchema),
  })

  const handlePasswordChange = async (data: PasswordFormData) => {
    // TODO: Implement password change API call
    console.log('Password change:', data)
    showSuccess(t('settings.password_change_soon'))
  }

  if (isLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <LoadingSpinner size="lg" />
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-base-100 py-8">
      <div className="container mx-auto max-w-2xl px-4">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
        >
          <h1 className="mb-6 text-3xl font-bold text-base-content">{t('settings.title')}</h1>

          <Card>
            <CardHeader>
              <CardTitle className="text-xl">{t('settings.account_settings')}</CardTitle>
            </CardHeader>
            <CardContent className="space-y-6">
              <div>
                <label className="text-sm font-medium text-base-content">{t('settings.username')}</label>
                <Input
                  value={profileUser?.username || ''}
                  disabled
                  className="mt-1"
                />
                <p className="mt-1 text-xs text-neutral/50">{t('settings.username_cannot_change')}</p>
              </div>

              <div>
                <label className="text-sm font-medium text-base-content">{t('settings.email')}</label>
                <Input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="mt-1"
                  placeholder="your@email.com"
                />
              </div>

              <div>
                <label className="text-sm font-medium text-base-content">{t('settings.role')}</label>
                <Input
                  value={profileUser?.role ? profileUser.role : ''}
                  disabled
                  className="mt-1"
                />
              </div>

              <div className="flex justify-end gap-3">
                <Button
                  variant="outline"
                  onClick={() => setEmail(profileUser?.email || '')}
                >
                  {t('settings.reset')}
                </Button>
                <Button onClick={handleSave} disabled={updateProfile.isPending}>
                  {updateProfile.isPending ? (
                    <LoadingSpinner size="sm" />
                  ) : (
                    t('settings.save_changes')
                  )}
                </Button>
              </div>
            </CardContent>
          </Card>

          {/* Change Password */}
          <Card className="mt-6">
            <CardHeader>
              <CardTitle className="text-xl">{t('settings.change_password')}</CardTitle>
            </CardHeader>
            <CardContent>
              <form onSubmit={handlePasswordSubmit(handlePasswordChange)} className="space-y-4">
                <Input
                  {...registerPassword('currentPassword')}
                  label={t('settings.current_password')}
                  type="password"
                  error={passwordErrors.currentPassword?.message}
                  disabled={passwordSubmitting}
                />
                <Input
                  {...registerPassword('newPassword')}
                  label={t('settings.new_password')}
                  type="password"
                  error={passwordErrors.newPassword?.message}
                  disabled={passwordSubmitting}
                />
                <Input
                  {...registerPassword('confirmPassword')}
                  label={t('settings.confirm_new_password')}
                  type="password"
                  error={passwordErrors.confirmPassword?.message}
                  disabled={passwordSubmitting}
                />
                <Button type="submit" isLoading={passwordSubmitting} disabled={passwordSubmitting}>
                  {t('settings.change_password')}
                </Button>
              </form>
            </CardContent>
          </Card>

          {/* Danger Zone */}
          <Card className="mt-6 border-error/30">
            <CardHeader>
              <CardTitle className="text-lg text-error">{t('settings.danger_zone')}</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="mb-4 text-sm text-neutral/70">
                {t('settings.logout_message')}
              </p>
            </CardContent>
          </Card>
        </motion.div>
      </div>
    </div>
  )
}

export default Settings
