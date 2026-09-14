import { useState, useRef, useCallback, useEffect } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { motion, AnimatePresence } from 'framer-motion'
import { useTranslation } from 'react-i18next'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { Avatar } from '@/components/ui/Avatar'
import { Badge } from '@/components/ui/Badge'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import { Button } from '@/components/ui/Button'
import { Modal } from '@/components/ui/Modal'
import { useToast } from '@/components/ui/Toast'
import { useAuthStore } from '@/store/auth'
import api from '@/services/api'
import { userApi } from '@/services/userApi'
import type { Punishment, AvatarData, PunishmentAppealData } from '@/types'

// ─── Avatar Crop Component ───────────────────────────────────────────────────

interface CropState {
  x: number
  y: number
  zoom: number
  rotation: number
}

function AvatarCropModal({
  imageUrl,
  isGif,
  onApply,
  onClose,
}: {
  imageUrl: string
  isGif: boolean
  onApply: (croppedBlob: Blob) => void
  onClose: () => void
}) {
  const { t } = useTranslation()
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const imgRef = useRef<HTMLImageElement>(null)
  const [crop, setCrop] = useState<CropState>({ x: 0, y: 0, zoom: 1, rotation: 0 })
  const isDragging = useRef(false)
  const lastPos = useRef({ x: 0, y: 0 })

  useEffect(() => {
    const img = imgRef.current
    if (!img) return
    const canvas = canvasRef.current
    if (!canvas) return
    const ctx = canvas.getContext('2d')
    if (!ctx) return

    const render = () => {
      canvas.width = 400
      canvas.height = 400
      ctx.clearRect(0, 0, 400, 400)
      ctx.save()
      ctx.translate(200, 200)
      ctx.rotate((crop.rotation * Math.PI) / 180)
      ctx.scale(crop.zoom, crop.zoom)
      ctx.drawImage(img, -img.naturalWidth / 2 + crop.x, -img.naturalHeight / 2 + crop.y)
      ctx.restore()
    }

    img.onload = render
    if (img.complete) render()
  }, [crop, imageUrl])

  const handleMouseDown = (e: React.MouseEvent) => {
    isDragging.current = true
    lastPos.current = { x: e.clientX, y: e.clientY }
  }

  const handleMouseMove = (e: React.MouseEvent) => {
    if (!isDragging.current) return
    const dx = e.clientX - lastPos.current.x
    const dy = e.clientY - lastPos.current.y
    setCrop((prev) => ({ ...prev, x: prev.x + dx, y: prev.y + dy }))
    lastPos.current = { x: e.clientX, y: e.clientY }
  }

  const handleMouseUp = () => {
    isDragging.current = false
  }

  const handleWheel = (e: React.WheelEvent) => {
    e.preventDefault()
    const delta = e.deltaY > 0 ? -0.1 : 0.1
    setCrop((prev) => ({
      ...prev,
      zoom: Math.max(0.5, Math.min(5, prev.zoom + delta)),
    }))
  }

  const rotate = (deg: number) => {
    setCrop((prev) => ({ ...prev, rotation: prev.rotation + deg }))
  }

  const handleApply = () => {
    const canvas = canvasRef.current
    if (!canvas) return
    canvas.toBlob((blob) => {
      if (blob) onApply(blob)
    }, 'image/png')
  }

  return (
    <Modal isOpen={true} onClose={onClose} size="xl">
      <div className="space-y-4">
        <h2 className="text-xl font-bold text-amber-400">{t('avatar.crop.title')}</h2>

        <div className="flex justify-center">
          <div
            className="relative w-80 h-80 bg-neutral/20 rounded-lg overflow-hidden cursor-move select-none"
            onMouseDown={handleMouseDown}
            onMouseMove={handleMouseMove}
            onMouseUp={handleMouseUp}
            onMouseLeave={handleMouseUp}
            onWheel={handleWheel}
          >
            <img
              ref={imgRef}
              src={imageUrl}
              alt="crop"
              className="hidden"
            />
            <canvas
              ref={canvasRef}
              className="w-full h-full"
            />
          </div>
        </div>

        <div className="flex justify-center gap-2">
          {!isGif && (
            <>
              <Button variant="outline" onClick={() => rotate(-90)} className="text-amber-400 border-amber-400 hover:bg-amber-400 hover:text-black">
                <svg className="w-4 h-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12.707 5.293a1 1 0 010 1.414L9.414 10l3.293 3.293a1 1 0 01-1.414 1.414l-4-4a1 1 0 010-1.414l4-4a1 1 0 011.414 0z" /></svg>
                {t('avatar.crop.rotate_left')}
              </Button>
              <Button variant="outline" onClick={() => rotate(90)} className="text-amber-400 border-amber-400 hover:bg-amber-400 hover:text-black">
                <svg className="w-4 h-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" /></svg>
                {t('avatar.crop.rotate_right')}
              </Button>
              <Button variant="outline" onClick={() => setCrop({ x: 0, y: 0, zoom: 1, rotation: 0 })} className="text-amber-400 border-amber-400 hover:bg-amber-400 hover:text-black">
                <svg className="w-4 h-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" /></svg>
                {t('avatar.crop.reset')}
              </Button>
            </>
          )}
        </div>

        <div className="flex justify-end gap-2">
          <Button variant="outline" onClick={onClose} className="text-amber-400 border-amber-400 hover:text-black">
            {t('avatar.crop.cancel')}
          </Button>
          <Button onClick={handleApply} className="bg-amber-400 text-black hover:bg-amber-500">
            <svg className="w-4 h-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" /></svg>
            {t('avatar.crop.apply')}
          </Button>
        </div>
      </div>
    </Modal>
  )
}

// ─── Avatar Upload Modal ─────────────────────────────────────────────────────

