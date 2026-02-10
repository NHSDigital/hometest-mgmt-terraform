import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  build: {
    outDir: 'dist',
    sourcemap: true,
  },
  // Note: API URLs are now path-based (/api1, /api2) and configured in App.tsx
  // CloudFront routes these paths to the appropriate API Gateway origins
})
