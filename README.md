# MyGameList

Aplicativo Flutter para organizar uma biblioteca pessoal de jogos e uma lista de desejos. Os dados do usuário são salvos localmente em SQLite com Drift, então o cadastro e a consulta da coleção funcionam offline. A pesquisa de metadados usa a API RAWG quando uma chave é configurada.

## Recursos

- Biblioteca e lista de desejos com cadastro, edição, detalhes e remoção de jogos.
- Dados pessoais como plataforma, situação, nota, tempo jogado e datas de início e conclusão.
- Pesquisa, filtros e ordenação; a ordem manual da lista também pode ser reorganizada.
- Tema claro e escuro.
- Pesquisa opcional no catálogo RAWG para preencher título, capa, plataformas e outros metadados. O formulário manual continua disponível sem chave ou conexão.
- Atribuição com link para RAWG nas telas que exibem jogos importados do catálogo.

## Requisitos

- Flutter e Dart compatíveis com `sdk: >=3.10.0 <4.0.0` (confira `pubspec.yaml`).
- Android Studio e Android SDK para executar no Android. Para compilar ou executar no iOS, é necessário macOS e Xcode.
- Chave de API RAWG para habilitar a pesquisa do catálogo; ela é opcional para o restante do app.

## Configurar a RAWG

1. Obtenha uma chave em [rawg.io/apidocs](https://rawg.io/apidocs).
2. Copie o exemplo para criar sua configuração local:

   ```powershell
   Copy-Item config/rawg.example.json config/rawg.local.json
   ```

3. Substitua `INSERIR_CHAVE_AQUI` pela chave em `config/rawg.local.json`.
4. Execute o app passando o arquivo:

   ```powershell
   flutter run --dart-define-from-file=config/rawg.local.json
   ```

Para compilar, passe a mesma opção ao comando de build, por exemplo `flutter build apk --dart-define-from-file=config/rawg.local.json` ou `flutter build web --release --dart-define-from-file=config/rawg.local.json`.

A chave é incluída no aplicativo compilado e pode ser extraída do APK; não a trate como um segredo. Ela não é enviada ao Firestore. O arquivo `config/rawg.local.json` está no `.gitignore` e não deve ser publicado. Sem a chave, a pesquisa RAWG informa como configurá-la e o cadastro manual permanece disponível.

O app não carrega arquivos `.env` automaticamente. A chave usada na execução e na compilação vem de `config/rawg.local.json` via `--dart-define-from-file`; `.env` também está ignorado pelo Git para evitar o envio acidental de chaves locais.

A integração consulta `GET /api/games` em páginas de até 20 resultados e busca os detalhes do jogo selecionado. A pesquisa aguarda 400 ms após a digitação, ignora respostas antigas e mantém resultados e detalhes em cache na memória por 10 minutos. A conexão precisa estar disponível para pesquisar ou carregar capas remotas.

## Executar

```powershell
flutter pub get
flutter run
```

Para usar a pesquisa RAWG durante a execução, acrescente `--dart-define-from-file=config/rawg.local.json` a `flutter run`. Sem esse arquivo, o catálogo fica desativado, mas o app pode ser usado para cadastrar jogos manualmente.

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

## Persistência e integrações pendentes

O schema local, definido em SQL em `lib/core/database/app_database.dart`, contém as tabelas `games`, `sync_operations` e `app_preferences` e está na versão 1. O ID RAWG é armazenado em `external_game_id`; `source_game_id` guarda o slug usado no link para o jogo no site da RAWG. A implementação atual reutiliza esses campos e não exige migração.

O app não tem autenticação nem sincronização remota configuradas. Os contratos de Firebase Auth, Firestore, importação Steam e importação Epic existem, mas seus provedores atuais retornam estado “não configurado”. Alterações continuam salvas localmente e a fila de sincronização não é enviada a um servidor. As dependências Firebase no `pubspec.yaml`, por si só, não configuram um projeto Firebase. Não há backend ou Cloud Functions neste projeto.
