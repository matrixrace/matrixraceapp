import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/auth_bloc.dart';

// ── Listas de localização ────────────────────────────────────────────────────

const _kCountries = [
  'Brasil',
  'Alemanha',
  'Argentina',
  'Austrália',
  'Bélgica',
  'Canadá',
  'Chile',
  'China',
  'Colômbia',
  'Espanha',
  'EUA',
  'França',
  'Holanda',
  'Itália',
  'Japão',
  'México',
  'Paraguai',
  'Peru',
  'Portugal',
  'Rússia',
  'Suíça',
  'Uruguai',
  'Outro',
];

const _kBrazilStates = [
  'AC — Acre',
  'AL — Alagoas',
  'AP — Amapá',
  'AM — Amazonas',
  'BA — Bahia',
  'CE — Ceará',
  'DF — Distrito Federal',
  'ES — Espírito Santo',
  'GO — Goiás',
  'MA — Maranhão',
  'MT — Mato Grosso',
  'MS — Mato Grosso do Sul',
  'MG — Minas Gerais',
  'PA — Pará',
  'PB — Paraíba',
  'PR — Paraná',
  'PE — Pernambuco',
  'PI — Piauí',
  'RJ — Rio de Janeiro',
  'RN — Rio Grande do Norte',
  'RS — Rio Grande do Sul',
  'RO — Rondônia',
  'RR — Roraima',
  'SC — Santa Catarina',
  'SP — São Paulo',
  'SE — Sergipe',
  'TO — Tocantins',
];

// ── Tela de Cadastro ─────────────────────────────────────────────────────────

/// Tela de Cadastro
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateTextController = TextEditingController();

  bool _obscurePassword = true;
  String? _selectedCountry;
  String? _selectedState; // só usado quando país == Brasil

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _cityController.dispose();
    _stateTextController.dispose();
    super.dispose();
  }

  void _onRegister() {
    if (_formKey.currentState!.validate()) {
      final stateValue = _selectedCountry == 'Brasil'
          ? _selectedState
          : _stateTextController.text.trim().isEmpty
              ? null
              : _stateTextController.text.trim();

      context.read<AuthBloc>().add(AuthRegisterRequested(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            displayName: _nameController.text.trim(),
            country: _selectedCountry,
            state: stateValue,
            city: _cityController.text.trim().isEmpty
                ? null
                : _cityController.text.trim(),
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            context.go('/');
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Criar Conta',
                        style: Theme.of(context).textTheme.headlineLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cadastre-se para fazer seus palpites',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // Nome
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome',
                          prefixIcon: Icon(Icons.person_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Digite seu nome';
                          }
                          if (value.length < 2) {
                            return 'Nome deve ter pelo menos 2 caracteres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // País
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCountry,
                        decoration: const InputDecoration(
                          labelText: 'País',
                          prefixIcon: Icon(Icons.public_outlined),
                        ),
                        items: _kCountries
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCountry = value;
                            _selectedState = null;
                            _stateTextController.clear();
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Estado
                      if (_selectedCountry == 'Brasil')
                        DropdownButtonFormField<String>(
                          initialValue: _selectedState,
                          decoration: const InputDecoration(
                            labelText: 'Estado',
                            prefixIcon: Icon(Icons.map_outlined),
                          ),
                          items: _kBrazilStates
                              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _selectedState = value),
                        )
                      else if (_selectedCountry != null)
                        TextFormField(
                          controller: _stateTextController,
                          decoration: const InputDecoration(
                            labelText: 'Estado / Província',
                            prefixIcon: Icon(Icons.map_outlined),
                          ),
                        ),
                      if (_selectedCountry != null) const SizedBox(height: 16),

                      // Município
                      if (_selectedCountry != null)
                        TextFormField(
                          controller: _cityController,
                          decoration: const InputDecoration(
                            labelText: 'Município',
                            prefixIcon: Icon(Icons.location_city_outlined),
                          ),
                        ),
                      if (_selectedCountry != null) const SizedBox(height: 16),

                      // Email
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Digite seu email';
                          }
                          if (!value.contains('@')) {
                            return 'Email inválido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Senha
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Digite uma senha';
                          }
                          if (value.length < 6) {
                            return 'Senha deve ter pelo menos 6 caracteres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Confirmar Senha
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirmar Senha',
                          prefixIcon: Icon(Icons.lock_outlined),
                        ),
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return 'As senhas não coincidem';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Botão Cadastrar
                      BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, state) {
                          final isLoading = state is AuthLoading;
                          return ElevatedButton(
                            onPressed: isLoading ? null : _onRegister,
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Criar Conta'),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text(
                          'Já tem conta? Entrar',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
