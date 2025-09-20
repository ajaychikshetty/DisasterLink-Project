// components/MessageManagement.jsx
import React, { useEffect, useState } from "react";

function MessageManagement() {
  const [messages, setMessages] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    const fetchMessages = async () => {
      try {
        const res = await fetch("http://127.0.0.1:5000/api/messages/");
        const data = await res.json();
        console.log("Fetched messages from backend:", data); // ✅ Debug log
        setMessages(data);
      } catch (err) {
        console.error("Error fetching messages:", err); // ✅ Debug log
        setError("Unable to load messages");
      } finally {
        setLoading(false);
      }
    };
    fetchMessages();
  }, []);

  if (loading) return <p className="text-white">Loading...</p>;
  if (error) return <p className="text-red-500">{error}</p>;

  return (
    <div className="bg-gray-800 p-6 rounded-lg shadow-lg text-white">
      <h2 className="text-2xl font-bold mb-4">Messages</h2>

      {messages.length === 0 ? (
        <p>No messages found.</p>
      ) : (
        <ul className="space-y-4">
          {messages.map((msg, idx) => (
            <li
              key={idx}
              className="p-4 bg-gray-700 rounded-lg flex flex-col gap-2"
            >
              <p>
                <strong>Sender:</strong> {msg.Sender || msg.sender}
              </p>
              <p>
                <strong>Message:</strong> {msg.Message || msg.message}
              </p>
              <p>
                <strong>Type:</strong> {msg.Type || msg.type}
              </p>
              <p>
                <strong>Battery:</strong> {msg.Battery ?? "N/A"}
              </p>
              <p>
                <strong>Timestamp:</strong>{" "}
                {msg.Timestamp || msg.timestamp}
              </p>
              {msg.Location || msg.location ? (
                <p>
                  <strong>Location:</strong>{" "}
                  {msg.Location?.latitude || msg.location?.latitude},{" "}
                  {msg.Location?.longitude || msg.location?.longitude}
                </p>
              ) : (
                <p>
                  <strong>Location:</strong> N/A
                </p>
              )}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

export default MessageManagement;

