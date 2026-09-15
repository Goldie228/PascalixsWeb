import api from './api'

export interface EmailLoginResponse {
  status: 'success' | 'error'
  message?: string
  errors?: Record<string, string[]>
  email?: string
}

export const emailLoginApi = {
  // Send login link to email
  sendLink: (email: string) =>
    api.post<EmailLoginResponse>('/sessions/email_login', { email }),

  // Resend login link
  resendLink: (email: string) =>
    api.post<EmailLoginResponse>('/sessions/resend_email_login', { email }),

  // Verify email login link
  verifyLink: (token: string) =>
    api.get<EmailLoginResponse>(`/sessions/email_login/verify/${token}`),

  // Legacy alias (deprecated, use sendLink instead)
  legacySendLink: (email: string) =>
    api.post('/sessions/email_login', { email }),
}

export default emailLoginApi
