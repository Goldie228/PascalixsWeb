import { useState, useEffect, useCallback, useRef } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'
import { useAuthStore } from '@/store/auth'
import { useToast } from '@/components/ui/Toast'
import { Card } from '@/components/ui/Card'
import { Button } from '@/components/ui/Button'
import { Badge } from '@/components/ui/Badge'
import { Modal } from '@/components/ui/Modal'
import { Input } from '@/components/ui/Input'
import {
  galleryApi,
  type GalleryPhoto,
  type GalleryAlbum,
  type GalleryAlbumsResponse,
} from '@/services/galleryApi'
import {
  ChevronLeft,
  ChevronRight,
  X,
  Upload,
  Image as ImageIcon,
  Search,
  Check,
  XCircle,
  Filter,
  Trash2,
  Edit2,
  Loader2,
} from 'lucide-react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { motion, AnimatePresence } from 'framer-motion'

/* ------------------------------------------------------------------ */
/*  Types                                                              */
/* ------------------------------------------------------------------ */

type SortOption = 'newest' | 'oldest' | 'az'
type ModerationStatus = 'all' | 'pending' | 'approved' | 'rejected'

interface UploadFileState {
  file: File
  progress: number
  status: 'uploading' | 'done' | 'error'
  error?: string
}

/* ------------------------------------------------------------------ */
/*  Helpers                                                            */
/* ------------------------------------------------------------------ */

function formatDate(dateStr: string): string {
  const d = new Date(dateStr)
  return d.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  })
}

function pluralizePhotos(count: number, t: (k: string, opts?: Record<string, unknown>) => string): string {
  const key = 'gallery.photos_count'
  try {
    return t(key, { count })
  } catch {
    return `${count} photos`
  }
}

/* ------------------------------------------------------------------ */
/*  Upload schema                                                      */
/* ------------------------------------------------------------------ */

const uploadSchema = z.object({
  title: z.string().min(1, 'Title is required'),
  description: z.string().max(500, 'Description must be at most 500 characters').optional().or(z.literal('')),
  albumId: z.coerce.number().optional().or(z.literal(0)).nullable(),
  files: z.any(),
})

type UploadFormData = z.infer<typeof uploadSchema>

const albumSchema = z.object({
  title: z.string().min(1, 'Title is required'),
  description: z.string().max(500, 'Description must be at most 500 characters').optional().or(z.literal('')),
})

/* ------------------------------------------------------------------ */
/*  Main Component                                                     */
/* ------------------------------------------------------------------ */

