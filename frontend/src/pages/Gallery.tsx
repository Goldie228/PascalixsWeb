import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'
import { useAuthStore } from '@/store/auth'
import { useToast } from '@/components/ui/Toast'
import { Card } from '@/components/ui/Card'
import { Button } from '@/components/ui/Button'
import { Badge } from '@/components/ui/Badge'
import { Modal } from '@/components/ui/Modal'
import { Input } from '@/components/ui/Input'
import { Alert, AlertContent } from '@/components/ui/Alert'
import { galleryApi, type GalleryPhoto, type GalleryAlbum } from '@/services/galleryApi'
import { Image as ImageIcon, ChevronLeft, ChevronRight, Upload, Trash2, Edit2, Check, X } from 'lucide-react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'

const uploadSchema = z.object({
  title: z.string().min(1, 'Title is required'),
  description: z.string().max(500, 'Description must be at most 500 characters'),
  albumId: z.number().optional(),
  files: z.any(),
})

type UploadFormData = z.infer<typeof uploadSchema>

export default function Gallery() {
  const { t } = useTranslation()
  const { user } = useAuthStore()
  const { success: showSuccess, error: showError } = useToast()
  const queryClient = useQueryClient()
  const [selectedPhoto, setSelectedPhoto] = useState<GalleryPhoto | null>(null)
  const [selectedAlbum, setSelectedAlbum] = useState<GalleryAlbum | null>(null)
  const [isUploadModalOpen, setIsUploadModalOpen] = useState(false)
  const [isCreateAlbumModalOpen, setIsCreateAlbumModalOpen] = useState(false)
  const [currentPage, setCurrentPage] = useState(1)
  const [editingPhoto, setEditingPhoto] = useState<GalleryPhoto | null>(null)
  const [moderationMode, setModerationMode] = useState(false)

  const { data: galleryData, isLoading } = useQuery({
    queryKey: ['gallery', currentPage],
    queryFn: () => galleryApi.getAlbums({ page: currentPage, per_page: 12 }),
    staleTime: 1000 * 60 * 5,
  })

  const { data: pendingData } = useQuery({
    queryKey: ['gallery-pending'],
    queryFn: () => galleryApi.getPendingPhotos(),
    staleTime: 1000 * 60 * 5,
    enabled: moderationMode,
  })

  const albums = galleryData?.data?.albums || []
  const total = galleryData?.data?.total || 0
  const totalPages = Math.ceil(total / 12)

  const uploadPhoto = useMutation({
    mutationFn: async (data: FormData) => {
      return await galleryApi.uploadPhoto(data)
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['gallery'] })
      setIsUploadModalOpen(false)
      showSuccess(t('gallery.upload_success'))
    },
    onError: () => {
      showError(t('gallery.upload_error'))
    },
  })

  const createAlbum = useMutation({
    mutationFn: async (data: { title: string; description: string }) => {
      return await galleryApi.createAlbum(data)
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['gallery'] })
      setIsCreateAlbumModalOpen(false)
      showSuccess(t('gallery.album_created'))
    },
    onError: () => {
      showError(t('gallery.album_create_error'))
    },
  })

  const moderatePhoto = useMutation({
    mutationFn: async ({ photoId, action }: { photoId: number; action: 'approve' | 'reject' }) => {
      return await galleryApi.moderatePhoto(photoId, action)
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['gallery-pending'] })
      queryClient.invalidateQueries({ queryKey: ['gallery'] })
      showSuccess(t('gallery.moderation_success'))
    },
    onError: () => {
      showError(t('gallery.moderation_error'))
    },
  })

  const deletePhoto = useMutation({
    mutationFn: async (photoId: number) => {
      return await galleryApi.deletePhoto(photoId)
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['gallery'] })
      queryClient.invalidateQueries({ queryKey: ['gallery-pending'] })
      showSuccess(t('gallery.delete_success'))
    },
    onError: () => {
      showError(t('gallery.delete_error'))
    },
  })

  const {
    register: registerUpload,
    handleSubmit: handleUploadSubmit,
    formState: { errors: uploadErrors, isSubmitting: uploadSubmitting },
    reset: resetUpload,
  } = useForm<UploadFormData>({
    resolver: zodResolver(uploadSchema),
  })

  const {
    register: registerAlbum,
    handleSubmit: handleAlbumSubmit,
    formState: { errors: albumErrors, isSubmitting: albumSubmitting },
    reset: resetAlbum,
  } = useForm<{ title: string; description: string }>({
    resolver: zodResolver(z.object({
      title: z.string().min(1, 'Title is required'),
      description: z.string().max(500, 'Description must be at most 500 characters'),
    })),
  })

  const onUploadSubmit = async (data: UploadFormData) => {
    const formData = new FormData()
    formData.append('title', data.title)
    if (data.description) formData.append('description', data.description)
    if (data.albumId) formData.append('album_id', data.albumId.toString())
    if (data.files && data.files[0]) {
      formData.append('image', data.files[0])
    }
    await uploadPhoto.mutateAsync(formData)
    resetUpload()
  }

  const onAlbumSubmit = async (data: { title: string; description: string }) => {
    await createAlbum.mutateAsync(data)
    resetAlbum()
  }

  const handleModeration = async (photoId: number, action: 'approve' | 'reject') => {
    await moderatePhoto.mutateAsync({ photoId, action })
  }

  const handleDelete = async (photoId: number) => {
    if (window.confirm(t('gallery.confirm_delete'))) {
      await deletePhoto.mutateAsync(photoId)
    }
  }

  const openAlbum = (album: GalleryAlbum) => {
    setSelectedAlbum(album)
  }

  const openPhoto = (photo: GalleryPhoto) => {
    setSelectedPhoto(photo)
  }

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-white text-lg">{t('gallery.loading')}</div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-base-100 py-8">
      <div className="container mx-auto max-w-7xl px-4">
        <div className="flex items-center justify-between mb-8">
          <div>
            <h1 className="text-3xl font-bold text-base-content mb-2">{t('gallery.title')}</h1>
            <p className="text-base-content/70">{t('gallery.subtitle')}</p>
          </div>
          <div className="flex gap-2">
            {user?.role === 'admin' && (
              <>
                <Button
                  variant={moderationMode ? 'default' : 'outline'}
                  onClick={() => setModerationMode(!moderationMode)}
                >
                  {moderationMode ? t('gallery.exit_moderation') : t('gallery.moderation')}
                </Button>
                <Button onClick={() => setIsCreateAlbumModalOpen(true)}>
                  <Upload className="w-4 h-4 mr-2" />
                  {t('gallery.create_album')}
                </Button>
              </>
            )}
            {user && (
              <Button onClick={() => setIsUploadModalOpen(true)}>
                <Upload className="w-4 h-4 mr-2" />
                {t('gallery.upload')}
              </Button>
            )}
          </div>
        </div>

        {moderationMode ? (
          <div className="space-y-6">
            <Alert variant="warning">
              <AlertContent>
                {t('gallery.moderation_desc')}
              </AlertContent>
            </Alert>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {pendingData?.data?.photos?.map((photo: GalleryPhoto) => (
                <Card key={photo.id} className="bg-base-200 border-base-300">
                  <div className="aspect-video bg-base-300 rounded-lg mb-4 overflow-hidden">
                    <img
                      src={photo.image_url}
                      alt={photo.title || `Photo ${photo.id}`}
                      className="w-full h-full object-cover"
                    />
                  </div>
                  <div className="space-y-2">
                    <h3 className="font-semibold text-base-content">{photo.title}</h3>
                    {photo.description && (
                      <p className="text-sm text-base-content/70">{photo.description}</p>
                    )}
                    <div className="flex gap-2 pt-2">
                      <Button
                        size="sm"
                        variant="success"
                        className="flex-1"
                        onClick={() => handleModeration(photo.id, 'approve')}
                      >
                        <Check className="w-4 h-4 mr-1" />
                        {t('gallery.approve')}
                      </Button>
                      <Button
                        size="sm"
                        variant="destructive"
                        className="flex-1"
                        onClick={() => handleModeration(photo.id, 'reject')}
                      >
                        <X className="w-4 h-4 mr-1" />
                        {t('gallery.reject')}
                      </Button>
                    </div>
                  </div>
                </Card>
              ))}
            </div>

            {(!pendingData?.data?.photos || pendingData.data.photos.length === 0) && (
              <div className="text-center py-12">
                <p className="text-base-content/70 text-lg">{t('gallery.no_pending')}</p>
              </div>
            )}
          </div>
        ) : (
          <>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {albums.map((album) => (
                <Card
                  key={album.id}
                  className="bg-base-200 border-base-300 cursor-pointer hover:border-primary/50 transition-colors"
                  onClick={() => openAlbum(album)}
                >
                  <div className="aspect-video bg-base-300 rounded-lg mb-4 overflow-hidden">
                    {album.photos.length > 0 ? (
                      <img
                        src={album.photos[0].image_url}
                        alt={album.title}
                        className="w-full h-full object-cover"
                      />
                    ) : (
                      <div className="flex items-center justify-center h-full">
                        <ImageIcon className="w-12 h-12 text-base-content/30" />
                      </div>
                    )}
                  </div>
                  <h3 className="text-lg font-semibold text-base-content mb-1">{album.title}</h3>
                  <p className="text-base-content/70 text-sm mb-2">{album.description}</p>
                  <div className="flex items-center justify-between">
                    <Badge variant="default">{album.photos.length} {t('gallery.photos')}</Badge>
                    <span className="text-base-content/50 text-xs">
                      {new Date(album.created_at).toLocaleDateString()}
                    </span>
                  </div>
                </Card>
              ))}
            </div>

            {albums.length === 0 && (
              <div className="text-center py-12">
                <ImageIcon className="w-16 h-16 text-base-content/30 mx-auto mb-4" />
                <p className="text-base-content/70 text-lg">{t('gallery.no_albums')}</p>
                <p className="text-base-content/50 text-sm mt-2">{t('gallery.check_back')}</p>
              </div>
            )}

            {totalPages > 1 && (
              <div className="flex items-center justify-center gap-2 mt-8">
                <Button
                  variant="outline"
                  onClick={() => setCurrentPage(Math.max(1, currentPage - 1))}
                  disabled={currentPage === 1}
                >
                  <ChevronLeft className="w-4 h-4" />
                </Button>
                <span className="text-base-content/70 px-4">
                  {currentPage} / {totalPages}
                </span>
                <Button
                  variant="outline"
                  onClick={() => setCurrentPage(Math.min(totalPages, currentPage + 1))}
                  disabled={currentPage === totalPages}
                >
                  <ChevronRight className="w-4 h-4" />
                </Button>
              </div>
            )}
          </>
        )}
      </div>

      {/* Album Detail Modal */}
      <Modal
        isOpen={!!selectedAlbum}
        onClose={() => setSelectedAlbum(null)}
        title={selectedAlbum?.title}
        size="xl"
      >
        {selectedAlbum && (
          <div className="space-y-4">
            <p className="text-base-content/70">{selectedAlbum.description}</p>
            <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
              {selectedAlbum.photos.map((photo) => (
                <div
                  key={photo.id}
                  className="aspect-video bg-base-300 rounded-lg overflow-hidden cursor-pointer hover:opacity-80 transition-opacity relative"
                  onClick={() => openPhoto(photo)}
                >
                  <img
                    src={photo.image_url}
                    alt={photo.title || `Photo ${photo.id}`}
                    className="w-full h-full object-cover"
                  />
                  {photo.is_edited && (
                    <div className="absolute top-2 right-2">
                      <Badge variant="info" className="px-1.5 py-0 text-[10px]">{t('gallery.edited')}</Badge>
                    </div>
                  )}
                  {user?.role === 'admin' && (
                    <div className="absolute bottom-2 right-2 flex gap-1">
                      <Button size="sm" variant="ghost" className="h-6 w-6 p-0" onClick={(e) => { e.stopPropagation(); setEditingPhoto(photo) }}>
                        <Edit2 className="w-3 h-3" />
                      </Button>
                      <Button size="sm" variant="ghost" className="h-6 w-6 p-0" onClick={(e) => { e.stopPropagation(); handleDelete(photo.id) }}>
                        <Trash2 className="w-3 h-3 text-error" />
                      </Button>
                    </div>
                  )}
                </div>
              ))}
            </div>
          </div>
        )}
      </Modal>

      {/* Photo View Modal */}
      <Modal
        isOpen={!!selectedPhoto}
        onClose={() => setSelectedPhoto(null)}
        size="lg"
      >
        {selectedPhoto && (
          <div className="flex flex-col items-center">
            <img
              src={selectedPhoto.image_url}
              alt={selectedPhoto.title || 'Photo'}
              className="max-w-full max-h-[70vh] object-contain rounded-lg"
            />
            <div className="mt-4 flex items-center gap-4">
              {selectedPhoto.is_edited && (
                <Badge variant="info">{t('gallery.edited')}</Badge>
              )}
              <span className="text-base-content/50 text-sm">
                {new Date(selectedPhoto.created_at).toLocaleDateString()}
              </span>
            </div>
          </div>
        )}
      </Modal>

      {/* Edit Photo Modal */}
      <Modal
        isOpen={!!editingPhoto}
        onClose={() => setEditingPhoto(null)}
        title={t('gallery.edit_photo')}
      >
        {editingPhoto && (
          <div className="space-y-4">
            <Input
              label={t('gallery.title')}
              defaultValue={editingPhoto.title}
            />
            <div>
              <label className="block text-sm font-medium text-base-content/70 mb-1">{t('gallery.description')}</label>
              <textarea
                className="textarea textarea-bordered w-full bg-base-200 text-base-content border-base-300 focus:border-primary focus:outline-none"
                rows={3}
                defaultValue={editingPhoto.description || ''}
              />
            </div>
            <div className="flex gap-2">
              <Button className="flex-1">{t('common.save')}</Button>
              <Button variant="outline" className="flex-1" onClick={() => setEditingPhoto(null)}>
                {t('common.cancel')}
              </Button>
            </div>
          </div>
        )}
      </Modal>

      {/* Upload Modal */}
      <Modal
        isOpen={isUploadModalOpen}
        onClose={() => setIsUploadModalOpen(false)}
        title={t('gallery.upload_title')}
      >
        <form onSubmit={handleUploadSubmit(onUploadSubmit)} className="space-y-4">
          <Input
            {...registerUpload('title')}
            label={t('gallery.title')}
            placeholder={t('gallery.title_placeholder')}
            error={uploadErrors.title?.message ? String(uploadErrors.title.message) : undefined}
            disabled={uploadSubmitting}
          />
          <div>
            <label className="block text-sm font-medium text-base-content/70 mb-1">{t('gallery.description')}</label>
            <textarea
              {...registerUpload('description')}
              className="textarea textarea-bordered w-full bg-base-200 text-base-content border-base-300 focus:border-primary focus:outline-none"
              rows={3}
              placeholder={t('gallery.description_placeholder')}
              disabled={uploadSubmitting}
            />
            {uploadErrors.description && (
              <p className="mt-1 text-sm text-error">{String(uploadErrors.description.message)}</p>
            )}
          </div>
          <div>
            <label className="block text-sm font-medium text-base-content/70 mb-1">{t('gallery.photos_label')}</label>
            <Input
              type="file"
              accept="image/*"
              {...registerUpload('files')}
              disabled={uploadSubmitting}
              className="cursor-pointer"
            />
            {uploadErrors.files && (
              <p className="mt-1 text-sm text-error">{String(uploadErrors.files.message)}</p>
            )}
          </div>
          <Button type="submit" className="w-full" isLoading={uploadSubmitting} disabled={uploadSubmitting}>
            {t('gallery.upload')}
          </Button>
        </form>
      </Modal>

      {/* Create Album Modal */}
      <Modal
        isOpen={isCreateAlbumModalOpen}
        onClose={() => setIsCreateAlbumModalOpen(false)}
        title={t('gallery.create_album_title')}
      >
        <form onSubmit={handleAlbumSubmit(onAlbumSubmit)} className="space-y-4">
          <Input
            {...registerAlbum('title')}
            label={t('gallery.title')}
            placeholder={t('gallery.album_title_placeholder')}
            error={albumErrors.title?.message ? String(albumErrors.title.message) : undefined}
            disabled={albumSubmitting}
          />
          <div>
            <label className="block text-sm font-medium text-base-content/70 mb-1">{t('gallery.description')}</label>
            <textarea
              {...registerAlbum('description')}
              className="textarea textarea-bordered w-full bg-base-200 text-base-content border-base-300 focus:border-primary focus:outline-none"
              rows={3}
              placeholder={t('gallery.description_placeholder')}
              disabled={albumSubmitting}
            />
            {albumErrors.description && (
              <p className="mt-1 text-sm text-error">{String(albumErrors.description.message)}</p>
            )}
          </div>
          <Button type="submit" className="w-full" isLoading={albumSubmitting} disabled={albumSubmitting}>
            {t('gallery.create_album')}
          </Button>
        </form>
      </Modal>
    </div>
  )
}
