import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  build: {
    outDir: 'dist',
    sourcemap: true,
  },
  define: {
    // These will be replaced at build time
    'import.meta.env.VITE_API1_URL': JSON.stringify(process.env.VITE_API1_URL || 'https://api1.dev1.hometest.service.nhs.uk'),
    'import.meta.env.VITE_API2_URL': JSON.stringify(process.env.VITE_API2_URL || 'https://api2.dev1.hometest.service.nhs.uk'),
  }
})
