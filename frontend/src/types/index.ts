export interface User {
  id: number
  username: string
  email: string
  role: 'player' | 'moderator' | 'admin'
  createdAt: string
  lastLoginAt?: string
}

export interface ServerStats {
  onlinePlayers: number
  maxPlayers: number
  uptime: string
  version: string
}

export interface NewsItem {
  id: number
  title: string
  content: string
  createdAt: string
  author: string
}

export interface Vote {
  id: number
  site: string
  userId: number
  createdAt: string
}
