import React, { useState } from "react";

const AlertSender = () => {
  const [disasterName, setDisasterName] = useState("");
  const [numbers, setNumbers] = useState("");
  const [status, setStatus] = useState(null);

  const sendAlert = async () => {
    const numbersArray = numbers.split(",").map(n => n.trim()).filter(Boolean);
    try {
      const res = await fetch("http://localhost:5000/disaster_alert", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          disaster_name: disasterName,
          numbers: numbersArray,
        }),
      });

      const data = await res.json();
      console.log("Response:", data);
      setStatus("✅ Alerts sent successfully!");
    } catch (err) {
      console.error("Error sending alert", err);
      setStatus("❌ Failed to send alerts.");
    }
  };

  return (
    <div className="alert-sender">
      <h3>Send Disaster Alert</h3>

      <input
        type="text"
        placeholder="Disaster name"
        value={disasterName}
        onChange={(e) => setDisasterName(e.target.value)}
        style={{ width: "100%", marginBottom: "8px" }}
      />

      <textarea
        placeholder="Enter numbers separated by commas"
        value={numbers}
        onChange={(e) => setNumbers(e.target.value)}
        style={{ width: "100%", height: "80px", marginBottom: "8px" }}
      />

      <button onClick={sendAlert}>Send Alert</button>

      {status && <p>{status}</p>}
    </div>
  );
};

export default AlertSender;