function AvatarModal({
  userId,
  isOpen,
  onClose,
  isSponsor,
}: {
  userId: number
  isOpen: boolean
  onClose: () => void
  isSponsor: boolean
}) {
  const { t } = useTranslation()
  const { success, error: toastError } = useToast()
  const queryClient = useQueryClient()

  const { data: avatar, isLoading } = useQuery({
    queryKey: ['avatar', userId],
    queryFn: () => userApi.getAvatar(userId).then((r) => r.data),
    enabled: isOpen,
  })

  const [previewUrl, setPreviewUrl] = useState<string | null>(null)
  const [selectedFile, setSelectedFile] = useState<File | null>(null)
  const [isDragging, setIsDragging] = useState(false)
  const [showCrop, setShowCrop] = useState(false)
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)
  const fileInputRef = useRef<HTMLInputElement>(null)

  const uploadMutation = useMutation({
    mutationFn: (file: File) => userApi.uploadAvatar(userId, file),
    onSuccess: () => {
      success(t('avatar.upload_success'))
      queryClient.invalidateQueries({ queryKey: ['avatar', userId] })
      onClose()
    },
    onError: () => toastError(t('avatar.upload_error')),
  })

  const deleteMutation = useMutation({
    mutationFn: () => userApi.deleteAvatar(userId),
    onSuccess: () => {
      success(t('avatar.delete_success'))
      queryClient.invalidateQueries({ queryKey: ['avatar', userId] })
      setShowDeleteConfirm(false)
      onClose()
    },
    onError: () => toastError(t('avatar.delete_error')),
  })

  useEffect(() => {
    if (isOpen && avatar?.url) {
      setPreviewUrl(avatar.url)
    }
  }, [isOpen, avatar])

  const handleFileSelect = (file: File) => {
    if (file.type === 'image/gif' && !isSponsor) {
      toastError(t('avatar.gif_for_sponsors_only'))
      return
    }
    const allowed = isSponsor ? ['image/jpeg', 'image/png', 'image/gif'] : ['image/jpeg', 'image/png']
    if (!allowed.includes(file.type)) {
      toastError(t('avatar.file_type_error'))
      return
    }
    if (file.size > 5 * 1024 * 1024) {
      toastError(t('avatar.file_size_error'))
      return
    }

    setSelectedFile(file)
    const url = URL.createObjectURL(file)
    setPreviewUrl(url)

    // GIFs skip crop
    if (file.type !== 'image/gif') {
      setShowCrop(true)
    }
  }

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault()
    setIsDragging(false)
    const file = e.dataTransfer.files[0]
    if (file) handleFileSelect(file)
  }

  const handleCropApply = (croppedBlob: Blob) => {
    const file = new File([croppedBlob], selectedFile?.name || 'avatar.png', { type: 'image/png' })
    setSelectedFile(null)
    setShowCrop(false)
    uploadMutation.mutate(file)
  }

  const handleDirectUpload = () => {
    if (selectedFile) {
      uploadMutation.mutate(selectedFile)
      setSelectedFile(null)
    }
  }

  const handleDelete = () => {
    deleteMutation.mutate()
  }

  const statusColors: Record<string, string> = {
    none: 'bg-gray-500',
    draft: 'bg-gray-500',
    pending: 'bg-yellow-500',
    approved: 'bg-green-500',
    rejected: 'bg-red-500',
  }

  const statusLabels: Record<string, string> = {
    none: t('avatar.status.none'),
    draft: t('avatar.status.draft'),
    pending: t('avatar.status.pending'),
    approved: t('avatar.status.approved'),
    rejected: t('avatar.status.rejected'),
  }

  const statusInfos: Record<string, string> = {
    none: t('avatar.status_info.none'),
    draft: t('avatar.status_info.draft'),
    pending: t('avatar.status_info.pending'),
    approved: t('avatar.status_info.approved'),
    rejected: t('avatar.status_info.rejected'),
  }

  const placeholderUrl = 'https://ui-avatars.com/api/?name=User&background=333&color=fff'

  return (
    <>
      <Modal isOpen={isOpen} onClose={onClose} size="xl">
        <div className="space-y-6">
          {/* Header */}
          <div className="text-center mt-2">
            <h2 className="text-2xl font-bold text-amber-400">{t('avatar.title')}</h2>
            <p className="text-neutral/70">{t('avatar.subtitle')}</p>
          </div>

          {/* Current Avatar Preview */}
          <div className="bg-neutral/20 rounded-lg p-5">
            <h3 className="text-lg font-semibold text-amber-400 mb-3 flex items-center gap-2">
              <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" /></svg>
              {t('avatar.current_avatar')}
            </h3>
            <div className="flex flex-wrap justify-center gap-4 mb-4">
              {[
                { size: 'w-16 h-16', label: t('avatar.sizes.small') },
                { size: 'w-24 h-24', label: t('avatar.sizes.medium') },
                { size: 'w-32 h-32', label: t('avatar.sizes.large') },
              ].map(({ size, label }) => (
                <div key={label} className="flex flex-col items-center">
                  <div className={`${size} rounded-full bg-neutral/30 overflow-hidden border-2 ${label === t('avatar.sizes.medium') ? 'border-amber-400' : 'border-neutral/40'}`}>
                    <img
                      src={previewUrl || placeholderUrl}
                      alt={label}
                      className="w-full h-full object-cover"
                    />
                  </div>
                  <span className="text-xs text-neutral/60 mt-1">{label}</span>
                </div>
              ))}
            </div>

            {/* Status */}
            {avatar && (
              <div className="mt-4 max-w-md mx-auto">
                <div className="flex items-center justify-between mb-2">
                  <span className="text-neutral/60">{t('avatar.status_label', { defaultValue: 'Status' })}</span>
                  <div className="flex items-center gap-2">
                    <div className={`w-3 h-3 rounded-full ${statusColors[avatar.status] || 'bg-gray-500'}`} />
                    <span className="text-amber-400 text-sm">{statusLabels[avatar.status] || avatar.status}</span>
                  </div>
                </div>
                <p className="text-sm text-neutral/60">{statusInfos[avatar.status] || ''}</p>
              </div>
            )}
          </div>

          {/* Upload Area */}
          <div className="bg-neutral/20 rounded-lg p-5">
            <h3 className="text-lg font-semibold text-amber-400 mb-3 flex items-center gap-2">
              <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" /></svg>
              {t('avatar.upload_new')}
            </h3>

            <div
              className={`border-2 border-dashed rounded-xl p-8 text-center cursor-pointer transition-all duration-300 ${
                isDragging
                  ? 'border-amber-400 bg-amber-400/10'
                  : 'border-neutral/40 hover:border-amber-400 hover:bg-neutral/30'
              }`}
              onDragOver={(e) => { e.preventDefault(); setIsDragging(true) }}
              onDragLeave={() => setIsDragging(false)}
              onDrop={handleDrop}
              onClick={() => fileInputRef.current?.click()}
            >
              <input
                ref={fileInputRef}
                type="file"
                className="hidden"
                accept="image/jpeg,image/png,image/gif"
                onChange={(e) => e.target.files?.[0] && handleFileSelect(e.target.files[0])}
              />
              <div className="flex flex-col items-center">
                <div className="w-16 h-16 bg-amber-400/20 rounded-full flex items-center justify-center mb-4">
                  <svg className="w-8 h-8 text-amber-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" /></svg>
                </div>
                <p className="text-neutral/80 mb-3 text-lg">{t('avatar.drag_drop')}</p>
                <Button variant="warning" className="bg-amber-400 text-black hover:bg-amber-500">
                  {t('avatar.select_file')}
                </Button>
                <p className="text-neutral/60 text-sm mt-3">
                  {t('avatar.file_info')}
                  {isSponsor && <span className="text-amber-400 ml-1">| {t('avatar.gif_info')}</span>}
                </p>
              </div>
            </div>

            {/* Preview */}
            {previewUrl && (
              <div className="mt-4">
                <div className="relative rounded-xl overflow-hidden border border-neutral/40">
                  <img src={previewUrl} alt="preview" className="w-full h-auto object-contain" />
                  {selectedFile?.type === 'image/gif' && (
                    <span className="absolute top-3 right-3 bg-amber-400 text-black text-xs font-bold px-2 py-1 rounded">GIF</span>
                  )}
                  <button
                    onClick={() => { setPreviewUrl(null); setSelectedFile(null) }}
                    className="absolute top-3 right-3 w-8 h-8 bg-red-500 hover:bg-red-600 text-white rounded-full flex items-center justify-center transition-all"
                    title="Remove"
                  >
                    <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" /></svg>
                  </button>
                </div>

                {selectedFile?.type !== 'image/gif' && (
                  <div className="mt-4 flex justify-center">
                    <Button
                      variant="outline"
                      onClick={() => {}}
                      className="text-amber-400 border-amber-400 hover:bg-amber-400 hover:text-black w-64"
                    >
                      {t('avatar.crop_photo', { defaultValue: 'Crop Photo' })}
                    </Button>
                  </div>
                )}
              </div>
            )}
          </div>

          {/* Action Buttons */}
          <div className="flex flex-col sm:flex-row justify-center gap-3">
            <Button
              onClick={handleDirectUpload}
              disabled={!selectedFile || uploadMutation.isPending}
              className="bg-amber-400 text-black hover:bg-amber-500 disabled:opacity-50"
            >
              <svg className="w-5 h-5 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" /></svg>
              {t('avatar.upload')}
            </Button>

            {avatar && avatar.status !== 'none' && (
              <Button
                onClick={() => setShowDeleteConfirm(true)}
                variant="destructive"
                className="bg-red-500 hover:bg-red-600"
              >
                <svg className="w-5 h-5 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
                {t('avatar.delete')}
              </Button>
            )}

            <Button variant="ghost" onClick={onClose} className="text-neutral/70 hover:bg-neutral/20">
              {t('common.cancel')}
            </Button>
          </div>

          {/* Moderation Info */}
          <div className="bg-neutral/10 border border-neutral/30 rounded-lg p-4">
            <p className="text-neutral/70 text-sm">{t('avatar.moderation_info')}</p>
          </div>
        </div>
      </Modal>

      {/* Crop Modal */}
      {showCrop && previewUrl && (
        <AvatarCropModal
          imageUrl={previewUrl}
          isGif={selectedFile?.type === 'image/gif' || false}
          onApply={handleCropApply}
          onClose={() => { setShowCrop(false); setPreviewUrl(null); setSelectedFile(null) }}
        />
      )}

      {/* Delete Confirmation */}
      <Modal isOpen={showDeleteConfirm} onClose={() => setShowDeleteConfirm(false)} size="md">
        <div className="space-y-4">
          <h3 className="text-xl text-red-400 font-bold">{t('avatar.delete')}</h3>
          <p className="text-neutral/70">{t('avatar.delete_confirm')}</p>
          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={() => setShowDeleteConfirm(false)}>
              {t('avatar.delete_cancel')}
            </Button>
            <Button onClick={handleDelete} variant="destructive" className="bg-red-500 hover:bg-red-600">
              {t('avatar.delete_confirm_btn')}
            </Button>
          </div>
        </div>
      </Modal>
    </>
  )
}

