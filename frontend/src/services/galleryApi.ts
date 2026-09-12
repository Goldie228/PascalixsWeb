import api from './api'

export interface GalleryPhoto {
  id: number
  title: string
  image_url: string
  created_at: string
  is_edited: boolean
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
}

export default galleryApi
