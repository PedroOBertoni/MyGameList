# MyGameList

Aplicativo Flutter para organizar uma biblioteca pessoal de jogos e uma lista de desejos. Os dados são salvos localmente em SQLite com Drift para uso offline e, após login, sincronizados com Firebase Auth e Cloud Firestore no Android. A pesquisa de metadados usa a API RAWG quando uma chave é configurada.

## Recursos

- Biblioteca e lista de desejos com cadastro, edição, detalhes e remoção de jogos.
- Dados pessoais como plataforma, situação, nota, tempo jogado e datas de início e conclusão.
- Pesquisa, filtros e ordenação; a ordem manual da lista também pode ser reorganizada.
- Tema claro e escuro.
- Pesquisa opcional no catálogo RAWG para preencher título, capa, plataformas e outros metadados. O formulário manual continua disponível sem chave ou conexão.
- Atribuição com link para RAWG nas telas que exibem jogos importados do catálogo.
- Vinculação de perfil Steam público e importação local da biblioteca, com horas jogadas e prevenção de duplicatas por título ou AppID.
- Cadastro e login por e-mail/senha, com biblioteca isolada por conta e sincronização de jogos e preferências com Firestore.

## Requisitos

- Flutter e Dart compatíveis com `sdk: >=3.10.0 <4.0.0` (confira `pubspec.yaml`).
- Android Studio e Android SDK para executar no Android. Para compilar ou executar no iOS, é necessário macOS e Xcode.
- Chave de API RAWG para habilitar a pesquisa do catálogo; ela é opcional para o restante do app.
- Chave Web API Steam para habilitar a importação de bibliotecas Steam públicas; ela também é opcional para o restante do app.

## Configurar RAWG e Steam

