# 🐱 Gatinhos RPG - PostgREST (Aiven) & Auth0 com Angular 22

Aplicação web desenvolvida em **Angular 22** (Node v26) para gerenciamento e interação com o jogo de gatinhos, utilizando o **PostgreSQL na Aiven** via **Data API (PostgREST)** autenticada com tokens Machine-to-Machine (M2M) do **Auth0**.

A aplicação foi preparada para ser publicada diretamente no **GitHub Pages**.

---

## 🔒 Modelo de Segurança e Blindagem do Banco de Dados

Seguindo o princípio do menor privilégio:
1. **Acesso Direto às Tabelas Revogado**:
   O acesso direto das roles REST (`api_worker`, `web_anon`) às tabelas `jogador`, `gatinho`, `raca` e `carinho` foi **revogado**. Nenhuma chamada REST direta (ex: `GET /gatinho` ou `GET /jogador`) é permitida.
2. **Acesso Exclusivo via Funções RPC com `SECURITY DEFINER`**:
   Todas as operações do jogo passam exclusivamente por `POST /rpc/<nome_da_funcao>`.
3. **Consistência Obrigatória de Credenciais**:
   Toda função RPC recebe e valida os campos:
   - `app_userid` (ID numérico do jogador)
   - `app_userpassword` (Senha do jogador)
   Se as credenciais forem incorretas ou o jogador não existir, a função aborta com exceção (`Acesso negado: ID ou senha incorretos`), retornando erro HTTP imediato.
4. **Proteção de Rotas Administrativas (`isadmin = TRUE`)**:
   Rotas administrativas (criação e edição de jogadores, ajuste de bônus de raças e visão global de gatinhos) checam a flag `isadmin` na tabela `jogador`. Jogadores comuns que tentarem acionar essas funções são bloqueados com `Acesso negado: Requer privilégios de administrador`.
5. **Consistência de Propriedade**:
   Ações como fazer carinho e renomear gatinho consistem se o gatinho realmente pertence ao `app_userid` que solicitou a ação.

O script SQL completo de segurança aplicado no banco está disponível em [`schema_security.sql`](schema_security.sql).

---

## ⚙️ Os 5 Parâmetros de Conexão

Ao abrir a aplicação, clique no botão **⚙️ Configurações** (ou será solicitado automaticamente na primeira execução) para informar os 5 parâmetros:

1. **`auth0_domain`**: Domínio do Auth0 (ex: `dev-xyz.us.auth0.com`).
2. **`auth0_client_id`**: Client ID da aplicação M2M no Auth0.
3. **`auth0_client_secret`**: Client Secret da aplicação M2M no Auth0.
4. **`auth0_audience`**: Audience da API configurada no Auth0 (ex: `https://my-aiven-pg-api/`).
5. **`aiven_domain`**: Endpoint do PostgREST da Aiven (ex: `pg-3c07c90e-vacadbteste.f.aivencloud.com:20582`).

> **Nota:** Esses 5 parâmetros ficam salvos no `localStorage` do seu navegador. Você só precisa preenchê-los uma vez! A aplicação obtém o token Bearer M2M automaticamente e o renova em segundo plano.

---

## 🎮 Usuários de Teste Pré-cadastrados no Banco

| ID | Nome | Senha | Perfil | Gatinhos Iniciais |
| :---: | :---: | :---: | :---: | :---: |
| **1** | **Jones** | `123` | 🛡️ **Administrador** | 4 gatinhos |
| **2** | **Bini** | `123` | 🎮 **Jogador** | 1 gatinho |
| **3** | **Kuma** | `123` | 🎮 **Jogador** | 3 gatinhos |

---

## 🚀 Como Executar Localmente

### Pré-requisitos
- Node.js v20+ ou v26+
- npm v10+

### Instalação e Execução
```bash
# Instalar dependências
npm install

# Iniciar servidor de desenvolvimento local
npm start
```
Acesse a aplicação no navegador em `http://localhost:4200/`.

