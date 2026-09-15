import api from './api'

export interface GalleryPhoto {
  id: number
  title: string
  description?: string
  file_url: string
  image_url?: string
  created_at: string
  updated_at?: string
  is_edited: boolean
  is_pending?: boolean
  is_approved?: boolean
  is_rejected?: boolean
  status?: 'pending' | 'approved' | 'rejected'
  cropped_file?: string
  original_width: number
  original_height: number
  original_file_size: number
  album_id?: number
}

export interface GalleryAlbum {
  id: number
  title: string
  description: string
  cover_url?: string
  photos_count: number
  photos: GalleryPhoto[]
  created_at: string
  updated_at?: string
  status?: string
}

export interface GalleryAlbumsResponse {
  galleries: GalleryAlbum[]
  total_count: number
  page: number
  per_page: number
  total_pages: number
}

export interface GalleryAlbumDetail {
  gallery: GalleryAlbum
}

export interface ModeratePhotoRequest {
  action: 'approve' | 'reject'
  reason?: string
}

export const galleryApi = {
  // Album CRUD
  getAlbums: (params?: {
    page?: number
    per_page?: number
    search?: string
    sort?: 'created_at' | 'title'
    order?: 'asc' | 'desc'
    published?: boolean
  }) =>
    api.get<GalleryAlbumsResponse>('/admin/galleries', {
      params,
    }),
  getAlbum: (albumId: number) =>
    api.get<GalleryAlbumDetail>(`/admin/galleries/${albumId}`),
  createAlbum: (data: { title: string; description: string }) =>
    api.post<GalleryAlbum>('/admin/galleries', data),
  updateAlbum: (albumId: number, data: { title?: string; description?: string }) =>
    api.put<GalleryAlbum>(`/admin/galleries/${albumId}`, data),
  deleteAlbum: (albumId: number) => api.delete(`/admin/galleries/${albumId}`),

  // Photo operations
  uploadPhoto: (data: FormData, onProgress?: (progress: number) => void) =>
    api.post<GalleryPhoto>('/gallery/photos', data, {
      headers: { 'Content-Type': 'multipart/form-data' },
      onUploadProgress: (progressEvent) => {
        if (onProgress && progressEvent.total) {
          onProgress(Math.round((progressEvent.loaded * 100) / progressEvent.total))
        }
      },
    }),
  getPendingPhotos: (params?: { status?: string }) =>
    api.get<{ photos: GalleryPhoto[] }>('/gallery/photos/pending', { params }),
  moderatePhoto: (photoId: number, action: 'approve' | 'reject', reason?: string) =>
    api.post(`/gallery/photos/${photoId}/moderate`, { action, reason }),
  deletePhoto: (photoId: number) =>
    api.delete(`/gallery/photos/${photoId}`),
}

export default galleryApi
