import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/network/api_client.dart';

// ==================
// EVENTOS (o que acontece)
// ==================
abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;
  AuthLoginRequested({required this.email, required this.password});
  @override
  List<Object?> get props => [email, password];
}

class AuthRegisterRequested extends AuthEvent {
  final String email;
  final String password;
  final String displayName;
  final String? country;
  final String? state;
  final String? city;
  AuthRegisterRequested({
    required this.email,
    required this.password,
    required this.displayName,
    this.country,
    this.state,
    this.city,
  });
  @override
  List<Object?> get props => [email, password, displayName, country, state, city];
}

class AuthLogoutRequested extends AuthEvent {}

// ==================
// ESTADOS (como está)
// ==================
abstract class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final User user;
  AuthAuthenticated(this.user);
  @override
  List<Object?> get props => [user.uid];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
  @override
  List<Object?> get props => [message];
}

// ==================
// BLOC (lógica)
// ==================
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final ApiClient _apiClient = ApiClient();

  AuthBloc() : super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheckAuth);
    on<AuthLoginRequested>(_onLogin);
    on<AuthRegisterRequested>(_onRegister);
    on<AuthLogoutRequested>(_onLogout);
  }

  // Verifica se já está logado
  Future<void> _onCheckAuth(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      emit(AuthAuthenticated(user));
    } else {
      emit(AuthUnauthenticated());
    }
  }

  // Faz login
  Future<void> _onLogin(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: event.email,
        password: event.password,
      );
      emit(AuthAuthenticated(credential.user!));
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_getFirebaseErrorMessage(e.code)));
    } catch (e) {
      emit(AuthError('Erro ao fazer login: $e'));
    }
  }

  // Registra novo usuário
  Future<void> _onRegister(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      // 1. Cria conta no Firebase
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: event.email,
        password: event.password,
      );

      // 2. Atualiza nome no Firebase
      await credential.user!.updateDisplayName(event.displayName);

      // 3. Registra no backend (banco de dados)
      await _apiClient.post('/auth/register', body: {
        'firebaseUid': credential.user!.uid,
        'email': event.email,
        'displayName': event.displayName,
        if (event.country != null) 'country': event.country,
        if (event.state != null) 'state': event.state,
        if (event.city != null) 'city': event.city,
      });

      emit(AuthAuthenticated(credential.user!));
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_getFirebaseErrorMessage(e.code)));
    } catch (e) {
      emit(AuthError('Erro ao criar conta: $e'));
    }
  }

  // Faz logout
  Future<void> _onLogout(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _firebaseAuth.signOut();
    emit(AuthUnauthenticated());
  }

  // Converte erros do Firebase para mensagens em português
  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Nenhum usuário encontrado com este email';
      case 'wrong-password':
        return 'Senha incorreta';
      case 'email-already-in-use':
        return 'Este email já está em uso';
      case 'weak-password':
        return 'A senha deve ter pelo menos 6 caracteres';
      case 'invalid-email':
        return 'Email inválido';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente mais tarde';
      case 'invalid-credential':
        return 'Email ou senha incorretos';
      default:
        return 'Erro de autenticação: $code';
    }
  }
}
