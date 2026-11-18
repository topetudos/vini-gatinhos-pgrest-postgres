import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Auth0Service } from './services/auth0.service';
import { GatinhosApiService } from './services/gatinhos-api.service';
import {
  ApiConfig,
  JogadorSession,
  Gatinho,
  RankingItem,
  Raca,
  AdminJogador,
  AdminGato,
  NovoGatoResult
} from './models/types';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './app.html',
  styleUrl: './app.css'
})
export class App implements OnInit {
  public auth0 = inject(Auth0Service);
  public api = inject(GatinhosApiService);

  // --- Estado de Configurações (5 parâmetros) ---
  public config: ApiConfig = {
    auth0_domain: '',
    auth0_client_id: '',
    auth0_client_secret: '',
    auth0_audience: '',
    aiven_domain: ''
  };
  public showConfigModal = false;
  public showSecret = false;
  public configTesting = false;
  public configStatusMsg = '';
  public configStatusType: 'success' | 'error' = 'success';

  // --- Estado de Login ---
  public currentUser: JogadorSession | null = null;
  public loginId: number = 1;
  public loginPassword: string = '123';
  public loginLoading = false;
  public loginError = '';

  // --- Abas e Navegação ---
  public activeTab: 'gatinhos' | 'ranking' | 'racas' | 'admin' = 'gatinhos';
  public adminSubTab: 'jogadores' | 'racas' | 'gatos' = 'jogadores';

  // --- Dados do Jogo ---
  public gatinhos: Gatinho[] = [];
  public gatinhosLoading = false;

  public ranking: RankingItem[] = [];
  public rankingLoading = false;

  public racas: Raca[] = [];
  public racasLoading = false;

  public adminJogadores: AdminJogador[] = [];
  public adminGatos: AdminGato[] = [];
  public adminLoading = false;

  // --- Ações / Modais ---
  public toast: { type: 'success' | 'error' | 'info'; message: string } | null = null;
  private toastTimeout: any = null;

  public novoGatoModal: NovoGatoResult | null = null;
  public adoptingCat = false;

  public renamingCatId: number | null = null;
  public newCatName: string = '';

  // Admin Forms
  public showAdminPlayerModal = false;
  public adminPlayerForm = { id: null as number | null, nome: '', userpassword: '', isadmin: false };

  public showAdminRacaModal = false;
  public adminRacaForm = { raca: '', pata: 1, barriga: 1, rabo: 1 };

  public actionLoadingCatId: number | null = null;

  ngOnInit(): void {
    this.config = this.auth0.getConfig();
    this.currentUser = this.api.getCurrentUser();

    if (!this.auth0.isConfigured()) {
      this.showConfigModal = true;
    } else if (this.currentUser) {
      this.carregarDadosIniciais();
    }
  }

  public showToast(message: string, type: 'success' | 'error' | 'info' = 'info'): void {
    if (this.toastTimeout) {
      clearTimeout(this.toastTimeout);
    }
    this.toast = { message, type };
    this.toastTimeout = setTimeout(() => {
      this.toast = null;
    }, 4500);
  }

  // --- Métodos de Configuração ---
  public abrirConfig(): void {
    this.config = { ...this.auth0.getConfig() };
    this.configStatusMsg = '';
    this.showConfigModal = true;
  }

  public fecharConfig(): void {
    if (!this.auth0.isConfigured()) {
      this.showToast('Por favor, informe os 5 parâmetros para poder conectar.', 'error');
      return;
    }
    this.showConfigModal = false;
  }

  public async salvarETestarConfig(): Promise<void> {
    this.configTesting = true;
    this.configStatusMsg = '';

    try {
      this.auth0.saveConfig(this.config);
      // Testa obtenção do token no Auth0
      const token = await this.auth0.getAccessToken(true);
      if (!token) throw new Error('Token não retornado pelo Auth0.');

      this.configStatusType = 'success';
      this.configStatusMsg = 'Conexão com Auth0 validada com sucesso! Token gerado.';
      this.showToast('Configurações salvas e validadas!', 'success');

      setTimeout(() => {
        this.showConfigModal = false;
        if (this.currentUser) {
          this.carregarDadosIniciais();
        }
      }, 1200);
    } catch (err: any) {
      this.configStatusType = 'error';
      this.configStatusMsg = err.message || 'Erro ao validar conexão com Auth0.';
    } finally {
      this.configTesting = false;
    }
  }

