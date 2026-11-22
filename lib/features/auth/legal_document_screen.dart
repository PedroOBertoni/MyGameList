import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';

enum LegalDocument { terms, privacy }

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({required this.document, super.key});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final isTerms = document == LegalDocument.terms;
    final theme = Theme.of(context);
    final accent = AppColors.accent(context);
    final sections = isTerms ? _termsSections : _privacySections;

    return Scaffold(
      appBar: AppBar(
        title: Text(isTerms ? 'Termos de Uso' : 'Política de Privacidade'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 36),
          children: [
            RichText(
              text: TextSpan(
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 15,
                  height: 1.6,
                ),
                children: isTerms ? _termsIntroduction : _privacyIntroduction,
              ),
            ),
            const SizedBox(height: 22),
            for (var index = 0; index < sections.length; index++) ...[
              _LegalSectionView(
                number: index + 1,
                section: sections[index],
                textColor: theme.colorScheme.onSurface,
                accent: accent,
              ),
              if (index != sections.length - 1) const SizedBox(height: 22),
            ],
            const SizedBox(height: 24),
            Text(
              'Última atualização: 21 de novembro de 2026',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalSectionView extends StatelessWidget {
  const _LegalSectionView({
    required this.number,
    required this.section,
    required this.textColor,
    required this.accent,
  });

  final int number;
  final _LegalSection section;
  final Color textColor;
  final Color accent;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '$number.',
              style: TextStyle(
                color: accent,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
          ),
          Expanded(
            child: Text(
              section.title,
              style: TextStyle(
                color: accent,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      for (final paragraph in section.paragraphs) ...[
        RichText(
          text: TextSpan(
            style: TextStyle(color: textColor, fontSize: 15, height: 1.6),
            children: paragraph,
          ),
        ),
        const SizedBox(height: 10),
      ],
    ],
  );
}

class _LegalSection {
  const _LegalSection(this.title, this.paragraphs);

  final String title;
  final List<List<InlineSpan>> paragraphs;
}

const _termsIntroduction = <InlineSpan>[
  TextSpan(text: 'Estes termos explicam as condições de uso do '),
  TextSpan(
    text: 'MyGameList',
    style: TextStyle(fontWeight: FontWeight.w800),
  ),
  TextSpan(
    text:
        '. Ao criar uma conta ou utilizar o aplicativo, você declara que leu e aceita estas condições.',
  ),
];

const _termsSections = <_LegalSection>[
  _LegalSection('Finalidade do aplicativo', [
    [
      TextSpan(
        text:
            'O MyGameList ajuda você a organizar sua biblioteca e lista de desejos de jogos, incluindo plataforma, situação, datas, avaliação e tempo de jogo. O aplicativo é destinado ao ',
      ),
      TextSpan(
        text: 'uso pessoal',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      TextSpan(text: '.'),
    ],
    [
      TextSpan(
        text:
            'Informações, descrições e imagens de jogos podem vir de serviços externos. Esses dados podem estar incompletos, mudar ou ficar indisponíveis.',
      ),
    ],
  ]),
  _LegalSection('Conta e acesso', [
    [
      TextSpan(
        text:
            'Você pode usar os recursos locais sem entrar. Para sincronizar a biblioteca, pode criar uma conta com e-mail e senha ou entrar com Google. As credenciais de autenticação são processadas pelo Firebase; mantenha o acesso à sua conta protegido.',
      ),
    ],
    [
      TextSpan(
        text:
            'As informações fornecidas devem ser verdadeiras e você deve avisar o responsável pelo aplicativo caso perceba uso não autorizado da sua conta.',
      ),
    ],
  ]),
  _LegalSection('Biblioteca e sincronização', [
    [
      TextSpan(
        text:
            'Sem login, os dados da biblioteca ficam salvos localmente no aparelho. Ao entrar em uma conta, o aplicativo pode importar os dados locais para essa conta e sincronizar alterações com o Firebase. A sincronização depende de conexão e pode sofrer atrasos ou interrupções.',
      ),
    ],
    [
      TextSpan(text: 'Sair da conta '),
      TextSpan(
        text: 'não apaga os dados locais',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      TextSpan(
        text:
            '. A sincronização não substitui uma cópia de segurança que você mantenha por conta própria.',
      ),
    ],
  ]),
  _LegalSection('Serviços de terceiros', [
    [
      TextSpan(
        text:
            'A pesquisa de jogos pode usar a RAWG. A importação da biblioteca Steam consulta dados de um perfil público informado por você; não solicitamos sua senha Steam. Para importar os jogos, o perfil e os detalhes relevantes precisam estar públicos.',
      ),
    ],
    [
      TextSpan(
        text:
            'Google, Firebase, Steam, RAWG, publicadoras e plataformas de jogos são serviços independentes, sujeitos às próprias condições e políticas. O MyGameList não é afiliado nem endossado por esses serviços.',
      ),
    ],
  ]),
  _LegalSection('Uso responsável', [
    [
      TextSpan(
        text:
            'Use o aplicativo de acordo com a legislação e com as regras dos serviços conectados. Não tente acessar contas ou dados de outras pessoas, interferir no funcionamento do aplicativo, contornar medidas de segurança ou usar integrações de forma abusiva.',
      ),
    ],
    [
      TextSpan(
        text:
            'Você é responsável por manter a privacidade do perfil Steam que informar e por obter autorização antes de importar ou utilizar dados de outra pessoa.',
      ),
    ],
  ]),
  _LegalSection('Conteúdo e propriedade intelectual', [
    [
      TextSpan(
        text:
            'Os nomes, marcas, capas e demais materiais de jogos pertencem aos respectivos titulares e podem ser exibidos por meio de serviços externos. A inclusão de um jogo no MyGameList não transfere esses direitos.',
      ),
    ],
    [
      TextSpan(
        text:
            'Os dados e avaliações que você registra continuam sob sua responsabilidade. Você permite que o aplicativo os armazene e processe apenas para exibir sua biblioteca e, quando ativado, sincronizá-la entre seus aparelhos.',
      ),
    ],
  ]),
  _LegalSection('Disponibilidade e alterações', [
    [
      TextSpan(
        text:
            'O aplicativo e as integrações podem ser atualizados, interrompidos ou alterados para manutenção, segurança ou evolução do serviço. Recursos que dependem de terceiros também podem deixar de funcionar quando esses serviços mudarem.',
      ),
    ],
  ]),
  _LegalSection('Encerramento e legislação', [
    [
      TextSpan(
        text:
            'Você pode parar de usar o aplicativo a qualquer momento. Sair da conta encerra a sessão, mas não exclui os dados sincronizados. Para informações sobre solicitação de exclusão, consulte a Política de Privacidade.',
      ),
    ],
    [
      TextSpan(
        text:
            'Estes termos são interpretados conforme a legislação brasileira, respeitadas as normas de proteção ao consumidor aplicáveis.',
      ),
    ],
  ]),
];

const _privacyIntroduction = <InlineSpan>[
  TextSpan(text: 'Esta política explica quais dados o '),
  TextSpan(
    text: 'MyGameList',
    style: TextStyle(fontWeight: FontWeight.w800),
  ),
  TextSpan(
    text:
        ' utiliza, para que são usados e como são armazenados quando você usa o aplicativo.',
  ),
];

const _privacySections = <_LegalSection>[
  _LegalSection('Dados utilizados', [
    [
      TextSpan(
        text:
            'Quando você cria uma conta ou entra, o Firebase processa identificadores da conta e o e-mail. Se você escolher Google, o provedor pode retornar também nome e imagem de perfil. O MyGameList não armazena sua senha Google.',
      ),
    ],
    [
      TextSpan(
        text:
            'A biblioteca pode conter nomes e plataformas de jogos, listas, situação, datas, avaliações, tempo de jogo, identificadores externos e endereços de imagens. Preferências, como ordenação de listas e perfil Steam informado para importação, também podem ser armazenadas.',
      ),
    ],
    [
      TextSpan(
        text:
            'Ao importar da Steam, são consultados o identificador ou endereço do perfil público e os dados de jogos e horas que a Steam disponibiliza. O aplicativo não pede sua senha Steam.',
      ),
    ],
  ]),
  _LegalSection('Como os dados são usados', [
    [
      TextSpan(
        text:
            'Usamos esses dados para autenticar sua conta, mostrar e organizar sua biblioteca, importar jogos quando você solicita, guardar suas preferências e sincronizar informações entre aparelhos conectados à mesma conta.',
      ),
    ],
    [
      TextSpan(
        text:
            'As pesquisas no catálogo enviam à RAWG o texto pesquisado e os parâmetros necessários para obter resultados. O aplicativo não precisa enviar sua senha ou biblioteca privada da Steam para pesquisar um jogo.',
      ),
    ],
  ]),
  _LegalSection('Armazenamento local e sincronização', [
    [
      TextSpan(
        text:
            'Quando você usa o aplicativo sem entrar, a biblioteca e as preferências ficam em um banco de dados local no aparelho. Com uma sessão autenticada, as alterações podem ser sincronizadas com o Firebase Firestore e associadas ao identificador da sua conta.',
      ),
    ],
    [
      TextSpan(
        text:
            'Ao entrar pela primeira vez, o aplicativo pode importar para a conta a biblioteca que estava salva localmente. Sair da conta não exclui essa cópia local nem apaga automaticamente os dados sincronizados na nuvem.',
      ),
    ],
  ]),
  _LegalSection('Serviços externos e compartilhamento', [
    [
      TextSpan(
        text:
            'Para oferecer os recursos escolhidos, o aplicativo utiliza Firebase Authentication e Firestore, autenticação Google, APIs da Steam e o catálogo RAWG. Cada serviço recebe os dados necessários à operação solicitada e trata esses dados de acordo com suas próprias políticas.',
      ),
    ],
    [
      TextSpan(
        text:
            'O MyGameList não vende seus dados pessoais. O compartilhamento ocorre com os serviços necessários para autenticação, catálogo, importação e sincronização, ou quando exigido por lei.',
      ),
    ],
  ]),
  _LegalSection('Retenção e exclusão', [
    [
      TextSpan(
        text:
            'Os dados locais permanecem no aparelho até que você os remova, limpe os dados do aplicativo ou desinstale o aplicativo. Dados sincronizados permanecem associados à conta até serem removidos conforme uma solicitação de exclusão ou outra obrigação aplicável.',
      ),
    ],
    [
      TextSpan(
        text:
            'Sair da conta não exclui os dados sincronizados, e atualmente o aplicativo não oferece um botão de exclusão de conta. Para solicitar acesso, correção ou exclusão dos dados da conta, entre em contato com o responsável pelo MyGameList pelo canal de suporte disponibilizado junto ao aplicativo.',
      ),
    ],
  ]),
  _LegalSection('Seus direitos', [
    [
      TextSpan(
        text:
            'Nos termos da legislação aplicável, incluindo a LGPD, você pode solicitar confirmação do tratamento, acesso, correção, informação sobre compartilhamentos, portabilidade quando aplicável, bloqueio ou eliminação de dados nos casos previstos em lei, além de revogar consentimentos quando essa for a base utilizada.',
      ),
    ],
    [
      TextSpan(
        text:
            'Para exercer esses direitos ou esclarecer uma dúvida sobre privacidade, use o canal de contato indicado na seção anterior. Poderemos solicitar informações para confirmar sua identidade antes de atender ao pedido.',
      ),
    ],
  ]),
  _LegalSection('Segurança', [
    [
      TextSpan(
        text:
            'Adotamos os recursos técnicos fornecidos pelas plataformas utilizadas e medidas razoáveis para proteger os dados. Nenhum armazenamento local, conexão ou serviço online pode oferecer garantia absoluta contra falhas ou acessos indevidos.',
      ),
    ],
  ]),
  _LegalSection('Atualizações desta política', [
    [
      TextSpan(
        text:
            'Esta política pode ser atualizada quando o aplicativo ou suas integrações mudarem. A data ao final indica a revisão mais recente. Se uma mudança exigir uma nova escolha sua, ela será apresentada quando aplicável.',
      ),
    ],
  ]),
];
