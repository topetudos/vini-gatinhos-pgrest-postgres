import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { firstValueFrom } from 'rxjs';
import { Auth0Service } from './auth0.service';
import {
  JogadorSession,
  Gatinho,
  RankingItem,
  Raca,
  AdminJogador,
  AdminGato,
  CarinhoResult,
  NovoGatoResult
} from '../models/types';

const STORAGE_KEY_USER = 'gatinhos_current_user';

@Injectable({
  providedIn: 'root'
})
export class GatinhosApiService {
  private http = inject(HttpClient);
  private auth0 = inject(Auth0Service);

  private currentUser: JogadorSession | null = null;

  constructor() {
    const raw = localStorage.getItem(STORAGE_KEY_USER);
    if (raw) {
      try {
        this.currentUser = JSON.parse(raw);
      } catch (e) {
        console.error('Falha ao restaurar sessao do usuario', e);
      }
    }
  }

  public getCurrentUser(): JogadorSession | null {
    return this.currentUser;
  }

  public isLoggedIn(): boolean {
    return !!this.currentUser && !!this.currentUser.userpassword;
  }

  public logout(): void {
    this.currentUser = null;
    localStorage.removeItem(STORAGE_KEY_USER);
  }

  /**
   * Executa uma função RPC no PostgreSQL via PostgREST na Aiven
   */
  public async callRpc<T>(functionName: string, extraParams: Record<string, any> = {}): Promise<T> {
    const cfg = this.auth0.getConfig();
    if (!cfg.aiven_domain) {
      throw new Error('Domínio da Aiven não configurado.');
    }

    // Obter Token M2M do Auth0
    const token = await this.auth0.getAccessToken();

    // Injetar credenciais do usuário se logado (ou se passadas explicitamente)
    const payload: Record<string, any> = { ...extraParams };
    if (this.currentUser) {
      if (payload['app_userid'] === undefined) {
        payload['app_userid'] = this.currentUser.id;
      }
      if (payload['app_userpassword'] === undefined) {
        payload['app_userpassword'] = this.currentUser.userpassword;
      }
    }

    const rpcUrl = `https://${cfg.aiven_domain}/rpc/${functionName}`;
    const headers = new HttpHeaders({
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    });

    try {
      const response = await firstValueFrom(
        this.http.post<T>(rpcUrl, payload, { headers })
      );
      return response;
    } catch (err: any) {
      console.error(`Erro ao chamar RPC [${functionName}]:`, err);
      let errMsg = 'Erro na requisição para a API Aiven.';
      if (err.error?.message) {
        errMsg = err.error.message;
      } else if (err.error?.hint) {
        errMsg += ` (${err.error.hint})`;
      } else if (err.message) {
        errMsg = err.message;
      }
      throw new Error(errMsg);
    }
  }

  /**
   * Realiza login no jogo verificando id e senha na função login_jogador
   */
  public async login(id: number, userpassword: string): Promise<JogadorSession> {
    const results = await this.callRpc<JogadorSession[]>('login_jogador', {
      app_userid: id,
      app_userpassword: userpassword
    });

    if (!results || results.length === 0) {
      throw new Error('Usuário não encontrado ou credenciais inválidas.');
    }

    const user: JogadorSession = {
      id: results[0].id,
      nome: results[0].nome,
      isadmin: results[0].isadmin,
      userpassword: userpassword
    };

    this.currentUser = user;
    localStorage.setItem(STORAGE_KEY_USER, JSON.stringify(user));
    return user;
  }

  // --- Operações de Jogador ---

  public async listarMeusGatinhos(): Promise<Gatinho[]> {
    return this.callRpc<Gatinho[]>('listar_meus_gatinhos');
  }

  public async ganharNovoGato(): Promise<NovoGatoResult> {
    const res = await this.callRpc<NovoGatoResult[]>('ganhar_novo_gato');
    return res[0];
  }

  public async renomearGatinho(idGatinho: number, novoNome: string): Promise<{ id: number; nome: string; mensagem: string }> {
    const res = await this.callRpc<{ id: number; nome: string; mensagem: string }[]>('renomear_gatinho', {
      p_id_gatinho: idGatinho,
      p_novo_nome: novoNome
    });
    return res[0];
  }

  public async carinhoPata(idGatinho: number): Promise<CarinhoResult> {
    const res = await this.callRpc<CarinhoResult[]>('carinho_pata_fn', {
      p_id_gatinho: idGatinho
    });
    return res[0];
  }

  public async carinhoBarriga(idGatinho: number): Promise<CarinhoResult> {
    const res = await this.callRpc<CarinhoResult[]>('carinho_barriga_fn', {
      p_id_gatinho: idGatinho
    });
    return res[0];
  }

  public async carinhoRabo(idGatinho: number): Promise<CarinhoResult> {
    const res = await this.callRpc<CarinhoResult[]>('carinho_rabo_fn', {
      p_id_gatinho: idGatinho
    });
    return res[0];
  }

  public async obterRanking(): Promise<RankingItem[]> {
    return this.callRpc<RankingItem[]>('obter_ranking_gatinhos');
  }

  public async listarRacas(): Promise<Raca[]> {
    return this.callRpc<Raca[]>('listar_racas');
  }

  // --- Operações de Administrador (isadmin = TRUE) ---

  public async adminListarJogadores(): Promise<AdminJogador[]> {
    return this.callRpc<AdminJogador[]>('admin_listar_jogadores');
  }

  public async adminSalvarJogador(
    id: number | null,
    nome: string,
    userpassword: string,
    isadmin: boolean
  ): Promise<any> {
    const res = await this.callRpc<any[]>('admin_salvar_jogador', {
      p_id: id,
      p_nome: nome,
      p_userpassword: userpassword,
      p_isadmin: isadmin
    });
    return res[0];
  }

  public async adminSalvarRaca(
    raca: string,
    pata: number,
    barriga: number,
    rabo: number
  ): Promise<any> {
    const res = await this.callRpc<any[]>('admin_salvar_raca', {
      p_raca: raca,
      p_pata: pata,
      p_barriga: barriga,
      p_rabo: rabo
    });
    return res[0];
  }

  public async adminListarTodosGatos(): Promise<AdminGato[]> {
    return this.callRpc<AdminGato[]>('admin_listar_todos_gatos');
  }
}
