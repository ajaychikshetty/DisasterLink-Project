// main.jsx
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import "./index.css";

import AuthPage from "./AuthPage";  // login page
import App from "./App";            // dashboard

createRoot(document.getElementById("root")).render(
  <StrictMode>
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<AuthPage />} />   {/* show login first */}
        <Route path="/app" element={<App />} />     {/* dashboard */}
      </Routes>
    </BrowserRouter>
  </StrictMode>
);

