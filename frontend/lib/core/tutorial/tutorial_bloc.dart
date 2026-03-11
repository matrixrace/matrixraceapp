import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tutorial_step.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// EVENTOS
// ═══════════════════════════════════════════════════════════════════════════════
abstract class TutorialEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

/// Carrega preferências do SharedPreferences ao iniciar o app
class TutorialInitialize extends TutorialEvent {}

/// Disparado ao entrar em uma tela — inicia tutorial se ainda não foi visto
class TutorialScreenVisited extends TutorialEvent {
  final String screenId;
  TutorialScreenVisited(this.screenId);
  @override
  List<Object?> get props => [screenId];
}

/// Avança para o próximo step
class TutorialNextStep extends TutorialEvent {}

/// Pula/fecha o tutorial da tela atual
class TutorialSkip extends TutorialEvent {}

/// Liga ou desliga tutoriais globalmente (via menu do usuário)
class TutorialToggleEnabled extends TutorialEvent {
  final bool enabled;
  TutorialToggleEnabled(this.enabled);
  @override
  List<Object?> get props => [enabled];
}

/// Marca "Não mostrar mais dicas" — desativa tudo
class TutorialDontShowAgain extends TutorialEvent {}

// ═══════════════════════════════════════════════════════════════════════════════
// ESTADO
// ═══════════════════════════════════════════════════════════════════════════════
class TutorialState extends Equatable {
  final bool initialized;
  final bool tutorialsEnabled;
  final Set<String> visitedScreens;
  final String? activeScreen;
  final int currentStepIndex;
  final bool isShowingOverlay;

  const TutorialState({
    this.initialized = false,
    this.tutorialsEnabled = true,
    this.visitedScreens = const {},
    this.activeScreen,
    this.currentStepIndex = 0,
    this.isShowingOverlay = false,
  });

  TutorialState copyWith({
    bool? initialized,
    bool? tutorialsEnabled,
    Set<String>? visitedScreens,
    String? activeScreen,
    int? currentStepIndex,
    bool? isShowingOverlay,
    bool clearActiveScreen = false,
  }) {
    return TutorialState(
      initialized: initialized ?? this.initialized,
      tutorialsEnabled: tutorialsEnabled ?? this.tutorialsEnabled,
      visitedScreens: visitedScreens ?? this.visitedScreens,
      activeScreen: clearActiveScreen ? null : (activeScreen ?? this.activeScreen),
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      isShowingOverlay: isShowingOverlay ?? this.isShowingOverlay,
    );
  }

  /// Retorna o step atual ou null
  TutorialStep? get currentStep {
    if (activeScreen == null) return null;
    final steps = tutorialStepsMap[activeScreen!];
    if (steps == null || currentStepIndex >= steps.length) return null;
    return steps[currentStepIndex];
  }

  /// Total de steps da tela ativa
  int get totalSteps => tutorialStepsMap[activeScreen]?.length ?? 0;

  @override
  List<Object?> get props => [
        initialized,
        tutorialsEnabled,
        visitedScreens,
        activeScreen,
        currentStepIndex,
        isShowingOverlay,
      ];
}

// ═══════════════════════════════════════════════════════════════════════════════
// BLOC
// ═══════════════════════════════════════════════════════════════════════════════
class TutorialBloc extends Bloc<TutorialEvent, TutorialState> {
  TutorialBloc() : super(const TutorialState()) {
    on<TutorialInitialize>(_onInitialize);
    on<TutorialScreenVisited>(_onScreenVisited);
    on<TutorialNextStep>(_onNextStep);
    on<TutorialSkip>(_onSkip);
    on<TutorialToggleEnabled>(_onToggleEnabled);
    on<TutorialDontShowAgain>(_onDontShowAgain);
  }

  // ── SharedPreferences keys ───────────────────────────────────────────────
  static const _keyEnabled = 'tutorial_enabled';
  static const _keyVisited = 'tutorial_visited';
  static const keyWelcomeShown = 'tutorial_welcome_shown';

  // ── Handlers ─────────────────────────────────────────────────────────────

  Future<void> _onInitialize(
    TutorialInitialize event,
    Emitter<TutorialState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_keyEnabled) ?? true;
    final visitedJson = prefs.getString(_keyVisited);
    final visited = visitedJson != null
        ? Set<String>.from(jsonDecode(visitedJson) as List)
        : <String>{};

    emit(state.copyWith(
      initialized: true,
      tutorialsEnabled: enabled,
      visitedScreens: visited,
    ));
  }

  Future<void> _onScreenVisited(
    TutorialScreenVisited event,
    Emitter<TutorialState> emit,
  ) async {
    if (!state.initialized || !state.tutorialsEnabled) return;
    if (state.visitedScreens.contains(event.screenId)) return;
    if (state.isShowingOverlay) return; // já tem um tutorial aberto

    final steps = tutorialStepsMap[event.screenId];
    if (steps == null || steps.isEmpty) return;

    emit(state.copyWith(
      activeScreen: event.screenId,
      currentStepIndex: 0,
      isShowingOverlay: true,
    ));
  }

  Future<void> _onNextStep(
    TutorialNextStep event,
    Emitter<TutorialState> emit,
  ) async {
    if (!state.isShowingOverlay || state.activeScreen == null) return;

    final nextIndex = state.currentStepIndex + 1;
    if (nextIndex < state.totalSteps) {
      emit(state.copyWith(currentStepIndex: nextIndex));
    } else {
      // Último step — marca tela como visitada
      await _markScreenVisited(emit);
    }
  }

  Future<void> _onSkip(
    TutorialSkip event,
    Emitter<TutorialState> emit,
  ) async {
    await _markScreenVisited(emit);
  }

  Future<void> _onToggleEnabled(
    TutorialToggleEnabled event,
    Emitter<TutorialState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, event.enabled);

    if (event.enabled) {
      // Ao reativar, limpa visited para rodar de novo
      await prefs.remove(_keyVisited);
      emit(state.copyWith(
        tutorialsEnabled: true,
        visitedScreens: <String>{},
        isShowingOverlay: false,
        clearActiveScreen: true,
        currentStepIndex: 0,
      ));
    } else {
      emit(state.copyWith(
        tutorialsEnabled: false,
        isShowingOverlay: false,
        clearActiveScreen: true,
        currentStepIndex: 0,
      ));
    }
  }

  Future<void> _onDontShowAgain(
    TutorialDontShowAgain event,
    Emitter<TutorialState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, false);
    emit(state.copyWith(
      tutorialsEnabled: false,
      isShowingOverlay: false,
      clearActiveScreen: true,
      currentStepIndex: 0,
    ));
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<void> _markScreenVisited(Emitter<TutorialState> emit) async {
    final screen = state.activeScreen;
    if (screen == null) return;

    final visited = {...state.visitedScreens, screen};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyVisited, jsonEncode(visited.toList()));

    emit(state.copyWith(
      visitedScreens: visited,
      isShowingOverlay: false,
      clearActiveScreen: true,
      currentStepIndex: 0,
    ));
  }
}
