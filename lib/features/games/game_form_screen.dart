import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/game.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/steam_cover_art.dart';
import '../../core/widgets/option_menu_field.dart';
import '../integrations/integration_contracts.dart';
import '../integrations/rawg_catalog_gateway.dart';
import '../integrations/rawg_attribution_link.dart';

class GameFormScreen extends ConsumerStatefulWidget {
  const GameFormScreen({
    this.gameId,
    this.initialListType = GameListType.library,
    super.key,
  });

  final String? gameId;
  final GameListType initialListType;

  @override
  ConsumerState<GameFormScreen> createState() => _GameFormScreenState();
}

class _GameFormScreenState extends ConsumerState<GameFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _coverController = TextEditingController();
  final _hoursController = TextEditingController();
  final _catalogSearchController = TextEditingController();
  String _platformId = 'pc';
  double _rating = 0;
  late GameListType _listType;
  GameStatus? _status = GameStatus.completed;
  DateTime? _startDate;
  DateTime? _completionDate;
  bool _initialized = false;
  bool _saving = false;
  bool _searchingCatalog = false;
  bool _catalogSearched = false;
  bool _catalogHasMore = false;
  int _catalogPage = 1;
  int _catalogRequest = 0;
  Timer? _catalogDebounce;
  String? _catalogError;
  CatalogGame? _selectedCatalogGame;
  String? _externalGameId;
  String? _sourceGameId;
  GameSource _source = GameSource.manual;
  List<CatalogGame> _catalogResults = const [];

  @override
  void initState() {
    super.initState();
    _listType = widget.initialListType;
    if (_listType == GameListType.wishlist) _status = null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _coverController.dispose();
    _hoursController.dispose();
    _catalogSearchController.dispose();
    _catalogDebounce?.cancel();
    super.dispose();
  }

  void _loadExisting(Game game) {
    _initialized = true;
    _nameController.text = game.name;
    final steamAppId = game.source == GameSource.steam
        ? game.sourceGameId ?? game.externalGameId
        : null;
    _coverController.text = steamAppId == null
        ? game.coverUrl ?? ''
        : steamLibraryCoverUrl(steamAppId);
    _rating = game.rating ?? 0;
    _hoursController.text = game.playtimeHours?.toString() ?? '';
    _platformId = platformFamilyId(game.platformId);
    _listType = game.listType;
    _status = game.status;
    _startDate = game.startDate;
    _completionDate = game.completionDate;
    _source = game.source;
    _externalGameId = game.externalGameId;
    _sourceGameId = game.sourceGameId;
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.gameId == null
        ? null
        : ref.watch(gameProvider(widget.gameId!));
    if (existing != null) {
      if (existing.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (existing.hasError || existing.value == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Editar jogo')),
          body: const Center(
            child: Text('Este jogo não está disponível neste dispositivo.'),
          ),
        );
      }
      if (!_initialized) _loadExisting(existing.value!);
    }
    final editing = widget.gameId != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Editar jogo' : 'Adicionar jogo')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!editing) ...[
                    _catalogPanel(context),
                    const SizedBox(height: 18),
                  ],
                  Text(
                    'Dados do jogo',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (value) {
                      if (widget.gameId == null &&
                          _selectedCatalogGame != null &&
                          value.trim() != _selectedCatalogGame!.name) {
                        setState(() {
                          _selectedCatalogGame = null;
                          _externalGameId = null;
                          _sourceGameId = null;
                          _source = GameSource.manual;
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Nome do jogo *',
                      prefixIcon: Icon(Icons.sports_esports_rounded),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Informe o nome do jogo.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: platformFamilyId(_platformId),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Plataforma *',
                      prefixIcon: Icon(Icons.devices_rounded),
                    ),
                    items: gamePlatforms
                        .map(
                          (platform) => DropdownMenuItem<String>(
                            value: platform.$1,
                            child: Text(platform.$2),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _platformId = value);
                    },
                  ),
                  if (editing && _source == GameSource.rawg)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: RawgAttributionLink(gameSlug: _sourceGameId),
                    ),
                  const SizedBox(height: 22),
                  Text(
                    'Sua experiência',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final ratingField = _ratingField(context);
                      final hoursField = TextFormField(
                        controller: _hoursController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Horas jogadas',
                          prefixIcon: Icon(Icons.schedule_rounded),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return null;
                          }
                          final hours = double.tryParse(
                            value.replaceAll(',', '.'),
                          );
                          if (hours == null ||
                              !hours.isFinite ||
                              hours < 0 ||
                              hours * 60 > 9007199254740991) {
                            return 'Informe zero ou mais horas.';
                          }
                          return null;
                        },
                      );
                      if (constraints.maxWidth < 540) {
                        return Column(
                          children: [
                            ratingField,
                            const SizedBox(height: 16),
                            hoursField,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: ratingField),
                          const SizedBox(width: 16),
                          Expanded(child: hoursField),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  OptionMenuField<GameListType>(
                    label: 'Lista de destino',
                    valueLabel: _listType.label,
                    icon: Icons.folder_open_rounded,
                    options: GameListType.values
                        .map((type) => (type, type.label))
                        .toList(),
                    onSelected: (value) => setState(() {
                      _listType = value;
                      if (_listType == GameListType.wishlist) _status = null;
                      if (_listType == GameListType.library &&
                          _status == null) {
                        _status = GameStatus.completed;
                      }
                    }),
                  ),
                  if (_listType == GameListType.library) ...[
                    const SizedBox(height: 16),
                    OptionMenuField<GameStatus>(
                      label: 'Status *',
                      valueLabel: (_status ?? GameStatus.playing).label,
                      icon: Icons.flag_outlined,
                      options: GameStatus.values
                          .map((status) => (status, status.label))
                          .toList(),
                      onSelected: (value) => setState(() => _status = value),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Text(
                    'Datas (opcionais)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _dateTile(
                          context,
                          'Início',
                          _startDate,
                          (date) => setState(() => _startDate = date),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _dateTile(
                          context,
                          'Conclusão',
                          _completionDate,
                          (date) => setState(() => _completionDate = date),
                        ),
                      ),
                    ],
                  ),
                  if (_startDate != null &&
                      _completionDate != null &&
                      _completionDate!.isBefore(_startDate!))
                    Padding(
                      padding: const EdgeInsets.only(top: 5, left: 4),
                      child: Text(
                        'A conclusão não pode ser anterior ao início.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(
                      _saving
                          ? 'Salvando no dispositivo…'
                          : editing
                          ? 'Salvar alterações'
                          : 'Salvar jogo',
                    ),
                    style: AppTheme.primaryActionButtonStyle(),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    'O cadastro é local e funciona sem conexão.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ratingField(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return InputDecorator(
      isEmpty: false,
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.fromLTRB(10, 6, 10, 4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Nota',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: .65),
                  ),
                ),
                child: Text(
                  '${_rating.toStringAsFixed(1)} / 10',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: colors.primary,
              inactiveTrackColor: colors.outlineVariant.withValues(alpha: .8),
              thumbColor: colors.primary,
              overlayColor: colors.primary.withValues(alpha: .14),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: _rating,
              min: 0,
              max: 10,
              divisions: 20,
              label: _rating.toStringAsFixed(1),
              semanticFormatterCallback: (value) =>
                  '${value.toStringAsFixed(1)} de 10',
              onChanged: (value) => setState(() => _rating = value),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 20,
                child: Text(
                  '0',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(
                width: 20,
                child: Text(
                  '10',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _catalogPanel(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppSpace.radius),
      border: Border.all(
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: .4),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.travel_explore_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Catálogo RAWG',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            RawgAttributionLink(
              compact: true,
              gameSlug: _selectedCatalogGame?.sourceGameId,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Pesquise o catálogo para preencher nome e imagem. Nota, horas e status continuam sendo seus.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _catalogSearchController,
                textInputAction: TextInputAction.search,
                onChanged: _onCatalogQueryChanged,
                onSubmitted: (_) => _catalogSearch(),
                decoration: InputDecoration(
                  hintText: 'Pesquisar título',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _catalogSearchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpar pesquisa',
                          onPressed: () {
                            _catalogSearchController.clear();
                            _onCatalogQueryChanged('');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Pesquisar RAWG',
              onPressed: _searchingCatalog ? null : _catalogSearch,
              icon: _searchingCatalog
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search_rounded),
            ),
          ],
        ),
        if (_selectedCatalogGame case final game?) ...[
          const SizedBox(height: 12),
          _selectedCatalogTile(game),
        ],
        if (_searchingCatalog && _catalogResults.isEmpty) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
          const SizedBox(height: 5),
          Text(
            'Consultando a RAWG…',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (_catalogError case final error?) ...[
          const SizedBox(height: 10),
          Text(
            error,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (_catalogSearched &&
            !_searchingCatalog &&
            _catalogError == null &&
            _catalogResults.isEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Nenhum resultado. O cadastro manual continua disponível.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (_catalogResults.isNotEmpty) ...[
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _catalogResults.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final game = _catalogResults[index];
                return Material(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: .5),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _selectCatalogGame(game),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          _catalogCover(game.coverUrl, 44, 58),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  game.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (game.platformNames.isNotEmpty)
                                  Text(
                                    game.platformNames.take(3).join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                Text(
                                  [
                                    if (game.releaseDate != null)
                                      DateFormat(
                                        'yyyy',
                                      ).format(game.releaseDate!),
                                    ...game.genres.take(2),
                                  ].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.add_circle_outline_rounded),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_catalogHasMore) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: _searchingCatalog ? null : _loadMoreCatalog,
                icon: _searchingCatalog
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded),
                label: const Text('Carregar mais resultados'),
              ),
            ),
          ],
        ],
      ],
    ),
  );

  Widget _catalogCover(String? url, double width, double height) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(
      width: width,
      height: height,
      child: url == null || url.isEmpty
          ? const ColoredBox(
              color: AppColors.ink,
              child: Icon(Icons.videogame_asset_rounded),
            )
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, _) => const ColoredBox(color: AppColors.ink),
              errorWidget: (_, _, _) => const ColoredBox(
                color: AppColors.ink,
                child: Icon(Icons.videogame_asset_rounded),
              ),
            ),
    ),
  );

  Widget _selectedCatalogTile(CatalogGame game) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: AppColors.green.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.green.withValues(alpha: .45)),
    ),
    child: Row(
      children: [
        _catalogCover(game.coverUrl, 40, 52),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selecionado da RAWG',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.green,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(game.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                [
                  if (game.releaseDate != null)
                    DateFormat('dd/MM/yyyy').format(game.releaseDate!),
                  ...game.genres.take(3),
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              if (game.platformNames.isNotEmpty)
                Text(
                  game.platformNames.take(3).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              if (game.description?.isNotEmpty == true)
                Text(
                  game.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              Text(
                'ID RAWG ${game.externalId}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Remover seleção da RAWG',
          onPressed: () => setState(() {
            _selectedCatalogGame = null;
            _externalGameId = null;
            _sourceGameId = null;
            _source = GameSource.manual;
          }),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
  );

  Widget _dateTile(
    BuildContext context,
    String label,
    DateTime? value,
    ValueChanged<DateTime?> onChanged,
  ) {
    final borderRadius = BorderRadius.circular(AppSpace.radius / 1.5);

    return Stack(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: value ?? DateTime.now(),
                firstDate: DateTime(1970),
                lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
                helpText: 'Selecionar data de $label'.toLowerCase(),
                builder: (context, child) => Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 344,
                      maxHeight: 540,
                    ),
                    child: child!,
                  ),
                ),
              );
              if (date != null) onChanged(date);
            },
            child: InputDecorator(
              isEmpty: false,
              decoration: InputDecoration(
                labelText: label,
                prefixIcon: const Icon(Icons.calendar_month_rounded),
              ),
              child: Text(
                value == null
                    ? 'Selecionar'
                    : DateFormat('dd/MM/yyyy').format(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        if (value != null)
          Positioned(
            top: 0,
            right: 3,
            child: SizedBox(
              width: 24,
              height: 24,
              child: IconButton(
                tooltip: 'Limpar data de $label',
                onPressed: () => onChanged(null),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 24,
                  height: 24,
                ),
                icon: const Icon(Icons.close_rounded),
                iconSize: 16,
              ),
            ),
          ),
      ],
    );
  }

  void _onCatalogQueryChanged(String value) {
    _catalogDebounce?.cancel();
    final query = value.trim();
    _catalogRequest++;
    setState(() {
      _catalogResults = const [];
      _catalogError = null;
      _catalogSearched = false;
      _catalogHasMore = false;
      _catalogPage = 1;
      _searchingCatalog = false;
    });
    if (query.length < 2) return;
    _catalogDebounce = Timer(const Duration(milliseconds: 400), _catalogSearch);
  }

  Future<void> _catalogSearch() => _fetchCatalogPage(page: 1, append: false);

  Future<void> _loadMoreCatalog() =>
      _fetchCatalogPage(page: _catalogPage + 1, append: true);

  Future<void> _fetchCatalogPage({
    required int page,
    required bool append,
  }) async {
    final query = _catalogSearchController.text.trim();
    if (query.length < 2) {
      setState(
        () =>
            _catalogError = 'Digite pelo menos dois caracteres para pesquisar.',
      );
      return;
    }
    final requestId = ++_catalogRequest;
    setState(() {
      _searchingCatalog = true;
      _catalogError = null;
      if (!append) _catalogSearched = false;
    });
    try {
      final result = await ref
          .read(catalogGatewayProvider)
          .search(query, page: page)
          .timeout(const Duration(seconds: 14));
      if (!mounted ||
          requestId != _catalogRequest ||
          query != _catalogSearchController.text.trim()) {
        return;
      }
      setState(() {
        _catalogResults = append
            ? [
                ..._catalogResults,
                ...result.games.where(
                  (item) => !_catalogResults.any(
                    (existing) => existing.externalId == item.externalId,
                  ),
                ),
              ]
            : result.games;
        _catalogHasMore = result.hasMore;
        _catalogPage = page;
        _catalogSearched = true;
        _searchingCatalog = false;
      });
    } on IntegrationNotConfiguredException catch (error) {
      if (!mounted || requestId != _catalogRequest) return;
      setState(() {
        _catalogError = '$error';
        _catalogSearched = true;
        _searchingCatalog = false;
      });
    } on CatalogSearchException catch (error) {
      if (!mounted || requestId != _catalogRequest) return;
      setState(() {
        _catalogError = error.message;
        _catalogSearched = true;
        _searchingCatalog = false;
      });
    } on TimeoutException {
      if (!mounted || requestId != _catalogRequest) return;
      setState(() {
        _catalogError = 'A pesquisa RAWG demorou demais. Tente novamente.';
        _catalogSearched = true;
        _searchingCatalog = false;
      });
    } catch (_) {
      if (!mounted || requestId != _catalogRequest) return;
      setState(() {
        _catalogError =
            'Não foi possível consultar a RAWG. Verifique a conexão.';
        _catalogSearched = true;
        _searchingCatalog = false;
      });
    }
  }

  Future<void> _selectCatalogGame(CatalogGame game) async {
    final requestId = ++_catalogRequest;
    setState(() {
      _selectedCatalogGame = game;
      _catalogResults = const [];
      _catalogHasMore = false;
      _catalogSearched = false;
      _catalogError = null;
      _searchingCatalog = true;
    });
    var selected = game;
    try {
      selected = await ref
          .read(catalogGatewayProvider)
          .getDetails(game)
          .timeout(const Duration(seconds: 14));
    } on CatalogSearchException catch (error) {
      if (mounted && requestId == _catalogRequest) {
        setState(
          () => _catalogError =
              'Descrição e metadados adicionais indisponíveis: ${error.message}',
        );
      }
    } on TimeoutException {
      if (mounted && requestId == _catalogRequest) {
        setState(
          () => _catalogError =
              'Os detalhes demoraram demais; os dados da pesquisa ainda podem ser usados.',
        );
      }
    } catch (_) {
      // Search results still contain enough real data to save the game.
    }
    if (!mounted || requestId != _catalogRequest) return;
    setState(() {
      _selectedCatalogGame = selected;
      _externalGameId = selected.externalId;
      _sourceGameId = selected.sourceGameId;
      _source = GameSource.rawg;
      _nameController.text = selected.name;
      _coverController.text = selected.coverUrl ?? '';
      _searchingCatalog = false;
      if (selected.platformNames.isNotEmpty) {
        _platformId = _platformFromRawg(selected.platformNames) ?? _platformId;
      }
    });
  }

  String? _platformFromRawg(List<String> names) {
    final normalized = names.map((name) => name.toLowerCase()).toList();
    const families = <(String, String)>[
      ('pc', 'pc'),
      ('windows', 'pc'),
      ('playstation', 'playstation'),
      ('xbox', 'xbox'),
      ('nintendo', 'nintendo'),
      ('switch', 'nintendo'),
    ];
    for (final family in families) {
      if (normalized.any((name) => name.contains(family.$1))) return family.$2;
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate != null &&
        _completionDate != null &&
        _completionDate!.isBefore(_startDate!)) {
      setState(() {});
      return;
    }
    setState(() => _saving = true);
    try {
      final hoursText = _hoursController.text.trim();
      final hours = hoursText.isEmpty
          ? null
          : double.parse(hoursText.replaceAll(',', '.'));
      final draft = GameDraft(
        name: _nameController.text.trim(),
        platformId: _platformId,
        listType: _listType,
        source: _source,
        externalGameId: _externalGameId,
        sourceGameId: _sourceGameId,
        coverUrl: _coverController.text.trim().isEmpty
            ? null
            : _coverController.text.trim(),
        rating: _rating,
        playtimeMinutes: hours == null ? null : (hours * 60).round(),
        startDate: _startDate,
        completionDate: _completionDate,
        status: _listType == GameListType.wishlist ? null : _status,
      );
      final repository = await ref.read(gameRepositoryProvider.future);
      await repository.saveGame(draft, id: widget.gameId);
      ref.invalidate(gamesProvider);
      ref.invalidate(gameProvider);
      ref.invalidate(pendingOperationCountProvider);
      if (mounted) {
        context.go(
          _listType == GameListType.wishlist ? '/wishlist' : '/library',
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível salvar: $error')),
        );
        setState(() => _saving = false);
      }
    }
  }
}
