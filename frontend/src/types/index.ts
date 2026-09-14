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
  two_factor_enabled?: boolean
  ban_reason?: string
  ban_expires_at?: string
  is_banned?: boolean
  is_youtube_bound?: boolean
  is_tiktok_bound?: boolean
  is_twitch_bound?: boolean
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
  expires_at?: string
  active: boolean
  resolved?: boolean
  status?: string
  appeal?: {
    id: number | null
    status: 'pending' | 'rejected' | 'accepted' | null
    can_repeal: boolean
    message: string
    admin_comment: string
  }
  user?: {
    id: number
    username: string
    discord_username?: string
  }
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
  expires_at?: string
  active: boolean
  resolved?: boolean
  status?: string
  appeal?: {
    id: number | null
    status: 'pending' | 'rejected' | 'accepted' | null
    can_repeal: boolean
    message: string
    admin_comment: string
  }
  user?: {
    id: number
    username: string
    discord_username?: string
  }
}

export interface DiscordAvatar {
  id: number
  user_id: number
  username: string
  url: string
  status: 'pending' | 'approved' | 'rejected'
  created_at: string
  user?: { username: string }
}

export interface Complaint {
  id: number
  reporter_id: number
  reported_id: number
  reporter_username: string
  reported_username: string
  reason: string
  status: 'open' | 'resolved' | 'dismissed'
  created_at: string
}

export interface Product {
  id: number
  name: string
  description: string
  price: number
  currency: string
  active: boolean
  created_at: string
}

export interface PunishmentReason {
  id: number
  name: string
  description: string
  active: boolean
  created_at: string
}

export interface RemovedPlayer {
  id: number
  nickname: string
  reason: string
  banned_at: string
  restored_at?: string
}

export interface GalleryAlbum {
  id: number
  title: string
  description: string
  photos_count: number
  created_at: string
}

export interface AdminPlayer {
  id: number
  nickname: string
  email: string
  role: string
  is_banned: boolean
  ban_reason?: string
  created_at: string
}

export interface Purchase {
  id: number
  user_id: number
  username: string
  product_name: string
  amount: number
  currency: string
  status: 'pending' | 'completed' | 'failed' | 'refunded'
  payment_method: string
  created_at: string
  updated_at: string
}

export interface ReportAttachment {
  id: number | string
  url: string
  content_type: string
  file_size?: number
  is_new?: boolean
  type?: 'existing' | 'uploaded'
}

export interface Report {
  id?: number
  title: string
  description: string
  reported_user_id: number
  attachments: ReportAttachment[]
  existingFiles?: ReportAttachment[]
  filesToDelete?: number[]
}

export interface AvatarData {
  id: number
  url: string
  status: 'pending' | 'approved' | 'rejected' | 'draft' | 'none'
  created_at: string
}

export interface IntegrationBinding {
  youtube_url?: string
  youtube_channel_name?: string
  twitch_url?: string
  twitch_channel_name?: string
  tiktok_url?: string
  tiktok_channel_name?: string
}

export interface PunishmentAppealData {
  id: number
  type: string
  reason: string
  status: string
  expires_at: string
  appeal?: {
    id: number | null
    status: 'pending' | 'rejected' | 'accepted' | null
    can_repeal: boolean
    message: string
    admin_comment: string
  }
}
