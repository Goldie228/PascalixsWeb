import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["searchInput", "usersList", "noUsersMessage", "loadMoreBtn", "loadingIndicator"]

  connect() {
    this.isLoading = false
    this.currentPage = 1
    this.searchTimeout = null
    this.setupSearch()
  }

  setupSearch() {
    const input = this.searchInputTarget || this.element.querySelector('#user_search')
    if (input) {
      input.addEventListener('input', () => {
        clearTimeout(this.searchTimeout)
        this.searchTimeout = setTimeout(() => this.loadUsers(1), 300)
      })
    }
  }

  loadUsers(page = 1) {
    if (this.isLoading) return

    const input = this.searchInputTarget || this.element.querySelector('#user_search')
    const searchTerm = input?.value?.trim() || ''

    this.isLoading = true
    this.showLoading(true)

    const url = `/get_not_public_users?page=${page}&search=${encodeURIComponent(searchTerm)}`

    fetch(url, {
      credentials: 'include',
      headers: {
        'Accept': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content
      }
    })
    .then(response => {
      if (!response.ok) throw new Error('Loading error')
      return response.json()
    })
    .then(data => {
      this.renderUsers(data.users, page)
      if (this.loadMoreBtn) {
        this.loadMoreBtn.style.display = data.has_more ? 'block' : 'none'
      }
      if (this.noUsersMessage && page === 1 && data.users.length === 0) {
        this.noUsersMessage.classList.remove('hidden')
      }
    })
    .catch(error => {
      console.error('Error loading users:', error)
      const container = this.usersListTarget || this.element.querySelector('#users_list')
      if (container) {
        container.innerHTML = `<div class="text-center py-4 text-red-400">Error: ${error.message}</div>`
      }
    })
    .finally(() => {
      this.isLoading = false
      this.showLoading(false)
    })
  }

  renderUsers(users, page) {
    const container = this.usersListTarget || this.element.querySelector('#users_list')
    if (!container) return

    if (page === 1) container.innerHTML = ''

    if (users.length === 0 && page === 1) return

    users.forEach(user => {
      const userEl = document.createElement('div')
      userEl.className = 'flex items-center gap-4 p-3 bg-[#2D2D2D] rounded-lg hover:bg-[#3A3A3A] cursor-pointer transition-all'
      userEl.onclick = () => this.selectUser(user)

      const avatarUrl = user.avatar_url || '/assets/steve.webp'

      userEl.innerHTML = `
        <img src="${avatarUrl}" alt="${user.nickname}" class="w-10 h-10 rounded-full object-cover" onerror="this.src='/assets/steve.webp'">
        <div class="flex-1 min-w-0">
          <p class="text-white font-medium truncate">${user.nickname}</p>
          <p class="text-[#A0A0A0] text-sm truncate">${user.uuid}</p>
        </div>
      `

      container.appendChild(userEl)
    })
  }

  selectUser(user) {
    this.dispatch('user-selected', { detail: user })
  }

  loadMore() {
    this.loadUsers(this.currentPage + 1)
  }

  showLoading(show) {
    if (this.loadingIndicator) {
      this.loadingIndicator.classList.toggle('hidden', !show)
    }
  }
}
