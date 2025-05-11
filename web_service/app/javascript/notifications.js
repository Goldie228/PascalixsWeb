(() => {
  let autoCloseNotificationTimeout, currentNotificationAnimationFrame;
  let autoCloseAlertTimeout, currentAlertAnimationFrame;
  let isNotifying = false; // Флаг блокировки анимации

  const bindCloseButtons = () => {
    document.querySelectorAll('.alert button').forEach(btn => {
      btn.onclick = (e) => {
        e.stopPropagation();
        const alertBox = btn.closest('.alert');
        if (alertBox?.id === 'notification') {
          closeNotification(true);
        } else if (alertBox?.id === 'alert-notification') {
          closeAlertNotification(true);
        }
      };
    });
  };

  function showNotification(message, duration = 3000) {
    if(isNotifying) return; // Блокируем новые вызовы
    
    const notification = document.getElementById('notification');
    const textElement = document.getElementById('notification-text');
    if (!notification || !textElement) return;

    cancelAnimationFrame(currentNotificationAnimationFrame);
    clearTimeout(autoCloseNotificationTimeout);
    
    isNotifying = true;
    notification.classList.remove('animate-fade-in', 'animate-fade-out', 'hidden');
    textElement.textContent = message;

    currentNotificationAnimationFrame = requestAnimationFrame(() => {
      notification.classList.add('animate-fade-in');
      
      const cleanUp = () => {
        notification.removeEventListener('animationend', cleanUp);
        isNotifying = false;
      };

      notification.addEventListener('animationend', cleanUp, { once: true });
      
      autoCloseNotificationTimeout = setTimeout(() => {
        closeNotification();
      }, duration);
    });
  }

  function closeNotification(immediate = false) {
    const notification = document.getElementById('notification');
    if (!notification || !notification.classList.contains('animate-fade-in')) return;

    clearTimeout(autoCloseNotificationTimeout);
    cancelAnimationFrame(currentNotificationAnimationFrame);
    
    if(immediate) {
      notification.classList.remove('animate-fade-in', 'animate-fade-out');
      notification.classList.add('hidden');
      isNotifying = false;
      return;
    }

    notification.classList.remove('animate-fade-in');
    notification.classList.add('animate-fade-out');

    notification.addEventListener('animationend', () => {
      notification.classList.add('hidden');
      notification.classList.remove('animate-fade-out');
      isNotifying = false;
    }, { once: true });
  }

  // Функция показа alert-уведомления (ошибки)
  function showAlertNotification(message, duration = 3000) {
    const alertNotification = document.getElementById('alert-notification');
    const textElement = document.getElementById('alert-notification-text');
    if (!alertNotification || !textElement) return;

    cancelAnimationFrame(currentAlertAnimationFrame);
    clearTimeout(autoCloseAlertTimeout);

    alertNotification.classList.remove('animate-fade-in', 'animate-fade-out');
    alertNotification.classList.add('hidden');

    textElement.textContent = message;

    currentAlertAnimationFrame = requestAnimationFrame(() => {
      alertNotification.classList.remove('hidden');
      alertNotification.classList.add('animate-fade-in');

      alertNotification.addEventListener('animationend', () => {
        if (!alertNotification.classList.contains('hidden')) {
          autoCloseAlertTimeout = setTimeout(closeAlertNotification, duration);
        }
      }, { once: true });
    });
  }

  // Функция закрытия alert-уведомления
  function closeAlertNotification() {
    const alertNotification = document.getElementById('alert-notification');
    if (!alertNotification || alertNotification.classList.contains('hidden')) return;

    alertNotification.classList.remove('animate-fade-in');
    alertNotification.classList.add('animate-fade-out');

    alertNotification.addEventListener('animationend', () => {
      alertNotification.classList.add('hidden');
      alertNotification.classList.remove('animate-fade-out');
			notification.style.animation = '';
    }, { once: true });
  }

  // Функция инициализации уведомлений
  const initNotifications = () => {
    // Установка позиции всплывающего уведомления в зависимости от наличия шапки (navbar)
    const toast = document.querySelector('.toast');
    const header = document.querySelector('.navbar');
    if (toast) {
      toast.style.top = header ? '140px' : '20px';
    }

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

  // Инициализация при полной загрузке страницы и при навигации Turbo
  document.addEventListener('DOMContentLoaded', initNotifications);
  document.addEventListener('turbo:load', initNotifications);

  // Экспортируем (при необходимости) глобальные функции для вызова
  window.showNotification = showNotification;
  window.closeNotification = closeNotification;
  window.showAlertNotification = showAlertNotification;
  window.closeAlertNotification = closeAlertNotification;
})();
