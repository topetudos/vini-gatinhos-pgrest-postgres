export interface ApiConfig {
  auth0_domain: string;
  auth0_client_id: string;
  auth0_client_secret: string;
  auth0_audience: string;
  aiven_domain: string;
}

export interface JogadorSession {
  id: number;
  nome: string;
  isadmin: boolean;
  userpassword?: string;
}

export interface Gatinho {
  id: number;
  nome: string;
  cor: string;
  raca: string;
  level: number;
  total_carinhos: number;
  ultimo_carinho?: string;
}

export interface RankingItem {
  posicao: number;
  id_gato: number;
  nome_gato: string;
  level_gato: number;
  raca: string;
  cor: string;
  nome_dono: string;
  quantidade_carinhos: number;
  data_ultimo_carinho?: string;
}

export interface Raca {
  raca: string;
  pata: number;
  barriga: number;
  rabo: number;
}

export interface AdminJogador {
  id: number;
  nome: string;
  isadmin: boolean;
  total_gatinhos: number;
}

export interface AdminGato {
  id: number;
  id_jogador: number;
  nome_dono: string;
  nome: string;
  cor: string;
  raca: string;
  level: number;
  total_carinhos: number;
}

export interface CarinhoResult {
  id: number;
  nome: string;
  novo_level: number;
  pontos_ganhos: number;
  mensagem: string;
}

export interface NovoGatoResult {
  id: number;
  nome: string;
  cor: string;
  raca: string;
  level: number;
  mensagem: string;
}
