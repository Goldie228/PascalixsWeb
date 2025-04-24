document.addEventListener('DOMContentLoaded', function() {
    // 1. Общая логика закрытия для всех dropdown
    const closeAllDropdowns = (excludeElement = null) => {
        document.querySelectorAll('.dropdown, details').forEach(element => {
            if (element !== excludeElement) {
                element.classList.remove('active');
                element.removeAttribute('open');
            }
        });
    };

    // 2. Обработка мобильного меню (navbar-start)
    document.querySelectorAll('.navbar-start .dropdown > [role="button"]').forEach(button => {
        button.addEventListener('click', function(e) {
            e.stopPropagation();
            const dropdown = this.closest('.dropdown');
            const wasActive = dropdown.classList.contains('active');
            
            closeAllDropdowns(dropdown);
            if (!wasActive) dropdown.classList.add('active');
        });
    });

    // 3. Обработка десктопного меню (navbar-center)
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

    // 4. Глобальный клик для закрытия
    document.addEventListener('click', function(e) {
        if (!e.target.closest('.dropdown, details')) {
            closeAllDropdowns();
        }
    });

    // 5. Обработка вложенных details-элементов
    document.querySelectorAll('details.dropdown').forEach(detail => {
        detail.addEventListener('toggle', function() {
            if (this.open) {
                closeAllDropdowns(this);
            }
        });
    });
});