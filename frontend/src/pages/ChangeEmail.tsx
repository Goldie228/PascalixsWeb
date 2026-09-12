import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { Link } from 'react-router-dom'
import { Button } from '@/components/ui/Button'
import { Input } from '@/components/ui/Input'
import { Card } from '@/components/ui/Card'
import { Mail, ArrowLeft } from 'lucide-react'

const changeEmailSchema = z.object({
  currentPassword: z.string().min(1, 'Current password is required'),
  newEmail: z.string().email('Invalid email address'),
  confirmEmail: z.string(),
}).refine((data) => data.newEmail === data.confirmEmail, {
  message: "Emails don't match",
  path: ['confirmEmail'],
})

type ChangeEmailFormData = z.infer<typeof changeEmailSchema>

export default function ChangeEmail() {
  const [isSent, setIsSent] = useState(false)

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<ChangeEmailFormData>({
    resolver: zodResolver(changeEmailSchema),
  })

  const onSubmit = async (data: ChangeEmailFormData) => {
    // TODO: Implement change email API call
    console.log('Changing email:', data)
    setIsSent(true)
  }

  if (isSent) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 p-4">
        <Card className="w-full max-w-md bg-gray-800/50 backdrop-blur-sm border-gray-700">
          <div className="text-center">
            <div className="w-16 h-16 rounded-full bg-green-500/20 flex items-center justify-center mx-auto mb-4">
              <Mail className="w-8 h-8 text-green-400" />
            </div>
            <h1 className="text-2xl font-bold text-white mb-2">Verification Sent</h1>
            <p className="text-gray-400 mb-6">
              We've sent a verification link to your new email address. Please check your inbox and click the link to confirm.
            </p>
            <Link to="/account">
              <Button variant="outline" className="w-full">
                <ArrowLeft className="w-4 h-4 mr-2" />
                Back to Account
              </Button>
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
            <Mail className="w-8 h-8 text-blue-400" />
          </div>
          <h1 className="text-2xl font-bold text-white mb-2">Change Email</h1>
          <p className="text-gray-400">Enter your new email address</p>
        </div>

        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
          <div>
            <Input
              {...register('currentPassword')}
              label="Current Password"
              type="password"
              error={errors.currentPassword?.message}
              disabled={isSubmitting}
            />
          </div>
          <div>
            <Input
              {...register('newEmail')}
              label="New Email"
              type="email"
              error={errors.newEmail?.message}
              disabled={isSubmitting}
            />
          </div>
          <div>
            <Input
              {...register('confirmEmail')}
              label="Confirm New Email"
              type="email"
              error={errors.confirmEmail?.message}
              disabled={isSubmitting}
            />
          </div>
          <Button type="submit" isLoading={isSubmitting} disabled={isSubmitting}>
            Send Verification
          </Button>
        </form>

        <div className="mt-4 text-center">
          <Link to="/account" className="text-gray-400 hover:text-white text-sm transition-colors">
            Cancel
          </Link>
        </div>
      </Card>
    </div>
  )
}
