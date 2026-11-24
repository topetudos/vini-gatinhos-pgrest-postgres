# 🐱 Gatinhos RPG - PostgREST (Aiven) & Auth0 com Angular 22

Aplicação web desenvolvida em **Angular 22** (Node v26) para gerenciamento e interação com o jogo de gatinhos, utilizando o **PostgreSQL na Aiven** via **Data API (PostgREST)** autenticada com tokens Machine-to-Machine (M2M) do **Auth0**.

A aplicação foi preparada para ser publicada diretamente no **GitHub Pages**.

> 📚 Toda a estrutura de acesso ao banco (PostgreSQL na Aiven exposto pela Data API/PostgREST, autenticado com Auth0) foi baseada no tutorial oficial da Aiven: [Aiven for PostgreSQL® Data API tutorial](https://aiven.io/docs/products/postgresql/howto/data-api/tutorial).

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

## 🎮 Usuários Cadastrados no Banco

| ID | Nome | Perfil |
| :---: | :---: | :---: |
| **1** | **Jones** | 🛡️ **Administrador** |
| **2** | **Bini** | 🎮 **Jogador** |
| **3** | **Kuma** | 🎮 **Jogador** |

As senhas não ficam neste repositório (ele é público). Peça a sua a um administrador, que pode criar jogadores e trocar senhas pelo Painel Admin.

---

## 🚀 Como Executar Localmente

### Pré-requisitos
- Node.js 26, definido no [`.nvmrc`](.nvmrc). Com [nvm](https://github.com/nvm-sh/nvm), rode `nvm use` na pasta do projeto.
- npm 11 (vem com o Node 26)

### Instalação e Execução
```bash
# Ativar o Node 26 do .nvmrc
nvm use

# Instalar dependências
npm install

# Iniciar servidor de desenvolvimento local
npm start
```
Acesse a aplicação no navegador em `http://localhost:4200/`.

> ⚠️ **Limitação no navegador (CORS do Auth0):** a resposta do `POST /oauth/token` do Auth0 para aplicações M2M não traz o header `Access-Control-Allow-Origin`. Por isso, no navegador (`npm start` ou GitHub Pages) a obtenção do token falha com `Http failure response ... 0 undefined`. O app Android não tem esse problema (veja abaixo). A API da Aiven aceita qualquer origem.

---

## 🌐 Como Publicar no GitHub Pages

O deploy é feito pelo GitHub Actions ([`.github/workflows/deploy.yml`](.github/workflows/deploy.yml)). A cada push na `main`, o workflow compila o Angular com o Node do `.nvmrc` e publica em:

`https://topetudos.github.io/vini-gatinhos-pgrest-postgres/`

Configuração no GitHub, feita uma vez: **Settings** &rarr; **Pages** &rarr; **Source**: **GitHub Actions**. No plano gratuito, o Pages exige repositório público.

Para acompanhar o deploy pelo terminal: `gh run list --limit 3`.

> A pasta `docs/` e o script `npm run build:gh-pages` são da forma antiga de publicação (Deploy from a branch) e não são usados pelo workflow.

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

# 2. Apontar para o JDK 21 e o Android SDK
export JAVA_HOME=~/.sdkman/candidates/java/21.0.13.1.2-amzn   # ajuste para o seu JDK 21
export ANDROID_HOME=~/Android/Sdk

# 3. Gerar o APK de debug
nvm use
npm run apk:debug
```
O APK fica em `android/app/build/outputs/apk/debug/app-debug.apk`.

Para instalar, copie o arquivo para o celular e abra (o Android pede permissão para apps de fonte desconhecida), ou use o cabo USB com depuração ativada:
```bash
~/Android/Sdk/platform-tools/adb install -r android/app/build/outputs/apk/debug/app-debug.apk
```

**Como o APK evita o CORS:** o [`capacitor.config.ts`](capacitor.config.ts) ativa o plugin `CapacitorHttp`, que faz as requisições `fetch` pela pilha HTTP nativa do Android, onde não existe CORS. O `HttpClient` do Angular usa `withFetch()`, então o código Angular não muda.

**Como a config é pré-preenchida:** a configuração `android` do `angular.json` troca `src/environments/app-config.ts` (vazio, vai para o git) por `app-config.local.ts` (valores reais, no `.gitignore`). O app usa esses valores só quando o `localStorage` está vazio; a tela ⚙️ Configurações continua permitindo trocar.

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
- **🛡️ Painel Admin** (Liberado apenas se `isadmin = TRUE`):
  - Listar e criar/editar jogadores e senhas (`admin_listar_jogadores`, `admin_salvar_jogador`).
  - Consultar os bônus de cada raça (`listar_racas`) e criar/atualizar raças e pontuações de carinho (`admin_salvar_raca`). Os bônus ficam ocultos para jogadores comuns: descobrir faz parte do jogo.
  - Visão global de todos os gatinhos e tutores do sistema (`admin_listar_todos_gatos`).

### 📏 Regras do jogo (aplicadas no banco)

| Regra | Onde | Mensagem de erro |
|---|---|---|
| No máximo **1 carinho por dia** por gatinho, somando pata, barriga e rabo | `carinho_*_fn` ([V004](migrations/V004__limite_um_carinho_por_dia.sql)) | `Você já fez carinho em <nome> hoje! Volte amanhã.` |
| No máximo **4 gatinhos** por jogador, inclusive admin | `ganhar_novo_gato` ([V006](migrations/V006__limite_quatro_gatinhos.sql)) | `Você já tem 4 gatinhos, o máximo permitido é 4.` |

O app mostra a mensagem de erro do banco no aviso (toast) da tela.

---

## 🗄️ Migrações do Banco

Toda alteração de estrutura ou de função no PostgreSQL é uma migração versionada em [`migrations/`](migrations/) (`V001` a `V006` hoje). Detalhes e convenções em [`migrations/README.md`](migrations/README.md).

Para aplicar as pendentes:
```bash
pip install --user psycopg2-binary   # uma vez
export DATABASE_URL="postgres://avnadmin:SENHA@host:porta/gatinhos?sslmode=require"
python3 migrations/run_migrations.py
```
O script consulta a tabela `schema_migrations` e aplica só as versões que ainda não rodaram. Nunca edite uma migração já commitada; crie a próxima `V00N`.

> `schema_security.sql` e `schema_atual.sql`, na raiz, são snapshots antigos de referência. Não os execute: eles não têm as correções das migrações V004 a V006.
