import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["albumsGrid", "albumsLoader", "albumsPagination", "albumViewContainer", "photosGrid", "currentSortLabel", "albumTitle", "albumDescription", "albumDate", "albumCount", "searchInput", "lightbox", "lightboxImage", "lightboxCounter", "lightboxCaption", "albumsContainer", "galleryControlPanel"]

  connect() {
    this.authServiceUrl = "<%= ENV['IDENTITY_SERVICE_URL'] || '' %>"
    this.i18n = {
      locale: "<%= I18n.locale %>",
      sort: {
        newest: "<%= j t('views.gallery.sort.newest') %>",
        oldest: "<%= j t('views.gallery.sort.oldest') %>",
        az: "<%= j t('views.gallery.sort.az') %>"
      },
      errors: {
        loading: "<%= j t('views.gallery.errors.loading') %>",
        open_failed: "<%= j t('views.gallery.errors.open_failed') %>"
      },
      no_results: "<%= j t('views.gallery.no_results') %>",
      album: {
        empty: "<%= j t('views.gallery.album.empty') %>",
        no_description: "<%= j t('views.gallery.album.no_description') %>",
        photos: {
          one: "<%= j t('views.gallery.album.photos.one') %>",
          few: "<%= j t('views.gallery.album.photos.few') %>",
          many: "<%= j t('views.gallery.album.photos.many') %>",
          other: "<%= j t('views.gallery.album.photos.other') %>"
        }
      }
    }

    this.state = {
      currentPage: 1,
      perPage: 12,
      totalPages: 1,
      albums: [],
      currentAlbum: null,
      currentPhotos: [],
      currentPhotoIndex: 0,
      search: '',
      sort: 'newest'
    }

    this.init()
  }

  disconnect() {
    if (this.keydownHandler) {
      document.removeEventListener('keydown', this.keydownHandler)
    }
  }

  init() {
    this.setupSearch()
    this.setupKeyboard()
    this.setupScroll()
    this.loadAlbums()
  }

  setSort(event) {
    const sortType = event.target.dataset.sortValue
    if (!sortType) return
    this.state.sort = sortType
    this.state.currentPage = 1
    if (this.currentSortLabel) {
      this.currentSortLabel.textContent = this.i18n.sort[sortType]
    }
    this.loadAlbums()
  }

  toggleSortDropdown() {
    // Let DaisyUI dropdown handle itself via tabindex
  }

  setupSearch() {
    const input = this.searchInputTarget
    if (!input) return

    let timeout
    input.addEventListener('input', (e) => {
      clearTimeout(timeout)
      timeout = setTimeout(() => {
        this.state.search = e.target.value
        this.state.currentPage = 1
        this.loadAlbums()
      }, 500)
    })
  }

  setupKeyboard() {
    this.keydownHandler = (e) => {
      if (e.key === 'Escape') this.closeLightbox()
      if (!this.lightbox.classList?.contains('hidden')) {
        if (e.key === 'ArrowLeft') this.prevPhoto()
        if (e.key === 'ArrowRight') this.nextPhoto()
      }
    }
    document.addEventListener('keydown', this.keydownHandler)
  }

  setupScroll() {
    let ticking = false
    window.addEventListener('scroll', () => {
      if (!ticking) {
        window.requestAnimationFrame(() => {
          const panel = this.galleryControlPanel
          if (panel) panel.classList.toggle('shadow-lg', window.scrollY > 10)
          ticking = false
        })
        ticking = true
      }
    })
  }

  async loadAlbums() {
    if (this.albumsGrid) this.albumsGrid.innerHTML = ''
    if (this.albumsLoader) this.albumsLoader.classList.remove('hidden')

    try {
      const params = new URLSearchParams()
      params.append('page', this.state.currentPage)
      params.append('per_page', this.state.perPage)
      params.append('published', 'true')
      if (this.state.search) params.append('search', this.state.search)

      if (this.state.sort === 'newest') { params.append('sort', 'created_at'); params.append('order', 'desc') }
      if (this.state.sort === 'oldest') { params.append('sort', 'created_at'); params.append('order', 'asc') }
      if (this.state.sort === 'az') { params.append('sort', 'title'); params.append('order', 'asc') }

      const response = await fetch(`${this.authServiceUrl}/api/v1/galleries?${params.toString()}`)
      if (!response.ok) throw new Error('Error')

      const data = await response.json()
      this.state.albums = data.galleries || []
      this.state.totalPages = Math.ceil((data.total_count || 0) / this.state.perPage)

      this.renderAlbums()
      this.renderPagination()
    } catch (error) {
      console.error(error)
      if (this.albumsGrid) {
        this.albumsGrid.innerHTML = `<div class="col-span-full text-center text-red-500 py-10">${this.i18n.errors.loading}</div>`
      }
    } finally {
      if (this.albumsLoader) this.albumsLoader.classList.add('hidden')
    }
  }

  renderAlbums() {
    if (this.state.albums.length === 0) {
      if (this.albumsGrid) {
        this.albumsGrid.innerHTML = `<div class="col-span-full text-center py-10 text-gray-500">${this.i18n.no_results}</div>`
      }
      return
    }

    this.albumsGrid.innerHTML = this.state.albums.map(album => {
      const coverUrl = album.cover_url || 'https://via.placeholder.com/400x300/1A1A1A/FFD700?text=No+Cover'
      const date = new Date(album.created_at).toLocaleDateString(this.i18n.locale === 'ru' ? 'ru-RU' : 'en-US', {
        year: 'numeric', month: 'long', day: 'numeric'
      })

      return `
        <div class="bg-[#1A1A1A] rounded-xl overflow-hidden border border-white/5 hover:border-amber-400 transition duration-300 group cursor-pointer shadow-md hover:shadow-xl" data-action="click->gallery#openAlbum" data-gallery-album-id="${album.id}">
          <div class="relative w-full aspect-[4/3] overflow-hidden bg-[#252525]">
            <img src="${coverUrl}" loading="lazy" alt="${this.escapeHtml(album.title)}" class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500">
          </div>
          <div class="p-5">
            <h3 class="text-lg font-bold text-white mb-1 truncate group-hover:text-amber-400 transition-colors">${this.escapeHtml(album.title)}</h3>
            <div class="flex justify-between items-center text-sm text-gray-400">
              <span class="flex items-center gap-1">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"></path></svg>
                ${album.photos_count || 0}
              </span>
              <span>${date}</span>
            </div>
          </div>
        </div>
      `
    }).join('')
  }

  async openAlbum(event) {
    const id = event?.detail?.albumId || parseInt(event?.currentTarget?.dataset?.galleryAlbumId)
    if (!id) return

    try {
      const response = await fetch(`${this.authServiceUrl}/api/v1/galleries/${id}`)
      if (!response.ok) throw new Error(this.i18n.errors.open_failed)

      const album = await response.json()
      this.state.currentAlbum = album
      this.state.currentPhotos = album.photos || []

      if (this.albumTitle) this.albumTitle.textContent = album.title
      if (this.albumDescription) this.albumDescription.textContent = album.description || this.i18n.album.no_description
      if (this.albumDate) this.albumDate.textContent = new Date(album.created_at).toLocaleDateString(this.i18n.locale === 'ru' ? 'ru-RU' : 'en-US')
      if (this.albumCount) this.albumCount.textContent = this.pluralize(this.state.currentPhotos.length)

      this.renderPhotos()

      if (this.galleryControlPanel) this.galleryControlPanel.classList.add('hidden')
      if (this.albumsContainer) this.albumsContainer.classList.add('hidden')
      if (this.albumViewContainer) this.albumViewContainer.classList.remove('hidden')

      window.scrollTo({ top: 0, behavior: 'smooth' })
    } catch (error) {
      console.error(error)
      alert(this.i18n.errors.open_failed)
    }
  }

  renderPhotos() {
    if (this.state.currentPhotos.length === 0) {
      if (this.photosGrid) {
        this.photosGrid.innerHTML = `<div class="col-span-full text-center py-10 text-gray-500">${this.i18n.album.empty}</div>`
      }
      return
    }

    this.photosGrid.innerHTML = this.state.currentPhotos.map((photo, index) => {
      const hasTitle = photo.title && photo.title.trim().length > 0
      return `
        <div class="break-inside-avoid mb-6 group cursor-pointer" data-action="click->gallery#openLightbox" data-lightbox-index="${index}">
          <div class="bg-[#121212] rounded-xl overflow-hidden border border-white/5 hover:border-amber-400 transition duration-300 shadow-sm hover:shadow-lg">
            <div class="relative overflow-hidden">
              <img src="${photo.file_url}" loading="lazy" alt="Photo" class="w-full h-auto object-cover group-hover:scale-105 transition-transform duration-500">
              <div class="absolute inset-0 bg-black/20 opacity-0 group-hover:opacity-100 transition-opacity duration-300"></div>
            </div>
            ${hasTitle ? `
              <div class="p-4 border-t border-white/5 bg-[#1A1A1A]">
                <h4 class="text-white font-medium text-sm leading-snug">${this.escapeHtml(photo.title)}</h4>
              </div>
            ` : ''}
          </div>
        </div>
      `
    }).join('')
  }

  closeAlbum() {
    this.state.currentAlbum = null
    this.state.currentPhotos = []

    if (this.galleryControlPanel) this.galleryControlPanel.classList.remove('hidden')
    if (this.albumViewContainer) this.albumViewContainer.classList.add('hidden')
    if (this.albumsContainer) this.albumsContainer.classList.remove('hidden')
  }

  openLightbox(event) {
    const el = event?.currentTarget
    const index = el?.dataset?.lightboxIndex ?? 0
    this.state.currentPhotoIndex = parseInt(index)
    this.updateLightboxContent()
    if (this.lightbox) this.lightbox.classList.remove('hidden')
    document.body.style.overflow = 'hidden'
  }

  updateLightboxContent() {
    const photo = this.state.currentPhotos[this.state.currentPhotoIndex]
    if (!photo) return

    const nextIdx = (this.state.currentPhotoIndex + 1) % this.state.currentPhotos.length
    const prevIdx = (this.state.currentPhotoIndex - 1 + this.state.currentPhotos.length) % this.state.currentPhotos.length

    if (this.state.currentPhotos[nextIdx]) new Image().src = this.state.currentPhotos[nextIdx].file_url
    if (this.state.currentPhotos[prevIdx]) new Image().src = this.state.currentPhotos[prevIdx].file_url

    if (this.lightboxImage) this.lightboxImage.src = photo.file_url
    if (this.lightboxCounter) this.lightboxCounter.textContent = `${this.state.currentPhotoIndex + 1} / ${this.state.currentPhotos.length}`

    if (this.lightboxCaption) {
      if (photo.title && photo.title.trim().length > 0) {
        this.lightboxCaption.querySelector('span').textContent = photo.title
        this.lightboxCaption.classList.remove('hidden')
      } else {
        this.lightboxCaption.classList.add('hidden')
      }
    }
  }

  closeLightbox() {
    if (this.lightbox) this.lightbox.classList.add('hidden')
    document.body.style.overflow = ''
  }

  nextPhoto() {
    this.state.currentPhotoIndex = (this.state.currentPhotoIndex + 1) % this.state.currentPhotos.length
    this.updateLightboxContent()
  }

  prevPhoto() {
    this.state.currentPhotoIndex = (this.state.currentPhotoIndex - 1 + this.state.currentPhotos.length) % this.state.currentPhotos.length
    this.updateLightboxContent()
  }

  renderPagination() {
    if (this.state.totalPages <= 1) {
      if (this.albumsPagination) this.albumsPagination.innerHTML = ''
      return
    }

    let html = ''
    const current = this.state.currentPage
    const total = this.state.totalPages
    const pageRange = []

    if (total <= 7) {
      for (let i = 1; i <= total; i++) pageRange.push(i)
    } else {
      if (current <= 4) pageRange.push(1, 2, 3, 4, 5, '...', total)
      else if (current >= total - 3) pageRange.push(1, '...', total - 4, total - 3, total - 2, total - 1, total)
      else pageRange.push(1, '...', current - 1, current, current + 1, '...', total)
    }

    pageRange.forEach(p => {
      if (p === '...') {
        html += `<span class="text-gray-500 px-2">...</span>`
      } else {
        const activeClass = p === current ? 'bg-amber-400 text-black font-semibold shadow-md border-amber-400' : 'bg-[#121212] text-white border-amber-400 hover:bg-[#1a1a1a]'
        html += `<button data-action="gallery#goToPage" data-page="${p}" class="btn border-2 transition ${activeClass} w-10 h-10 min-h-0 px-0 mx-1 rounded-lg">${p}</button>`
      }
    })

    if (this.albumsPagination) this.albumsPagination.innerHTML = html
  }

  goToPage(event) {
    const page = parseInt(event.target.dataset.page)
    if (page) {
      this.state.currentPage = page
      this.loadAlbums()
      window.scrollTo({ top: 0, behavior: 'smooth' })
    }
  }

  pluralize(count) {
    if (this.i18n.locale === 'ru') {
      const mod10 = count % 10
      const mod100 = count % 100
      if (mod10 === 1 && mod100 !== 11) return this.i18n.album.photos.one.replace('%{count}', count)
      if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) return this.i18n.album.photos.few.replace('%{count}', count)
      return this.i18n.album.photos.many.replace('%{count}', count)
    } else {
      return this.i18n.album.photos.other.replace('%{count}', count)
    }
  }

  escapeHtml(unsafe) {
    if (!unsafe) return ''
    return unsafe.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#039;')
  }
}
