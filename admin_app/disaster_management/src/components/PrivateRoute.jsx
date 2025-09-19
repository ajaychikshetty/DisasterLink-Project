
// PrivateRoute.jsx
import React, { useState } from "react";
import { Navigate } from "react-router-dom";

const PrivateRoute = ({ children }) => {
  const token = localStorage.getItem("idToken"); // check token

  if (!token) {
    return <Navigate to="/" />; // redirect to login if no token
  }

  return children; // render the component if logged in
};

export default PrivateRoute;
