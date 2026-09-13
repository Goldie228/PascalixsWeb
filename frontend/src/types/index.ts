export interface User {
  id: number
  username: string
  email: string
  role: 'player' | 'moderator' | 'admin'
  createdAt: string
  lastLoginAt?: string
  is_added?: boolean
  is_sponsor?: boolean
  about_me?: string
  nickname?: string
  created_at?: string
  last_login_at?: string
}

export interface AdminUser {
  id: number
  discord_id: string
  discord_username: string
  minecraft_nickname: string | null
  role: string
  is_added: boolean
  is_sponsor: boolean
  created_at: string
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

export interface Punishment {
  id: number
  type: string
  user_id: number
  reason: string
  issuer: string
  issued_at: string
  active: boolean
}

export interface Appeal {
  id: number
  user_id: number
  punishment_id: number
  reason: string
  status: 'pending' | 'approved' | 'rejected'
  created_at: string
}

export interface Notification {
  id: number
  userId: number
  message: string
  type: 'info' | 'warning' | 'error' | 'success'
  read: boolean
  createdAt: string
}

export interface PaginationMeta {
  current_page: number
  total_pages: number
  total_items: number
}

export interface StatsOverview {
  total_users: number
  active_users: number
  total_punishments: number
  active_punishments: number
  total_appeals: number
  pending_appeals: number
  new_users_today: number
  new_users_this_week: number
  punishments_today: number
  punishments_this_week: number
}

export interface Appeal {
  id: number
  user_id: number
  punishment_id: number
  reason: string
  status: 'pending' | 'approved' | 'rejected'
  created_at: string
  player?: {
    id: number
    username: string
  }
  punishment?: {
    id: number
    type: string
    reason: string
  }
  admin_answer?: string
}

export interface Punishment {
  id: number
  type: string
  user_id: number
  reason: string
  issuer: string
  issued_at: string
  active: boolean
  resolved: boolean
  user?: {
    id: number
    username: string
    discord_username?: string
  }
}
