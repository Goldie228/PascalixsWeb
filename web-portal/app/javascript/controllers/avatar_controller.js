import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dropArea", "previewContainer", "preview", "button", "uploadBtn", "input", "gifIndicator", "cropBtn", "deleteBtn", "smallAvatar", "mediumAvatar", "largeAvatar", "statusIndicator", "statusText", "statusInfo", "cropImage"]

  connect() {
    this.authUrl = "<%= ENV['IDENTITY_SERVICE_URL'] || '' %>"
    this.i18n = {
      locale: "<%= I18n.locale %>",
      error_gif_for_sponsors_only: "<%= j t('views.users.avatar_modal.error_gif_for_sponsors_only') %>",
      error_gif_editing_unavailable: "<%= j t('views.users.avatar_modal.error_gif_editing_unavailable') %>",
      error_modal_not_found: "<%= j t('views.users.avatar_modal.error_modal_not_found') %>",
      error_confirmation_modal_not_found: "<%= j t('views.users.avatar_modal.error_confirmation_modal_not_found') %>",
      error_crop_modal_not_found: "<%= j t('views.users.avatar_modal.error_crop_modal_not_found') %>",
      error_no_original_image: "<%= j t('views.users.avatar_modal.error_no_original_image') %>",
      error_cropper_not_loaded: "<%= j t('views.users.avatar_modal.error_cropper_not_loaded') %>",
      error_cropper_init: "<%= j t('views.users.avatar_modal.error_cropper_init') %>",
      error_rotate_unavailable: "<%= j t('views.users.avatar_modal.error_rotate_unavailable') %>",
      error_rotate_image: "<%= j t('views.users.avatar_modal.error_rotate_image') %>",
      error_reset_unavailable: "<%= j t('views.users.avatar_modal.error_reset_unavailable') %>",
      error_reset_crop: "<%= j t('views.users.avatar_modal.error_reset_crop') %>",
      error_crop_unavailable: "<%= j t('views.users.avatar_modal.error_crop_unavailable') %>",
      error_create_file: "<%= j t('views.users.avatar_modal.error_create_file') %>",
      error_crop_image: "<%= j t('views.users.avatar_modal.error_crop_image') %>",
      error_crop_operation: "<%= j t('views.users.avatar_modal.error_crop_operation') %>",
      error_destroy_cropper: "<%= j t('views.users.avatar_modal.error_destroy_cropper') %>",
      error_no_file: "<%= j t('views.users.avatar_modal.error_no_file') %>",
      error_file_type: "<%= j t('views.users.avatar_modal.error_file_type') %>",
      error_file_size: "<%= j t('views.users.avatar_modal.error_file_size') %>",
      notification_avatar_uploaded: "<%= j t('views.users.avatar_modal.notification_avatar_uploaded') %>",
      notification_upload_error: "<%= j t('views.users.avatar_modal.notification_upload_error') %>",
      notification_avatar_deleted: "<%= j t('views.users.avatar_modal.notification_avatar_deleted') %>",
      notification_delete_error: "<%= j t('views.users.avatar_modal.notification_delete_error') %>",
      notification_photo_cropped: "<%= j t('views.users.avatar_modal.notification_photo_cropped') %>",
      status_none: "<%= j t('views.users.avatar_modal.status_none') %>",
      status_draft: "<%= j t('views.users.avatar_modal.status_draft') %>",
      status_pending: "<%= j t('views.users.avatar_modal.status_pending') %>",
      status_approved: "<%= j t('views.users.avatar_modal.status_approved') %>",
      status_rejected: "<%= j t('views.users.avatar_modal.status_rejected') %>",
      status_info_none: "<%= j t('views.users.avatar_modal.status_info_none') %>",
      status_info_draft: "<%= j t('views.users.avatar_modal.status_info_draft') %>",
      status_info_pending: "<%= j t('views.users.avatar_modal.status_info_pending') %>",
      status_info_approved: "<%= j t('views.users.avatar_modal.status_info_approved') %>",
      status_info_rejected: "<%= j t('views.users.avatar_modal.status_info_rejected') %>"
    }
    this.avatarFile = null
    this.originalAvatarFile = null
    this.originalAvatarBlob = null
    this.cropper = null
    this.croppedCanvas = null
    this.croppedFile = null
    this.currentAvatarBlobUrl = null
    this.currentAvatarBlob = null
    this.avatarUploaded = false
    this.playerUserId = "<%= @player.user_id.present? ? @player.user_id : current_user.id %>"
    this.isSponsor = <%= current_user.is_sponsor %>
    this.currentAvatarStatus = 'none'
    this.avatarStatuses = {
      none: { text: this.i18n.status_none, color: 'bg-gray-500', info: this.i18n.status_info_none },
      draft: { text: this.i18n.status_draft, color: 'bg-gray-500', info: this.i18n.status_info_draft },
      pending: { text: this.i18n.status_pending, color: 'bg-yellow-500', info: this.i18n.status_info_pending },
      approved: { text: this.i18n.status_approved, color: 'bg-green-500', info: this.i18n.status_info_approved },
      rejected: { text: this.i18n.status_rejected, color: 'bg-red-500', info: this.i18n.status_info_rejected }
    }
    this.setupDropHandlers()
    this.setupModalListeners()
  }

  disconnect() {
    if (this.cropper) this.cropper.destroy()
    if (this.currentAvatarBlobUrl) URL.revokeObjectURL(this.currentAvatarBlobUrl)
  }

  open() {
    this.cleanupModalEventListeners()
    const modal = document.getElementById('avatar_modal')
    if (modal) {
      if (modal.open) modal.close()
      this.resetModalState()
      const closeHandler = () => this.close()
      modal.addEventListener('close', closeHandler)
      this.modalEventListeners.push({ element: modal, type: 'close', handler: closeHandler })
      modal.showModal()
      this.loadCurrentAvatar()
    } else {
      this.showNotification(this.i18n.error_modal_not_found)
    }
  }

  close() {
    if (this.cropper) {
      try { this.cropper.destroy() } catch (error) { console.error('Error destroying cropper:', error) }
      finally { this.cropper = null }
    }
    if (this.currentAvatarBlobUrl) { URL.revokeObjectURL(this.currentAvatarBlobUrl); this.currentAvatarBlobUrl = null }
    const modal = document.getElementById('avatar_modal')
    if (modal && modal.open) modal.close()
    this.avatarFile = null
    this.originalAvatarFile = null
    this.originalAvatarBlob = null
    this.croppedCanvas = null
    this.croppedFile = null
    this.currentAvatarBlob = null
    this.avatarUploaded = false
  }

  async loadCurrentAvatar() {
    const url = `${this.getAuthUrl()}/api/v1/discord_avatar/${this.playerUserId}`
    try {
      const response = await fetch(url, { method: 'GET', headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': this.getCsrfToken(), 'X-User-ID': this.playerUserId }, credentials: 'same-origin' })
      if (!response.ok) throw new Error('Network response was not ok')
      const data = await response.json()
      if (data && data.id && data.url) {
        const blobResponse = await fetch(data.url)
        const blob = await blobResponse.blob()
        this.currentAvatarBlob = blob
        this.originalAvatarBlob = blob
        const blobUrl = URL.createObjectURL(blob)
        this.updateAvatarPreviews(blobUrl)
        if (this.previewTarget) this.previewTarget.src = blobUrl
        const previewContainer = document.getElementById('avatar-preview-container')
        const dropArea = document.getElementById('avatar-drop-area')
        if (previewContainer) previewContainer.classList.remove('hidden')
        if (dropArea) dropArea.style.display = 'none'
        if (this.buttonTarget) this.buttonTarget.classList.remove('hidden')
        if (this.deleteBtnTarget) this.deleteBtnTarget.classList.remove('hidden')
        if (this.uploadBtnTarget) this.uploadBtnTarget.disabled = false
        if (blob.type === 'image/gif') {
          if (this.gifIndicator) this.gifIndicator.classList.remove('hidden')
          if (this.cropBtnTarget) this.cropBtnTarget.style.display = 'none'
        }
      } else {
        this.updateAvatarPreviews('https://ui-avatars.com/api/?name=User&background=333&color=fff')
      }
      this.currentAvatarStatus = data.status || 'none'
      this.updateAvatarStatus(this.currentAvatarStatus)
    } catch (error) {
      this.updateAvatarPreviews('https://ui-avatars.com/api/?name=User&background=333&color=fff')
      this.currentAvatarStatus = 'none'
      this.updateAvatarStatus(this.currentAvatarStatus)
    }
  }

  setupDropHandlers() {
    const dropArea = this.dropAreaTarget
    if (!dropArea) return
    dropArea.addEventListener('dragover', (e) => { e.preventDefault(); e.stopPropagation(); dropArea.classList.add('border-amber-400', 'bg-amber-900/30') })
    dropArea.addEventListener('dragleave', (e) => { e.preventDefault(); e.stopPropagation(); dropArea.classList.remove('border-amber-400', 'bg-amber-900/30') })
    dropArea.addEventListener('drop', (e) => {
      e.preventDefault(); e.stopPropagation()
      dropArea.classList.remove('border-amber-400', 'bg-amber-900/30')
      if (e.dataTransfer.files.length > 0) this.handleAvatarFile(e.dataTransfer.files)
    })
    dropArea.addEventListener('click', () => document.getElementById('avatar-input')?.click())
  }

  setupModalListeners() {
    const modal = document.getElementById('avatar_modal')
    if (!modal) return
    modal.addEventListener('close', () => this.close())
    modal.addEventListener('open', () => {
      const firstFocusable = modal.querySelector('button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])')
      if (firstFocusable) firstFocusable.focus()
    })
  }

  cleanupModalEventListeners() {
    this.modalEventListeners?.forEach(({ element, type, handler }) => element.removeEventListener(type, handler))
    this.modalEventListeners = []
  }

  resetModalState() {
    this.avatarFile = null; this.originalAvatarFile = null; this.originalAvatarBlob = null; this.croppedFile = null; this.currentAvatarBlob = null; this.avatarUploaded = false
    if (this.currentAvatarBlobUrl) { URL.revokeObjectURL(this.currentAvatarBlobUrl); this.currentAvatarBlobUrl = null }
    const input = document.getElementById('avatar-input'); if (input) input.value = ''
    const previewContainer = document.getElementById('avatar-preview-container'); if (previewContainer) previewContainer.classList.add('hidden')
    const dropArea = document.getElementById('avatar-drop-area'); if (dropArea) dropArea.style.display = 'block'
    const uploadBtn = document.getElementById('upload-avatar-btn'); if (uploadBtn) uploadBtn.disabled = true
    const removeBtn = document.getElementById('avatar-remove-button'); if (removeBtn) removeBtn.classList.add('hidden')
    const deleteBtn = document.getElementById('delete-avatar-btn'); if (deleteBtn) deleteBtn.classList.add('hidden')
    if (this.gifIndicator) this.gifIndicator.classList.add('hidden')
    if (this.cropBtnTarget) this.cropBtnTarget.style.display = 'block'
    const placeholderUrl = 'https://ui-avatars.com/api/?name=User&background=333&color=fff'
    if (this.smallAvatarTarget) this.smallAvatarTarget.src = placeholderUrl
    if (this.mediumAvatarTarget) this.mediumAvatarTarget.src = placeholderUrl
    if (this.largeAvatarTarget) this.largeAvatarTarget.src = placeholderUrl
    this.currentAvatarStatus = 'none'
    this.updateAvatarStatus(this.currentAvatarStatus)
  }

  handleAvatarFile(files) {
    if (files.length === 0) return
    const file = files[0]
    if (file.type === 'image/gif' && !this.isSponsor) { this.showNotification(this.i18n.error_gif_for_sponsors_only); return }
    const allowedTypes = ['image/jpeg', 'image/png']
    if (this.isSponsor) allowedTypes.push('image/gif')
    if (!allowedTypes.includes(file.type)) { this.showNotification(this.i18n.error_file_type); return }
    if (file.size > 5 * 1024 * 1024) { this.showNotification(this.i18n.error_file_size); return }

    this.originalAvatarFile = file; this.avatarFile = file; this.croppedFile = null; this.currentAvatarBlob = null; this.originalAvatarBlob = null; this.avatarUploaded = false

    if (file.type === 'image/gif') this.handleGifFile(file)
    else this.handleImageFile(file)
  }

  handleImageFile(file) {
    this.createBasicCroppedFile(file, (blobUrl) => {
      if (this.previewTarget) this.previewTarget.src = blobUrl
      this.updateAvatarPreviews(blobUrl)
      const previewContainer = document.getElementById('avatar-preview-container'); if (previewContainer) previewContainer.classList.remove('hidden')
      const removeBtn = document.getElementById('avatar-remove-button'); if (removeBtn) removeBtn.classList.remove('hidden')
      const dropArea = document.getElementById('avatar-drop-area'); if (dropArea) dropArea.style.display = 'none'
      const uploadBtn = document.getElementById('upload-avatar-btn'); if (uploadBtn) uploadBtn.disabled = false
      if (this.gifIndicator) this.gifIndicator.classList.add('hidden')
      if (this.cropBtnTarget) this.cropBtnTarget.style.display = 'block'
      this.currentAvatarStatus = 'draft'; this.updateAvatarStatus(this.currentAvatarStatus)
    })
  }

  handleGifFile(file) {
    const blobUrl = URL.createObjectURL(file)
    if (this.previewTarget) this.previewTarget.src = blobUrl
    this.updateAvatarPreviews(blobUrl)
    const previewContainer = document.getElementById('avatar-preview-container'); if (previewContainer) previewContainer.classList.remove('hidden')
    const removeBtn = document.getElementById('avatar-remove-button'); if (removeBtn) removeBtn.classList.remove('hidden')
    const dropArea = document.getElementById('avatar-drop-area'); if (dropArea) dropArea.style.display = 'none'
    const uploadBtn = document.getElementById('upload-avatar-btn'); if (uploadBtn) uploadBtn.disabled = false
    if (this.gifIndicator) this.gifIndicator.classList.remove('hidden')
    if (this.cropBtnTarget) this.cropBtnTarget.style.display = 'none'
    this.currentAvatarStatus = 'draft'; this.updateAvatarStatus(this.currentAvatarStatus)
  }

  removeAvatar() {
    this.avatarFile = null; this.originalAvatarFile = null; this.originalAvatarBlob = null; this.croppedFile = null; this.currentAvatarBlob = null; this.avatarUploaded = false
    if (this.currentAvatarBlobUrl) { URL.revokeObjectURL(this.currentAvatarBlobUrl); this.currentAvatarBlobUrl = null }
    const input = document.getElementById('avatar-input'); if (input) input.value = ''
    const previewContainer = document.getElementById('avatar-preview-container'); if (previewContainer) previewContainer.classList.add('hidden')
    const dropArea = document.getElementById('avatar-drop-area'); if (dropArea) dropArea.style.display = 'block'
    if (this.gifIndicator) this.gifIndicator.classList.add('hidden')
    if (this.cropBtnTarget) this.cropBtnTarget.style.display = 'block'
    const placeholderUrl = 'https://ui-avatars.com/api/?name=User&background=333&color=fff'
    if (this.smallAvatarTarget) this.smallAvatarTarget.src = placeholderUrl
    if (this.mediumAvatarTarget) this.mediumAvatarTarget.src = placeholderUrl
    if (this.largeAvatarTarget) this.largeAvatarTarget.src = placeholderUrl
    const uploadBtn = document.getElementById('upload-avatar-btn'); if (uploadBtn) uploadBtn.disabled = true
    const removeBtn = document.getElementById('avatar-remove-button'); if (removeBtn) removeBtn.classList.add('hidden')
    this.currentAvatarStatus = 'none'; this.updateAvatarStatus(this.currentAvatarStatus)
  }

  confirmDeleteAvatar() {
    const modal = document.getElementById('confirm_avatar_deletion_modal')
    if (modal) modal.showModal()
    else this.showNotification(this.i18n.error_confirmation_modal_not_found)
  }

  closeAvatarDeletionModal() {
    const modal = document.getElementById('confirm_avatar_deletion_modal')
    if (modal) modal.close()
  }

  async proceedAvatarDeletion() {
    try {
      const response = await fetch(`${this.getAuthUrl()}/api/v1/discord_avatar/${this.playerUserId}`, { method: 'DELETE', headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': this.getCsrfToken(), 'X-User-ID': this.playerUserId }, credentials: 'same-origin' })
      if (response.status === 204) { }
      else if (!response.ok) { const text = await response.text(); let errorData; try { errorData = JSON.parse(text) } catch (e) { errorData = { message: text } }; throw new Error(errorData.error || errorData.message || 'Network response was not ok') }
      else { await response.json() }
      this.showNotification(this.i18n.notification_avatar_deleted)
      const deletionModal = document.getElementById('confirm_avatar_deletion_modal'); if (deletionModal) deletionModal.close()
      const avatarModal = document.getElementById('avatar_modal'); if (avatarModal) avatarModal.close()
      setTimeout(() => window.location.reload(), 1000)
    } catch (error) {
      this.showNotification(`${this.i18n.notification_delete_error}: ${error.message}`)
      const deletionModal = document.getElementById('confirm_avatar_deletion_modal'); if (deletionModal) deletionModal.close()
    }
  }

  openCropModal() {
    if (this.cropper) this.closeCropModal()
    if (this.originalAvatarFile && this.originalAvatarFile.type === 'image/gif') { this.showNotification(this.i18n.error_gif_editing_unavailable); return }
    const modal = document.getElementById('crop_modal')
    const cropImage = document.getElementById('crop-image')
    if (!modal || !cropImage) { this.showNotification(this.i18n.error_crop_modal_not_found); return }
    let imageSource
    if (this.originalAvatarFile) {
      const reader = new FileReader()
      reader.onload = (e) => { imageSource = e.target.result; this.setupCropper(imageSource) }
      reader.readAsDataURL(this.originalAvatarFile)
      return
    } else if (this.originalAvatarBlob) {
      imageSource = URL.createObjectURL(this.originalAvatarBlob)
      this.setupCropper(imageSource)
      return
    } else {
      this.showNotification(this.i18n.error_no_original_image)
      return
    }
  }

  setupCropper(imageSource) {
    const cropImage = document.getElementById('crop-image')
    const modal = document.getElementById('crop_modal')
    cropImage.src = imageSource
    cropImage.classList.remove('hidden')
    modal.showModal()
    setTimeout(() => {
      if (this.cropper) { this.cropper.destroy(); this.cropper = null }
      if (typeof Cropper === 'undefined') { this.showNotification(this.i18n.error_cropper_not_loaded); return }
      try {
        this.cropper = new Cropper(cropImage, { aspectRatio: 1, viewMode: 1, autoCropArea: 0.8, responsive: true, checkCrossOrigin: false, background: false, guides: true, center: true, highlight: false, cropBoxMovable: true, cropBoxResizable: true, toggleDragModeOnDblclick: false, minCropBoxWidth: 100, minCropBoxHeight: 100 })
      } catch (error) { this.showNotification(this.i18n.error_cropper_init); this.cropper = null }
    }, 100)
  }

  rotateCrop(degrees) {
    if (!this.cropper || typeof this.cropper.rotate !== 'function') { this.showNotification(this.i18n.error_rotate_unavailable); return }
    try { this.cropper.rotate(degrees) } catch (error) { this.showNotification(this.i18n.error_rotate_image) }
  }

  resetCrop() {
    if (this.cropper && typeof this.cropper.reset === 'function') {
      try { this.cropper.reset() } catch (error) { this.showNotification(this.i18n.error_reset_crop) }
    } else { this.showNotification(this.i18n.error_reset_unavailable) }
  }

  applyCrop() {
    if (!this.cropper || typeof this.cropper.getCroppedCanvas !== 'function') { this.showNotification(this.i18n.error_crop_unavailable); return }
    try {
      this.croppedCanvas = this.cropper.getCroppedCanvas({ width: 400, height: 400, minWidth: 256, minHeight: 256, maxWidth: 4096, maxHeight: 4096, fillColor: '#fff', imageSmoothingEnabled: true, imageSmoothingQuality: 'high' })
      if (this.croppedCanvas) {
        const originalMimeType = this.originalAvatarFile ? this.originalAvatarFile.type : 'image/jpeg'
        this.croppedCanvas.toBlob((blob) => {
          if (blob) {
            const originalName = this.originalAvatarFile ? this.originalAvatarFile.name : `avatar.${originalMimeType.split('/')[1] || 'jpg'}`
            this.croppedFile = new File([blob], originalName, { type: originalMimeType })
            const blobUrl = URL.createObjectURL(blob)
            if (this.previewTarget) this.previewTarget.src = blobUrl
            this.updateAvatarPreviews(blobUrl)
            this.currentAvatarStatus = 'draft'; this.updateAvatarStatus(this.currentAvatarStatus)
            this.closeCropModal()
            this.showNotification(this.i18n.notification_photo_cropped)
          } else { this.showNotification(this.i18n.error_create_file) }
        }, originalMimeType, 0.9)
      } else { this.showNotification(this.i18n.error_crop_image) }
    } catch (error) { this.showNotification(this.i18n.error_crop_operation); this.closeCropModal() }
  }

  closeCropModal() {
    const modal = document.getElementById('crop_modal')
    if (this.cropper) {
      try {
        const cropImage = document.getElementById('crop-image')
        if (cropImage) { cropImage.classList.add('hidden'); cropImage.src = '' }
        this.cropper.destroy()
      } catch (error) { console.error('Error in crop cleanup:', error) }
      finally { this.cropper = null }
    }
    if (modal && modal.open) modal.close()
  }

  uploadAvatar() {
    let fileToSend = null
    if (this.originalAvatarFile && this.originalAvatarFile.type === 'image/gif') { fileToSend = this.originalAvatarFile; this.proceedWithUpload(fileToSend); return }
    if (this.croppedFile) { fileToSend = this.croppedFile; this.proceedWithUpload(fileToSend) }
    else if (this.originalAvatarFile) {
      this.createBasicCroppedFileForUpload(this.originalAvatarFile, (croppedFile) => { fileToSend = croppedFile; this.proceedWithUpload(fileToSend) })
    } else if (this.originalAvatarBlob) {
      const tempFile = new File([this.originalAvatarBlob], "temp_avatar.jpg", { type: this.originalAvatarBlob.type })
      this.createBasicCroppedFileForUpload(tempFile, (croppedFile) => { fileToSend = croppedFile; this.proceedWithUpload(fileToSend) })
    } else { this.showNotification(this.i18n.error_no_file); return }
  }

  proceedWithUpload(fileToSend) {
    const formData = new FormData()
    formData.append('avatar', fileToSend)
    const url = `${this.getAuthUrl()}/api/v1/discord_avatar/${this.playerUserId}`
    fetch(url, { method: 'POST', headers: { 'X-CSRF-Token': this.getCsrfToken(), 'X-User-ID': this.playerUserId }, body: formData, credentials: 'same-origin' })
      .then(response => { if (!response.ok) throw new Error('Network response was not ok'); return response.json() })
      .then(data => {
        this.showNotification(this.i18n.notification_avatar_uploaded)
        this.avatarUploaded = true; this.currentAvatarStatus = 'pending'; this.updateAvatarStatus(this.currentAvatarStatus)
        this.close()
      })
      .catch(error => { this.showNotification(this.i18n.notification_upload_error) })
  }

  createBasicCroppedFile(inputFile, callback) {
    if (inputFile.type === 'image/gif') { callback(URL.createObjectURL(inputFile)); return }
    const img = new Image()
    const reader = new FileReader()
    reader.onload = (e) => {
      img.onload = () => {
        const canvas = document.createElement('canvas')
        const ctx = canvas.getContext('2d')
        const size = Math.min(img.width, img.height)
        canvas.width = size; canvas.height = size
        const sx = (img.width - size) / 2; const sy = (img.height - size) / 2
        ctx.drawImage(img, sx, sy, size, size, 0, 0, size, size)
        const mimeType = inputFile.type || 'image/jpeg'
        canvas.toBlob((blob) => { callback(URL.createObjectURL(blob)) }, mimeType, 0.9)
      }
      img.src = e.target.result
    }
    reader.readAsDataURL(inputFile)
  }

  createBasicCroppedFileForUpload(inputFile, callback) {
    if (inputFile.type === 'image/gif') { callback(inputFile); return }
    const img = new Image()
    const reader = new FileReader()
    reader.onload = (e) => {
      img.onload = () => {
        const canvas = document.createElement('canvas')
        const ctx = canvas.getContext('2d')
        const size = Math.min(img.width, img.height)
        canvas.width = size; canvas.height = size
        const sx = (img.width - size) / 2; const sy = (img.height - size) / 2
        ctx.drawImage(img, sx, sy, size, size, 0, 0, size, size)
        const mimeType = inputFile.type || 'image/jpeg'
        canvas.toBlob((blob) => {
          const fileName = inputFile.name || `avatar.${mimeType.split('/')[1] || 'jpg'}`
          callback(new File([blob], fileName, { type: mimeType }))
        }, mimeType, 0.9)
      }
      img.src = e.target.result
    }
    reader.readAsDataURL(inputFile)
  }

  updateAvatarPreviews(avatarUrl) {
    const placeholderUrl = 'https://ui-avatars.com/api/?name=User&background=333&color=fff'
    if (!avatarUrl || avatarUrl === placeholderUrl) {
      if (this.smallAvatarTarget) this.smallAvatarTarget.src = placeholderUrl
      if (this.mediumAvatarTarget) this.mediumAvatarTarget.src = placeholderUrl
      if (this.largeAvatarTarget) this.largeAvatarTarget.src = placeholderUrl
      return
    }
    const img = new Image()
    img.onload = () => {
      if (this.smallAvatarTarget) this.smallAvatarTarget.src = avatarUrl
      if (this.mediumAvatarTarget) this.mediumAvatarTarget.src = avatarUrl
      if (this.largeAvatarTarget) this.largeAvatarTarget.src = avatarUrl
      if (this.currentAvatarBlobUrl && this.currentAvatarBlobUrl !== avatarUrl) URL.revokeObjectURL(this.currentAvatarBlobUrl)
      this.currentAvatarBlobUrl = avatarUrl
    }
    img.onerror = () => {
      if (this.smallAvatarTarget) this.smallAvatarTarget.src = placeholderUrl
      if (this.mediumAvatarTarget) this.mediumAvatarTarget.src = placeholderUrl
      if (this.largeAvatarTarget) this.largeAvatarTarget.src = placeholderUrl
    }
    img.src = avatarUrl
  }

  updateAvatarStatus(status) {
    const statusData = this.avatarStatuses[status] || this.avatarStatuses.none
    if (this.statusIndicatorTarget) this.statusIndicatorTarget.className = `w-3 h-3 rounded-full ${statusData.color}`
    if (this.statusTextTarget) this.statusTextTarget.textContent = statusData.text
    if (this.statusInfoTarget) this.statusInfoTarget.textContent = statusData.info
  }

  getAuthUrl() {
    if (!this.authUrl) this.authUrl = window.location.origin
    return this.authUrl
  }

  getCsrfToken() { return document.querySelector('meta[name="csrf-token"]')?.content }

  showNotification(message) {
    const notification = document.createElement('div')
    notification.className = 'fixed bottom-4 right-4 bg-amber-500 text-white px-6 py-3 rounded-lg shadow-lg z-50 animate-fadeIn'
    notification.textContent = message
    document.body.appendChild(notification)
    setTimeout(() => { notification.style.opacity = '0'; setTimeout(() => { if (document.body.contains(notification)) document.body.removeChild(notification) }, 300) }, 3000)
  }
}
