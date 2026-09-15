import { useState, useMemo } from 'react'
import { motion } from 'framer-motion'
import { useTranslation } from 'react-i18next'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { Search, Pencil, Ban, VolumeX, Lock, Trash2, X, User, Shield, AlertTriangle } from 'lucide-react'
import { Card, CardContent } from '@/components/ui/Card'
import { Button } from '@/components/ui/Button'
import { Badge } from '@/components/ui/Badge'
import { Modal } from '@/components/ui/Modal'
import { Input } from '@/components/ui/Input'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import { useToast } from '@/components/ui/Toast'
import AdminLayout from '@/components/admin/AdminLayout'
import { adminApi } from '@/services/adminApi'
import type { AdminPlayer } from '@/types'

function StatusBadge({ player }: { player: AdminPlayer }) {
  if (player.is_banned) {
    return (
      <Badge variant="error">
        {player.ban_reason ? `${player.ban_reason}` : 'Banned'}
      </Badge>
    )
  }
  return <Badge variant="success">Active</Badge>
}

type EditSubTab = 'info' | 'social' | 'security'

function AdminPlayers() {
  const { t } = useTranslation()
  const { success: showSuccess, error: showError } = useToast()
  const queryClient = useQueryClient()

  const [page, setPage] = useState(1)
  const [perPage, setPerPage] = useState(25)
  const [search, setSearch] = useState('')
  const [selected, setSelected] = useState<AdminPlayer | null>(null)
  const [modalTab, setModalTab] = useState<'edit' | 'ban' | 'mute' | 'password' | 'delete' | 'cancel' | 'report'>('edit')
  const [editSubTab, setEditSubTab] = useState<EditSubTab>('info')

  // Form states
  const [editEmail, setEditEmail] = useState('')
  const [editRole, setEditRole] = useState('')
  const [banReason, setBanReason] = useState('')
  const [banDuration, setBanDuration] = useState('')
  const [muteReason, setMuteReason] = useState('')
  const [muteDuration, setMuteDuration] = useState('')
  const [newPassword, setNewPassword] = useState('')
  const [cancelReason, setCancelReason] = useState('')
  const [reportReason, setReportReason] = useState('')
  const [reportUserId, setReportUserId] = useState('')

  const { data, isLoading } = useQuery({
    queryKey: ['admin-players', page, perPage],
    queryFn: () => adminApi.getPlayers({ page, per_page: perPage }),
    staleTime: 1000 * 60 * 5,
  })

  const players = data?.data?.players ?? []
  const total = data?.data?.total ?? 0
  const totalPages = Math.ceil(total / perPage) || 1

  const filteredPlayers = useMemo(() => {
    if (!search) return players
    const q = search.toLowerCase()
    return players.filter(
      (p) => p.nickname.toLowerCase().includes(q) || p.email.toLowerCase().includes(q),
    )
  }, [players, search])

  const resetPage = () => setPage(1)

  const openModal = (player: AdminPlayer, tab: typeof modalTab) => {
    setSelected(player)
    setModalTab(tab)
    setEditSubTab('info')
    if (tab === 'edit') {
      setEditEmail(player.email)
      setEditRole(player.role)
    }
    setBanReason('')
    setBanDuration('')
    setMuteReason('')
    setMuteDuration('')
    setNewPassword('')
    setCancelReason('')
    setReportReason('')
    setReportUserId('')
  }

  const closeModal = () => { setSelected(null); setModalTab('edit') }

  const update = useMutation({
    mutationFn: (d: { nickname: string; email?: string; role?: string }) =>
      adminApi.updatePlayer(d.nickname, { email: d.email, role: d.role }),
    onSuccess: () => {
      showSuccess(t('admin.players.updated', 'Player updated'))
      queryClient.invalidateQueries({ queryKey: ['admin-players'] })
      closeModal()
    },
    onError: () => showError(t('admin.players.update_error', 'Failed to update player')),
  })

  const ban = useMutation({
    mutationFn: (d: { nickname: string; reason: string; duration?: string }) =>
      adminApi.banPlayer(d.nickname, { reason: d.reason, duration: d.duration || undefined }),
    onSuccess: () => {
      showSuccess(t('admin.players.banned', 'Player banned'))
      queryClient.invalidateQueries({ queryKey: ['admin-players'] })
      closeModal()
    },
    onError: () => showError(t('admin.players.ban_error', 'Failed to ban player')),
  })

  const mute = useMutation({
    mutationFn: (d: { nickname: string; reason: string; duration: string }) =>
      adminApi.mutePlayer(d.nickname, { reason: d.reason, duration: d.duration }),
    onSuccess: () => {
      showSuccess(t('admin.players.muted', 'Player muted'))
      queryClient.invalidateQueries({ queryKey: ['admin-players'] })
      closeModal()
    },
    onError: () => showError(t('admin.players.mute_error', 'Failed to mute player')),
  })

  const changePassword = useMutation({
    mutationFn: (d: { nickname: string; password: string }) =>
      adminApi.changePlayerPassword(d.nickname, { password: d.password }),
    onSuccess: () => {
      showSuccess(t('admin.players.password_updated', 'Password updated'))
      queryClient.invalidateQueries({ queryKey: ['admin-players'] })
      closeModal()
    },
    onError: () => showError(t('admin.players.password_error', 'Failed to change password')),
  })

  const cancelPunishment = useMutation({
    mutationFn: (d: { nickname: string; reason: string }) =>
      adminApi.cancelPunishment(d.nickname, { reason: d.reason }),
    onSuccess: () => {
      showSuccess(t('admin.players.cancel_success', 'Punishment cancelled'))
      queryClient.invalidateQueries({ queryKey: ['admin-players'] })
      closeModal()
    },
    onError: () => showError(t('admin.players.cancel_error', 'Failed to cancel punishment')),
  })

  const deletePlayer = useMutation({
    mutationFn: (nickname: string) => adminApi.deletePlayer(nickname),
    onSuccess: () => {
      showSuccess(t('admin.players.deleted', 'Player deleted'))
      queryClient.invalidateQueries({ queryKey: ['admin-players'] })
      closeModal()
    },
    onError: () => showError(t('admin.players.delete_error', 'Failed to delete player')),
  })

  const reportPlayer = useMutation({
    mutationFn: (d: { nickname: string; reported_user_id: number; reason: string }) =>
      adminApi.reportPlayer(d.nickname, {
        reported_user_id: Number(d.reported_user_id),
        reason: d.reason,
      }),
    onSuccess: () => {
      showSuccess(t('admin.players.report_success', 'Report submitted'))
      queryClient.invalidateQueries({ queryKey: ['admin-players'] })
      closeModal()
    },
    onError: () => showError(t('admin.players.report_error', 'Failed to submit report')),
  })

  const editSubTabs: { key: EditSubTab; label: string; icon: React.ReactNode }[] = [
    { key: 'info', label: t('admin.players.edit_tab_info', 'Info'), icon: <User className="w-4 h-4" /> },
    { key: 'social', label: t('admin.players.edit_tab_social', 'Social'), icon: <Shield className="w-4 h-4" /> },
    { key: 'security', label: t('admin.players.edit_tab_security', 'Security'), icon: <Lock className="w-4 h-4" /> },
  ]

  return (
    <AdminLayout>
      <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.3 }}>
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-base-content">{t('admin.players.title', 'Players')}</h1>
          <p className="text-sm text-neutral/60">{t('admin.players.manage_desc', 'Manage registered players')}</p>
        </div>

        {/* Filters */}
        <Card className="mb-4">
          <CardContent className="p-4">
            <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
              <div className="relative sm:col-span-2">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-neutral/50" />
                <Input
                  value={search}
                  onChange={(e) => { setSearch(e.target.value); resetPage() }}
                  placeholder={t('admin.players.search', 'Search players...')}
                  className="pl-10"
                />
              </div>
              <div className="flex items-end gap-2">
                <label className="text-sm text-neutral/60 whitespace-nowrap">{t('admin.players.per_page', 'Records per page')}</label>
                <select
                  value={perPage}
                  onChange={(e) => { setPerPage(Number(e.target.value)); resetPage() }}
                  className="h-10 w-20 rounded-lg border border-neutral/20 bg-base-200 px-2 text-sm text-base-content focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
                >
                  <option value={25}>25</option>
                  <option value={50}>50</option>
                  <option value={75}>75</option>
                </select>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Content */}
        <Card>
          <CardContent className="p-0">
            {isLoading ? (
              <div className="p-8 text-center">
                <LoadingSpinner size="md" />
                <p className="text-neutral/60 mt-2">{t('admin.players.loading', 'Loading players...')}</p>
              </div>
            ) : filteredPlayers.length === 0 ? (
              <div className="p-8 text-center text-neutral/60">{t('admin.players.no_data', 'No players found')}</div>
            ) : (
              <>
                {/* Desktop table */}
                <div className="hidden overflow-x-auto md:block">
                  <table className="w-full">
                    <thead>
                      <tr className="border-b border-base-300">
                        <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.players.table.nickname', 'Nickname')}</th>
                        <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.players.table.email', 'Email')}</th>
                        <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.players.table.role', 'Role')}</th>
                        <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.players.table.status', 'Status')}</th>
                        <th className="text-left p-4 text-sm font-medium text-neutral/60">{t('admin.players.table.date', 'Created')}</th>
                        <th className="text-right p-4 text-sm font-medium text-neutral/60">{t('admin.players.table.actions', 'Actions')}</th>
                      </tr>
                    </thead>
                    <tbody>
                      {filteredPlayers.map((player) => (
                        <tr key={player.id} className="border-b border-base-300 hover:bg-base-200/50 transition-colors">
                          <td className="p-4 font-medium text-base-content">{player.nickname}</td>
                          <td className="p-4 text-sm text-neutral/60">{player.email || '—'}</td>
                          <td className="p-4">
                            <Badge variant={player.role === 'admin' ? 'error' : player.role === 'moderator' ? 'warning' : 'default'}>
                              {player.role}
                            </Badge>
                          </td>
                          <td className="p-4"><StatusBadge player={player} /></td>
                          <td className="p-4 text-sm text-neutral/60">{new Date(player.created_at).toLocaleDateString()}</td>
                          <td className="p-4">
                            <div className="flex justify-end gap-1">
                              <Button variant="ghost" size="icon" className="h-8 w-8" onClick={() => openModal(player, 'edit')} title={t('admin.players.edit', 'Edit')}>
                                <Pencil className="w-3.5 h-3.5" />
                              </Button>
                              {!player.is_banned && (
                                <Button variant="ghost" size="icon" className="h-8 w-8 text-error" onClick={() => openModal(player, 'ban')} title={t('admin.players.ban', 'Ban')}>
                                  <Ban className="w-3.5 h-3.5" />
                                </Button>
                              )}
                              <Button variant="ghost" size="icon" className="h-8 w-8 text-warning" onClick={() => openModal(player, 'mute')} title={t('admin.players.mute', 'Mute')}>
                                <VolumeX className="w-3.5 h-3.5" />
                              </Button>
                              <Button variant="ghost" size="icon" className="h-8 w-8" onClick={() => openModal(player, 'password')} title={t('admin.players.change_password', 'Change Password')}>
                                <Lock className="w-3.5 h-3.5" />
                              </Button>
                              {player.is_banned && (
                                <Button variant="ghost" size="icon" className="h-8 w-8 text-info" onClick={() => openModal(player, 'cancel')} title={t('admin.players.cancel_punishment', 'Cancel Punishment')}>
                                  <X className="w-3.5 h-3.5" />
                                </Button>
                              )}
                              <Button variant="ghost" size="icon" className="h-8 w-8 text-warning" onClick={() => openModal(player, 'report')} title={t('admin.players.report', 'Report')}>
                                <AlertTriangle className="w-3.5 h-3.5" />
                              </Button>
                              <Button variant="ghost" size="icon" className="h-8 w-8" onClick={() => openModal(player, 'delete')} title={t('admin.players.delete', 'Delete')}>
                                <Trash2 className="w-3.5 h-3.5" />
                              </Button>
                            </div>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>

                {/* Mobile cards */}
                <div className="md:hidden divide-y divide-base-300">
                  {filteredPlayers.map((player) => (
                    <div key={player.id} className="p-4 space-y-3">
                      <div className="flex items-center justify-between">
                        <div>
                          <p className="font-medium text-base-content">{player.nickname}</p>
                          <p className="text-xs text-neutral/60">{player.email || '—'}</p>
                        </div>
                        <StatusBadge player={player} />
                      </div>
                      <div className="flex items-center justify-between text-xs text-neutral/60">
                        <Badge variant={player.role === 'admin' ? 'error' : player.role === 'moderator' ? 'warning' : 'default'}>{player.role}</Badge>
                        <span>{new Date(player.created_at).toLocaleDateString()}</span>
                      </div>
                      <div className="flex flex-wrap gap-1">
                        <Button variant="ghost" size="sm" className="flex-1" onClick={() => openModal(player, 'edit')}>
                          <Pencil className="w-3.5 h-3.5 mr-1" />{t('admin.players.edit', 'Edit')}
                        </Button>
                        {!player.is_banned && (
                          <Button variant="ghost" size="sm" className="flex-1 text-error" onClick={() => openModal(player, 'ban')}>
                            <Ban className="w-3.5 h-3.5 mr-1" />{t('admin.players.ban', 'Ban')}
                          </Button>
                        )}
                        <Button variant="ghost" size="sm" className="flex-1 text-warning" onClick={() => openModal(player, 'mute')}>
                          <VolumeX className="w-3.5 h-3.5 mr-1" />{t('admin.players.mute', 'Mute')}
                        </Button>
                        <Button variant="ghost" size="sm" className="flex-1" onClick={() => openModal(player, 'password')}>
                          <Lock className="w-3.5 h-3.5 mr-1" />{t('admin.players.change_password', 'Password')}
                        </Button>
                        {player.is_banned && (
                          <Button variant="ghost" size="sm" className="flex-1 text-info" onClick={() => openModal(player, 'cancel')}>
                            <X className="w-3.5 h-3.5 mr-1" />{t('admin.players.cancel_punishment', 'Cancel')}
                          </Button>
                        )}
                        <Button variant="ghost" size="sm" className="flex-1 text-warning" onClick={() => openModal(player, 'report')}>
                          <AlertTriangle className="w-3.5 h-3.5 mr-1" />{t('admin.players.report', 'Report')}
                        </Button>
                        <Button variant="ghost" size="sm" className="flex-1" onClick={() => openModal(player, 'delete')}>
                          <Trash2 className="w-3.5 h-3.5 mr-1" />{t('admin.players.delete', 'Delete')}
                        </Button>
                      </div>
                    </div>
                  ))}
                </div>
              </>
            )}

            {/* Pagination */}
            {totalPages > 1 && (
              <div className="p-4 flex items-center justify-between border-t border-base-300">
                <p className="text-sm text-neutral/60">
                  {t('admin.players.showing', 'Showing')} {filteredPlayers.length} / {total}
                </p>
                <div className="flex items-center gap-2">
                  <Button variant="outline" size="sm" onClick={() => setPage(Math.max(1, page - 1))} disabled={page === 1}>
                    {t('admin.previous', 'Prev')}
                  </Button>
                  <span className="text-neutral/60 text-sm px-2">{page} / {totalPages}</span>
                  <Button variant="outline" size="sm" onClick={() => setPage(Math.min(totalPages, page + 1))} disabled={page === totalPages}>
                    {t('admin.next', 'Next')}
                  </Button>
                </div>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Action Modal */}
        <Modal isOpen={!!selected} onClose={closeModal} title={
          {
            edit: t('admin.players.edit_title', 'Edit Player'),
            ban: t('admin.players.ban_title', 'Ban Player'),
            mute: t('admin.players.mute_title', 'Mute Player'),
            password: t('admin.players.password_title', 'Change Password'),
            delete: t('admin.players.delete_title', 'Delete Account'),
            cancel: t('admin.players.cancel_title', 'Cancel Punishment'),
            report: t('admin.players.report_title', 'Report Player'),
          }[modalTab]
        } size="md">
          {selected && (
            <div className="space-y-4">
              {/* Edit with sub-tabs */}
              {modalTab === 'edit' && (
                <>
                  {/* Sub-tabs */}
                  <div className="flex gap-1 border-b border-base-300 pb-0">
                    {editSubTabs.map((tab) => (
                      <button
                        key={tab.key}
                        type="button"
                        onClick={() => setEditSubTab(tab.key)}
                        className={`flex items-center gap-2 px-4 py-2 text-sm font-medium border-b-2 transition-colors ${
                          editSubTab === tab.key
                            ? 'border-primary text-primary'
                            : 'border-transparent text-neutral/60 hover:text-base-content'
                        }`}
                      >
                        {tab.icon}
                        {tab.label}
                      </button>
                    ))}
                  </div>

                  {/* Info tab */}
                  {editSubTab === 'info' && (
                    <div className="space-y-4 pt-4">
                      <div>
                        <label className="text-sm font-medium text-base-content">{t('admin.players.nickname', 'Nickname')}</label>
                        <p className="text-base-content font-medium mt-1">{selected.nickname}</p>
                      </div>
                      <Input
                        label={t('admin.players.email_label', 'Email')}
                        value={editEmail}
                        onChange={(e) => setEditEmail(e.target.value)}
                      />
                      <div className="flex gap-3 pt-2">
                        <Button className="flex-1" onClick={() => update.mutate({ nickname: selected.nickname, email: editEmail, role: editRole })} isLoading={update.isPending}>
                          {t('admin.players.save', 'Save')}
                        </Button>
                        <Button variant="outline" className="flex-1" onClick={closeModal}>
                          {t('admin.players.cancel', 'Cancel')}
                        </Button>
                      </div>
                    </div>
                  )}

                  {/* Social tab */}
                  {editSubTab === 'social' && (
                    <div className="space-y-4 pt-4">
                      <div className="p-4 bg-base-200 rounded-lg">
                        <p className="text-sm text-neutral/60">{t('admin.players.social_info', 'Social integrations (YouTube, Twitch, TikTok)')}</p>
                        <p className="text-sm text-base-content mt-1">{t('admin.players.social_info_desc', 'Manage player social media links')}</p>
                      </div>
                      <div className="flex gap-3 pt-2">
                        <Button variant="outline" className="flex-1" onClick={closeModal}>
                          {t('admin.players.close', 'Close')}
                        </Button>
                      </div>
                    </div>
                  )}

                  {/* Security tab */}
                  {editSubTab === 'security' && (
                    <div className="space-y-4 pt-4">
                      <div>
                        <label className="text-sm font-medium text-base-content">{t('admin.players.role_label', 'Role')}</label>
                        <select
                          value={editRole}
                          onChange={(e) => setEditRole(e.target.value)}
                          className="mt-1 w-full rounded-lg border border-neutral/20 bg-base-200 px-3 py-2 text-sm text-base-content focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
                        >
                          <option value="player">Player</option>
                          <option value="moderator">Moderator</option>
                          <option value="admin">Admin</option>
                        </select>
                      </div>
                      <div className="flex gap-3 pt-2">
                        <Button className="flex-1" onClick={() => update.mutate({ nickname: selected.nickname, email: editEmail, role: editRole })} isLoading={update.isPending}>
                          {t('admin.players.save', 'Save')}
                        </Button>
                        <Button variant="outline" className="flex-1" onClick={closeModal}>
                          {t('admin.players.cancel', 'Cancel')}
                        </Button>
                      </div>
                    </div>
                  )}
                </>
              )}

              {/* Ban */}
              {modalTab === 'ban' && (
                <>
                  <p className="text-sm text-base-content">
                    {t('admin.players.ban_confirm', 'Are you sure you want to ban')} <strong>{selected.nickname}</strong>?
                  </p>
                  <Input
                    label={t('admin.players.reason_label', 'Reason')}
                    value={banReason}
                    onChange={(e) => setBanReason(e.target.value)}
                    placeholder={t('admin.players.reason_placeholder', 'Violation reason')}
                  />
                  <Input
                    label={t('admin.players.duration', 'Duration (optional)')}
                    value={banDuration}
                    onChange={(e) => setBanDuration(e.target.value)}
                    placeholder={t('admin.players.duration_placeholder', 'e.g. 7d, 30d, permanent')}
                  />
                  <div className="flex gap-3 pt-2">
                    <Button variant="destructive" className="flex-1" onClick={() => ban.mutate({ nickname: selected.nickname, reason: banReason, duration: banDuration || undefined })} isLoading={ban.isPending}>
                      {t('admin.players.ban', 'Ban')}
                    </Button>
                    <Button variant="outline" className="flex-1" onClick={closeModal}>
                      {t('admin.players.cancel', 'Cancel')}
                    </Button>
                  </div>
                </>
              )}

              {/* Mute */}
              {modalTab === 'mute' && (
                <>
                  <p className="text-sm text-base-content">
                    {t('admin.players.mute_confirm', 'Are you sure you want to mute')} <strong>{selected.nickname}</strong>?
                  </p>
                  <Input
                    label={t('admin.players.reason_label', 'Reason')}
                    value={muteReason}
                    onChange={(e) => setMuteReason(e.target.value)}
                    placeholder={t('admin.players.reason_placeholder', 'Violation reason')}
                  />
                  <Input
                    label={t('admin.players.duration', 'Duration')}
                    value={muteDuration}
                    onChange={(e) => setMuteDuration(e.target.value)}
                    placeholder={t('admin.players.duration_placeholder', 'e.g. 1h, 24h')}
                  />
                  <div className="flex gap-3 pt-2">
                    <Button variant="destructive" className="flex-1" onClick={() => mute.mutate({ nickname: selected.nickname, reason: muteReason, duration: muteDuration })} isLoading={mute.isPending}>
                      {t('admin.players.mute', 'Mute')}
                    </Button>
                    <Button variant="outline" className="flex-1" onClick={closeModal}>
                      {t('admin.players.cancel', 'Cancel')}
                    </Button>
                  </div>
                </>
              )}

              {/* Change Password */}
              {modalTab === 'password' && (
                <>
                  <p className="text-sm text-base-content">
                    {t('admin.players.change_pw_confirm', 'Change password for')} <strong>{selected.nickname}</strong>?
                  </p>
                  <Input
                    type="password"
                    label={t('admin.players.new_password', 'New Password')}
                    value={newPassword}
                    onChange={(e) => setNewPassword(e.target.value)}
                    placeholder={t('admin.players.new_password_placeholder', 'Enter new password')}
                  />
                  <div className="flex gap-3 pt-2">
                    <Button className="flex-1" onClick={() => changePassword.mutate({ nickname: selected.nickname, password: newPassword })} isLoading={changePassword.isPending}>
                      {t('admin.players.save', 'Save')}
                    </Button>
                    <Button variant="outline" className="flex-1" onClick={closeModal}>
                      {t('admin.players.cancel', 'Cancel')}
                    </Button>
                  </div>
                </>
              )}

              {/* Cancel Punishment */}
              {modalTab === 'cancel' && (
                <>
                  <div className="p-4 bg-info/10 rounded-lg border border-info/20">
                    <p className="text-sm text-base-content">
                      {t('admin.players.cancel_confirm', 'Cancel punishment for')} <strong>{selected.nickname}</strong>?
                    </p>
                  </div>
                  <Input
                    label={t('admin.players.cancel_reason', 'Reason for cancellation')}
                    value={cancelReason}
                    onChange={(e) => setCancelReason(e.target.value)}
                    placeholder={t('admin.players.cancel_reason_placeholder', 'Why are you canceling this punishment?')}
                  />
                  <div className="flex gap-3 pt-2">
                    <Button className="flex-1" onClick={() => cancelPunishment.mutate({ nickname: selected.nickname, reason: cancelReason })} isLoading={cancelPunishment.isPending}>
                      {t('admin.players.cancel_punishment', 'Cancel Punishment')}
                    </Button>
                    <Button variant="outline" className="flex-1" onClick={closeModal}>
                      {t('admin.players.cancel', 'Cancel')}
                    </Button>
                  </div>
                </>
              )}

              {/* Delete */}
              {modalTab === 'delete' && (
                <>
                  <div className="p-4 bg-error/10 rounded-lg border border-error/20">
                    <p className="text-sm text-base-content">
                      {t('admin.players.confirm_delete', 'Are you sure you want to delete this player\'s account?')}
                    </p>
                    <p className="text-sm font-bold text-error mt-2">{selected.nickname}</p>
                  </div>
                  <div className="flex gap-3 pt-2">
                    <Button variant="destructive" className="flex-1" onClick={() => deletePlayer.mutate(selected.nickname)} isLoading={deletePlayer.isPending}>
                      <Trash2 className="w-4 h-4 mr-2" />{t('admin.players.delete', 'Delete')}
                    </Button>
                    <Button variant="outline" className="flex-1" onClick={closeModal}>
                      {t('admin.players.cancel', 'Cancel')}
                    </Button>
                  </div>
                </>
              )}

              {/* Report Player */}
              {modalTab === 'report' && (
                <>
                  <div className="p-4 bg-warning/10 rounded-lg border border-warning/20">
                    <p className="text-sm text-base-content">
                      {t('admin.players.report_confirm', 'Submit a report for')} <strong>{selected.nickname}</strong>?
                    </p>
                  </div>
                  <Input
                    label={t('admin.players.report_user_id', 'Reported User ID')}
                    value={reportUserId}
                    onChange={(e) => setReportUserId(e.target.value)}
                    placeholder={t('admin.players.report_user_id_placeholder', 'Enter user ID to report')}
                  />
                  <div>
                    <label className="text-sm font-medium text-base-content">{t('admin.players.report_reason', 'Reason')}</label>
                    <textarea
                      value={reportReason}
                      onChange={(e) => setReportReason(e.target.value)}
                      placeholder={t('admin.players.report_reason_placeholder', 'Describe the violation')}
                      className="mt-1 w-full min-h-[80px] rounded-lg border border-neutral/20 bg-base-200 px-3 py-2 text-sm text-base-content focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
                    />
                  </div>
                  <div className="flex gap-3 pt-2">
                    <Button className="flex-1" onClick={() => reportPlayer.mutate({ nickname: selected.nickname, reported_user_id: Number(reportUserId), reason: reportReason })} isLoading={reportPlayer.isPending}>
                      {t('admin.players.submit_report', 'Submit Report')}
                    </Button>
                    <Button variant="outline" className="flex-1" onClick={closeModal}>
                      {t('admin.players.cancel', 'Cancel')}
                    </Button>
                  </div>
                </>
              )}
            </div>
          )}
        </Modal>
      </motion.div>
    </AdminLayout>
  )
}

export default AdminPlayers
