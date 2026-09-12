import axios from 'axios'

let isRefreshing = false
const failedQueue: Array<{
  resolve: (token: string) => void
  reject: (error: unknown) => void
}> = []

const processQueue = (error: unknown | null, token: string | null = null) => {
  failedQueue.forEach((prom) => {
    if (error) prom.reject(error)
    else prom.resolve(token!)
  })
  failedQueue.length = 0
}

export const refreshToken = async (): Promise<string> => {
  const refresh_token = localStorage.getItem('refresh_token')
  if (!refresh_token) throw new Error('No refresh token')

  const api = axios.create({
    baseURL: '/api/v1',
    headers: {
      'Content-Type': 'application/json',
    },
  })

  const { data } = await api.post('/auth/refresh', { refresh_token })
  localStorage.setItem('token', data.token)
  localStorage.setItem('refresh_token', data.refresh_token)
  return data.token
}

export const intercept401 = async (error: any) => {
  const originalRequest = error.config
  if (error.response?.status === 401 && !originalRequest._retry) {
    if (isRefreshing) {
      return new Promise<string>((resolve, reject) => {
        failedQueue.push({ resolve, reject })
      })
        .then((token) => {
          originalRequest.headers.Authorization = `Bearer ${token}`
          return axios(originalRequest)
        })
        .catch((err) => Promise.reject(err))
    }

    originalRequest._retry = true
    isRefreshing = true

    try {
      const token = await refreshToken()
      processQueue(null, token)
      originalRequest.headers.Authorization = `Bearer ${token}`
      return axios(originalRequest)
    } catch (refreshError) {
      processQueue(refreshError, null)
      localStorage.removeItem('token')
      localStorage.removeItem('refresh_token')
      window.location.href = '/login'
      return Promise.reject(refreshError)
    } finally {
      isRefreshing = false
    }
  }
  return Promise.reject(error)
}
