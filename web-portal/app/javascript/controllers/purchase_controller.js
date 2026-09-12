import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["type", "amount", "status", "dropArea", "previewContainer", "preview", "button", "submitBtn", "input", "receiptUploadSection", "loader", "viewerModal", "viewerContainer", "viewerLoader", "viewerInfo", "downloadBtn"]

  connect() {
    this.authUrl = "<%= ENV['IDENTITY_SERVICE_URL'] || '' %>"
    this.translations = {
      status_pending: "<%= j t('views.purchases.modal.status_pending') %>",
      error_loading_purchases: "<%= j t('views.purchases.modal.error_loading_purchases') %>",
      receipt_submitted: "<%= j t('views.purchases.modal.receipt_submitted') %>",
      replace_receipt: "<%= j t('views.purchases.modal.replace_receipt') %>",
      revoke_receipt: "<%= j t('views.purchases.modal.revoke_receipt') %>",
      deleting: "<%= j t('views.purchases.modal.deleting') %>",
      receipt_revoked: "<%= j t('views.purchases.modal.receipt_revoked') %>",
      error_revoking_receipt: "<%= j t('views.purchases.modal.error_revoking_receipt') %>",
      error_revoking_receipt_retry: "<%= j t('views.purchases.modal.error_revoking_receipt_retry') %>",
      error_no_receipt_info: "<%= j t('views.purchases.modal.error_no_receipt_info') %>",
      loading_price: "<%= j t('views.purchases.modal.loading_price') %>",
      error_getting_price: "<%= j t('views.purchases.modal.error_getting_price') %>",
      loading: "<%= j t('views.purchases.modal.loading') %>",
      submit_receipt: "<%= j t('views.purchases.modal.submit_receipt') %>",
      please_upload_receipt: "<%= j t('views.purchases.modal.please_upload_receipt') %>",
      sending: "<%= j t('views.purchases.modal.sending') %>",
      receipt_deleted: "<%= j t('views.purchases.modal.receipt_deleted') %>",
      receipt_submitted_for_review: "<%= j t('views.purchases.modal.receipt_submitted_for_review') %>",
      error_submitting_receipt: "<%= j t('views.purchases.modal.error_submitting_receipt') %>",
      error_submitting_receipt_retry: "<%= j t('views.purchases.modal.error_submitting_receipt_retry') %>",
      price_unavailable: "<%= j t('views.purchases.modal.price_unavailable') %>",
      status_approved: "<%= j t('views.purchases.modal.status_approved') %>",
      status_rejected: "<%= j t('views.purchases.modal.status_rejected') %>",
      status_refunded: "<%= j t('views.purchases.modal.status_refunded') %>",
      type_pass_purchase: "<%= j t('views.purchases.modal.type_pass_purchase') %>",
      type_pass_gift: "<%= j t('views.purchases.modal.type_pass_gift') %>",
      type_donation: "<%= j t('views.purchases.modal.type_donation') %>",
      type_sponsor: "<%= j t('views.purchases.modal.type_sponsor') %>",
      type_unban: "<%= j t('views.purchases.modal.type_unban') %>",
      type_unmute: "<%= j t('views.purchases.modal.type_unmute') %>",
      please_select_image: "<%= j t('views.purchases.modal.please_select_image') %>",
      file_size_exceeded: "<%= j t('views.purchases.modal.file_size_exceeded', size: '5 MB') %>",
      receipt_viewer_alt: "<%= j t('views.purchases.modal.receipt_viewer_alt') %>",
      error_loading: "<%= j t('views.purchases.modal.error_loading') %>",
      error_loading_receipt_retry: "<%= j t('views.purchases.modal.error_loading_receipt_retry') %>",
      receipt_info: "<%= j t('views.purchases.modal.receipt_info') %>"
    }
    this.receiptFile = null
    this.existingReceipt = null
    this.removeExistingReceipt = false
    this.purchaseData = {
      type: 'pass_purchase',
      amount: '3.00',
      currency: 'USD',
      status: this.translations.status_pending,
      id: null,
      targetUserId: null
    }
    this.setupDropHandlers()
    this.setupDownloadBtn()
    this.setupModalListeners()
  }

  async open(event) {
    const purchaseType = event.target.dataset.purchaseType || 'pass_purchase'
    this.showGlobalLoading()

    try {
      const purchases = await this.loadUserPurchases({ purchase_type: purchaseType, status: 'pending', ...(targetId ? { target_user_id: targetId } : {}) })
      const modal = document.getElementById('purchase_modal')
      if (modal) modal.showModal()

      const purchase = purchases.length > 0 ? purchases[purchases.length - 1] : null
      if (purchase) {
        this.purchaseData.type = purchase.purchase_type
        this.purchaseData.amount = purchase.amount.toString()
        this.purchaseData.currency = purchase.currency || 'USD'
        this.purchaseData.status = purchase.status
        this.purchaseData.id = purchase.id
        if (purchase.target_user_id) this.purchaseData.targetUserId = purchase.target_user_id

        this.typeTarget.textContent = this.getPurchaseTypeName(this.purchaseData.type)
        this.amountTarget.textContent = `${this.purchaseData.amount} ${this.purchaseData.currency}`
        this.updateStatusDisplay(this.purchaseData.status)

        if (purchase.receipt) {
          this.existingReceipt = purchase.receipt
          this.displayReceipt(this.existingReceipt)
          this.dropAreaTarget.style.display = 'none'
          if (purchase.status !== 'pending') {
            this.submitBtnTarget.disabled = true
            this.submitBtnTarget.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" /></svg>${this.translations.receipt_submitted}`
          } else {
            this.addReplaceAndRevokeButtons(purchase)
          }
        }
      } else {
        this.amountTarget.textContent = this.translations.loading_price
        await this.updatePurchaseData(purchaseType, null)
        if (price) {
          this.purchaseData.amount = price.toString()
          this.amountTarget.textContent = `${this.purchaseData.amount} ${this.purchaseData.currency}`
        }
        this.dropAreaTarget.style.display = 'block'
        this.resetForNewPurchase()
        if (this.purchaseData.amount === null) {
          this.submitBtnTarget.disabled = true
          this.showAlertNotification(this.translations.error_getting_price)
        }
      }

      const receiptBtn = this.buttonTarget
      if (receiptBtn) {
        const replaceBtn = document.getElementById('replace-receipt')
        receiptBtn.classList.toggle('hidden', !!replaceBtn)
      }
    } catch (error) {
      this.showAlertNotification(this.translations.error_loading_purchases)
    } finally {
      this.hideGlobalLoading()
    }
  }

  close() {
    document.getElementById('replace-receipt')?.remove()
    document.getElementById('revoke-receipt')?.remove()
    const dropArea = document.getElementById('receipt-drop-area')
    if (dropArea) dropArea.style.display = 'none'
    const preview = document.getElementById('receipt-preview-container')
    if (preview) {
      preview.classList.add('hidden')
      const previewImg = document.getElementById('receipt-preview')
      if (previewImg) previewImg.src = ''
    }
    const fileInput = document.getElementById('receipt-input')
    if (fileInput) fileInput.value = ''
    const submitBtn = document.getElementById('submit-receipt-btn')
    if (submitBtn) {
      submitBtn.disabled = false
      submitBtn.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" /></svg>${this.translations.submit_receipt}`
    }
    this.purchaseData.targetUserId = null
    this.resetForNewPurchase()
    const typeEl = document.getElementById('purchase-type')
    const amountEl = document.getElementById('purchase-amount')
    const statusEl = document.getElementById('purchase-status')
    if (typeEl) typeEl.textContent = ''
    if (amountEl) amountEl.textContent = ''
    if (statusEl) statusEl.textContent = ''
    const modal = document.getElementById('purchase_modal')
    if (modal) modal.close()
    this.updateStatusDisplay('')
  }

  async submit() {
    if (!this.receiptFile && !this.existingReceipt && !this.removeExistingReceipt) {
      this.showAlertNotification(this.translations.please_upload_receipt)
      return
    }

    const submitBtn = document.getElementById('submit-receipt-btn')
    const originalText = submitBtn.innerHTML
    submitBtn.disabled = true
    submitBtn.innerHTML = `<span class="loading loading-spinner loading-md"></span><span class="ml-2">${this.translations.sending}</span>`

    try {
      const formData = new FormData()
      if (!this.purchaseData.id) {
        formData.append('purchase[purchase_type]', this.purchaseData.type)
        formData.append('purchase[amount]', this.purchaseData.amount)
        formData.append('purchase[currency]', this.purchaseData.currency)
        formData.append('purchase[purchaser_user_id]', this.getCurrentUserId())
        if (this.purchaseData.type === 'pass_gift' && this.purchaseData.targetUserId) {
          formData.append('purchase[target_user_id]', this.purchaseData.targetUserId)
        }
      }
      if (this.receiptFile) formData.append('receipt', this.receiptFile)
      if (this.removeExistingReceipt && this.existingReceipt) {
        formData.append('remove_receipt', 'true')
        formData.append('existing_receipt_id', this.existingReceipt.id)
      }

      const url = this.purchaseData.id ? `/purchases/${this.purchaseData.id}` : '/purchases'
      const method = this.purchaseData.id ? 'PATCH' : 'POST'
      const response = await fetch(url, { method, body: formData, headers: { 'X-CSRF-Token': this.getCsrfToken() }, credentials: 'same-origin' })
      const data = await response.json()

      if (response.ok) {
        this.purchaseData.status = 'pending'
        this.updateStatusDisplay(this.purchaseData.status)
        if (!this.purchaseData.id && data.id) this.purchaseData.id = data.id
        if (data.receipt && data.receipt.length > 0) {
          this.existingReceipt = data.receipt[0]
          this.displayReceipt(this.existingReceipt)
          this.dropAreaTarget.style.display = 'none'
        } else if (this.removeExistingReceipt) {
          document.getElementById('receipt-preview-container').classList.add('hidden')
          this.dropAreaTarget.style.display = 'block'
          this.existingReceipt = null
        }
        this.removeExistingReceipt = false
        this.close()
        this.showNotification(this.removeExistingReceipt ? this.translations.receipt_deleted : this.translations.receipt_submitted_for_review)
      } else {
        const errorMessage = data.errors ? data.errors.join(', ') : this.translations.error_submitting_receipt
        this.showAlertNotification(errorMessage)
      }
    } catch (error) {
      this.showAlertNotification(this.translations.error_submitting_receipt_retry)
    } finally {
      submitBtn.disabled = false
      submitBtn.innerHTML = originalText
    }
  }

  async revokeReceipt() {
    if (!this.existingReceipt || !this.purchaseData.id) {
      this.showAlertNotification(this.translations.error_no_receipt_info)
      return
    }

    this.removeReceipt()
    const revokeButton = document.getElementById('revoke-receipt')
    revokeButton.disabled = true
    revokeButton.innerHTML = `<span class="loading loading-spinner loading-sm"></span><span class="ml-2">${this.translations.deleting}</span>`

    try {
      const response = await fetch(`/purchases/${this.purchaseData.id}`, { method: 'DELETE', headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': this.getCsrfToken() }, credentials: 'same-origin' })
      if (response.ok) {
        this.showNotification(this.translations.receipt_revoked)
        document.getElementById('receipt-preview-container').classList.add('hidden')
        this.dropAreaTarget.style.display = 'block'
        this.existingReceipt = null
        this.receiptFile = null
        this.purchaseData.status = this.translations.status_pending
        this.updateStatusDisplay(this.purchaseData.status)
        document.getElementById('replace-receipt')?.remove()
        revokeButton.remove()
        document.getElementById('submit-receipt-btn').disabled = true
        document.getElementById('submit-receipt-btn').innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" /></svg>${this.translations.submit_receipt}`
      } else {
        const errorData = await response.json()
        const errorMessage = errorData.errors ? errorData.errors.join(', ') : this.translations.error_revoking_receipt
        this.showAlertNotification(errorMessage)
      }
    } catch (error) {
      this.showAlertNotification(this.translations.error_revoking_receipt_retry)
    } finally {
      revokeButton.disabled = false
      revokeButton.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M9 2a1 1 0 00-.894.553L7.382 4H4a1 1 0 000 2v10a2 2 0 002 2h8a2 2 0 002-2V6a1 1 0 100-2h-3.382l-.724-1.447A1 1 0 0011 2H9zM7 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z" clip-rule="evenodd" /></svg><span>${this.translations.revoke_receipt}</span>`
      this.updatePurchaseData(this.purchaseData.type, null)
      this.close()
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
      if (e.dataTransfer.files.length > 0) this.handleReceiptFile(e.dataTransfer.files)
    })
    dropArea.addEventListener('click', () => document.getElementById('receipt-input')?.click())
  }

  setupDownloadBtn() {
    const btn = this.downloadBtnTarget || document.getElementById('download-receipt')
    if (btn) {
      btn.addEventListener('click', async () => {
        const url = btn.getAttribute('data-receipt-url')
        if (url) await this.downloadFile(url, 'receipt.png')
      })
    }
  }

  setupModalListeners() {
    const modal = document.getElementById('purchase_modal')
    if (!modal) return

    modal.addEventListener('close', () => {
      this.resetForNewPurchase()
      document.querySelector('#receipt-upload-section button[onclick*="replace"]')?.remove()
    })
    modal.addEventListener('open', () => {
      const firstFocusable = modal.querySelector('button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])')
      if (firstFocusable) firstFocusable.focus()
    })
  }

  handleReceiptFile(files) {
    if (files.length === 0) return
    const file = files[0]
    const allowedTypes = ['image/jpeg', 'image/png']
    if (!allowedTypes.includes(file.type)) { this.showAlertNotification(this.translations.please_select_image); return }
    if (file.size > 5 * 1024 * 1024) { this.showAlertNotification(this.translations.file_size_exceeded); return }

    this.receiptFile = file
    this.removeExistingReceipt = false

    const previewContainer = document.getElementById('receipt-preview-container')
    let previewImg = document.getElementById('receipt-preview')
    if (!previewImg) {
      previewImg = document.createElement('img')
      previewImg.id = 'receipt-preview'
      previewImg.className = 'w-full h-auto object-contain cursor-pointer'
      previewImg.setAttribute('loading', 'lazy')
      const imageWrapper = previewContainer.querySelector('.relative')
      if (imageWrapper) imageWrapper.appendChild(previewImg)
      else previewContainer.appendChild(previewImg)
    }

    const reader = new FileReader()
    reader.onload = (e) => {
      previewImg.src = e.target.result
      previewImg.onclick = () => this.openReceiptViewer(e.target.result)
      previewContainer.classList.remove('hidden')
      const receiptBtn = document.getElementById('receipt-button')
      if (receiptBtn) receiptBtn.classList.remove('hidden')
      this.dropAreaTarget.style.display = 'none'
      if (this.purchaseData.amount !== null) document.getElementById('submit-receipt-btn').disabled = false
    }
    reader.readAsDataURL(file)
  }

  removeReceipt() {
    if (this.existingReceipt) {
      this.removeExistingReceipt = true
    } else {
      this.receiptFile = null
    }
    document.getElementById('receipt-input').value = ''
    document.getElementById('receipt-preview-container').classList.add('hidden')
    this.dropAreaTarget.style.display = 'block'
    document.getElementById('submit-receipt-btn').disabled = true
    document.getElementById('submit-receipt-btn').innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" /></svg>${this.translations.submit_receipt}`
  }

  openReceiptViewer(imageSource) {
    const modal = document.getElementById('receipt-viewer-modal')
    const container = document.getElementById('receipt-container')
    const loader = document.getElementById('receipt-loader')
    const downloadBtn = document.getElementById('download-receipt')
    loader.style.display = 'flex'
    container.innerHTML = ''

    const isBase64 = imageSource.startsWith('data:image')
    if (isBase64) downloadBtn.style.display = 'none'
    else {
      downloadBtn.style.display = ''
      downloadBtn.setAttribute('data-receipt-url', imageSource)
    }

    const img = document.createElement('img')
    img.src = imageSource
    img.className = 'max-w-full max-h-[70vh] object-contain'
    img.alt = this.translations.receipt_viewer_alt
    img.setAttribute('loading', 'lazy')
    if (!imageSource.startsWith('data:')) img.crossOrigin = "use-credentials"

    img.onload = () => { loader.style.display = 'none'; document.getElementById('receipt-info').textContent = this.translations.receipt_info }
    img.onerror = () => {
      loader.style.display = 'none'
      container.innerHTML = `<div class="text-center p-8"><div class="text-amber-400 text-5xl mb-4">⚠️</div><h3 class="text-xl font-bold text-white mb-2">${this.translations.error_loading}</h3><p class="text-amber-400/70">${this.translations.error_loading_receipt_retry}</p></div>`
    }
    container.appendChild(img)
    modal.showModal()
  }

  closeReceiptViewer() {
    this.dropAreaTarget.style.display = 'none'
    const modal = document.getElementById('receipt-viewer-modal')
    const downloadBtn = document.getElementById('download-receipt')
    downloadBtn.removeAttribute('data-receipt-url')
    downloadBtn.style.display = ''
    modal.close()
  }

  async loadUserPurchases(filters = {}) {
    const queryParams = new URLSearchParams()
    if (filters.purchase_type) queryParams.append('purchase_type', filters.purchase_type)
    if (filters.status) queryParams.append('status', filters.status)
    if (filters.target_user_id) queryParams.append('target_user_id', filters.target_user_id)
    try {
      const response = await fetch(`/purchases?${queryParams.toString()}`, { method: 'GET', headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': this.getCsrfToken() || '' }, credentials: 'same-origin' })
      return response.ok ? await response.json() : []
    } catch (error) {
      this.showAlertNotification(this.translations.error_loading_purchases)
      return []
    }
  }

  async getProductPrice(productType) {
    const url = this.authUrl && !this.authUrl.includes('<%') ? `${this.authUrl}/api/v1/product/${productType}` : `${this.authUrl}/api/v1/product/${productType}`
    try {
      const response = await fetch(url, { method: 'GET', headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': this.getCsrfToken() || '' }, credentials: 'same-origin' })
      if (response.ok) { const data = await response.json(); return data.price }
      return null
    } catch (error) { return null }
  }

  async updatePurchaseData(type, id) {
    this.purchaseData.type = type
    this.purchaseData.id = id
    this.typeTarget.textContent = this.getPurchaseTypeName(type)
    this.amountTarget.textContent = this.translations.loading_price
    const price = await this.getProductPrice(type)
    if (price !== null) {
      this.purchaseData.amount = price.toString()
      this.purchaseData.currency = 'USD'
      this.amountTarget.textContent = `${this.purchaseData.amount} ${this.purchaseData.currency}`
      this.amountTarget.classList.remove('text-red-500')
      if (this.receiptFile || this.existingReceipt) document.getElementById('submit-receipt-btn').disabled = false
    } else {
      this.purchaseData.amount = null
      this.purchaseData.currency = 'USD'
      this.amountTarget.textContent = this.translations.price_unavailable
      this.amountTarget.classList.add('text-red-500')
      document.getElementById('submit-receipt-btn').disabled = true
      document.getElementById('submit-receipt-btn').innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd" /></svg>${this.translations.error_getting_price}`
      this.showAlertNotification(this.translations.error_getting_price)
    }
  }

  updateStatusDisplay(status) {
    const statusElement = document.getElementById('purchase-status')
    const statusContainer = statusElement?.closest('div')
    if (!status || status.trim() === '') statusContainer.style.display = 'none'
    else {
      statusContainer.style.display = ''
      statusElement.textContent = this.getStatusName(status)
    }
  }

  resetForNewPurchase() {
    this.receiptFile = null
    this.existingReceipt = null
    this.removeExistingReceipt = false
    document.getElementById('receipt-input').value = ''
    const previewContainer = document.getElementById('receipt-preview-container')
    if (previewContainer) { previewContainer.classList.add('hidden'); const previewImg = document.getElementById('receipt-preview'); if (previewImg) previewImg.src = '' }
    document.getElementById('replace-receipt')?.remove()
    document.getElementById('revoke-receipt')?.remove()
    document.getElementById('purchase-amount').classList.remove('text-red-500')
    document.getElementById('submit-receipt-btn').disabled = true
    document.getElementById('submit-receipt-btn').innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" /></svg>${this.translations.submit_receipt}`
    this.updateStatusDisplay('')
  }

  displayReceipt(receipt) {
    const previewContainer = document.getElementById('receipt-preview-container')
    let previewImg = document.getElementById('receipt-preview')
    if (!previewImg) {
      previewImg = document.createElement('img')
      previewImg.id = 'receipt-preview'
      previewImg.className = 'w-full h-auto object-contain'
      previewImg.setAttribute('loading', 'lazy')
      previewContainer.appendChild(previewImg)
    }
    const newPreviewImg = previewImg.cloneNode(true)
    previewImg.parentNode.replaceChild(newPreviewImg, previewImg)
    const baseUrl = receipt.url.split('?')[0]
    const imageUrl = `${baseUrl}?t=${new Date().getTime()}`
    newPreviewImg.src = imageUrl
    newPreviewImg.onload = () => previewContainer.classList.remove('hidden')
    newPreviewImg.onclick = () => this.openReceiptViewer(imageUrl)
  }

  async downloadFile(url, fallbackName = 'receipt') {
    const a = document.createElement('a')
    a.style.display = 'none'
    document.body.appendChild(a)
    try {
      const res = await fetch(url, { credentials: 'include' })
      if (!res.ok) throw new Error(`HTTP ${res.status}`)
      const cd = res.headers.get('Content-Disposition') || ''
      const nameMatch = cd.match(/filename\*?=(?:UTF-8''|")?([^\";]+)/i)
      const fileName = nameMatch ? decodeURIComponent(nameMatch[1]) : fallbackName
      const blob = await res.blob()
      const objectUrl = URL.createObjectURL(blob)
      a.href = objectUrl
      a.download = fileName
      a.click()
      URL.revokeObjectURL(objectUrl)
    } finally {
      document.body.removeChild(a)
    }
  }

  addReplaceAndRevokeButtons(purchase) {
    const receiptUploadSection = document.getElementById('receipt-upload-section')
    receiptUploadSection.querySelector('.replace-receipt-btn')?.remove()
    receiptUploadSection.querySelector('.revoke-receipt-btn')?.remove()

    const replaceButton = document.createElement('button')
    replaceButton.type = 'button'
    replaceButton.id = 'replace-receipt'
    replaceButton.className = 'replace-receipt-btn btn btn-warning btn-md w-full flex items-center justify-center gap-2 shadow-md hover:shadow-lg transition duration-200 mt-4'
    replaceButton.setAttribute('aria-label', this.translations.replace_receipt)
    replaceButton.innerHTML = `<span>${this.translations.replace_receipt}</span>`
    replaceButton.onclick = () => {
      document.getElementById('receipt-drop-area').style.display = 'block'
      document.getElementById('receipt-preview-container').classList.add('hidden')
      document.getElementById('receipt-preview').src = ''
      document.getElementById('receipt-button').classList.add('hidden')
      const submitBtn = document.getElementById('submit-receipt-btn')
      if (submitBtn) { submitBtn.disabled = true; submitBtn.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" /></svg>${this.translations.submit_receipt}` }
      this.receiptFile = null
      document.getElementById('replace-receipt')?.remove()
      document.getElementById('revoke-receipt')?.remove()
    }

    const revokeButton = document.createElement('button')
    revokeButton.type = 'button'
    revokeButton.id = 'revoke-receipt'
    revokeButton.className = 'revoke-receipt-btn btn btn-outline btn-error btn-md w-full flex items-center justify-center gap-2 shadow-md hover:shadow-lg transition duration-200 mt-2'
    revokeButton.setAttribute('aria-label', this.translations.revoke_receipt)
    revokeButton.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M9 2a1 1 0 00-.894.553L7.382 4H4a1 1 0 000 2v10a2 2 0 002 2h8a2 2 0 002-2V6a1 1 0 100-2h-3.382l-.724-1.447A1 1 0 0011 2H9zM7 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z" clip-rule="evenodd" /></svg><span>${this.translations.revoke_receipt}</span>`
    revokeButton.onclick = () => this.revokeReceipt()

    receiptUploadSection.appendChild(replaceButton)
    receiptUploadSection.appendChild(revokeButton)
  }

  showGlobalLoading() {
    if (!document.getElementById('global-loading')) {
      const loadingDiv = document.createElement('div')
      loadingDiv.id = 'global-loading'
      loadingDiv.className = 'fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50'
      loadingDiv.innerHTML = `<div class="flex flex-col items-center"><div class="w-16 h-16 border-4 border-amber-400 border-t-transparent rounded-full animate-spin"></div><span class="text-amber-400 mt-4 text-lg">${this.translations.loading}</span></div>`
      document.body.appendChild(loadingDiv)
    }
  }

  hideGlobalLoading() {
    const loadingDiv = document.getElementById('global-loading')
    if (loadingDiv) loadingDiv.remove()
  }

  getCsrfToken() { return document.querySelector('meta[name="csrf-token"]')?.content }

  getCurrentUserId() {
    const userIdMeta = document.querySelector('meta[name="current-user-id"]')
    if (userIdMeta) return userIdMeta.getAttribute('content')
    if (typeof currentUserId !== 'undefined') return currentUserId
    return null
  }

  getStatusName(status) {
    const names = { 'pending': this.translations.status_pending, 'approved': this.translations.status_approved, 'rejected': this.translations.status_rejected, 'refunded': this.translations.status_refunded }
    return names[status] || status
  }

  getPurchaseTypeName(type) {
    const names = { 'pass_purchase': this.translations.type_pass_purchase, 'pass_gift': this.translations.type_pass_gift, 'donation': this.translations.type_donation, 'sponsor': this.translations.type_sponsor, 'unban': this.translations.type_unban, 'unmute': this.translations.type_unmute }
    return names[type] || this.translations.type_donation
  }

  showNotification(message) {
    const notification = document.createElement('div')
    notification.className = 'fixed bottom-4 right-4 bg-amber-500 text-white px-6 py-3 rounded-lg shadow-lg z-50 animate-fadeIn'
    notification.textContent = message
    document.body.appendChild(notification)
    setTimeout(() => { notification.style.opacity = '0'; setTimeout(() => { if (document.body.contains(notification)) document.body.removeChild(notification) }, 300) }, 3000)
  }

  showAlertNotification(message) {
    const alertNotification = document.getElementById('alert-notification')
    const alertText = document.getElementById('alert-notification-text')
    if (alertText) alertText.textContent = message
    if (alertNotification) alertNotification.classList.remove('hidden')
    setTimeout(() => { if (alertNotification) alertNotification.classList.add('hidden') }, 5000)
  }
}