1. Obtenha uma chave em [rawg.io/apidocs](https://rawg.io/apidocs) e, se for usar a importação Steam, em [steamcommunity.com/dev](https://steamcommunity.com/dev).
2. Copie o exemplo para criar sua configuração local:

   ```powershell
   Copy-Item config/rawg.example.json config/rawg.local.json
   ```

3. Preencha `RAWG_API_KEY` e `STEAM_API_KEY` em `config/rawg.local.json`. Deixe o placeholder Steam se não for usar a importação.
4. Execute o app passando o arquivo:

   ```powershell
   flutter run --dart-define-from-file=config/rawg.local.json
   ```

Para compilar, passe a mesma opção ao comando de build, por exemplo `flutter build apk --dart-define-from-file=config/rawg.local.json` ou `flutter build web --release --dart-define-from-file=config/rawg.local.json`.

No VS Code, use **Ctrl+Shift+B** para executar a tarefa padrão **MyGameList: Build APK**. Pelo menu **Terminal > Run Build Task**, também estão disponíveis as tarefas para App Bundle e Web; todas carregam `config/rawg.local.json` automaticamente. Comandos `flutter build` executados manualmente no terminal ainda precisam incluir `--dart-define-from-file=config/rawg.local.json`.

A chave é incluída no aplicativo compilado e pode ser extraída do APK; não a trate como um segredo. Isso vale para as chaves RAWG e Steam. O arquivo `config/rawg.local.json` está no `.gitignore` e não deve ser publicado. Sem essas chaves, os catálogos externos ficam indisponíveis, mas o cadastro manual permanece disponível.

O app não carrega arquivos `.env` automaticamente. A chave usada na execução e na compilação vem de `config/rawg.local.json` via `--dart-define-from-file`; `.env` também está ignorado pelo Git para evitar o envio acidental de chaves locais.

A integração RAWG consulta `GET /api/games` em páginas de até 20 resultados e busca os detalhes do jogo selecionado. A pesquisa aguarda 400 ms após a digitação, ignora respostas antigas e mantém resultados e detalhes em cache na memória por 10 minutos. A conexão precisa estar disponível para pesquisar ou carregar capas remotas.

Na tela Perfil, informe o SteamID64, a URL personalizada (`steamcommunity.com/id/...`) ou a URL numérica (`steamcommunity.com/profiles/...`) de um perfil público para importar a biblioteca. O perfil e os detalhes dos jogos precisam estar públicos. A importação inclui jogos gratuitos jogados, salva-os como PC/concluídos, mantém a nota vazia e transfere o tempo total de jogo em minutos. Jogos já cadastrados manualmente, via RAWG ou pela Steam são preservados e não são duplicados por nome normalizado ou AppID.

## Configurar Firebase (Android)

O app inicializa Firebase no Android com `android/app/google-services.json`. O arquivo fornecido está configurado para o package `com.example.mygamelist.my_game_list` e o projeto Firebase `mygamelist-d99cc`. O plugin Google Services processa esse arquivo durante o build.

Antes de usar cadastro e sincronização, habilite **E-mail/senha** em **Authentication > Sign-in method** e crie um banco em **Firestore Database** no Firebase Console.

Para publicar as regras, abra o terminal do VS Code na raiz deste repositório (a pasta que contém `firebase.json`). No Windows/PowerShell, instale o Firebase CLI uma vez e autentique sua conta Google:

```powershell
npm install -g firebase-tools
firebase login
firebase projects:list
```

Confirme que `mygamelist-d99cc` aparece na lista e execute na mesma pasta:

```powershell
firebase deploy --only firestore:rules --project mygamelist-d99cc
```

O deploy substitui as regras atualmente publicadas no projeto pelas regras locais de `firestore.rules`; se já houver regras próprias, combine-as antes de publicar.

O app guarda primeiro os dados no SQLite. Ao criar conta ou entrar, importa uma vez a biblioteca local para a conta e sincroniza jogos, lista de desejos, posições e preferências em `users/{uid}`. Cada conta usa também um arquivo local separado. Alterações feitas sem conexão ficam na fila e são sincronizadas na próxima abertura online ou pelo botão de sincronização no Perfil. As regras permitem que cada conta leia e altere somente seus próprios documentos.

O `google-services.json` configura apenas Android. Para ativar Firebase em iOS ou Web, registre essas plataformas no projeto e gere a configuração FlutterFire correspondente.

## Executar

```powershell
flutter pub get
flutter run --dart-define-from-file=config/rawg.local.json
```

No VS Code, a configuração **MyGameList (catálogos)** em Run and Debug passa esse arquivo automaticamente ao iniciar o app. O arquivo fornece as chaves de compilação RAWG e Steam; preencher apenas um `.env` não as disponibiliza ao Flutter. Sem a configuração, o cadastro manual continua disponível, mas as integrações não recebem suas chaves.

## Testes e análise estática

```powershell
flutter analyze
flutter test
```

A suíte cobre navegação, ordenação e empates, persistência local, formulário manual e RAWG, cards e layout responsivo. Os testes usam respostas controladas; a pesquisa ao serviço RAWG exige uma chave válida e não é executada pela suíte.

## Estrutura do projeto

- `lib/core/database/`: banco SQLite/Drift, preferências e fila local de operações pendentes.
- `lib/core/models/`: modelos de jogo e regras de ordenação.
- `lib/core/router/` e `lib/core/widgets/`: navegação e componentes compartilhados, incluindo a barra inferior.
- `lib/core/theme/`: temas claro/escuro e controle da preferência de aparência.
- `lib/features/games/`: formulário, detalhes e repositório de jogos.
- `lib/features/library/`: biblioteca, lista de desejos, filtros, ordenação e cabeçalho.
- `lib/features/integrations/`: clientes RAWG, Firebase Auth/Firestore, atribuição e contratos das integrações.
- `lib/features/settings/`: perfil, aparência e estado das integrações.
- `test/`: testes organizados por área do app.
- `assets/images/img_fundo.webp`: imagem local usada no cabeçalho da Biblioteca.
- `config/rawg.example.json`: exemplo de configuração da chave RAWG.

## Próximos passos

O schema local, definido em SQL em `lib/core/database/app_database.dart`, contém as tabelas `games`, `sync_operations` e `app_preferences` e está na versão 1. O ID RAWG é armazenado em `external_game_id`; `source_game_id` guarda o slug usado no link para o jogo no site da RAWG.

- [x] **Firebase Auth e Firestore no Android:** cadastro/login por e-mail, dados locais isolados por conta, migração inicial da biblioteca local e sincronização offline-first de jogos e preferências.
- [ ] **Configuração operacional do Firebase:** habilitar E-mail/senha, criar Firestore Database e publicar `firestore.rules` no projeto `mygamelist-d99cc`.
- [ ] **Outras plataformas Firebase:** registrar iOS/Web e gerar as configurações FlutterFire correspondentes.
- [ ] **Refinar a nota** nas telas de cadastro e edição e revisar os fluxos da tela Perfil e da Lista de Desejos.
- [ ] **Integrar a Epic Games**, incluindo associação da conta e importação da biblioteca, preservando cadastro manual, RAWG e Steam.

O perfil Steam e as preferências passam a acompanhar a conta pelo Firestore; a importação Steam ainda depende de um perfil público e de uma chave Web API. A integração Epic Games continua pendente. O login social Google/Steam/Epic também não está incluído neste fluxo; a autenticação implementada usa e-mail e senha.
