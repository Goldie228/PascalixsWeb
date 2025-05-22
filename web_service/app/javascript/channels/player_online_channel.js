import consumer from "./consumer";

// Глобальная переменная для хранения ожидаемого статуса
let desiredStatus = "false";

// Функция обновления статуса с debounce
function updatePlayerStatus(status) {
  const statusElement = document.getElementById("player-status");
  if (!statusElement) return;

  // Обновляем глобальную переменную
  desiredStatus = status;
  
  const isOnline = desiredStatus === "true";
  const circle = statusElement.querySelector('.status-circle');
  
  if (circle) {
    const wasOnline = circle.classList.contains('bg-green-400');
    
    // Анимируем только если статус изменился
    if (isOnline !== wasOnline) {
      circle.classList.add('animate-change');
      circle.classList.remove('animate-change');
      circle.classList.toggle('bg-green-400', isOnline);
      circle.classList.toggle('bg-gray-400', !isOnline);
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
  if (!nickname) return;

  // Изначальный статус OFFLINE
  updatePlayerStatus("false");

  // Создаем подписку для обновления статуса
  consumer.subscriptions.create({ channel: "PlayerOnlineChannel", nickname: nickname }, {
    connected() {
      console.log("ActionCable: connected");
      updatePlayerStatus("true");
    },

    disconnected() {
      console.log("ActionCable: disconnected");
      updatePlayerStatus("false");
    },

    received(data) {
      console.log("Received data:", data);
      updatePlayerStatus(data);
    }
  });
});
