import consumer from "./consumer";

// Глобальная переменная для хранения ожидаемого статуса
let desiredStatus = "false";

// Функция обновления статуса с debounce
function updatePlayerStatus(status) {
  const statusElement = document.getElementById("player-status");
  if (!statusElement) return;

  // Если получен статус "ban", то устанавливаем красный кружок и выходим
  if (status === "ban") {
    desiredStatus = status;
    let circle = statusElement.querySelector('.status-circle');
    if (!circle) {
      circle = document.createElement('span');
      circle.className =
        "status-circle absolute bottom-0 right-0 w-1/4 aspect-square rounded-full border-6 border-[#1A1A1A] transition-all duration-300";
      statusElement.appendChild(circle);
    }
    // Устанавливаем красный цвет: можно использовать, например, bg-red-600
    circle.classList.remove("bg-green-400", "bg-gray-400", "animate-pulse", "animate-change");
    circle.classList.add("bg-red-500");
    return;
  }

  // Обработаем обычный статус (online/offline)
  desiredStatus = status;
  const isOnline = desiredStatus === "true";
  let circle = statusElement.querySelector('.status-circle');

  if (circle) {
    const wasOnline = circle.classList.contains('bg-green-400');
    // Анимируем только если статус изменился
    if (isOnline !== wasOnline) {
      circle.classList.add('animate-change');
      circle.classList.toggle('bg-green-400', isOnline);
      circle.classList.toggle('bg-gray-400', !isOnline);
      // Убираем класс анимации (можно доработать по необходимости)
      circle.classList.remove('animate-change');
    }
  } else {
    const newCircle = document.createElement('span');
    newCircle.className = `status-circle absolute bottom-0 right-0 w-1/4 aspect-square 
                           ${isOnline ? 'bg-green-400' : 'bg-gray-400'} rounded-full 
                           border-6 border-[#1A1A1A] transition-all duration-300 
                           ${isOnline ? 'animate-pulse' : ''}`;
    statusElement.appendChild(newCircle);
  }
}

document.addEventListener("DOMContentLoaded", () => {
  const nickname = window.correlationID;
  const user_id = window.currentUserId;

  if (!nickname) return;

  // Изначальный статус OFFLINE
  updatePlayerStatus("false");

  // Создаем подписку для обновления статуса
  const subscription = consumer.subscriptions.create({ channel: "PlayerOnlineChannel", nickname: nickname, user_id: user_id }, {
    received(data) {
      if (data === "ban") {
        updatePlayerStatus("ban");
        // Отписываемся, поскольку пользователь забанен и дальнейшие обновления не требуются
        this.unsubscribe();
      } else {
        updatePlayerStatus(data);
      }
    }
  });
});
