import { ApiConfig } from '../app/models/types';

/**
 * Modelo para o build Android. Copie para `app-config.local.ts`
 * (ignorado pelo git) e preencha com os valores reais:
 *
 *   cp src/environments/app-config.local.example.ts src/environments/app-config.local.ts
 */
export const DEFAULT_API_CONFIG: ApiConfig = {
  auth0_domain: 'seu-tenant.us.auth0.com',
  auth0_client_id: '',
  auth0_client_secret: '',
  auth0_audience: 'https://sua-api',
  aiven_domain: 'seu-servico.aiven.app'
};
