import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { firstValueFrom } from 'rxjs';
import { ApiConfig } from '../models/types';

interface Auth0TokenResponse {
  access_token: string;
  token_type: string;
  expires_in: number;
}

const STORAGE_KEY_CONFIG = 'gatinhos_api_config';
const STORAGE_KEY_TOKEN = 'gatinhos_auth0_token';
const STORAGE_KEY_EXPIRES = 'gatinhos_token_expires_at';

@Injectable({
  providedIn: 'root'
})
export class Auth0Service {
  private http = inject(HttpClient);

  private cachedToken: string | null = null;
  private tokenExpiresAt: number = 0;

  constructor() {
    this.cachedToken = localStorage.getItem(STORAGE_KEY_TOKEN);
    const expires = localStorage.getItem(STORAGE_KEY_EXPIRES);
    if (expires) {
      this.tokenExpiresAt = parseInt(expires, 10);
    }
  }

  public getConfig(): ApiConfig {
    const raw = localStorage.getItem(STORAGE_KEY_CONFIG);
    if (raw) {
      try {
        return JSON.parse(raw);
      } catch (e) {
        console.error('Falha ao ler configuracao do localStorage', e);
      }
    }
    return {
      auth0_domain: '',
      auth0_client_id: '',
      auth0_client_secret: '',
      auth0_audience: '',
      aiven_domain: ''
    };
  }

  public saveConfig(config: ApiConfig): void {
    // Sanitizar dominios (remover https:// e barras finais)
    const sanitized: ApiConfig = {
      auth0_domain: this.cleanDomain(config.auth0_domain),
      auth0_client_id: (config.auth0_client_id || '').trim(),
      auth0_client_secret: (config.auth0_client_secret || '').trim(),
      auth0_audience: (config.auth0_audience || '').trim(),
      aiven_domain: this.cleanDomain(config.aiven_domain)
    };

    localStorage.setItem(STORAGE_KEY_CONFIG, JSON.stringify(sanitized));
    // Limpar cache de token anterior pois as credenciais podem ter mudado
    this.clearToken();
  }

  public isConfigured(): boolean {
    const cfg = this.getConfig();
    return !!(
      cfg.auth0_domain &&
      cfg.auth0_client_id &&
      cfg.auth0_client_secret &&
      cfg.auth0_audience &&
      cfg.aiven_domain
    );
  }

  public clearToken(): void {
    this.cachedToken = null;
    this.tokenExpiresAt = 0;
    localStorage.removeItem(STORAGE_KEY_TOKEN);
    localStorage.removeItem(STORAGE_KEY_EXPIRES);
  }

  public async getAccessToken(forceRefresh = false): Promise<string> {
    const now = Date.now();
    // Reutilizar se ainda faltar mais de 60 segundos para expirar
    if (!forceRefresh && this.cachedToken && this.tokenExpiresAt > now + 60000) {
      return this.cachedToken;
    }

    const cfg = this.getConfig();
    if (!this.isConfigured()) {
      throw new Error('Configurações de Auth0 e Aiven incompletas. Por favor preencha os 5 parâmetros.');
    }

    const tokenUrl = `https://${cfg.auth0_domain}/oauth/token`;
    const payload = {
      client_id: cfg.auth0_client_id,
      client_secret: cfg.auth0_client_secret,
      audience: cfg.auth0_audience,
      grant_type: 'client_credentials'
    };

    try {
      const response = await firstValueFrom(
        this.http.post<Auth0TokenResponse>(tokenUrl, payload, {
          headers: { 'Content-Type': 'application/json' }
        })
      );

      this.cachedToken = response.access_token;
      this.tokenExpiresAt = Date.now() + (response.expires_in * 1000);

      localStorage.setItem(STORAGE_KEY_TOKEN, this.cachedToken);
      localStorage.setItem(STORAGE_KEY_EXPIRES, this.tokenExpiresAt.toString());

      return this.cachedToken;
    } catch (err: any) {
      console.error('Erro ao obter token do Auth0:', err);
      let msg = 'Erro ao autenticar com Auth0.';
      if (err.error?.error_description) {
        msg += ` ${err.error.error_description}`;
      } else if (err.message) {
        msg += ` ${err.message}`;
      }
      throw new Error(msg);
    }
  }

  public cleanDomain(domain: string): string {
    if (!domain) return '';
    return domain.trim().replace(/^https?:\/\//i, '').replace(/\/+$/, '');
  }
}