---

## 🌐 Como Publicar no GitHub Pages

O projeto já inclui duas formas automatizadas de publicação:

### Opção 1: Publicação Direta via Pasta `/docs` (Recomendada)
1. Faça o build com o script pré-configurado:
   ```bash
   npm run build:gh-pages
   ```
   *(Esse comando compila o Angular com suporte a caminhos relativos `--base-href ./` e copia para a pasta `docs/`)*.
2. Faça commit e push para o seu repositório no GitHub:
   ```bash
   git add .
   git commit -m "Deploy gatinhos app para GitHub Pages"
   git push origin main
   ```
3. No repositório no GitHub, vá em:
   **Settings** &rarr; **Pages** &rarr; **Build and deployment**:
   - **Source**: `Deploy from a branch`
   - **Branch**: `main` (ou `master`) / pasta `/docs`
   - Clique em **Save**.
4. Em poucos segundos, sua aplicação estará no ar em:
   `https://seu-usuario.github.io/seu-repositorio/`

### Opção 2: Publicação Automática via GitHub Actions
O arquivo [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml) já está pronto.
Basta ir em **Settings** &rarr; **Pages** &rarr; **Source**: selecionar **GitHub Actions**. A cada push na branch principal, o GitHub compilará e publicará a aplicação automaticamente!

---

## 📱 Como Gerar o APK Android (Capacitor)

O app Android usa o mesmo código Angular, empacotado com [Capacitor](https://capacitorjs.com/). Os 5 parâmetros podem vir pré-preenchidos no APK, sem ir para o git.

### Pré-requisitos
- JDK 21 (`JAVA_HOME`)
- Android SDK com `platforms;android-36` e `build-tools;36.0.0` (`ANDROID_HOME`, ex: `~/Android/Sdk`)

### Passos
```bash
# 1. Criar a config local (ignorada pelo git) e preencher os valores reais
cp src/environments/app-config.local.example.ts src/environments/app-config.local.ts

# 2. Gerar o APK de debug
nvm use
npm run apk:debug
```
O APK fica em `android/app/build/outputs/apk/debug/app-debug.apk`.

> ⚠️ O APK carrega o `auth0_client_secret` dentro do bundle e pode ser descompilado. Distribua só para pessoas de confiança. O build web (`npm run build` / GitHub Pages) **não** inclui esses valores.

---

## 📋 Funcionalidades da Aplicação

- **🐾 Meus Gatinhos**:
  - Exibição de cards de todos os gatinhos do jogador logado com avatar estilizado pela cor (`amarelo`, `preto`, `branco`).
  - Renomear gatinho inline (`POST /rpc/renomear_gatinho`).
  - Botões de carinho:
    - 🐾 Carinho na Pata (`POST /rpc/carinho_pata_fn`)
    - 🫄 Carinho na Barriga (`POST /rpc/carinho_barriga_fn`)
    - 🐈 Carinho no Rabo (`POST /rpc/carinho_rabo_fn`)
  - Adoção/Sorteio de novo gatinho aleatório (`POST /rpc/ganhar_novo_gato`).
- **🏆 Ranking Top 5**:
  - Classificação oficial dos 5 melhores gatinhos de acordo com as regras de negócio (`POST /rpc/obter_ranking_gatinhos`).
  - Destaque especial quando um dos gatinhos pertence ao jogador logado.
- **📖 Raças & Bônus**:
  - Consulta interativa aos bônus de pontos de cada raça cadastrada (`POST /rpc/listar_racas`).
- **🛡️ Painel Admin** (Liberado apenas se `isadmin = TRUE`):
  - Listar e criar/editar jogadores e senhas (`admin_listar_jogadores`, `admin_salvar_jogador`).
  - Criar e atualizar raças e pontuações de carinho (`admin_salvar_raca`).
  - Visão global de todos os gatinhos e tutores do sistema (`admin_listar_todos_gatos`).
