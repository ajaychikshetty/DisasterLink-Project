// AuthPage.jsx
import React, { useState } from "react";
import { useNavigate } from "react-router-dom";

function AuthPage() {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const navigate = useNavigate();

  const handleLogin = async () => {
    try {
      const response = await fetch("http://127.0.0.1:5000/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ username, password }),
      });

      const data = await response.json();

      if (data.status === "success") {
        localStorage.setItem("idToken", data.idToken); // store token
        navigate("/app"); // redirect to App component
      } else {
        setError("Invalid credentials");
      }
    } catch (err) {
      setError("Error logging in");
    }
  };

  return (
    <div className="flex flex-col items-center justify-center min-h-screen bg-gray-900 text-white">
      <h1 className="text-3xl mb-6">Login</h1>

      <input
        type="text"
        placeholder="Username"
        value={username}
        onChange={(e) => setUsername(e.target.value)}
        className="mb-3 p-2 w-72 rounded bg-gray-800 text-white placeholder-gray-400"
      />

      <input
        type="password"
        placeholder="Password"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
        className="mb-3 p-2 w-72 rounded bg-gray-800 text-white placeholder-gray-400"
      />

      <button
        onClick={handleLogin}
        className="bg-blue-600 hover:bg-blue-700 px-4 py-2 rounded-lg"
      >
        Login
      </button>

      {error && <p className="mt-4 text-red-400">{error}</p>}
    </div>
  );
}

export default AuthPage;
