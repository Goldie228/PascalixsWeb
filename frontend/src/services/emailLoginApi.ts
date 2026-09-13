import api from './api'

export const emailLoginApi = {
  sendLink: (email: string) =>
    api.post('/sessions/email_login', { email }),
}

export default emailLoginApi
