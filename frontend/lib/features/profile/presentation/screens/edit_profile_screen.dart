import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/config/app_config.dart';
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
  String? _avatarUrl;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;

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
        _avatarUrl = data['avatarUrl'] as String?;
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

  Future<void> _pickAndUploadAvatar() async {
    final messenger = ScaffoldMessenger.of(context);

    // Abre o seletor de arquivo nativo do browser (dart:html)
    final input = html.FileUploadInputElement()..accept = 'image/*';
    html.document.body?.append(input);
    input.click();

    try {
      await input.onChange.first.timeout(const Duration(minutes: 1));
    } catch (_) {
      input.remove();
      return;
    }
    input.remove();

    if (input.files == null || input.files!.isEmpty || !mounted) return;

    setState(() => _isUploadingAvatar = true);

    try {
      final file = input.files!.first;

      // Lê como data URL (base64) — funciona em todas as versões do Flutter Web
      final completer = Completer<Uint8List>();
      final reader = html.FileReader();
      reader.onLoad.listen((_) {
        try {
          final dataUrl = reader.result as String;
          final base64Data = dataUrl.split(',').last;
          completer.complete(base64.decode(base64Data));
        } catch (e) {
          completer.completeError('Erro ao decodificar imagem: $e');
        }
      });
      reader.onError.listen((e) {
        completer.completeError('Erro ao ler arquivo: $e');
      });
      reader.readAsDataUrl(file);
      final bytes = await completer.future;

      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) throw Exception('Usuário não autenticado');

      // Determina o Content-Type real do arquivo para o Multer aceitar
      final mimeStr = file.type.isNotEmpty ? file.type : 'image/jpeg';
      final mimeType = MediaType.parse(mimeStr);

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.apiBaseUrl}/auth/me/avatar'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(http.MultipartFile.fromBytes(
        'avatar',
        bytes,
        filename: file.name,
        contentType: mimeType,
      ));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final res = await _api.get('/auth/me');
        if (mounted && res.success && res.data != null) {
          setState(() {
            _avatarUrl = (res.data as Map<String, dynamic>)['avatarUrl'] as String?;
          });
        }
        messenger.showSnackBar(const SnackBar(content: Text('Foto atualizada!')));
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text('Erro no upload (${response.statusCode}): ${response.body}')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
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
                    // Avatar com botão de câmera
                    Center(
                      child: GestureDetector(
                        onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 44,
                              backgroundColor: AppTheme.surfaceColor,
                              backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                                  ? CachedNetworkImageProvider(_avatarUrl!)
                                  : null,
                              child: _isUploadingAvatar
                                  ? const SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppTheme.primaryRed),
                                    )
                                  : (_avatarUrl == null || _avatarUrl!.isEmpty)
                                      ? Text(
                                          _nameController.text.isNotEmpty
                                              ? _nameController.text[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                              fontSize: 36,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryRed),
                                        )
                                      : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: AppTheme.primaryRed,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt,
                                    size: 14, color: Colors.white),
                              ),
                            ),
                          ],
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
