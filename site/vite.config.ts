import path from "path"
import tailwindcss from "@tailwindcss/vite"
import react from "@vitejs/plugin-react"
import { defineConfig } from "vite"

// GitHub Pages(docs/)へ静的出力する。og画像等は public/ 配下から毎ビルドでコピーされる。
export default defineConfig({
  plugins: [react(), tailwindcss()],
  base: "./",
  build: {
    outDir: "../docs",
    emptyOutDir: false,
    rollupOptions: {
      input: {
        main: path.resolve(__dirname, "index.html"),
        support: path.resolve(__dirname, "support.html"),
        terms: path.resolve(__dirname, "terms.html"),
        privacy: path.resolve(__dirname, "privacy.html"),
        "hero-lab": path.resolve(__dirname, "hero-lab.html"),
      },
    },
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
})
