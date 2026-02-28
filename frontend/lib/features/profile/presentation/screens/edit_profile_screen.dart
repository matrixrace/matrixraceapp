import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

// ── Listas de localização (mesmas do register_screen) ───────────────────────

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

// ── Tela de edição ───────────────────────────────────────────────────────────

/// Tela de edição do perfil do usuário
/// Permite alterar nome de exibição, bio e localização
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final ApiClient _api = ApiClient();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateTextController = TextEditingController();

  String? _selectedCountry;
  String? _selectedState;
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    _stateTextController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentProfile() async {
    setState(() => _isLoading = true);
    final res = await _api.get('/auth/me');
    if (mounted && res.success && res.data != null) {
      final data = res.data as Map<String, dynamic>;
      _nameController.text = data['displayName'] ?? '';
      _bioController.text = data['bio'] ?? '';
      _cityController.text = data['city'] ?? '';

      final savedCountry = data['country'] as String?;
      final savedState = data['state'] as String?;

      setState(() {
        _selectedCountry = _kCountries.contains(savedCountry) ? savedCountry : null;

        if (savedCountry == 'Brasil') {
          // Verifica se o estado salvo está na lista de UFs
          _selectedState = _kBrazilStates.contains(savedState) ? savedState : null;
        } else {
          _stateTextController.text = savedState ?? '';
        }
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final stateValue = _selectedCountry == 'Brasil'
        ? _selectedState
        : _stateTextController.text.trim().isEmpty
            ? null
            : _stateTextController.text.trim();

    final res = await _api.put('/auth/me', body: {
      'displayName': _nameController.text.trim(),
      'bio': _bioController.text.trim(),
      'country': _selectedCountry,
      'state': stateValue,
      'city': _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
    });

    if (mounted) {
      setState(() => _isSaving = false);
      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil atualizado com sucesso!')),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar Perfil')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Avatar (apenas visual)
                    Center(
                      child: CircleAvatar(
                        radius: 44,
                        backgroundColor: AppTheme.surfaceColor,
                        child: Text(
                          _nameController.text.isNotEmpty
                              ? _nameController.text[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryRed),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Nome de exibição
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome de exibição',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Informe seu nome';
                        if (v.trim().length < 2) return 'Nome muito curto';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Bio
                    TextFormField(
                      controller: _bioController,
                      decoration: const InputDecoration(
                        labelText: 'Bio (opcional)',
                        prefixIcon: Icon(Icons.info_outline),
                        hintText: 'Conte um pouco sobre você...',
                      ),
                      maxLines: 3,
                      maxLength: 160,
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

                    // Estado (dropdown para Brasil, texto livre para outros)
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
                    TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'Município',
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                    ),
                    const SizedBox(height: 28),

                    ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Text('Salvar'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
