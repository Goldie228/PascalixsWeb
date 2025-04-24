let isAnimating = false;
let drawerVisible = false;

function toggleAccountDrawer() {
  if (isAnimating) return;
  
  const drawer = document.getElementById('account-drawer');
  if (!drawer) return;
  const isMobile = window.innerWidth <= 767;
  isAnimating = true;
  
  if (drawerVisible) {
    // Запуск анимации закрытия
    drawer.classList.remove('animate-fade-in');
    drawer.classList.add('animate-fade-out');
    
    // После завершения анимации скрываем элемент
    drawer.addEventListener(
      'animationend',
      function handleClose() {
        drawer.classList.remove('animate-fade-out');
        drawer.classList.remove('visible');
        drawer.classList.add('hidden');
        drawerVisible = false;
        isAnimating = false;
        drawer.removeEventListener('animationend', handleClose);
      },
      { once: true }
    );
  } else {
    // Открываем — сперва убираем скрытие и добавляем класс видимости
    drawer.classList.remove('hidden');
    drawer.classList.add('visible');
    // Устанавливаем стили для мобильного/десктопного вида
    drawer.style.transform = isMobile ? 'translateY(0)' : 'translateX(0)';
    drawer.style.opacity = '1';
    
    // Запускаем анимацию появления
    drawer.classList.add('animate-fade-in');
    
    // После завершения анимации чистим класс анимации открытия
    drawer.addEventListener(
      'animationend',
      function handleOpen() {
        drawer.classList.remove('animate-fade-in');
        drawerVisible = true;
        isAnimating = false;
        drawer.removeEventListener('animationend', handleOpen);
      },
      { once: true }
    );
  }
}

// Привязываем переключение к триггеру (например, кнопке/аватарке)
const trigger = document.querySelector('[data-drawer-trigger]');
if (trigger) {
  trigger.addEventListener('click', (event) => {
    event.stopPropagation(); // Чтобы клик на триггере не срабатывал как клик вне области
    toggleAccountDrawer();
  });
}

// Если клик вне области drawer и триггера — закрываем его
document.addEventListener('click', (event) => {
  const drawer = document.getElementById('account-drawer');
  const trigger = document.querySelector('[data-drawer-trigger]');
  if (!drawer || !trigger) return;

  // Используем closest для проверки, является ли клик внутри drawer или trigger
  if (
    drawerVisible &&
    !event.target.closest('#account-drawer') &&
    !event.target.closest('[data-drawer-trigger]')
  ) {
    toggleAccountDrawer();
  }
});

// Обработчик изменения размера окна (при открытом drawer)
window.addEventListener('resize', () => {
  if (drawerVisible) {
    const drawer = document.getElementById('account-drawer');
    const isMobile = window.innerWidth <= 767;
    drawer.style.transform = isMobile ? 'translateY(0)' : 'translateX(0)';
  }
});