export default function Gallery() {
  const { t, i18n } = useTranslation()
  const { user } = useAuthStore()
  const { success: showSuccess, error: showError } = useToast()
  const queryClient = useQueryClient()

  /* ---- view state ---- */
  const [view, setView] = useState<'albums' | 'albumDetail' | 'moderation'>('albums')
  const [selectedAlbum, setSelectedAlbum] = useState<GalleryAlbum | null>(null)
  const [lightboxPhoto, setLightboxPhoto] = useState<{ photo: GalleryPhoto; photos: GalleryPhoto[]; index: number } | null>(null)
  const [isUploadModalOpen, setIsUploadModalOpen] = useState(false)
  const [isCreateAlbumModalOpen, setIsCreateAlbumModalOpen] = useState(false)
  const [editingPhoto, setEditingPhoto] = useState<GalleryPhoto | null>(null)

  /* ---- albums list state ---- */
  const [currentPage, setCurrentPage] = useState(1)
  const [searchQuery, setSearchQuery] = useState('')
  const [sort, setSort] = useState<SortOption>('newest')
  const [hasMore, setHasMore] = useState(true)
  const searchTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  /* ---- upload state ---- */
  const [uploadFiles, setUploadFiles] = useState<UploadFileState[]>([])
  const fileInputRef = useRef<HTMLInputElement>(null)
  const dropZoneRef = useRef<HTMLDivElement>(null)

  /* ---- moderation state ---- */
  const [modFilter, setModFilter] = useState<ModerationStatus>('pending')

  /* ---- ref for lightbox keyboard ---- */
  const lightboxRef = useRef<HTMLDivElement>(null)

  /* ---- scroll container ref ---- */
  const scrollContainerRef = useRef<HTMLDivElement>(null)

  /* ---- album detail query ---- */
  const {
    data: albumDetailData,
    isLoading: isLoadingAlbum,
    refetch: refetchAlbum,
  } = useQuery({
    queryKey: ['gallery-album-detail', selectedAlbum?.id],
    queryFn: () => galleryApi.getAlbum(selectedAlbum!.id),
    enabled: view === 'albumDetail' && !!selectedAlbum,
    staleTime: 1000 * 60 * 5,
  })

  /* ---- albums list query ---- */
  const {
    data: galleryData,
    isLoading,
    isFetching,
    refetch: refetchAlbums,
  } = useQuery<GalleryAlbumsResponse>({
    queryKey: ['gallery', currentPage, searchQuery, sort],
    queryFn: () => {
      const params: Record<string, unknown> = {
        page: currentPage,
        per_page: 12,
        published: true,
      }
      if (searchQuery) params.search = searchQuery
      if (sort === 'newest') { params.sort = 'created_at'; params.order = 'desc' }
      if (sort === 'oldest') { params.sort = 'created_at'; params.order = 'asc' }
      if (sort === 'az') { params.sort = 'title'; params.order = 'asc' }
      return galleryApi.getAlbums(params)
    },
    staleTime: 1000 * 60 * 5,
  })

  /* ---- moderation query ---- */
  const { data: pendingData } = useQuery({
    queryKey: ['gallery-pending', modFilter],
    queryFn: () => {
      const params: Record<string, unknown> = {}
      if (modFilter !== 'all') params.status = modFilter
      return galleryApi.getPendingPhotos(params)
    },
    staleTime: 1000 * 60 * 5,
    enabled: view === 'moderation',
  })

  /* ---- derived data ---- */
  const albums = galleryData?.data?.galleries || []
  const totalCount = galleryData?.data?.total_count || 0
  const totalPages = Math.ceil(totalCount / 12)
  const currentPhotos = albumDetailData?.data?.gallery?.photos || selectedAlbum?.photos || []

  /* ---- mutations ---- */
  const uploadPhotoMutation = useMutation({
    mutationFn: async (file: File) => {
      const formData = new FormData()
      formData.append('title', editingPhoto?.title || '')
      if (editingPhoto?.description) formData.append('description', editingPhoto.description)
      if (selectedAlbum?.id) formData.append('album_id', selectedAlbum.id.toString())
      formData.append('image', file)
      return galleryApi.uploadPhoto(formData, (progress) => {
        setUploadFiles((prev) =>
          prev.map((f) => (f.file === file ? { ...f, progress } : f))
        )
      })
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['gallery'] })
      queryClient.invalidateQueries({ queryKey: ['gallery-album-detail', selectedAlbum?.id] })
      queryClient.invalidateQueries({ queryKey: ['gallery-pending'] })
      showSuccess(t('gallery.upload_success'))
      setUploadFiles([])
    },
    onError: (err: Error) => {
      showError(err.message || t('gallery.upload_error'))
      setUploadFiles((prev) =>
        prev.map((f) => ({ ...f, status: 'error', error: err.message }))
      )
    },
  })

  const createAlbumMutation = useMutation({
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

  const deleteAlbumMutation = useMutation({
    mutationFn: (albumId: number) => galleryApi.deleteAlbum(albumId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['gallery'] })
      if (selectedAlbum?.id === albumId) {
        setView('albums')
        setSelectedAlbum(null)
      }
      showSuccess(t('gallery.album_delete_success'))
    },
    onError: () => {
      showError(t('gallery.album_delete_error'))
    },
  })

  const moderatePhotoMutation = useMutation({
    mutationFn: async ({ photoId, action, reason }: { photoId: number; action: 'approve' | 'reject'; reason?: string }) => {
      return await galleryApi.moderatePhoto(photoId, action, reason)
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['gallery-pending'] })
      queryClient.invalidateQueries({ queryKey: ['gallery'] })
      queryClient.invalidateQueries({ queryKey: ['gallery-album-detail'] })
      showSuccess(t('gallery.moderation_success'))
    },
    onError: () => {
      showError(t('gallery.moderation_error'))
    },
  })

  const deletePhotoMutation = useMutation({
    mutationFn: (photoId: number) => galleryApi.deletePhoto(photoId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['gallery'] })
      queryClient.invalidateQueries({ queryKey: ['gallery-pending'] })
      queryClient.invalidateQueries({ queryKey: ['gallery-album-detail', selectedAlbum?.id] })
      showSuccess(t('gallery.delete_success'))
    },
    onError: () => {
      showError(t('gallery.delete_error'))
    },
  })

  /* ---- form hooks ---- */
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
  } = useForm<z.infer<typeof albumSchema>>({
    resolver: zodResolver(albumSchema),
  })

  /* ---- upload submit ---- */
  const onUploadSubmit = async (data: UploadFormData) => {
    if (!data.files || (Array.isArray(data.files) && data.files.length === 0)) {
      showError(t('gallery.upload_error'))
      return
    }
    const files = Array.isArray(data.files) ? data.files : [data.files]
    setUploadFiles(files.map((f: File) => ({ file: f, progress: 0, status: 'uploading' })))
    for (const file of files) {
      await uploadPhotoMutation.mutateAsync(file)
    }
    resetUpload()
    setIsUploadModalOpen(false)
    if (selectedAlbum) refetchAlbum()
  }

  const onAlbumSubmit = async (data: { title: string; description?: string }) => {
    await createAlbumMutation.mutateAsync(data)
    resetAlbum()
  }

  /* ---- moderation handlers ---- */
  const handleModeration = async (photoId: number, action: 'approve' | 'reject') => {
    const reason = action === 'reject' ? undefined : undefined
    if (window.confirm(t(`gallery.moderation_confirm_${action === 'approve' ? 'approve' : 'reject'}`))) {
      await moderatePhotoMutation.mutateAsync({ photoId, action, reason })
    }
  }

  /* ---- photo delete ---- */
  const handleDelete = async (photoId: number) => {
    if (window.confirm(t('gallery.confirm_delete'))) {
      await deletePhotoMutation.mutateAsync(photoId)
    }
  }

  /* ---- album delete ---- */
  const handleAlbumDelete = async (albumId: number) => {
    if (window.confirm(t('gallery.album_delete_confirm'))) {
      await deleteAlbumMutation.mutateAsync(albumId)
    }
  }

  /* ---- navigation ---- */
  const openAlbum = (album: GalleryAlbum) => {
    setSelectedAlbum(album)
    setView('albumDetail')
    setLightboxPhoto(null)
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  const closeAlbum = () => {
    setView('albums')
    setSelectedAlbum(null)
    setLightboxPhoto(null)
    refetchAlbums()
  }

  /* ---- lightbox ---- */
  const openLightbox = (photo: GalleryPhoto, index: number) => {
    setLightboxPhoto({ photo, photos: currentPhotos, index })
  }

  const closeLightbox = useCallback(() => {
    setLightboxPhoto(null)
  }, [])

  const lightboxNext = useCallback(() => {
    setLightboxPhoto((prev) => {
      if (!prev) return prev
      const nextIndex = (prev.index + 1) % prev.photos.length
      return { ...prev, index: nextIndex, photo: prev.photos[nextIndex] }
    })
  }, [])

  const lightboxPrev = useCallback(() => {
    setLightboxPhoto((prev) => {
      if (!prev) return prev
      const prevIndex = (prev.index - 1 + prev.photos.length) % prev.photos.length
      return { ...prev, index: prevIndex, photo: prev.photos[prevIndex] }
    })
  }, [])

  /* ---- keyboard navigation ---- */
  useEffect(() => {
    if (!lightboxPhoto) return
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'Escape') closeLightbox()
      if (e.key === 'ArrowRight') lightboxNext()
      if (e.key === 'ArrowLeft') lightboxPrev()
    }
    document.addEventListener('keydown', handler)
    return () => document.removeEventListener('keydown', handler)
  }, [lightboxPhoto, closeLightbox, lightboxNext, lightboxPrev])

  /* ---- debounced search ---- */
  const handleSearch = (value: string) => {
    setSearchQuery(value)
    if (searchTimerRef.current) clearTimeout(searchTimerRef.current)
    searchTimerRef.current = setTimeout(() => {
      setCurrentPage(1)
    }, 300)
  }

  const handleSortChange = (newSort: SortOption) => {
    setSort(newSort)
    setCurrentPage(1)
  }

  /* ---- load more ---- */
  const handleLoadMore = () => {
    if (currentPage < totalPages) {
      setCurrentPage((p) => p + 1)
    }
  }

  /* ---- drag and drop ---- */
  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
    const files = Array.from(e.dataTransfer.files).filter((f) => f.type.startsWith('image/'))
    if (files.length > 0) {
      setUploadFiles(files.map((f) => ({ file: f, progress: 0, status: 'uploading' })))
      for (const file of files) {
        uploadPhotoMutation.mutate(file)
      }
    }
  }

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
  }

  /* ---- sort label ---- */
  const sortLabel = sort === 'newest' ? t('gallery.sort_newest') : sort === 'oldest' ? t('gallery.sort_oldest') : t('gallery.sort_az')

  /* ---- loading state ---- */
  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-base-content text-lg">{t('gallery.loading')}</div>
      </div>
    )
  }

  /* ---- render ---- */
  return (
    <div ref={scrollContainerRef} className="min-h-screen bg-base-100 py-8">
      <div className="container mx-auto max-w-7xl px-4">
        {/* ============================================================ */}
        {/*  VIEW: ALBUMS LIST                                            */}
        {/* ============================================================ */}
        {view === 'albums' && (
          <div>
            {/* Header */}
            <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-4 mb-8">
              <div>
                <h1 className="text-3xl font-bold text-base-content mb-2">{t('gallery.title')}</h1>
                <p className="text-base-content/70">{t('gallery.subtitle')}</p>
              </div>
              <div className="flex gap-2 flex-wrap">
                {user?.role === 'admin' && (
                  <>
                    <Button
                      variant={view === 'moderation' ? 'default' : 'outline'}
                      onClick={() => setView('moderation')}
                    >
                      <Filter className="w-4 h-4 mr-2" />
                      {t('gallery.moderation')}
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

            {/* Control Panel: Sort + Search */}
            <div className="flex flex-col md:flex-row gap-3 mb-8 sticky top-16 z-20 bg-base-100 py-4">
              {/* Sort Dropdown */}
              <div className="dropdown dropdown-bottom w-full md:w-56">
                <label
                  tabIndex={0}
                  className="btn bg-base-200 border border-base-300 text-base-content hover:bg-base-300 flex justify-between items-center w-full"
                >
                  <span className="text-sm font-medium">{t('gallery.sort')}: {sortLabel}</span>
                  <ChevronRight className="w-4 h-4 rotate-90 text-base-content/50" />
                </label>
                <ul tabIndex={0} className="dropdown-content z-[1] menu p-2 shadow-lg bg-base-200 rounded-xl w-full mt-2 border border-base-300">
                  <li>
                    <a onClick={() => handleSortChange('newest')} className={sort === 'newest' ? 'active' : ''}>
                      {t('gallery.sort_newest')}
                    </a>
                  </li>
                  <li>
                    <a onClick={() => handleSortChange('oldest')} className={sort === 'oldest' ? 'active' : ''}>
                      {t('gallery.sort_oldest')}
                    </a>
                  </li>
                  <li>
                    <a onClick={() => handleSortChange('az')} className={sort === 'az' ? 'active' : ''}>
                      {t('gallery.sort_az')}
                    </a>
                  </li>
                </ul>
              </div>

              {/* Search */}
              <div className="relative flex-1">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-base-content/40" />
                <input
                  type="text"
                  placeholder={t('gallery.search_placeholder')}
                  value={searchQuery}
                  onChange={(e) => handleSearch(e.target.value)}
                  className="input input-bordered w-full bg-base-200 border-base-300 focus:border-primary pl-10"
                />
              </div>
            </div>

            {/* Albums Grid */}
            {isFetching && currentPage > 1 && (
              <div className="flex justify-center py-4">
                <Loader2 className="w-6 h-6 animate-spin text-primary" />
              </div>
            )}

            {albums.length > 0 ? (
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
                <AnimatePresence>
                  {albums.map((album) => (
                    <motion.div
                      key={album.id}
                      initial={{ opacity: 0, y: 20 }}
                      animate={{ opacity: 1, y: 0 }}
                      transition={{ duration: 0.3 }}
                    >
                      <Card
                        className="bg-base-200 border-base-300 cursor-pointer hover:border-primary/50 transition-all duration-300 hover:shadow-lg group"
                        onClick={() => openAlbum(album)}
                      >
                        <div className="aspect-video bg-base-300 rounded-xl mb-4 overflow-hidden">
                          {album.cover_url || album.photos?.[0]?.file_url || album.photos?.[0]?.image_url ? (
                            <img
                              src={album.cover_url || album.photos[0].file_url || album.photos[0].image_url!}
                              alt={album.title}
                              className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
                            />
                          ) : (
                            <div className="flex items-center justify-center h-full">
                              <ImageIcon className="w-12 h-12 text-base-content/30" />
                            </div>
                          )}
                        </div>
                        <h3 className="text-lg font-semibold text-base-content mb-1 truncate group-hover:text-primary transition-colors">
                          {album.title}
                        </h3>
                        <p className="text-base-content/70 text-sm mb-3 line-clamp-2">
                          {album.description || t('gallery.no_description')}
                        </p>
                        <div className="flex items-center justify-between">
                          <Badge variant="default">{album.photos_count ?? album.photos?.length ?? 0} {t('gallery.photos')}</Badge>
                          <span className="text-base-content/50 text-xs">{formatDate(album.created_at)}</span>
                        </div>
                      </Card>
                    </motion.div>
                  ))}
                </AnimatePresence>
              </div>
            ) : (
              <div className="text-center py-16">
                <ImageIcon className="w-16 h-16 text-base-content/20 mx-auto mb-4" />
                <p className="text-base-content/70 text-lg font-medium">{t('gallery.no_results')}</p>
                <p className="text-base-content/50 text-sm mt-2">{t('gallery.no_results_desc')}</p>
              </div>
            )}

            {/* Load More */}
            {totalPages > 1 && (
              <div className="flex items-center justify-center gap-3 mt-10">
                <Button
                  variant="outline"
                  onClick={() => setCurrentPage(Math.max(1, currentPage - 1))}
                  disabled={currentPage === 1}
                >
                  <ChevronLeft className="w-4 h-4" />
                  {t('common.previous')}
                </Button>
                <span className="text-base-content/70 px-4 text-sm">
                  {currentPage} / {totalPages}
                </span>
                <Button
                  variant="outline"
                  onClick={handleLoadMore}
                  disabled={currentPage === totalPages}
                >
                  {t('gallery.load_more')}
                  <ChevronRight className="w-4 h-4 ml-1" />
                </Button>
              </div>
            )}
          </div>
        )}

        {/* ============================================================ */}
        {/*  VIEW: ALBUM DETAIL                                           */}
        {/* ============================================================ */}
        {view === 'albumDetail' && selectedAlbum && (
          <div>
            {/* Back button */}
            <div className="mb-6">
              <Button variant="ghost" onClick={closeAlbum} className="text-base-content/70 hover:text-base-content">
                <ChevronLeft className="w-5 h-5 mr-1" />
                {t('gallery.back')}
              </Button>
            </div>

            {/* Album Header */}
            <div className="bg-base-200 rounded-2xl p-6 md:p-8 mb-8 border border-base-300">
              <h2 className="text-2xl md:text-3xl font-bold text-base-content mb-2">{selectedAlbum.title}</h2>
              <p className="text-base-content/70 text-base mb-4">
                {selectedAlbum.description || t('gallery.no_description')}
              </p>
              <div className="flex flex-wrap items-center gap-3 text-sm text-base-content/50">
                <span>{formatDate(selectedAlbum.created_at)}</span>
                <span>•</span>
                <span>{pluralizePhotos(currentPhotos.length, t)}</span>
                {user?.role === 'admin' && (
                  <>
                    <span>•</span>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => setIsUploadModalOpen(true)}
                      className="text-primary"
                    >
                      <Upload className="w-4 h-4 mr-1" />
                      {t('gallery.upload_photos')}
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => handleAlbumDelete(selectedAlbum.id)}
                      className="text-error"
                    >
                      <Trash2 className="w-4 h-4 mr-1" />
                      {t('common.delete')}
                    </Button>
                  </>
                )}
              </div>
            </div>

            {/* Upload progress area */}
            {uploadFiles.length > 0 && (
              <div className="bg-base-200 rounded-xl p-4 mb-6 border border-base-300">
                <h4 className="text-sm font-medium text-base-content mb-3">{t('gallery.uploading')}</h4>
                <div className="space-y-2">
                  {uploadFiles.map((f, i) => (
                    <div key={i} className="flex items-center gap-3">
                      <div className="flex-1 h-2 bg-base-300 rounded-full overflow-hidden">
                        <div
                          className="h-full bg-primary transition-all duration-300 rounded-full"
                          style={{ width: `${f.status === 'error' ? 100 : f.progress}%` }}
                        />
                      </div>
                      <span className="text-xs text-base-content/60 w-12 text-right">
                        {f.status === 'error' ? '!' : `${f.progress}%`}
                      </span>
                      {f.status === 'error' && <XCircle className="w-4 h-4 text-error" />}
                      {f.status === 'done' && <Check className="w-4 h-4 text-success" />}
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Photos Grid - Masonry-like */}
            {currentPhotos.length > 0 ? (
              <div className="columns-1 sm:columns-2 lg:columns-3 xl:columns-4 gap-4 space-y-4">
                <AnimatePresence>
                  {currentPhotos.map((photo, index) => (
                    <motion.div
                      key={photo.id}
                      initial={{ opacity: 0, scale: 0.95 }}
                      animate={{ opacity: 1, scale: 1 }}
                      transition={{ duration: 0.2, delay: index * 0.03 }}
                      className="break-inside-avoid"
                    >
                      <div
                        className="bg-base-200 rounded-xl overflow-hidden border border-base-300 hover:border-primary/50 transition-all duration-300 shadow-sm hover:shadow-lg cursor-pointer group"
                        onClick={() => openLightbox(photo, index)}
                      >
                        <div className="relative overflow-hidden">
                          <img
                            src={photo.file_url || photo.image_url}
                            alt={photo.title || `Photo ${photo.id}`}
                            className="w-full h-auto object-cover group-hover:scale-105 transition-transform duration-500"
                            loading="lazy"
                          />
                          <div className="absolute inset-0 bg-black/20 opacity-0 group-hover:opacity-100 transition-opacity duration-300" />
                          {photo.is_edited && (
                            <div className="absolute top-2 right-2">
                              <Badge variant="info" className="px-1.5 py-0.5 text-[10px]">
                                {t('gallery.edited')}
                              </Badge>
                            </div>
                          )}
                        </div>
                        {photo.title && (
                          <div className="p-3 border-t border-base-300">
                            <p className="text-base-content text-sm font-medium truncate">{photo.title}</p>
                          </div>
                        )}
                      </div>
                    </motion.div>
                  ))}
                </AnimatePresence>
              </div>
            ) : (
              <div className="text-center py-16">
                <ImageIcon className="w-16 h-16 text-base-content/20 mx-auto mb-4" />
                <p className="text-base-content/70 text-lg">{t('gallery.no_photos')}</p>
              </div>
            )}
          </div>
        )}

        {/* ============================================================ */}
        {/*  VIEW: MODERATION                                             */}
        {/* ============================================================ */}
        {view === 'moderation' && (
          <div>
            {/* Header */}
            <div className="flex items-center justify-between mb-6">
              <div>
                <Button variant="ghost" onClick={() => setView('albums')} className="text-base-content/70 hover:text-base-content mb-2">
                  <ChevronLeft className="w-5 h-5 mr-1" />
                  {t('gallery.back')}
                </Button>
                <h1 className="text-2xl font-bold text-base-content">{t('gallery.moderation')}</h1>
                <p className="text-base-content/70 text-sm">{t('gallery.moderation_desc')}</p>
              </div>
              <Button variant="outline" onClick={() => setView('albums')}>
                {t('gallery.exit_moderation')}
              </Button>
            </div>

            {/* Filter Tabs */}
            <div className="flex flex-wrap gap-2 mb-6">
              {([
                { key: 'all', label: t('gallery.moderation_filter_all') },
                { key: 'pending', label: t('gallery.moderation_filter_pending') },
                { key: 'approved', label: t('gallery.moderation_filter_approved') },
                { key: 'rejected', label: t('gallery.moderation_filter_rejected') },
              ] as { key: ModerationStatus; label: string }[]).map((filter) => (
                <Button
                  key={filter.key}
                  variant={modFilter === filter.key ? 'default' : 'outline'}
                  size="sm"
                  onClick={() => setModFilter(filter.key)}
                >
                  {filter.label}
                </Button>
              ))}
            </div>

            {/* Photos Grid */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {pendingData?.data?.photos?.map((photo) => (
                <Card key={photo.id} className="bg-base-200 border-base-300">
                  <div className="aspect-video bg-base-300 rounded-xl mb-4 overflow-hidden relative">
                    <img
                      src={photo.file_url || photo.image_url}
                      alt={photo.title || `Photo ${photo.id}`}
                      className="w-full h-full object-cover"
                    />
                    <Badge
                      variant={
                        photo.status === 'approved' ? 'success'
                          : photo.status === 'rejected' ? 'error'
                          : 'warning'
                      }
                      className="absolute top-2 left-2"
                    >
                      {photo.status === 'approved' ? t('gallery.moderation_approved')
                        : photo.status === 'rejected' ? t('gallery.moderation_rejected')
                        : t('gallery.moderation_pending')}
                    </Badge>
                  </div>
                  <div className="space-y-2">
                    <h3 className="font-semibold text-base-content">{photo.title || `#${photo.id}`}</h3>
                    {photo.description && (
                      <p className="text-sm text-base-content/70 line-clamp-2">{photo.description}</p>
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
                <ImageIcon className="w-16 h-16 text-base-content/20 mx-auto mb-4" />
                <p className="text-base-content/70 text-lg">{t('gallery.no_pending')}</p>
              </div>
            )}
          </div>
        )}
      </div>

      {/* ============================================================ */}
      {/*  LIGHTBOX                                                     */}
      {/* ============================================================ */}
      <AnimatePresence>
        {lightboxPhoto && (
          <motion.div
            ref={lightboxRef}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 bg-black/95 flex items-center justify-center"
          >
            {/* Close button */}
            <button
              onClick={closeLightbox}
              className="absolute top-4 right-4 text-white/70 hover:text-white z-50 p-2 transition-colors"
              aria-label={t('common.close')}
            >
              <X className="w-8 h-8" />
            </button>

            {/* Previous */}
            <button
              onClick={lightboxPrev}
              className="absolute left-2 md:left-6 text-white/50 hover:text-white z-50 p-3 transition-colors"
              aria-label={t('common.previous')}
            >
              <ChevronLeft className="w-10 h-10" />
            </button>

            {/* Next */}
            <button
              onClick={lightboxNext}
              className="absolute right-2 md:right-6 text-white/50 hover:text-white z-50 p-3 transition-colors"
              aria-label={t('common.next')}
            >
              <ChevronRight className="w-10 h-10" />
            </button>

            {/* Photo */}
            <div className="relative max-h-[85vh] max-w-[90vw] flex flex-col items-center">
              <motion.img
                key={lightboxPhoto.photo.id}
                src={lightboxPhoto.photo.file_url || lightboxPhoto.photo.image_url}
                alt={lightboxPhoto.photo.title || t('gallery.lightbox_full_view')}
                className="max-h-[80vh] max-w-[90vw] object-contain shadow-2xl rounded-sm"
                initial={{ opacity: 0, scale: 0.95 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ duration: 0.2 }}
              />
              {lightboxPhoto.photo.title && (
                <div className="mt-3 text-center">
                  <span className="bg-black/60 text-white px-4 py-2 rounded-lg text-sm backdrop-blur-md">
                    {lightboxPhoto.photo.title}
                  </span>
                </div>
              )}
            </div>

            {/* Counter */}
            <div className="absolute bottom-4 left-4 text-white/60 text-sm font-mono">
              {lightboxPhoto.index + 1} / {lightboxPhoto.photos.length}
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* ============================================================ */}
      {/*  UPLOAD MODAL                                                 */}
      {/* ============================================================ */}
      <Modal
        isOpen={isUploadModalOpen}
        onClose={() => {
          setIsUploadModalOpen(false)
          resetUpload()
          setUploadFiles([])
        }}
        title={t('gallery.upload_title')}
        size="lg"
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
            <label className="block text-sm font-medium text-base-content/70 mb-1">
              {t('gallery.description')}
            </label>
            <textarea
              {...registerUpload('description')}
              className="textarea textarea-bordered w-full bg-base-200 text-base-content border-base-300 focus:border-primary focus:outline-none h-20 resize-none"
              rows={3}
              placeholder={t('gallery.description_placeholder')}
              disabled={uploadSubmitting}
            />
            {uploadErrors.description && (
              <p className="mt-1 text-xs text-error">{String(uploadErrors.description.message)}</p>
            )}
          </div>

          {selectedAlbum && (
            <div className="text-sm text-base-content/60 bg-base-200 rounded-lg p-3">
              {t('gallery.album')}: <span className="font-medium text-base-content">{selectedAlbum.title}</span>
            </div>
          )}

          {/* Drag & Drop Zone */}
          <div
            ref={dropZoneRef}
            onDrop={handleDrop}
            onDragOver={handleDragOver}
            onClick={() => fileInputRef.current?.click()}
            className="border-2 border-dashed border-base-300 rounded-xl p-8 text-center cursor-pointer hover:border-primary/50 hover:bg-base-200/50 transition-colors"
          >
            <Upload className="w-10 h-10 text-base-content/30 mx-auto mb-3" />
            <p className="text-base-content/70 font-medium">{t('gallery.drag_drop_photos')}</p>
            <p className="text-base-content/40 text-sm mt-1">{t('gallery.drag_drop_photos_desc')}</p>
            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              multiple
              className="hidden"
              {...registerUpload('files')}
              disabled={uploadSubmitting}
            />
            {uploadErrors.files && (
              <p className="mt-1 text-xs text-error">{String(uploadErrors.files.message)}</p>
            )}
          </div>

          {/* Upload progress */}
          {uploadFiles.length > 0 && (
            <div className="space-y-2">
              {uploadFiles.map((f, i) => (
                <div key={i} className="flex items-center gap-3 bg-base-200 rounded-lg p-3">
                  <ImageIcon className="w-5 h-5 text-base-content/40 flex-shrink-0" />
                  <div className="flex-1 min-w-0">
                    <p className="text-sm text-base-content truncate">{f.file.name}</p>
                    <div className="flex items-center gap-2 mt-1">
                      <div className="flex-1 h-1.5 bg-base-300 rounded-full overflow-hidden">
                        <div
                          className={`h-full rounded-full transition-all duration-300 ${
                            f.status === 'error' ? 'bg-error' : f.status === 'done' ? 'bg-success' : 'bg-primary'
                          }`}
                          style={{ width: `${f.status === 'error' ? 100 : f.progress}%` }}
                        />
                      </div>
                      <span className="text-xs text-base-content/50 w-10 text-right">
                        {f.status === 'error' ? '!' : f.status === 'done' ? '✓' : `${f.progress}%`}
                      </span>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}

          <Button type="submit" className="w-full" isLoading={uploadSubmitting} disabled={uploadSubmitting}>
            {t('gallery.upload')}
          </Button>
        </form>
      </Modal>

      {/* ============================================================ */}
      {/*  CREATE ALBUM MODAL                                           */}
      {/* ============================================================ */}
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
            <label className="block text-sm font-medium text-base-content/70 mb-1">
              {t('gallery.description')}
            </label>
            <textarea
              {...registerAlbum('description')}
              className="textarea textarea-bordered w-full bg-base-200 text-base-content border-base-300 focus:border-primary focus:outline-none h-20 resize-none"
              rows={3}
              placeholder={t('gallery.description_placeholder')}
              disabled={albumSubmitting}
            />
            {albumErrors.description && (
              <p className="mt-1 text-xs text-error">{String(albumErrors.description.message)}</p>
            )}
          </div>
          <Button type="submit" className="w-full" isLoading={albumSubmitting} disabled={albumSubmitting}>
            {t('gallery.create_album')}
          </Button>
        </form>
      </Modal>

      {/* ============================================================ */}
      {/*  EDIT PHOTO MODAL                                             */}
      {/* ============================================================ */}
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
              <label className="block text-sm font-medium text-base-content/70 mb-1">
                {t('gallery.description')}
              </label>
              <textarea
                className="textarea textarea-bordered w-full bg-base-200 text-base-content border-base-300 focus:border-primary focus:outline-none h-20 resize-none"
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
    </div>
  )
}
