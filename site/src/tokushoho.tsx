import { StrictMode } from "react"
import { createRoot } from "react-dom/client"
import "./index.css"
import TokushohoPage from "./TokushohoPage.tsx"

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <TokushohoPage />
  </StrictMode>,
)
