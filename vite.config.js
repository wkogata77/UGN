import { defineConfig } from 'vite';

export default defineConfig({
  server: {
    // Windows-mounted workspaces under WSL do not reliably emit file events.
    watch: { usePolling: true, interval: 350 },
  },
});
