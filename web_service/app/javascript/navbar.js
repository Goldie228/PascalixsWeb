document.addEventListener('DOMContentLoaded', function() {
	// 1. Универсальная функция закрытия
	const closeAllDropdowns = (excludeElement = null) => {
			document.querySelectorAll('.dropdown, details').forEach(element => {
					if (element === excludeElement) return;
					if (excludeElement && element.contains(excludeElement)) return;
					
					element.classList.remove('active');
					if (element.tagName === 'DETAILS') element.removeAttribute('open');
			});
	};

	// 2. Обработчик для мобильных dropdown
	const handleMobileDropdown = (button) => {
			button.addEventListener('click', function(e) {
					e.preventDefault();
					e.stopPropagation();
					
					const dropdown = this.closest('.dropdown, details');
					const isActive = dropdown.classList.contains('active') || dropdown.open;
					
					// Закрываем все элементы
					closeAllDropdowns(dropdown);
					
					// Переключаем состояние только если dropdown был закрыт
					if (!isActive) {
							dropdown.classList.add('active');
							if (dropdown.tagName === 'DETAILS') dropdown.setAttribute('open', '');
					}
			});
	};

	// 3. Инициализация для всех триггеров
	document.querySelectorAll(`
			.navbar-start [role="button"],
			.dropdown-toggle,
			details > summary
	`).forEach(handleMobileDropdown);

	// 4. Глобальный клик для закрытия
	document.addEventListener('click', function(e) {
			if (!e.target.closest('.dropdown, details')) {
					closeAllDropdowns();
			}
	});

	// 5. Обработка наведения для десктопа
	document.querySelectorAll('.navbar-center .dropdown').forEach(dropdown => {
			dropdown.addEventListener('mouseenter', () => {
					closeAllDropdowns(dropdown);
					dropdown.classList.add('active');
			});
			
			dropdown.addEventListener('mouseleave', () => {
					setTimeout(() => {
							if (!dropdown.matches(':hover')) {
									dropdown.classList.remove('active');
							}
					}, 100);
			});
	});
});