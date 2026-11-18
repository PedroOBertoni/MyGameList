# MyGameList

Aplicativo Flutter offline-first para biblioteca pessoal e lista de desejos. Os registros do usuário são mantidos localmente em SQLite/Drift; o catálogo RAWG só preenche dados de catálogo no formulário.

## Requisitos

- Flutter stable e Dart compatível com `sdk: >=3.10.0 <4.0.0`.
- Android Studio/Android SDK para executar no Android. Para iOS, use macOS e Xcode.
- Uma API key RAWG para habilitar a pesquisa do catálogo. O cadastro manual não depende dela.

## Configurar a RAWG

1. Obtenha uma chave pessoal em [rawg.io/apidocs](https://rawg.io/apidocs).
2. Copie o arquivo de exemplo para a configuração local ignorada pelo Git:

   ```powershell
   Copy-Item config/rawg.example.json config/rawg.local.json
   ```

3. Substitua `INSERIR_CHAVE_AQUI` pela sua chave em `config/rawg.local.json`.
4. Execute o aplicativo passando o arquivo local:

   ```powershell
   flutter run --dart-define-from-file=config/rawg.local.json
   ```

Para compilar, passe a mesma opção a `flutter build apk`, `flutter build appbundle` ou `flutter build web`.

A chave não é enviada ao Firestore, mas fica embutida no aplicativo compilado e pode ser extraída do APK. Ela não é um segredo inviolável. Não publique o arquivo `config/rawg.local.json`. Sem chave, o formulário informa como configurá-la e mantém o cadastro manual disponível.

A integração consulta `GET /api/games` em páginas de até 20 resultados e busca detalhes do jogo selecionado. Resultados e detalhes ficam em cache apenas na memória do app por 10 minutos. A pesquisa aguarda 400 ms após a digitação e ignora respostas antigas. A documentação RAWG lista a cota do plano gratuito e exige um link ativo para RAWG em cada tela que usa os dados ou imagens; o aplicativo mostra essa atribuição no formulário, na Biblioteca, nos Detalhes e nas telas que contêm jogos RAWG.

## Executar

```powershell
flutter pub get
flutter run --dart-define-from-file=config/rawg.local.json
```

Sem a configuração RAWG, execute apenas `flutter run`; o catálogo mostrará a pendência e o cadastro manual continuará funcionando offline.

## Validação

```powershell
flutter analyze
flutter test
```

Os testes cobrem ordenação, empates, reorganização, banco local, cadastro manual, catálogo RAWG e layout responsivo. A pesquisa real precisa de uma chave válida; ela não é incluída no projeto.

## Arquitetura e estado atual

- `lib/core/database/` contém o SQLite/Drift, a fila de operações e as preferências.
- `lib/core/models/` contém os jogos e as regras de ordenação.
- `lib/features/games/` contém cadastro, edição, detalhes e repositório.
- `lib/features/integrations/rawg_catalog_gateway.dart` contém o cliente HTTP, cache local e leitura de metadados.
- `lib/features/library/` contém Biblioteca, lista de desejos e cabeçalho.
- `assets/images/img_fundo.webp` é a imagem local usada no cabeçalho da Biblioteca.

O campo existente `external_game_id` armazena o ID RAWG e `source_game_id` guarda o slug para o link de atribuição. A sincronização e autenticação Firebase permanecem nos contratos locais existentes e ainda dependem de um projeto Firebase configurado; não foi adicionado backend, Cloud Functions ou configuração de faturamento.

O esquema Drift é escrito em SQL manual. Esta implementação reutiliza os campos existentes e não exige migração do banco.
