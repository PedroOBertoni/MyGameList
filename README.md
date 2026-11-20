# MyGameList

Aplicativo Flutter para organizar uma biblioteca pessoal de jogos e uma lista de desejos. Os dados do usuário são salvos localmente em SQLite com Drift, então o cadastro e a consulta da coleção funcionam offline. A pesquisa de metadados usa a API RAWG quando uma chave é configurada.

## Recursos

- Biblioteca e lista de desejos com cadastro, edição, detalhes e remoção de jogos.
- Dados pessoais como plataforma, situação, nota, tempo jogado e datas de início e conclusão.
- Pesquisa, filtros e ordenação; a ordem manual da lista também pode ser reorganizada.
- Tema claro e escuro.
- Pesquisa opcional no catálogo RAWG para preencher título, capa, plataformas e outros metadados. O formulário manual continua disponível sem chave ou conexão.
- Atribuição com link para RAWG nas telas que exibem jogos importados do catálogo.
- Vinculação de perfil Steam público e importação local da biblioteca, com horas jogadas e prevenção de duplicatas por título ou AppID.

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
- `lib/features/integrations/`: cliente RAWG, atribuição e contratos das integrações.
- `lib/features/settings/`: perfil, aparência e estado das integrações.
- `test/`: testes organizados por área do app.
- `assets/images/img_fundo.webp`: imagem local usada no cabeçalho da Biblioteca.
- `config/rawg.example.json`: exemplo de configuração da chave RAWG.

## Próximos passos: Firebase, ajustes e Epic Games

O schema local, definido em SQL em `lib/core/database/app_database.dart`, contém as tabelas `games`, `sync_operations` e `app_preferences` e está na versão 1. O ID RAWG é armazenado em `external_game_id`; `source_game_id` guarda o slug usado no link para o jogo no site da RAWG. A implementação atual reutiliza esses campos e não exige migração.

O próximo marco é levar os dados do app para a nuvem e concluir os fluxos que ainda precisam de ajustes. Estes itens continuam pendentes:

- [ ] **Integrar o app com Firebase** para autenticação e persistência/sincronização online da biblioteca, lista de desejos, notas, status, horas jogadas, posições e preferências. A fila local `sync_operations` deverá ser processada para enviar alterações ao serviço remoto e receber atualizações, mantendo o uso offline.
- [ ] **Refinar o campo de nota** nas telas de cadastro e edição de jogos, incluindo a interação de seleção e a apresentação do valor carregado e salvo.
- [ ] **Ajustar a tela de Perfil** e concluir o fluxo de associação/sincronização das integrações, salvando online os dados de perfil que devem acompanhar a conta.
- [ ] **Ajustar a Lista de Desejos** e garantir que seus jogos, ordenação e alterações também façam parte da sincronização com Firebase.
- [ ] **Integrar a Epic Games**, incluindo a associação da conta e a importação da biblioteca, sem remover o cadastro manual, o catálogo RAWG ou a importação Steam.

**Estado atual:** jogos e preferências ainda ficam salvos localmente no SQLite/Drift. O perfil Steam é associado localmente por URL/SteamID e consultado pela Web API; a autenticação OpenID Steam e a sincronização Firestore ainda não estão configuradas. A importação Steam funciona apenas para dados visíveis de perfis públicos. A integração Epic Games ainda não foi implementada. As dependências Firebase no `pubspec.yaml`, por si só, não configuram um projeto Firebase; este repositório ainda não tem sincronização remota ou Cloud Functions configuradas.
