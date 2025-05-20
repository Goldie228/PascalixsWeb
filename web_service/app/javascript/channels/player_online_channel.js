// app/javascript/channels/player_online_channel.js
import consumer from "./consumer";

// Функция обновления UI в зависимости от статуса
function updatePlayerStatus(status) {
  console.log(`[updatePlayerStatus] Called with status: ${status}`);
  const statusElement = document.getElementById("player-status");
  if (!statusElement) {
    console.error("[updatePlayerStatus] Элемент с id 'player-status' не найден");
    return;
  }

  if (status === "true") {
    console.log("[updatePlayerStatus] Отрисовка статуса: ONLINE");
    statusElement.innerHTML = `
      <span class="absolute bottom-0 right-0 w-1/4 aspect-square bg-green-400 rounded-full border-6 border-[#1A1A1A]"></span>
    `;
  } else if (status === "false") {
    console.log("[updatePlayerStatus] Отрисовка статуса: OFFLINE");
    statusElement.innerHTML = `
      <span class="absolute bottom-0 right-0 w-1/4 aspect-square bg-gray-400 rounded-full border-6 border-[#1A1A1A]"></span>
    `;
  } else {
    console.log("[updatePlayerStatus] Отрисовка статуса: LOADING (default)");
    statusElement.innerHTML = `
      <span class="absolute bottom-0 right-0 w-1/4 aspect-square bg-[#989898] rounded-full border-6 border-[#1A1A1A] animate-pulse"></span>
    `;
  }
}

// Запускаем подписку, когда документ готов
document.addEventListener("DOMContentLoaded", () => {
  const nickname = window.correlationID;
  if (!nickname) {
    console.warn("Не найден параметр nickname для подключения");
    return;
  }
  console.log(`[DOMContentLoaded] Nickname получен: ${nickname}`);

  // Отображаем начальное состояние "загрузка"
  updatePlayerStatus("loading");

  // Создаём подписку на канал с использованием переданного nickname
  consumer.subscriptions.create({ channel: "PlayerOnlineChannel", nickname: nickname }, {
    connected() {
      console.log(`[ActionCable] Подключились к PlayerOnlineChannel для ${nickname}`);
    },

    disconnected() {
      console.log(`[ActionCable] Отключены от PlayerOnlineChannel для ${nickname}`);
      // При разрыве соединения сразу показываем статус оффлайн
      updatePlayerStatus("false");
    },

    received(data) {
      console.log(`[ActionCable] Получены данные для ${nickname}:`, data);
      // Ожидаем, что сервер передаст "true" или "false"
      updatePlayerStatus(data);
    }
  });
});
