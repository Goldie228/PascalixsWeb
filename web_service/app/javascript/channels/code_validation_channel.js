import consumer from "./consumer";

// Используем window.currentUserId, которое было установлено в layout
consumer.subscriptions.create({ channel: "CodeValidationChannel", user_id: window.currentUserId }, {
  received(data) {
    if (data.success) {
      const csrfToken = document.body.dataset.csrfToken;
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
        showNotification(window.translations.two_factor_authentication.code_confirmed);
        setTimeout(() => window.location.href = "/", 1500);
      })
      .catch(error => {
        console.error("Session update error:", error);
        showNotification(window.translations.two_factor_authentication.code_confirmed_update_failed);
        setTimeout(() => window.location.href = "/", 1500);
      });
    } else {
      showAlertNotification(window.translations.two_factor_authentication.invalid_code);
    }
  }
});
