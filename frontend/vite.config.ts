import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

const apiBaseUrl = import.meta.env.VITE_API_BASE_URL || 'http://localhost:3000'

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  server: {
    port: 5173,
    proxy: {
      // Identity service (auth, users)
      '/api/v1/auth': {
        target: apiBaseUrl,
        changeOrigin: true,
      },
      '/api/v1/users': {
        target: apiBaseUrl,
        changeOrigin: true,
      },
      // Game service (server stats, punishments, game data)
      '/api/v1/servers': {
        target: apiBaseUrl,
        changeOrigin: true,
      },
      '/api/v1/punishments': {
        target: apiBaseUrl,
        changeOrigin: true,
      },
      '/api/v1/game': {
        target: apiBaseUrl,
        changeOrigin: true,
      },
      '/api/v1/news': {
        target: apiBaseUrl,
        changeOrigin: true,
      },
      '/api/v1/votes': {
        target: apiBaseUrl,
        changeOrigin: true,
      },
      // Notification service
      '/api/v1/notifications': {
        target: apiBaseUrl,
        changeOrigin: true,
      },
      // Admin API (identity service)
      '/api/v1/admin': {
        target: apiBaseUrl,
        changeOrigin: true,
      },
    },
  },
})
