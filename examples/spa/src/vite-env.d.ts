/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API1_URL: string
  readonly VITE_API2_URL: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
