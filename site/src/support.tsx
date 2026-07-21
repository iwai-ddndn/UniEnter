import { StrictMode } from "react"
import { createRoot } from "react-dom/client"
import "./index.css"
import SupportPage from "./SupportPage.tsx"

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <SupportPage />
  </StrictMode>,
)
