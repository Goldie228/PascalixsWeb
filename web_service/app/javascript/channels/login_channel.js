import consumer from "./consumer";


consumer.subscriptions.create(
  { channel: "LoginChannel", correlation_id: window.correlationID },
  {
    connected() {
      console.log("Connected to LoginChannel for correlation_id:", window.correlationID);
    },
    disconnected() {
      console.log("Disconnected from LoginChannel");
    },
    received(data) {
      console.log("Received data from LoginChannel:", data);
      window.dispatchEvent(new CustomEvent("login:update", { detail: data }));
    }
  }
);