  // --- Autenticação do Jogador ---
  public async realizarLogin(): Promise<void> {
    if (!this.loginId || !this.loginPassword) {
      this.loginError = 'Informe o ID e a senha.';
      return;
    }

    if (!this.auth0.isConfigured()) {
      this.showConfigModal = true;
      this.loginError = 'Configure primeiro as chaves de acesso Auth0 e Aiven.';
      return;
    }

    this.loginLoading = true;
    this.loginError = '';

    try {
      this.currentUser = await this.api.login(this.loginId, this.loginPassword);
      this.showToast(`Bem-vindo de volta, ${this.currentUser.nome}!`, 'success');
      this.carregarDadosIniciais();
    } catch (err: any) {
      this.loginError = err.message || 'Falha no login.';
    } finally {
      this.loginLoading = false;
    }
  }

  public realizarLogout(): void {
    this.api.logout();
    this.currentUser = null;
    this.gatinhos = [];
    this.ranking = [];
    this.activeTab = 'gatinhos';
    this.showToast('Sessão encerrada.', 'info');
  }

  public carregarDadosIniciais(): void {
    this.carregarGatinhos();
    this.carregarRanking();
    this.carregarRacas();
    if (this.currentUser?.isadmin) {
      this.carregarAdminData();
    }
  }

  // --- Gatinhos do Jogador ---
  public async carregarGatinhos(): Promise<void> {
    this.gatinhosLoading = true;
    try {
      this.gatinhos = await this.api.listarMeusGatinhos();
    } catch (err: any) {
      this.showToast(err.message, 'error');
    } finally {
      this.gatinhosLoading = false;
    }
  }

  public async adotarNovoGato(): Promise<void> {
    this.adoptingCat = true;
    try {
      const res = await this.api.ganharNovoGato();
      this.novoGatoModal = res;
      await this.carregarGatinhos();
      this.showToast(res.mensagem, 'success');
    } catch (err: any) {
      this.showToast(err.message, 'error');
    } finally {
      this.adoptingCat = false;
    }
  }

  public iniciarRenomear(gato: Gatinho): void {
    this.renamingCatId = gato.id;
    this.newCatName = gato.nome;
  }

  public cancelarRenomear(): void {
    this.renamingCatId = null;
    this.newCatName = '';
  }

  public async confirmarRenomear(idGato: number): Promise<void> {
    if (!this.newCatName.trim()) {
      this.showToast('O nome não pode ser vazio.', 'error');
      return;
    }
    try {
      const res = await this.api.renomearGatinho(idGato, this.newCatName.trim());
      this.showToast(res.mensagem, 'success');
      this.renamingCatId = null;
      await this.carregarGatinhos();
    } catch (err: any) {
      this.showToast(err.message, 'error');
    }
  }

  // --- Carinhos ---
  public async darCarinho(gato: Gatinho, local: 'pata' | 'barriga' | 'rabo'): Promise<void> {
    this.actionLoadingCatId = gato.id;
    try {
      let res;
      if (local === 'pata') {
        res = await this.api.carinhoPata(gato.id);
      } else if (local === 'barriga') {
        res = await this.api.carinhoBarriga(gato.id);
      } else {
        res = await this.api.carinhoRabo(gato.id);
      }

      this.showToast(res.mensagem, 'success');
      // Atualiza gato localmente e ranking
      gato.level = res.novo_level;
      gato.total_carinhos = (gato.total_carinhos || 0) + 1;
      gato.ultimo_carinho = new Date().toISOString();
      this.carregarRanking();
    } catch (err: any) {
      this.showToast(err.message, 'error');
    } finally {
      this.actionLoadingCatId = null;
    }
  }

