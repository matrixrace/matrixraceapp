import 'package:flutter/material.dart';

// ─── Posição do tooltip relativo ao elemento destacado ───────────────────────
enum TooltipPosition { above, below }

// ─── Modelo de um passo do tutorial ──────────────────────────────────────────
class TutorialStep {
  final String title;
  final String description;
  final GlobalKey targetKey;
  final TooltipPosition position;

  const TutorialStep({
    required this.title,
    required this.description,
    required this.targetKey,
    this.position = TooltipPosition.below,
  });
}

// ─── GlobalKeys compartilhadas entre steps e widgets ─────────────────────────
class TutorialKeys {
  // MainShell — AppBar
  static final appBarHelp = GlobalKey(debugLabel: 'tut_appbar_help');
  static final appBarNotifications = GlobalKey(debugLabel: 'tut_appbar_notif');
  static final appBarMenu = GlobalKey(debugLabel: 'tut_appbar_menu');
  // MainShell — BottomNav
  static final bottomNav = GlobalKey(debugLabel: 'tut_bottom_nav');

  // Home
  static final homeNextRace = GlobalKey(debugLabel: 'tut_home_next_race');
  static final homePredictionBtn = GlobalKey(debugLabel: 'tut_home_prediction');
  static final homeCalendar = GlobalKey(debugLabel: 'tut_home_calendar');

  // Leagues
  static final leaguesFilter = GlobalKey(debugLabel: 'tut_leagues_filter');
  static final leaguesCreateBtn = GlobalKey(debugLabel: 'tut_leagues_create');

  // Live
  static final liveSessionTabs = GlobalKey(debugLabel: 'tut_live_tabs');

  // Rankings
  static final rankingsFilters = GlobalKey(debugLabel: 'tut_rankings_filters');

  // F1 Results
  static final f1Tabs = GlobalKey(debugLabel: 'tut_f1_tabs');

  // Profile
  static final profileEdit = GlobalKey(debugLabel: 'tut_profile_edit');
}

// ─── Steps por tela ──────────────────────────────────────────────────────────
final Map<String, List<TutorialStep>> tutorialStepsMap = {
  'home': [
    TutorialStep(
      title: 'Próxima Corrida',
      description:
          'Aqui aparece a próxima corrida com contagem regressiva em tempo real. Fique de olho para não perder o prazo!',
      targetKey: TutorialKeys.homeNextRace,
      position: TooltipPosition.below,
    ),
    TutorialStep(
      title: 'Fazer Palpite',
      description:
          'Toque aqui para montar seu palpite. Quanto antes travar, mais pontos você pode ganhar!',
      targetKey: TutorialKeys.homePredictionBtn,
      position: TooltipPosition.above,
    ),
    TutorialStep(
      title: 'Calendário',
      description:
          'Veja todas as corridas que estão por vir e já faça seus palpites com antecedência.',
      targetKey: TutorialKeys.homeCalendar,
      position: TooltipPosition.below,
    ),
  ],
  'leagues': [
    TutorialStep(
      title: 'Filtros',
      description: 'Filtre suas ligas por status ou busque pelo nome.',
      targetKey: TutorialKeys.leaguesFilter,
      position: TooltipPosition.below,
    ),
    TutorialStep(
      title: 'Criar Liga',
      description: 'Crie sua própria liga e convide seus amigos!',
      targetKey: TutorialKeys.leaguesCreateBtn,
      position: TooltipPosition.above,
    ),
  ],
  'live': [
    TutorialStep(
      title: 'Sessões ao Vivo',
      description:
          'Altere entre sessões para ver cada resultado em tempo real.',
      targetKey: TutorialKeys.liveSessionTabs,
      position: TooltipPosition.below,
    ),
  ],
  'rankings': [
    TutorialStep(
      title: 'Filtros de Período',
      description:
          'Filtre o ranking por período: mês, 30 dias, 60 dias ou período personalizado.',
      targetKey: TutorialKeys.rankingsFilters,
      position: TooltipPosition.below,
    ),
  ],
  'f1results': [
    TutorialStep(
      title: 'Resultados Oficiais',
      description:
          'Consulte resultados oficiais de qualquer temporada. Use as tabs para ver GPs, Pilotos ou Construtores.',
      targetKey: TutorialKeys.f1Tabs,
      position: TooltipPosition.below,
    ),
  ],
  'profile': [
    TutorialStep(
      title: 'Editar Perfil',
      description:
          'Personalize seu perfil com foto, bio e localização para seus amigos te encontrarem.',
      targetKey: TutorialKeys.profileEdit,
      position: TooltipPosition.below,
    ),
  ],
};
