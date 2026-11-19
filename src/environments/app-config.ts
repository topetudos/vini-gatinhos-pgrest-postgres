import { ApiConfig } from '../app/models/types';

/**
 * Valores padrão dos 5 parâmetros de conexão.
 *
 * Este arquivo vai para o git e DEVE ficar vazio (o repositório é público).
 * Para o build Android, copie `app-config.local.example.ts` para
 * `app-config.local.ts` (ignorado pelo git) e preencha os valores reais.
 * O `npm run build:android` substitui este arquivo pelo local.
 */
export const DEFAULT_API_CONFIG: ApiConfig = {
  auth0_domain: '',
  auth0_client_id: '',
  auth0_client_secret: '',
  auth0_audience: '',
  aiven_domain: ''
};
