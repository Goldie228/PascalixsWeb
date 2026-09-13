import api from './api'

export interface GalleryPhoto {
  id: number
  title: string
  description?: string
  image_url: string
  created_at: string
  is_edited: boolean
  is_pending?: boolean
  cropped_file?: string
  original_width: number
  original_height: number
  original_file_size: number
}

export interface GalleryAlbum {
  id: number
  title: string
  description: string
  photos: GalleryPhoto[]
  created_at: string
}

export const galleryApi = {
  getAlbums: (params?: { page?: number; per_page?: number }) =>
    api.get<{ albums: GalleryAlbum[]; total: number; page: number }>('/admin/galleries', {
      params,
    }),
  getAlbum: (albumId: number) => api.get<GalleryAlbum>(`/admin/galleries/${albumId}`),
  createAlbum: (data: { title: string; description: string; photos?: File[] }) =>
    api.post<GalleryAlbum>('/admin/galleries', data, {
      headers: { 'Content-Type': 'multipart/form-data' },
    }),
  updateAlbum: (albumId: number, data: Partial<GalleryAlbum>) =>
    api.put<GalleryAlbum>(`/admin/galleries/${albumId}`, data),
  deleteAlbum: (albumId: number) => api.delete(`/admin/galleries/${albumId}`),
  uploadPhoto: (data: FormData) =>
    api.post<GalleryPhoto>('/gallery/photos', data, {
      headers: { 'Content-Type': 'multipart/form-data' },
    }),
  getPendingPhotos: () =>
    api.get<{ photos: GalleryPhoto[] }>('/gallery/photos/pending'),
  moderatePhoto: (photoId: number, action: 'approve' | 'reject') =>
    api.post(`/gallery/photos/${photoId}/moderate`, { action }),
  deletePhoto: (photoId: number) =>
    api.delete(`/gallery/photos/${photoId}`),
}

export default galleryApi
