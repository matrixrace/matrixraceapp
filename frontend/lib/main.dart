import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'routes/app_router.dart';
import 'firebase_options.dart';

/// Ponto de entrada do app Matrix Race
void main() async {
  // Usa URL sem # (path strategy) em vez de hash strategy
  // Permite URLs como /admin em vez de /#/admin
  usePathUrlStrategy();

  // Garante que o Flutter está inicializado
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Firebase com as configurações do projeto
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Inicia o app
  runApp(const F1PredictionsApp());
}

class F1PredictionsApp extends StatelessWidget {
  const F1PredictionsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthBloc()..add(AuthCheckRequested()),
      child: MaterialApp.router(
        title: 'Matrix Race',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,

        // Sistema de rotas (navegação)
        routerConfig: AppRouter.router,
      ),
    );
  }
}