// ─── About Me Modal ──────────────────────────────────────────────────────────

function AboutMeModal({
  isOpen,
  onClose,
  initialAboutMe,
  userId,
}: {
  isOpen: boolean
  onClose: () => void
  initialAboutMe: string
  userId: number
}) {
  const { t } = useTranslation()
  const { success, error: toastError } = useToast()
  const queryClient = useQueryClient()
  const [value, setValue] = useState(initialAboutMe || '')
  const [savedValue, setSavedValue] = useState(initialAboutMe || '')

  const mutation = useMutation({
    mutationFn: (data: { about_me: string }) => userApi.updateAboutMe(data),
    onSuccess: () => {
      success(t('about_me.update_success'))
      queryClient.invalidateQueries({ queryKey: ['user-profile'] })
      onClose()
    },
    onError: () => toastError(t('about_me.update_error')),
  })

  const isDirty = value.trim() !== savedValue
  const charCount = value.length

  const handleSave = () => {
    if (!isDirty) return
    mutation.mutate({ about_me: value })
    setSavedValue(value)
  }

  return (
    <Modal isOpen={isOpen} onClose={onClose} size="lg">
      <div className="space-y-4">
        <h2 className="text-xl font-bold text-amber-400">{t('about_me.label')}</h2>
        <textarea
          value={value}
          onChange={(e) => setValue(e.target.value)}
          maxLength={250}
          placeholder={t('about_me.placeholder')}
          className="textarea textarea-bordered w-full min-h-[200px] bg-neutral/20 text-white border-neutral/40 focus:border-amber-400 focus:outline-none resize-none"
        />
        <div className="flex justify-between items-center">
          <span className="text-neutral/60 text-sm">{t('about_me.max_chars', { defaultValue: 'max 250 characters' })}</span>
          <span className={`text-sm ${charCount > 230 ? 'text-amber-400' : 'text-neutral/60'}`}>{charCount}/250</span>
        </div>
        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={onClose} className="text-neutral/70">
            {t('common.cancel')}
          </Button>
          <Button
            onClick={handleSave}
            disabled={!isDirty || mutation.isPending}
            className="bg-amber-400 text-black hover:bg-amber-500 disabled:opacity-50"
          >
            {mutation.isPending ? (
              <LoadingSpinner size="sm" />
            ) : (
              <>
                <svg className="w-4 h-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" /></svg>
                {t('about_me.apply')}
              </>
            )}
          </Button>
        </div>
      </div>
    </Modal>
  )
}

// ─── Report User Modal ───────────────────────────────────────────────────────

