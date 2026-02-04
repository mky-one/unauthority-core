import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import wasm from 'vite-plugin-wasm'
import topLevelAwait from 'vite-plugin-top-level-await'

export default defineConfig({
  plugins: [react(), wasm(), topLevelAwait()],
  base: './',
  build: {
    outDir: 'dist',
    emptyOutDir: true,
  },
  server: {
    port: 5176,
    strictPort: false, // Allow auto port selection
  },
  resolve: {
    alias: {
      buffer: 'buffer',
      events: 'events',
    },
  },
  define: {
    global: 'globalThis',
  },
  optimizeDeps: {
    exclude: ['tiny-secp256k1'],
    esbuildOptions: {
      define: {
        global: 'globalThis',
      },
    },
  },
})