  // --- Ranking e Raças ---
  public async carregarRanking(): Promise<void> {
    this.rankingLoading = true;
    try {
      this.ranking = await this.api.obterRanking();
    } catch (err: any) {
      console.error(err);
    } finally {
      this.rankingLoading = false;
    }
  }

  public async carregarRacas(): Promise<void> {
    this.racasLoading = true;
    try {
      this.racas = await this.api.listarRacas();
    } catch (err: any) {
      console.error(err);
    } finally {
      this.racasLoading = false;
    }
  }

  // --- Painel Administrativo ---
  public async carregarAdminData(): Promise<void> {
    if (!this.currentUser?.isadmin) return;
    this.adminLoading = true;
    try {
      this.adminJogadores = await this.api.adminListarJogadores();
      this.adminGatos = await this.api.adminListarTodosGatos();
    } catch (err: any) {
      this.showToast(`Admin: ${err.message}`, 'error');
    } finally {
      this.adminLoading = false;
    }
  }

  public abrirModalNovoJogador(): void {
    this.adminPlayerForm = { id: null, nome: '', userpassword: '', isadmin: false };
    this.showAdminPlayerModal = true;
  }

  public abrirModalEditarJogador(jog: AdminJogador): void {
    this.adminPlayerForm = { id: jog.id, nome: jog.nome, userpassword: '', isadmin: jog.isadmin };
    this.showAdminPlayerModal = true;
  }

  public async salvarJogadorAdmin(): Promise<void> {
    if (!this.adminPlayerForm.nome.trim()) {
      this.showToast('Nome é obrigatório.', 'error');
      return;
    }
    if (!this.adminPlayerForm.id && !this.adminPlayerForm.userpassword) {
      this.showToast('Senha é obrigatória para novo jogador.', 'error');
      return;
    }

    try {
      const res = await this.api.adminSalvarJogador(
        this.adminPlayerForm.id,
        this.adminPlayerForm.nome.trim(),
        this.adminPlayerForm.userpassword,
        this.adminPlayerForm.isadmin
      );
      this.showToast(res.mensagem, 'success');
      this.showAdminPlayerModal = false;
      this.carregarAdminData();
    } catch (err: any) {
      this.showToast(err.message, 'error');
    }
  }

  public abrirModalNovaRaca(): void {
    this.adminRacaForm = { raca: '', pata: 1, barriga: 1, rabo: 1 };
    this.showAdminRacaModal = true;
  }

  public abrirModalEditarRaca(r: Raca): void {
    this.adminRacaForm = { raca: r.raca, pata: r.pata, barriga: r.barriga, rabo: r.rabo };
    this.showAdminRacaModal = true;
  }

  public async salvarRacaAdmin(): Promise<void> {
    if (!this.adminRacaForm.raca.trim()) {
      this.showToast('Nome da raça é obrigatório.', 'error');
      return;
    }

    try {
      const res = await this.api.adminSalvarRaca(
        this.adminRacaForm.raca.trim().toLowerCase(),
        Number(this.adminRacaForm.pata),
        Number(this.adminRacaForm.barriga),
        Number(this.adminRacaForm.rabo)
      );
      this.showToast(res.mensagem, 'success');
      this.showAdminRacaModal = false;
      this.carregarRacas();
    } catch (err: any) {
      this.showToast(err.message, 'error');
    }
  }

  // --- Helpers Visuais ---
  public getCorBadge(cor: string): string {
    switch ((cor || '').toLowerCase()) {
      case 'amarelo': return '🟡 Amarelo';
      case 'preto': return '⚫ Preto';
      case 'branco': return '⚪ Branco';
      default: return `🐱 ${cor}`;
    }
  }

  public formatarData(dataStr?: string): string {
    if (!dataStr) return 'Nunca';
    try {
      const d = new Date(dataStr);
      return d.toLocaleDateString('pt-BR') + ' ' + d.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
    } catch {
      return dataStr;
    }
  }
}
