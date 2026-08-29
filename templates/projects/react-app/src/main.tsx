import React from "react";
import { createRoot } from "react-dom/client";

function App() {
  return <main><h1>__PROJECT_NAME__</h1></main>;
}

createRoot(document.getElementById("root")!).render(
  <React.StrictMode><App /></React.StrictMode>
);