function ReportModal({
  userId,
  isOpen,
  onClose,
}: {
  userId: number
  isOpen: boolean
  onClose: () => void
}) {
  const { t } = useTranslation()
  const { success, error: toastError } = useToast()
  const queryClient = useQueryClient()

  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [uploadedFiles, setUploadedFiles] = useState<File[]>([])
  const [existingFiles, setExistingFiles] = useState<any[]>([])
  const [isEditing, setIsEditing] = useState(false)
  const [reportId, setReportId] = useState<number | null>(null)
  const [mediaViewerOpen, setMediaViewerOpen] = useState(false)
  const [currentMediaIndex, setCurrentMediaIndex] = useState(0)
  const [isDragging, setIsDragging] = useState(false)
  const MAX_FILES = 12
  const MAX_TOTAL_SIZE = 2 * 1024 * 1024 * 1024 // 2GB

  const allFiles = [...existingFiles.map((f) => ({ ...f, type: 'existing' as const })), ...uploadedFiles.map((f, i) => ({ ...f, type: 'uploaded' as const, id: `file-${i}`, name: f.name, content_type: f.type, file_size: f.size }))]

  const totalSize = uploadedFiles.reduce((sum, f) => sum + f.size, 0)

  const submitMutation = useMutation({
    mutationFn: async (formData: FormData) => userApi.reportUser(formData),
    onSuccess: () => {
      success(t('report.notifications.report_submitted'))
      queryClient.invalidateQueries({ queryKey: ['reports'] })
      resetForm()
      onClose()
    },
    onError: () => toastError(t('report.errors.empty_fields')),
  })

  const revokeMutation = useMutation({
    mutationFn: () => userApi.revokeReport(reportId!),
    onSuccess: () => {
      success(t('report.notifications.report_revoked'))
      queryClient.invalidateQueries({ queryKey: ['reports'] })
      resetForm()
      onClose()
    },
    onError: () => toastError(t('report.errors.revoke_error')),
  })

  const handleFileSelect = (files: FileList | null) => {
    if (!files || files.length === 0) return
    const totalFiles = existingFiles.length + uploadedFiles.length + files.length
    if (totalFiles > MAX_FILES) {
      toastError(t('report.errors.max_files', { count: MAX_FILES }))
      return
    }
    const validFiles: File[] = []
    for (const file of files) {
      const validTypes = ['image/jpeg', 'image/png', 'video/mp4']
      if (!validTypes.includes(file.type)) {
        toastError(t('report.errors.invalid_file_format', { file_name: file.name }))
        continue
      }
      validFiles.push(file)
    }
    setUploadedFiles((prev) => [...prev, ...validFiles])
  }

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault()
    setIsDragging(false)
    handleFileSelect(e.dataTransfer.files)
  }

  const removeUploadedFile = (index: number) => {
    setUploadedFiles((prev) => prev.filter((_, i) => i !== index))
  }

  const removeExistingFile = (fileId: number | string) => {
    setExistingFiles((prev) => prev.filter((f) => f.id !== fileId))
  }

  const openMediaViewer = (index: number) => {
    setCurrentMediaIndex(index)
    setMediaViewerOpen(true)
  }

  const resetForm = () => {
    setTitle('')
    setDescription('')
    setUploadedFiles([])
    setExistingFiles([])
    setIsEditing(false)
    setReportId(null)
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!title.trim() || !description.trim()) {
      toastError(t('report.errors.empty_fields'))
      return
    }

    const formData = new FormData()
    formData.append('title', title)
    formData.append('description', description)
    formData.append('reported_user_id', String(userId))

    uploadedFiles.forEach((file) => formData.append('files[]', file))

    existingFiles.forEach((file) => formData.append('existing_files[]', file.url))

    submitMutation.mutate(formData)
  }

  return (
    <>
      <Modal isOpen={isOpen} onClose={() => { resetForm(); onClose() }} size="xl">
        <div className="space-y-6">
          {/* Header */}
          <div className="flex justify-between items-center pb-4 border-b border-amber-400/30">
            <h2 className="text-xl font-bold text-amber-400 flex items-center gap-2">
              <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" /></svg>
              {isEditing ? t('report.edit_title') : t('report.title')}
            </h2>
            {isEditing && (
              <Button
                variant="outline"
                onClick={() => revokeMutation.mutate()}
                disabled={revokeMutation.isPending}
                className="text-red-400 border-red-400 hover:bg-red-400/20"
              >
                <svg className="w-5 h-5 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
                {t('report.revoke_button')}
              </Button>
            )}
          </div>

          <form onSubmit={handleSubmit} className="space-y-6">
            {/* Title */}
            <div>
              <label className="block text-white mb-2">
                <span className="font-bold">{t('report.form.title_label')}</span>{' '}
                <span className="text-red-500">*</span>
              </label>
              <input
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                maxLength={80}
                placeholder={t('report.form.title_placeholder')}
                className="input input-bordered w-full bg-neutral/20 text-white border-neutral/40 focus:border-amber-400 focus:outline-none"
                required
              />
              <div className="text-right mt-1">
                <span className={`text-sm ${title.length > 70 ? 'text-amber-400' : 'text-neutral/60'}`}>{title.length}/80</span>
              </div>
            </div>

            {/* Description */}
            <div>
              <label className="block text-white mb-2">
                <span className="font-bold">{t('report.form.description_label')}</span>{' '}
                <span className="text-red-500">*</span>
              </label>
              <textarea
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                maxLength={5000}
                placeholder={t('report.form.description_placeholder')}
                className="textarea textarea-bordered w-full min-h-[150px] bg-neutral/20 text-white border-neutral/40 focus:border-amber-400 focus:outline-none resize-none"
                required
              />
              <div className="text-right mt-1">
                <span className={`text-sm ${description.length > 4500 ? 'text-amber-400' : 'text-neutral/60'}`}>{description.length}/5000</span>
              </div>
            </div>

            {/* File Upload */}
            <div>
              <label className="block text-white mb-2">
                <span className="font-bold">{t('report.form.files_label')}</span>
                <span className="text-sm text-neutral/60 block">{t('report.form.files_info')}</span>
              </label>

              {/* Storage indicator */}
              <div className="mb-3 bg-neutral/20 rounded-lg p-3 border border-neutral/40">
                <div className="flex justify-between items-center mb-1">
                  <span className="text-neutral/70 text-sm">{t('report.form.storage_used')}</span>
                  <span className="text-amber-400 text-sm">{(totalSize / (1024 * 1024)).toFixed(2)} MB / 2048 MB</span>
                </div>
                <div className="w-full bg-neutral/40 rounded-full h-2">
                  <div
                    className="bg-amber-400 h-2 rounded-full transition-all"
                    style={{ width: `${Math.min(100, (totalSize / MAX_TOTAL_SIZE) * 100)}%` }}
                  />
                </div>
              </div>

              {/* Drop area */}
              {uploadedFiles.length + existingFiles.length < MAX_FILES && (
                <div
                  className={`border-2 border-dashed rounded-xl p-8 text-center cursor-pointer transition-all duration-300 mb-4 ${
                    isDragging ? 'border-amber-400 bg-amber-400/10' : 'border-amber-400/50 hover:border-amber-400 hover:bg-neutral/30'
                  }`}
                  onDragOver={(e) => { e.preventDefault(); setIsDragging(true) }}
                  onDragLeave={() => setIsDragging(false)}
                  onDrop={handleDrop}
                  onClick={() => document.getElementById('report-file-input')?.click()}
                >
                  <input
                    id="report-file-input"
                    type="file"
                    className="hidden"
                    multiple
                    accept=".jpg,.jpeg,.png,.mp4"
                    onChange={(e) => handleFileSelect(e.target.files)}
                  />
                  <div className="flex flex-col items-center">
                    <div className="w-16 h-16 bg-amber-500/20 rounded-full flex items-center justify-center mb-4">
                      <svg className="w-8 h-8 text-amber-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" /></svg>
                    </div>
                    <p className="text-neutral/80 mb-3 text-lg">{t('report.form.drag_drop_text')}</p>
                    <Button variant="warning" className="bg-amber-400 text-black hover:bg-amber-500">
                      {t('report.form.select_files_button')}
                    </Button>
                    <p className="text-neutral/60 text-sm mt-3">{t('report.form.files_limit')}</p>
                  </div>
                </div>
              )}

              {/* File preview grid */}
              {(uploadedFiles.length > 0 || existingFiles.length > 0) && (
                <div className="grid grid-cols-2 md:grid-cols-3 gap-3 mt-4">
                  {existingFiles.map((file) => (
                    <div
                      key={file.id}
                      className="relative group overflow-hidden rounded-xl bg-neutral/20 border border-neutral/40 transition-all hover:border-amber-400/50"
                    >
                      <div
                        className="w-full h-36 flex items-center justify-center cursor-pointer"
                        onClick={() => openMediaViewer(allFiles.findIndex((f) => f.id === file.id))}
                      >
                        {file.content_type?.startsWith('image/') ? (
                          <img src={file.url} alt="" className="w-full h-full object-cover" />
                        ) : (
                          <div className="w-full h-full bg-neutral/30 flex items-center justify-center">
                            <svg className="w-10 h-10 text-amber-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z" /><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                          </div>
                        )}
                      </div>
                      <button
                        onClick={(e) => { e.stopPropagation(); removeExistingFile(file.id) }}
                        className="absolute top-2 right-2 w-7 h-7 bg-red-500/90 hover:bg-red-600 text-white rounded-full flex items-center justify-center opacity-0 group-hover:opacity-100 transition-all"
                      >
                        <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" /></svg>
                      </button>
                    </div>
                  ))}
                  {uploadedFiles.map((file, i) => (
                    <div
                      key={`upload-${i}`}
                      className="relative group overflow-hidden rounded-xl bg-neutral/20 border border-neutral/40 transition-all hover:border-amber-400/50"
                    >
                      <div
                        className="w-full h-36 flex items-center justify-center cursor-pointer"
                        onClick={() => openMediaViewer(allFiles.length - uploadedFiles.length + i)}
                      >
                        {file.type.startsWith('image/') ? (
                          <img src={URL.createObjectURL(file)} alt="" className="w-full h-full object-cover" />
                        ) : (
                          <div className="w-full h-full bg-neutral/30 flex items-center justify-center">
                            <svg className="w-10 h-10 text-amber-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z" /><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                          </div>
                        )}
                      </div>
                      <button
                        onClick={() => removeUploadedFile(i)}
                        className="absolute top-2 right-2 w-7 h-7 bg-red-500/90 hover:bg-red-600 text-white rounded-full flex items-center justify-center opacity-0 group-hover:opacity-100 transition-all"
                      >
                        <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" /></svg>
                      </button>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Submit */}
            <div className="flex justify-end gap-2">
              <Button variant="ghost" onClick={() => { resetForm(); onClose() }} className="text-neutral/70">
                {t('report.form.cancel_button')}
              </Button>
              <Button
                type="submit"
                disabled={submitMutation.isPending || !title.trim() || !description.trim()}
                className="bg-amber-400 text-black hover:bg-amber-500 disabled:opacity-50"
              >
                {submitMutation.isPending ? <LoadingSpinner size="sm" /> : null}
                {isEditing ? t('report.form.save_button') : t('report.form.submit_button')}
              </Button>
            </div>
          </form>
        </div>
      </Modal>

      {/* Media Viewer */}
      <Modal isOpen={mediaViewerOpen} onClose={() => setMediaViewerOpen(false)} size="xl">
        {allFiles.length > 0 && (
          <div className="space-y-4">
            <div className="flex justify-between items-center">
              <h3 className="text-lg font-bold text-amber-400 truncate max-w-[70%]">
                {allFiles[currentMediaIndex]?.name || 'Media'}
              </h3>
              <div className="text-amber-400 text-sm">
                {currentMediaIndex + 1} / {allFiles.length}
              </div>
            </div>
            <div className="w-full flex items-center justify-center min-h-[40vh] bg-neutral/10 rounded-lg">
              {(() => {
                const file = allFiles[currentMediaIndex]
                if (!file) return null
                const isImage = file.content_type?.startsWith('image/') || file.type?.startsWith('image/')
                const isVideo = file.content_type === 'video/mp4' || file.type === 'video/mp4'
                const src = isImage
                  ? file.url || (file.type === 'uploaded' ? URL.createObjectURL(file as unknown as File) : '')
                  : file.url || ''
                if (isImage) {
                  return <img src={src} alt="" className="max-w-full max-h-[60vh] object-contain" />
                }
                if (isVideo) {
                  return (
                    <video src={src} controls className="max-w-full max-h-[60vh] object-contain" />
                  )
                }
                return <span className="text-neutral/60">{t('report.media.error')}</span>
              })()}
            </div>
            <div className="flex justify-between">
              <Button
                variant="outline"
                onClick={() => setCurrentMediaIndex((i) => Math.max(0, i - 1))}
                disabled={currentMediaIndex === 0}
                className="text-amber-400 border-amber-400"
              >
                ←
              </Button>
              <Button
                variant="outline"
                onClick={() => setCurrentMediaIndex((i) => Math.min(allFiles.length - 1, i + 1))}
                disabled={currentMediaIndex === allFiles.length - 1}
                className="text-amber-400 border-amber-400"
              >
                →
              </Button>
            </div>
          </div>
        )}
      </Modal>
    </>
  )
}

// ─── Appeal Punishment Modal ─────────────────────────────────────────────────

function AppealModal({
  punishment,
  isOpen,
  onClose,
}: {
  punishment: PunishmentAppealData | null
  isOpen: boolean
  onClose: () => void
}) {
  const { t } = useTranslation()
  const { success, error: toastError } = useToast()
  const queryClient = useQueryClient()

  const [message, setMessage] = useState('')
  const [appealData, setAppealData] = useState<{
    status: 'pending' | 'rejected' | 'accepted' | null
    can_repeal: boolean
    admin_comment: string
  } | null>(null)

  useEffect(() => {
    if (isOpen && punishment?.appeal) {
      setAppealData(punishment.appeal)
      setMessage(punishment.appeal.message || '')
    }
  }, [isOpen, punishment])

  const submitMutation = useMutation({
    mutationFn: (msg: string) => userApi.submitAppeal(punishment!.id, msg),
    onSuccess: () => {
      success(t('punishment_appeal.appeal_sent_notice'))
      setAppealData({ status: 'pending', can_repeal: true, admin_comment: '' })
      queryClient.invalidateQueries({ queryKey: ['user-punishments'] })
    },
    onError: () => toastError(t('punishment_appeal.error_processing_appeal')),
  })

  const revokeMutation = useMutation({
    mutationFn: () => userApi.revokeAppeal(punishment!.id),
    onSuccess: () => {
      success(t('punishment_appeal.appeal_revoked_notice'))
      setAppealData(null)
      setMessage('')
      queryClient.invalidateQueries({ queryKey: ['user-punishments'] })
    },
    onError: () => toastError(t('punishment_appeal.error_processing_appeal')),
  })

  if (!punishment) return null

  const statusBadge = (status: string | null) => {
    if (!status) return null
    const config: Record<string, { bg: string; text: string; label: string }> = {
      pending: { bg: 'bg-amber-400', text: 'text-black', label: t('punishment_appeal.status_pending') },
      rejected: { bg: 'bg-red-500', text: 'text-white', label: t('punishment_appeal.status_rejected') },
      accepted: { bg: 'bg-gray-500', text: 'text-white', label: t('punishment_appeal.status_accepted') },
    }
    const c = config[status]
    if (!c) return null
    return (
      <span className={`px-3 py-1 rounded-full text-sm font-medium ${c.bg} ${c.text}`}>
        {c.label}
      </span>
    )
  }

  const isPending = appealData?.status === 'pending'
  const isRejected = appealData?.status === 'rejected'
  const isAccepted = appealData?.status === 'accepted'
  const canResubmit = isRejected && appealData?.can_repeal
  const isFinalRejection = isRejected && !appealData?.can_repeal

  const submitLabel = isPending
    ? t('punishment_appeal.submit_button_pending')
    : isFinalRejection
      ? t('punishment_appeal.submit_button_rejected_final')
      : canResubmit
        ? t('punishment_appeal.submit_button_rejected_resubmit')
        : isAccepted
          ? t('punishment_appeal.submit_button_accepted')
          : t('punishment_appeal.submit_button')

  const isDisabled = isAccepted || isFinalRejection || (!message.trim() && !isPending && !canResubmit)

  const handleSubmit = () => {
    if (isPending) {
      revokeMutation.mutate()
    } else {
      submitMutation.mutate(message)
    }
  }

  return (
    <Modal isOpen={isOpen} onClose={onClose} size="lg">
      <div className="space-y-6">
        <h2 className="text-2xl text-amber-400 font-bold">{t('punishment_appeal.title')}</h2>

        {/* Status */}
        {appealData && (
          <div className="mb-4">
            <div className="flex items-center mb-2">
              <span className="text-neutral/60 mr-2">{t('punishment_appeal.status_label')}</span>
              {statusBadge(appealData.status)}
            </div>
            {appealData.admin_comment && (
              <div className="bg-neutral/20 p-3 rounded-lg">
                <p className="text-neutral/70 text-sm font-medium mb-1">{t('punishment_appeal.admin_comment_label')}</p>
                <p className="text-neutral/60 text-sm">{appealData.admin_comment}</p>
              </div>
            )}
          </div>
        )}

        {/* Final rejection warning */}
        {isFinalRejection && (
          <div className="p-3 bg-red-500/10 rounded-lg">
            <p className="text-red-400 flex items-start gap-2">
              <svg className="w-5 h-5 flex-shrink-0 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" /></svg>
              {t('punishment_appeal.final_rejection_warning')}
            </p>
          </div>
        )}

        {/* Message */}
        <div>
          <label className="block text-white mb-2">
            <span className="font-bold">{t('punishment_appeal.your_message_label')}</span>
            <span className="text-neutral/60 text-sm ml-2">{t('punishment_appeal.max_chars')}</span>
          </label>
          <textarea
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            maxLength={500}
            placeholder={t('punishment_appeal.placeholder')}
            disabled={isPending || isAccepted || (isRejected && !appealData?.can_repeal)}
            className="textarea textarea-bordered w-full min-h-[150px] bg-neutral/20 text-white border-neutral/40 focus:border-amber-400 focus:outline-none resize-none disabled:bg-neutral/30 disabled:text-neutral/50 disabled:cursor-not-allowed"
          />
          <div className="text-right mt-1">
            <span className={`text-sm ${message.length > 450 ? 'text-amber-400' : 'text-neutral/60'}`}>{message.length}/500</span>
          </div>
        </div>

        {/* Actions */}
        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={onClose} className="text-neutral/70">
            {t('punishment_appeal.cancel_button')}
          </Button>
          <Button
            onClick={handleSubmit}
            disabled={isDisabled || submitMutation.isPending || revokeMutation.isPending}
            className={
              isPending
                ? 'bg-red-500 hover:bg-red-600 text-white'
                : isAccepted || isFinalRejection
                  ? 'bg-gray-600 text-neutral/50 cursor-not-allowed'
                  : 'bg-amber-400 text-black hover:bg-amber-500'
            }
          >
            {(submitMutation.isPending || revokeMutation.isPending) ? <LoadingSpinner size="sm" /> : null}
            {submitLabel}
          </Button>
        </div>
      </div>
    </Modal>
  )
}

// ─── Social Integration Bind/Unbind Modal ─────────────────────────────────────

function IntegrationModal({
  platform,
  isOpen,
  onClose,
  boundUrl,
  channelName,
}: {
  platform: 'youtube' | 'twitch' | 'tiktok'
  isOpen: boolean
  onClose: () => void
  boundUrl?: string
  channelName?: string
}) {
  const { t } = useTranslation()

  const isLinked = !!boundUrl
  const titleKey = isLinked ? `integrations.bind_modal.${platform}.title_linked` : `integrations.bind_modal.${platform}.title_unlinked`
  const descKey = isLinked ? `integrations.bind_modal.${platform}.description_linked` : `integrations.bind_modal.${platform}.description_unlinked`
  const actionKey = isLinked ? `integrations.bind_modal.${platform}.action_button_update` : `integrations.bind_modal.${platform}.action_button_link`

  return (
    <Modal isOpen={isOpen} onClose={onClose} size="lg">
      <div className="space-y-6">
        <h3 className="text-2xl text-amber-400 font-bold">
          {t(titleKey)}
          {isLinked && (
            <span className="text-white font-semibold">
              {channelName ? `${channelName}` : ''}
            </span>
          )}
        </h3>

        <p className="text-neutral/70">
          {t(descKey)}
          {isLinked && boundUrl && (
            <a href={boundUrl} target="_blank" rel="noopener" className="text-amber-400 hover:underline">
              {boundUrl}
            </a>
          )}
        </p>

        <div className="flex flex-col sm:flex-row justify-end gap-2">
          {isLinked && (
            <Button variant="ghost" onClick={onClose} className="text-neutral/70">
              {t(`integrations.bind_modal.${platform}.unlink_button`, { defaultValue: 'Unlink' })}
            </Button>
          )}
          <a
            href={`/integrations/${platform}/auth`}
            className="inline-flex items-center justify-center bg-amber-400 text-black hover:bg-amber-500 font-medium rounded-lg px-6 py-2 transition-colors"
          >
            {t(actionKey)}
          </a>
          <Button variant="outline" onClick={onClose} className="text-amber-400 border-amber-400 hover:text-black">
            {t('integrations.bind_modal.youtube.cancel_button')}
          </Button>
        </div>
      </div>
    </Modal>
  )
}

// ─── Minecraft Roles Expand Toggle ───────────────────────────────────────────

function McRoles({ roles }: { roles: Record<string, { name: string; color?: string }> | null }) {
  const { t } = useTranslation()
  const [expanded, setExpanded] = useState(false)

  if (!roles || Object.keys(roles).length === 0) {
    return (
      <span
        className="badge badge-soft text-sm md:text-lg h-auto w-auto"
        style={{ 'backgroundColor': 'rgba(128,128,128,0.2)', color: '#989898', border: '0' }}
      >
        {t('roles.no_pass')}
      </span>
    )
  }

  const roleEntries = Object.entries(roles)
  const firstRoles = roleEntries.slice(0, 11)
  const remaining = roleEntries.slice(11)

  const renderRole = ([key, role]: [string, { name: string; color?: string }]) => {
    const color = role.color || '#808080'
    const hexMatch = color.match(/^#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i)
    const rgb = hexMatch
      ? `${parseInt(hexMatch[1], 16)}, ${parseInt(hexMatch[2], 16)}, ${parseInt(hexMatch[3], 16)}`
      : '128, 128, 128'

    return (
      <span
        key={key}
        className="badge badge-soft text-sm md:text-lg h-auto w-auto"
        style={{ backgroundColor: `rgba(${rgb}, 0.2)`, color, border: '0' }}
      >
        {role.name}
      </span>
    )
  }

  return (
    <div className="flex flex-wrap gap-2">
      {firstRoles.map(renderRole)}
      {remaining.length > 0 && (
        <>
          <button
            onClick={() => setExpanded(!expanded)}
            className="badge badge-soft cursor-pointer transition-colors hover:bg-gray-600/20 text-sm md:text-lg h-auto w-auto"
            style={{ backgroundColor: 'rgba(128,128,128,0.2)', color: '#989898', border: '0' }}
          >
            +{remaining.length}...
          </button>
          {expanded && (
            <>
              {remaining.map(renderRole)}
              <button
                onClick={() => setExpanded(false)}
                className="badge badge-soft cursor-pointer transition-colors hover:bg-gray-600/20 text-sm md:text-lg h-auto w-auto"
                style={{ backgroundColor: 'rgba(128,128,128,0.2)', color: '#989898', border: '0' }}
              >
                {t('roles.collapse')}
              </button>
            </>
          )}
        </>
      )}
    </div>
  )
}

// ─── Main Profile Page ───────────────────────────────────────────────────────

function Profile() {
  const { t } = useTranslation()
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated)
  const queryClient = useQueryClient()
  const { success, error: toastError } = useToast()

  // Modal states
  const [avatarModalOpen, setAvatarModalOpen] = useState(false)
  const [aboutMeModalOpen, setAboutMeModalOpen] = useState(false)
  const [reportModalOpen, setReportModalOpen] = useState(false)
  const [appealModalOpen, setAppealModalOpen] = useState(false)
  const [selectedPunishment, setSelectedPunishment] = useState<PunishmentAppealData | null>(null)
  const [integrationModalOpen, setIntegrationModalOpen] = useState(false)
  const [integrationPlatform, setIntegrationPlatform] = useState<'youtube' | 'twitch' | 'tiktok'>('youtube')

  const { data: profileUser, isLoading } = useQuery({
    queryKey: ['user-profile'],
    queryFn: async () => {
      const response = await api.get('/users/me')
      return response.data
    },
    enabled: isAuthenticated,
    staleTime: 1000 * 60 * 5,
  })

  const { data: punishments, isLoading: punishmentsLoading } = useQuery({
    queryKey: ['user-punishments', profileUser?.username],
    queryFn: async () => {
      const response = await api.get(`/players/${profileUser?.username}/punishments`)
      return response.data
    },
    enabled: !!profileUser?.username,
    staleTime: 1000 * 60 * 5,
  })

  const { data: integrations } = useQuery({
    queryKey: ['user-integrations', profileUser?.username],
    queryFn: async () => {
      const response = await api.get(`/players/${profileUser?.username}/integrations`)
      return response.data
    },
    enabled: !!profileUser?.username,
    staleTime: 1000 * 60 * 5,
  })

  const { data: bankAccount } = useQuery({
    queryKey: ['user-bank', profileUser?.username],
    queryFn: async () => {
      const response = await api.get(`/players/${profileUser?.username}/bank_account`)
      return response.data
    },
    enabled: !!profileUser?.username,
    staleTime: 1000 * 60 * 5,
  })

  // Load appeal data when opening appeal modal
  const openAppealModal = async (punishment: Punishment) => {
    try {
      const response = await api.get(`/load_punishment_appeal/${punishment.id}`)
      setSelectedPunishment(response.data)
      setAppealModalOpen(true)
    } catch {
      // If endpoint doesn't exist, open modal with basic data
      setSelectedPunishment({
        id: punishment.id,
        type: punishment.type,
        reason: punishment.reason,
        status: punishment.active ? 'active' : 'expired',
        expires_at: punishment.expires_at || '',
        appeal: punishment.appeal || {
          id: null,
          status: null,
          can_repeal: true,
          message: '',
          admin_comment: '',
        },
      })
      setAppealModalOpen(true)
    }
  }

  // Check if current date is far future (permanent detection)
  const isPermanent = (dateStr?: string) => {
    if (!dateStr) return false
    try {
      const expireDate = new Date(dateStr)
      const now = new Date()
      const diffYears = (expireDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24 * 365)
      return diffYears > 50
    } catch {
      return false
    }
  }

  if (!isAuthenticated) {
    return (
      <div className="flex min-h-[60vh] items-center justify-center">
        <Card className="w-full max-w-md">
          <CardHeader>
            <CardTitle className="text-center text-xl">{t('profile.access_required')}</CardTitle>
          </CardHeader>
          <CardContent className="text-center">
            <p className="mb-4 text-neutral/70">{t('profile.please_login')}</p>
          </CardContent>
        </Card>
      </div>
    )
  }

  if (isLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <LoadingSpinner size="lg" />
      </div>
    )
  }

  const userId = profileUser?.id || 0
  const isOwnProfile = true // Assuming viewing own profile

  // Determine avatar URL
  const avatarUrl = profileUser?.avatar_url || profileUser?.discord_avatar_url || undefined

  // Media badges
  const mediaBadges = []
  if (integrations?.youtube_url) {
    mediaBadges.push({ label: 'YOUTUBER', color: '#FF0000' })
  }
  if (integrations?.twitch_url) {
    mediaBadges.push({ label: 'TWITCHER', color: '#9146FF' })
  }
  if (integrations?.tiktok_url) {
    mediaBadges.push({ label: 'TIKTOKER', color: '#69C9D0' })
  }
  if (profileUser?.is_sponsor) {
    mediaBadges.push({ label: 'SPONSOR', color: '#FFD700' })
  }

  // Ban/Mute badges
  const isBanned = profileUser?.is_banned || false
  const isMuted = profileUser?.is_muted || false

  // Minecraft roles
  const mcRoles = profileUser?.mc_roles || null

  return (
    <>
      <div className="min-h-screen bg-[#1A1A1A] py-8">
        <div className="container mx-auto max-w-5xl px-4">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
          >
            {/* ─── Profile Header ──────────────────────────────────────────── */}
            <div className="bg-[#1A1A1A] rounded-lg shadow-lg mt-4 mb-4 mx-auto w-full max-w-4xl overflow-hidden px-4 py-8">
              <div className="flex flex-col md:flex-row">
                {/* Avatar */}
                <div className="relative mb-6 md:mb-0 md:ml-8">
                  <div className="relative w-[150px] md:w-[208px] aspect-square flex items-center justify-center group">
                    <div className="relative w-full h-full flex items-center justify-center">
                      {/* Border ring */}
                      <div
                        className="absolute z-10 inset-0 rounded-full border-4"
                        style={{ borderColor: profileUser?.role_color || '#A0A0A0' }}
                      />
                      {/* Avatar image */}
                      <div
                        className="group relative w-full h-full rounded-full overflow-hidden cursor-pointer transition-all duration-300 z-0"
                        onClick={() => isOwnProfile && setAvatarModalOpen(true)}
                      >
                        <Avatar
                          src={avatarUrl}
                          fallback={profileUser?.username || 'U'}
                          size="xl"
                          className="w-full h-full"
                        />
                        {/* Camera overlay on hover (own profile only) */}
                        {isOwnProfile && (
                          <div className="absolute inset-0 flex flex-col items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity duration-300 rounded-full z-20 bg-black/50">
                            <svg className="w-9 h-9 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z" />
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 13a3 3 0 11-6 0 3 3 0 016 0z" />
                            </svg>
                            <span className="text-white text-sm font-semibold bg-black/70 px-2 py-1 rounded-full">
                              {t('avatar.change')}
                            </span>
                          </div>
                        )}
                      </div>
                    </div>
                  </div>
                </div>

                {/* Main Info */}
                <div className="w-full md:ml-8 text-center md:text-left">
                  {profileUser?.nickname && (
                    <div className="flex flex-col md:flex-row items-center md:items-start flex-wrap gap-2">
                      <h1 className="truncate font-extrabold text-3xl md:text-4xl text-white">
                        {profileUser.nickname}
                      </h1>
                      <div className="flex flex-wrap justify-center gap-2">
                        {/* Web role badge */}
                        {profileUser?.web_role && profileUser.web_role !== 'User' && (
                          <div
                            className="text-white text-sm font-bold rounded-full px-4 py-1 md:px-6 md:py-2 w-fit text-md md:text-xl"
                            style={{ backgroundColor: profileUser.role_color || '#A0A0A0' }}
                          >
                            {profileUser.web_role}
                          </div>
                        )}

                        {/* Media badges */}
                        {mediaBadges.map((badge) => (
                          <div
                            key={badge.label}
                            className="text-black text-sm font-bold rounded-full px-3 py-1 text-xs md:text-base shadow-md"
                            style={{ backgroundColor: badge.color }}
                          >
                            {badge.label}
                          </div>
                        ))}

                        {/* Ban/Mute badges */}
                        {isBanned && (
                          <div className="text-white text-sm font-bold rounded-full px-3 py-1 text-xs md:text-base shadow-md" style={{ backgroundColor: '#dc2626' }}>
                            {t('profile.ban')}
                          </div>
                        )}
                        {isMuted && !isBanned && (
                          <div className="text-black text-sm font-bold rounded-full px-3 py-1 text-xs md:text-base shadow-md" style={{ backgroundColor: '#ca8a04' }}>
                            {t('profile.mute')}
                          </div>
                        )}
                      </div>
                    </div>
                  )}

                  {/* Discord username */}
                  {profileUser?.discord_username && (
                    <h2 className="mt-2 text-md md:text-xl" style={{ color: profileUser?.role_color || '#A0A0A0' }}>
                      @{profileUser.discord_username}
                    </h2>
                  )}

                  {/* Minecraft Roles */}
                  <div className="flex flex-wrap gap-2 mt-4 justify-center md:justify-start">
                    <McRoles roles={mcRoles} />
                  </div>
                </div>

                {/* Report button (for viewing other users) */}
                {profileUser?.user_id && profileUser.user_id !== userId && !isBanned && !isMuted && (
                  <div className="hidden md:flex md:items-center md:justify-center md:ml-8">
                    <Button
                      onClick={() => setReportModalOpen(true)}
                      variant="outline"
                      className="bg-[#2D2D2D] hover:bg-red-600 text-white border-neutral/40"
                    >
                      <svg className="w-5 h-5 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" /></svg>
                      {t('report.trigger')}
                    </Button>
                  </div>
                )}
              </div>
            </div>

            {/* ─── About Me ────────────────────────────────────────────────── */}
            <div className="bg-[#1A1A1A] rounded-lg shadow-lg pt-4 pl-4 pr-0 mt-0 mb-4 mx-auto px-4 w-full max-w-4xl">
              <div className="pt-4 pl-4 flex items-center space-x-4">
                <h1 className="text-2xl text-amber-400">
                  <b>{t('about_me.title')}</b>
                </h1>
                {isOwnProfile && (
                  <button
                    onClick={() => setAboutMeModalOpen(true)}
                    className="cursor-pointer transition hover:text-gray-400 text-amber-400 flex items-center justify-center"
                  >
                    <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                    </svg>
                  </button>
                )}
              </div>
              <div className="text-lg mt-4 mb-0 mr-6 pl-4 pb-8 text-gray-400 break-all">
                {profileUser?.about_me || t('about_me.default_description')}
              </div>
            </div>

            {/* ─── Integrations ────────────────────────────────────────────── */}
            <div className="mx-auto md:pb-0 pb-4 w-full max-w-4xl">
              <div className="flex flex-col md:flex-row md:items-start md:justify-start">
                <div className="relative flex flex-col">
                  <div>
                    <h1 className="text-white text-3xl pb-4"><b>{t('integrations.title')}</b></h1>
                  </div>

                  {/* YouTube */}
                  <button
                    onClick={() => { setIntegrationPlatform('youtube'); setIntegrationModalOpen(true) }}
                    className="btn bg-[#1A1A1A] flex items-center justify-start md:w-80 w-full h-24 mb-4 mr-2 font-normal focus:outline-none border-none shadow-none hover:bg-[#2D2D2D] transition-colors"
                  >
                    <svg className="w-12 h-12" fill="currentColor" viewBox="0 0 24 24">
                      <path d="M21.7 8.037a4.26 4.26 0 0 0-.789-1.964 2.84 2.84 0 0 0-1.984-.839c-2.767-.2-6.926-.2-6.926-.2s-4.157 0-6.928.2a2.836 2.836 0 0 0-1.983.839 4.225 4.225 0 0 0-.79 1.965 30.146 30.146 0 0 0-.2 3.206v1.5a30.12 30.12 0 0 0 .2 3.206c.094.712.364 1.39.784 1.972.604.536 1.38.837 2.187.848 1.583.151 6.731.2 6.731.2s4.161 0 6.928-.2a2.844 2.844 0 0 0 1.985-.84 4.27 4.27 0 0 0 .787-1.965 30.12 30.12 0 0 0 .2-3.206v-1.516a30.672 30.672 0 0 0-.202-3.206Zm-11.692 6.554v-5.62l5.4 2.819-5.4 2.801Z" />
                    </svg>
                    <div className="text-xl text-white ml-2">
                      {integrations?.youtube_channel_name
                        ? integrations.youtube_channel_name.length > 19
                          ? integrations.youtube_channel_name.slice(0, 19) + '…'
                          : integrations.youtube_channel_name
                        : t('integrations.youtube.bind')}
                    </div>
                  </button>

                  {/* Twitch */}
                  <button
                    onClick={() => { setIntegrationPlatform('twitch'); setIntegrationModalOpen(true) }}
                    className="btn bg-[#1A1A1A] flex items-center justify-start md:w-80 w-full h-24 mb-4 mr-2 font-normal focus:outline-none border-none shadow-none hover:bg-[#2D2D2D] transition-colors"
                  >
                    <svg className="w-11 h-11 text-white" fill="currentColor" viewBox="0 0 24 24">
                      <path d="M2.149 0l-1.612 4.119v16.836h5.731v3.045h3.224l3.045-3.045h4.657l6.269-6.269v-14.686h-21.314zm19.164 13.612l-3.582 3.582h-5.731l-3.045 3.045v-3.045h-4.836v-15.045h17.194v11.463zm-3.582-7.343v6.262h-2.149v-6.262h2.149zm-5.731 0v6.262h-2.149v-6.262h2.149z" />
                    </svg>
                    <div className="text-xl text-white ml-2">
                      {integrations?.twitch_channel_name
                        ? integrations.twitch_channel_name.length > 19
                          ? integrations.twitch_channel_name.slice(0, 19) + '…'
                          : integrations.twitch_channel_name
                        : t('integrations.twitch.bind')}
                    </div>
                  </button>

                  {/* TikTok */}
                  <button
                    onClick={() => { setIntegrationPlatform('tiktok'); setIntegrationModalOpen(true) }}
                    className="btn bg-[#1A1A1A] flex items-center justify-start md:w-80 w-full h-24 mb-4 mr-2 font-normal focus:outline-none border-none shadow-none hover:bg-[#2D2D2D] transition-colors"
                  >
                    <svg className="w-12 h-12" fill="currentColor" viewBox="0 0 16 16">
                      <path d="M9 0h1.98c.144.715.54 1.617 1.235 2.512C12.895 3.389 13.797 4 15 4v2c-1.753 0-3.07-.814-4-1.829V11a5 5 0 1 1-5-5v2a3 3 0 1 0 3 3z" />
                    </svg>
                    <div className="text-xl text-white ml-2">
                      {integrations?.tiktok_channel_name
                        ? integrations.tiktok_channel_name.length > 19
                          ? '@' + integrations.tiktok_channel_name.slice(0, 19) + '…'
                          : '@' + integrations.tiktok_channel_name
                        : t('integrations.tiktok.bind')}
                    </div>
                  </button>
                </div>
              </div>
            </div>

            {/* ─── Bank Account ────────────────────────────────────────────── */}
            <div className="mx-auto pb-4 w-full max-w-4xl">
              <div className="flex flex-col md:flex-row md:items-start md:justify-start">
                <div>
                  <h1 className="text-white text-3xl pb-4"><b>{t('profile.bank_account')}</b></h1>
                  {bankAccount ? (
                    <div className="space-y-1">
                      <p className="text-base-content">
                        <span className="text-neutral/60">{t('profile.bank_name')}:</span> {bankAccount.bank_name}
                      </p>
                      <p className="text-base-content">
                        <span className="text-neutral/60">{t('profile.card_number')}:</span> {bankAccount.card_number}
                      </p>
                    </div>
                  ) : (
                    <p className="text-neutral/60">{t('profile.no_bank_account')}</p>
                  )}
                </div>
              </div>
            </div>

            {/* ─── Punishments ─────────────────────────────────────────────── */}
            <div className="bg-[#1A1A1A] rounded-lg shadow-lg mx-auto mb-4 w-full max-w-4xl overflow-hidden px-6 py-6">
              <div className="flex flex-col md:flex-row justify-between items-start md:items-center mb-4">
                <h2 className="text-2xl text-amber-400 font-bold">{t('punishments_history.title')}</h2>
                <div className="mt-2 md:mt-0">
                  {punishments?.some((p: Punishment) => p.active || p.status !== 'expired') ? (
                    <span className="px-2 py-0.5 md:px-3 md:py-1 rounded-full bg-red-500 text-white text-xs md:text-sm font-medium">
                      {t('punishments_history.active_punishments')}
                    </span>
                  ) : (
                    <span className="px-2 py-0.5 md:px-3 md:py-1 rounded-full bg-[#252525] text-white text-xs md:text-sm font-medium">
                      {t('punishments_history.no_active_punishments')}
                    </span>
                  )}
                </div>
              </div>

              {punishmentsLoading ? (
                <div className="flex justify-center py-8">
                  <LoadingSpinner size="lg" />
                </div>
              ) : (
                <div className="overflow-x-auto">
                  <div className="min-w-[700px] rounded-lg overflow-hidden">
                    {/* Header */}
                    <div className="grid grid-cols-12 gap-2 md:gap-3 px-3 md:px-6 py-2 md:py-4 bg-[#2D2D2D]">
                      <div className="col-span-2 text-xs md:text-md font-medium">{t('punishments_history.table.type')}</div>
                      <div className="col-span-3 text-xs md:text-md font-medium">{t('punishments_history.table.reason')}</div>
                      <div className="col-span-2 text-xs md:text-md font-medium">{t('punishments_history.table.issued_at')}</div>
                      <div className="col-span-2 text-xs md:text-md font-medium">{t('punishments_history.table.expires_at')}</div>
                      <div className="col-span-1 text-xs md:text-md font-medium">{t('punishments_history.table.status')}</div>
                      <div className="col-span-2 text-xs md:text-md font-medium">{t('punishments_history.table.action')}</div>
                    </div>

                    {/* Rows */}
                    <div className="max-h-[300px] overflow-y-auto divide-y divide-[#333333]">
                      {punishments?.length === 0 || !punishments?.length ? (
                        <div className="text-center py-4 md:py-6">
                          <p className="text-[#A3A3A3] text-sm md:text-base">{t('punishments_history.no_records')}</p>
                        </div>
                      ) : (
                        punishments.map((p: Punishment, i: number) => {
                          const typeLower = p.type?.toLowerCase() || ''
                          const isActive = p.active || p.status !== 'expired'
                          const isPermanentDate = isPermanent(p.expires_at)

                          // Color coding
                          let dotColor = 'bg-[#525252]'
                          if (typeLower === 'ban') dotColor = 'bg-[#DC2626]'
                          else if (typeLower === 'mute') dotColor = 'bg-[#CA8A04]'

                          return (
                            <div
                              key={p.id}
                              className={`grid grid-cols-12 gap-2 md:gap-3 px-3 md:px-6 py-3 md:py-4 ${i % 2 === 0 ? 'bg-[#1A1A1A]' : 'bg-[#1F1F1F]'} hover:bg-[#252525]`}
                            >
                              {/* Type */}
                              <div className="col-span-2 text-white text-xs md:text-sm font-medium">
                                <span className="inline-flex items-center">
                                  <span className={`w-2 h-2 md:w-3 md:h-3 rounded-full ${dotColor} mr-1 md:mr-2`} />
                                  {p.type?.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase())}
                                </span>
                              </div>

                              {/* Reason */}
                              <div className="col-span-3 text-gray-300 text-xs md:text-sm">
                                {p.reason || '—'}
                              </div>

                              {/* Issued At */}
                              <div className="col-span-2 text-gray-300 text-xs md:text-sm">
                                {p.issued_at ? new Date(p.issued_at).toLocaleDateString() : '—'}
                              </div>

                              {/* Expires At */}
                              <div className="col-span-2 text-gray-300 text-xs md:text-sm">
                                {isPermanentDate ? (
                                  <span className="text-[#A3A3A3]">{t('punishments_history.permanent')}</span>
                                ) : p.expires_at ? (
                                  new Date(p.expires_at).toLocaleDateString()
                                ) : (
                                  <span className="text-[#A3A3A3]">{t('punishments_history.permanent')}</span>
                                )}
                              </div>

                              {/* Status */}
                              <div className="col-span-1">
                                {p.active || p.status !== 'expired' ? (
                                  <span className="px-1.5 py-0.5 md:px-2 md:py-1 rounded-full bg-[#DC2626] text-white text-[10px] md:text-xs">
                                    {t('punishments_history.status.active')}
                                  </span>
                                ) : (
                                  <span className="px-1.5 py-0.5 md:px-2 md:py-1 rounded-full bg-[#404040] text-[#D4D4D4] text-[10px] md:text-xs">
                                    {t('punishments_history.status.expired')}
                                  </span>
                                )}
                              </div>

                              {/* Actions */}
                              <div className="col-span-2 flex space-x-1 md:space-x-2">
                                {(typeLower === 'ban' || typeLower === 'mute') && isActive && (
                                  <a
                                    href="/donate"
                                    className="text-[10px] md:text-xs px-2 py-1 md:px-3 md:py-1.5 rounded bg-[#16A34A] hover:bg-[#15803D] text-white transition-colors whitespace-nowrap"
                                  >
                                    {t('punishments_history.actions.buy_out')}
                                  </a>
                                )}
                                {isActive && (
                                  <button
                                    onClick={() => openAppealModal(p)}
                                    className="text-[10px] md:text-xs px-2 py-1 md:px-3 md:py-1.5 rounded bg-amber-500 hover:bg-amber-600 text-black transition-colors whitespace-nowrap"
                                  >
                                    {t('punishments_history.actions.appeal')}
                                  </button>
                                )}
                              </div>
                            </div>
                          )
                        })
                      )}
                    </div>
                  </div>
                </div>
              )}
            </div>
          </motion.div>
        </div>
      </div>

      {/* ─── Modals ──────────────────────────────────────────────────────── */}
      <AnimatePresence>
        {avatarModalOpen && (
          <AvatarModal
            key="avatar"
            userId={userId}
            isOpen={avatarModalOpen}
            onClose={() => setAvatarModalOpen(false)}
            isSponsor={profileUser?.is_sponsor || false}
          />
        )}
      </AnimatePresence>

      <AboutMeModal
        isOpen={aboutMeModalOpen}
        onClose={() => setAboutMeModalOpen(false)}
        initialAboutMe={profileUser?.about_me || ''}
        userId={userId}
      />

      <ReportModal
        userId={profileUser?.user_id || userId}
        isOpen={reportModalOpen}
        onClose={() => setReportModalOpen(false)}
      />

      <AppealModal
        punishment={selectedPunishment}
        isOpen={appealModalOpen}
        onClose={() => { setAppealModalOpen(false); setSelectedPunishment(null) }}
      />

      <IntegrationModal
        platform={integrationPlatform}
        isOpen={integrationModalOpen}
        onClose={() => setIntegrationModalOpen(false)}
        boundUrl={
          integrationPlatform === 'youtube' ? integrations?.youtube_url :
          integrationPlatform === 'twitch' ? integrations?.twitch_url :
          integrations?.tiktok_url
        }
        channelName={
          integrationPlatform === 'youtube' ? integrations?.youtube_channel_name :
          integrationPlatform === 'twitch' ? integrations?.twitch_channel_name :
          integrations?.tiktok_channel_name
        }
      />
    </>
  )
}

export default Profile
