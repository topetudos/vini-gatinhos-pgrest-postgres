import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'io.github.topetudos.gatinhos',
  appName: 'Gatinhos RPG',
  webDir: 'dist/gatinhos-app/browser',
  plugins: {
    // Faz fetch/XHR pela pilha HTTP nativa do Android (sem CORS).
    // Necessário porque o Auth0 /oauth/token não devolve
    // Access-Control-Allow-Origin na resposta do POST para apps M2M.
    CapacitorHttp: { enabled: true }
  }
};

export default config;
