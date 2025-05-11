import consumer from "./consumer";

// Теперь используем window.currentUserId, которое было установлено в layout
consumer.subscriptions.create({ channel: "CodeValidationChannel", user_id: window.currentUserId }, {
  received(data) {
    if (data.success) {
      // Получаем CSRF токен из meta-тега
      const csrfToken = document.querySelector('meta[name="csrf-token"]').getAttribute('content');

      // Выполняем AJAX-запрос для обновления сессии (устанавливаем флаг)
      fetch('/two_factor_success', {
        method: 'POST',
        headers: { 
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken
        },
        body: JSON.stringify({ two_factor_passed: true })
      })
      .then(response => response.json())
      .then(result => {
        console.log("Session updated:", result);
        showNotification("Код подтвержден!");
        setTimeout(() => window.location.href = "/", 1500);
      })
      .catch(error => {
        console.error("Session update error:", error);
        showNotification("Код подтвержден! (но обновление сессии не удалось.)");
        setTimeout(() => window.location.href = "/", 1500);
      });
    } else {
      showAlertNotification("Неверный код!");
    }
  }
});
