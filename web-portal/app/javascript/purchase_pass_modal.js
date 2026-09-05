// Открытие модального окна
function openModal() {
	const modal = document.querySelector('.modal');
	if (modal) {
		modal.classList.add('modal-open');
	}
}

// Закрытие модального окна
function closeModal() {
	const modal = document.querySelector('.modal');
	if (modal) {
		modal.classList.remove('modal-open');
	}
}