(() => {
  // Состояния и таймеры
  const state = {
    notification: {
      isVisible: false,
      timeout: null,
      animationFrame: null,
      element: null,
      textElement: null
    },
    alert: {
      isVisible: false,
      timeout: null,
      animationFrame: null,
      element: null,
      textElement: null
    }
  };

  // Инициализация элементов
  const initElements = () => {
    state.notification.element = document.getElementById('notification');
    state.notification.textElement = document.getElementById('notification-text');
    state.alert.element = document.getElementById('alert-notification');
    state.alert.textElement = document.getElementById('alert-notification-text');
  };

  // Управление анимациями через промисы, ждём окончание анимации
  const animateElement = (element, animationClass) => {
    return new Promise(resolve => {
      const handleAnimationEnd = () => {
        element.removeEventListener('animationend', handleAnimationEnd);
        resolve();
      };
      element.classList.add(animationClass);
      element.addEventListener('animationend', handleAnimationEnd, { once: true });
    });
  };

  // Функция закрытия уведомления с анимацией
  const resetNotification = async (immediate = false) => {
    const { element } = state.notification;
    clearTimeout(state.notification.timeout);

    if (!element) return;

    if (immediate) {
      element.classList.remove('animate-fade-in', 'animate-fade-out');
      element.classList.add('hidden');
      state.notification.isVisible = false;
      return;
    }

    await animateElement(element, 'animate-fade-out');
    element.classList.add('hidden');
    element.classList.remove('animate-fade-out');
    state.notification.isVisible = false;
  };

  window.showNotification = (message, duration = 3000) => {
    if (!state.notification.element || !state.notification.textElement) {
      initElements();
    }

    if (state.notification.isVisible) {
      state.notification.textElement.textContent = message;
      clearTimeout(state.notification.timeout);
      state.notification.timeout = setTimeout(async () => {
        await resetNotification();
      }, duration);
    } else {
      state.notification.isVisible = true;
      state.notification.textElement.textContent = message;
      state.notification.element.classList.remove('hidden');
      animateElement(state.notification.element, 'animate-fade-in').then(() => {
        state.notification.timeout = setTimeout(async () => {
          await resetNotification();
        }, duration);
      });
    }
  };

  // Метод немедленного закрытия уведомления
  window.closeNotification = (immediate = false) => {
    resetNotification(immediate);
  };

  // Функции для alert-уведомлений (аналогично)
  window.showAlertNotification = async (message, duration = 3000) => {
    const { element, textElement } = state.alert;
    if (state.alert.isVisible) {
      await closeAlertNotification(true);
    }
    if (!element || !textElement) return;

    state.alert.isVisible = true;
    textElement.textContent = message;
    element.classList.remove('hidden');

    await animateElement(element, 'animate-fade-in');
    state.alert.timeout = setTimeout(() => {
      closeAlertNotification();
    }, duration);
  };

  window.closeAlertNotification = async (immediate = false) => {
    const { element } = state.alert;
    clearTimeout(state.alert.timeout);
    if (!element || !state.alert.isVisible) return;
    if (immediate) {
      element.classList.remove('animate-fade-in', 'animate-fade-out');
      element.classList.add('hidden');
      state.alert.isVisible = false;
      return;
    }
    await animateElement(element, 'animate-fade-out');
    element.classList.add('hidden');
    element.classList.remove('animate-fade-out');
    state.alert.isVisible = false;
  };

  // Привязка кнопок закрытия уведомлений, если они есть в разметке
  const bindCloseButtons = () => {
    document.querySelectorAll('.alert button').forEach(btn => {
      btn.onclick = (e) => {
        e.stopPropagation();
        const alertBox = btn.closest('.alert');
        if (alertBox?.id === 'notification') {
          window.closeNotification(true);
        } else if (alertBox?.id === 'alert-notification') {
          window.closeAlertNotification(true);
        }
      };
    });
  };

  // Инициализация
  const init = () => {
    const toast = document.querySelector('.toast');
    const header = document.querySelector('.navbar');
    if (toast) {
      toast.style.top = header ? '140px' : '20px';
    }

    initElements();
    bindCloseButtons();

    const notice = document.body.dataset.notice;
    const alertMsg = document.body.dataset.alert;

    if (notice) {
      showNotification(notice);
    }
    if (alertMsg) {
      showAlertNotification(alertMsg);
    }
  };

  // Привязка событий загрузки страницы и Turbo
  document.addEventListener('DOMContentLoaded', init);
  document.addEventListener('turbo:load', init);
})();
