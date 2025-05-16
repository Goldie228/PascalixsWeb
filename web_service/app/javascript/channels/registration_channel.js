import consumer from "./consumer";

consumer.subscriptions.create(
  { channel: "RegistrationChannel", user_id: window.currentUserId },
  {
    received(data) {
      window.dispatchEvent(new CustomEvent("registration:update", { detail: data }));
    }
  }
);
