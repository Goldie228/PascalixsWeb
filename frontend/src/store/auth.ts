import { create } from 'zustand'
import { authApi } from '@/services/api'
import type { User } from '@/types'

interface AuthState {
  user: User | null
  token: string | null
  isAuthenticated: boolean
  isLoading: boolean
  error: string | null
  login: (username: string, password: string) => Promise<void>
  register: (data: {
    username: string
    email: string
    password: string
    passwordConfirmation: string
  }) => Promise<void>
  logout: () => Promise<void>
  fetchUser: () => Promise<void>
}

export const useAuthStore = create<AuthState>((set, get) => ({
  user: null,
  token: localStorage.getItem('token'),
  isAuthenticated: !!localStorage.getItem('token'),
  isLoading: false,
  error: null,

  login: async (username, password) => {
    set({ isLoading: true, error: null })
    try {
      const response = await authApi.login(username, password)
      const { token, refresh_token } = response.data
      localStorage.setItem('token', token)
      if (refresh_token) localStorage.setItem('refresh_token', refresh_token)
      set({ token, isAuthenticated: true, isLoading: false, error: null })
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Login failed'
      set({ isLoading: false, error: message })
      throw error
    }
  },

  register: async (data) => {
    set({ isLoading: true, error: null })
    try {
      await authApi.register(data)
      set({ isLoading: false, error: null })
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Registration failed'
      set({ isLoading: false, error: message })
      throw error
    }
  },

  logout: async () => {
    try {
      await authApi.logout()
    } finally {
      localStorage.removeItem('token')
      localStorage.removeItem('refresh_token')
      set({ user: null, token: null, isAuthenticated: false, error: null })
    }
  },

  fetchUser: async () => {
    const token = localStorage.getItem('token')
    if (!token) {
      set({ isAuthenticated: false })
      return
    }
    try {
      const response = await authApi.me()
      set({ user: response.data, isAuthenticated: true, error: null })
    } catch {
      localStorage.removeItem('token')
      localStorage.removeItem('refresh_token')
      set({ user: null, token: null, isAuthenticated: false, error: null })
    }
  },
}))
