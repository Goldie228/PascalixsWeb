import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { useAuthStore } from '@/store/auth'
import { Card } from '@/components/ui/Card'
import { Button } from '@/components/ui/Button'
import { Badge } from '@/components/ui/Badge'
import { Modal } from '@/components/ui/Modal'
import { galleryApi, type GalleryPhoto, type GalleryAlbum } from '@/services/galleryApi'
import { Image as ImageIcon, ChevronLeft, ChevronRight, Upload } from 'lucide-react'

export default function Gallery() {
  const { user } = useAuthStore()
  const [selectedPhoto, setSelectedPhoto] = useState<GalleryPhoto | null>(null)
  const [selectedAlbum, setSelectedAlbum] = useState<GalleryAlbum | null>(null)
  const [isUploadModalOpen, setIsUploadModalOpen] = useState(false)
  const [currentPage, setCurrentPage] = useState(1)

  const { data: galleryData, isLoading } = useQuery({
    queryKey: ['gallery', currentPage],
    queryFn: () => galleryApi.getAlbums({ page: currentPage, per_page: 12 }),
    staleTime: 1000 * 60 * 5,
  })

  const albums = galleryData?.data?.albums || []
  const total = galleryData?.data?.total || 0
  const totalPages = Math.ceil(total / 12)

  const openAlbum = (album: GalleryAlbum) => {
    setSelectedAlbum(album)
  }

  const openPhoto = (photo: GalleryPhoto) => {
    setSelectedPhoto(photo)
  }

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-white text-lg">Loading gallery...</div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 p-4 md:p-8">
      <div className="max-w-7xl mx-auto">
        <div className="flex items-center justify-between mb-8">
          <div>
            <h1 className="text-3xl font-bold text-white mb-2">Gallery</h1>
            <p className="text-gray-400">Browse community photos and screenshots</p>
          </div>
          {user?.role === 'admin' && (
            <Button onClick={() => setIsUploadModalOpen(true)}>
              <Upload className="w-4 h-4 mr-2" />
              Upload
            </Button>
          )}
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {albums.map((album) => (
            <Card
              key={album.id}
              className="bg-gray-800/50 backdrop-blur-sm border-gray-700 cursor-pointer hover:border-gray-600 transition-colors"
              onClick={() => openAlbum(album)}
            >
              <div className="aspect-video bg-gray-700 rounded-lg mb-4 overflow-hidden">
                {album.photos.length > 0 ? (
                  <img
                    src={album.photos[0].image_url}
                    alt={album.title}
                    className="w-full h-full object-cover"
                  />
                ) : (
                  <div className="flex items-center justify-center h-full">
                    <ImageIcon className="w-12 h-12 text-gray-500" />
                  </div>
                )}
              </div>
              <h3 className="text-lg font-semibold text-white mb-1">{album.title}</h3>
              <p className="text-gray-400 text-sm mb-2">{album.description}</p>
              <div className="flex items-center justify-between">
                <Badge variant="default">{album.photos.length} photos</Badge>
                <span className="text-gray-500 text-xs">
                  {new Date(album.created_at).toLocaleDateString()}
                </span>
              </div>
            </Card>
          ))}
        </div>

        {albums.length === 0 && (
          <div className="text-center py-12">
            <ImageIcon className="w-16 h-16 text-gray-600 mx-auto mb-4" />
            <p className="text-gray-400 text-lg">No albums yet</p>
            <p className="text-gray-500 text-sm mt-2">Check back later for new content</p>
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
            <span className="text-gray-400 px-4">
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
      </div>

      {/* Album Detail Modal */}
      <Modal
        isOpen={!!selectedAlbum}
        onClose={() => setSelectedAlbum(null)}
        title={selectedAlbum?.title}
        size="xl"
      >
        {selectedAlbum && (
          <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
            {selectedAlbum.photos.map((photo) => (
              <div
                key={photo.id}
                className="aspect-video bg-gray-700 rounded-lg overflow-hidden cursor-pointer hover:opacity-80 transition-opacity relative"
                onClick={() => openPhoto(photo)}
              >
                <img
                  src={photo.image_url}
                  alt={photo.title || `Photo ${photo.id}`}
                  className="w-full h-full object-cover"
                />
                {photo.is_edited && (
                  <div className="absolute top-2 right-2">
                    <Badge variant="info" className="px-1.5 py-0 text-[10px]">Edited</Badge>
                  </div>
                )}
              </div>
            ))}
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
                <Badge variant="info">Edited</Badge>
              )}
              <span className="text-gray-400 text-sm">
                {new Date(selectedPhoto.created_at).toLocaleDateString()}
              </span>
            </div>
          </div>
        )}
      </Modal>

      {/* Upload Modal */}
      <Modal
        isOpen={isUploadModalOpen}
        onClose={() => setIsUploadModalOpen(false)}
        title="Upload to Gallery"
      >
        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-400 mb-1">Album Title</label>
            <input
              type="text"
              className="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white focus:outline-none focus:border-blue-500"
              placeholder="Enter album title"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-400 mb-1">Description</label>
            <textarea
              className="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white focus:outline-none focus:border-blue-500"
              rows={3}
              placeholder="Enter album description"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-400 mb-1">Photos</label>
            <div className="border-2 border-dashed border-gray-600 rounded-lg p-8 text-center">
              <Upload className="w-8 h-8 text-gray-500 mx-auto mb-2" />
              <p className="text-gray-400 text-sm">Drag and drop photos here or click to browse</p>
            </div>
          </div>
          <Button className="w-full">Upload</Button>
        </div>
      </Modal>
    </div>
  )
}
