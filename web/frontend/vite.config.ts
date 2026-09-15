import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    // The FastAPI backend (web/backend) serves the API during development.
    proxy: {
      '/api': 'http://127.0.0.1:8000',
    },
  },
})
