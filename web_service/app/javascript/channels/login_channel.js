import consumer from "./consumer";


consumer.subscriptions.create(
  { channel: "LoginChannel", correlation_id: window.correlationID },
  {
    connected() {
    },
    disconnected() {
    },
    received(data) {
      window.dispatchEvent(new CustomEvent("login:update", { detail: data }));
    }
  }
);
