// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/config/app_config.dart';

/// Tela Admin — Gerenciar Pilotos
class AdminDriversScreen extends StatefulWidget {
  const AdminDriversScreen({super.key});

  @override
  State<AdminDriversScreen> createState() => _AdminDriversScreenState();
}

class _AdminDriversScreenState extends State<AdminDriversScreen> {
  final ApiClient _api = ApiClient();
  List<dynamic> _drivers = [];
  List<dynamic> _teams = [];
  bool _loading = true;
  bool _syncing = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _syncDrivers() async {
    final year = DateTime.now().year;
    setState(() => _syncing = true);
    final res = await _api.post('/admin/drivers/sync?year=$year');
    if (mounted) {
      setState(() => _syncing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res.success ? res.message : 'Erro: ${res.message}'),
        backgroundColor: res.success ? AppTheme.successGreen : AppTheme.primaryRed,
      ));
      if (res.success) _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final dRes = await _api.get('/admin/drivers');
    final tRes = await _api.get('/admin/teams');
    if (mounted) {
      setState(() {
        _drivers = (dRes.data as List?) ?? [];
        _teams = (tRes.data as List?) ?? [];
        _loading = false;
      });
    }
  }

  List<dynamic> get _filtered {
    if (_search.isEmpty) return _drivers;
    final q = _search.toLowerCase();
    return _drivers.where((d) {
      final name = '${d['first_name']} ${d['last_name']}'.toLowerCase();
      return name.contains(q) || '${d['number']}'.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pilotos', style: Theme.of(context).textTheme.headlineMedium),
                          Text('${_drivers.length} pilotos cadastrados',
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    if (_syncing)
                      const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      TextButton.icon(
                        onPressed: _syncDrivers,
                        icon: const Icon(Icons.sync, size: 16),
                        label: Text('Sincronizar ${DateTime.now().year}'),
                        style: TextButton.styleFrom(foregroundColor: AppTheme.primaryRed),
                      ),
                    IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: const InputDecoration(
                    hintText: 'Buscar por nome ou número...',
                    prefixIcon: Icon(Icons.search),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: _filtered.map((d) => _buildDriverCard(d)).toList(),
                  ),
                ),
              ),
            ],
          );
  }

  Widget _buildDriverCard(dynamic d) {
    final isActive = d['is_active'] == true;
    final photoUrl = d['photo_url'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.surfaceColor,
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
          child: photoUrl == null
              ? Text(
                  '${d['number'] ?? '?'}',
                  style: const TextStyle(
                      color: AppTheme.primaryRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                )
              : null,
        ),
        title: Text('${d['first_name'] ?? ''} ${d['last_name'] ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(d['team_name'] ?? 'Sem equipe',
            style: const TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.successGreen.withValues(alpha: 0.15)
                    : Colors.grey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isActive ? 'Ativo' : 'Inativo',
                style: TextStyle(
                  color: isActive ? AppTheme.successGreen : Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () => _showEditModal(d),
              tooltip: 'Editar',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditModal(dynamic driver) async {
    final firstCtrl = TextEditingController(text: driver['first_name'] ?? '');
    final lastCtrl = TextEditingController(text: driver['last_name'] ?? '');
    final numCtrl = TextEditingController(text: '${driver['number'] ?? ''}');
    String? selectedTeamId = driver['team_id']?.toString();
    bool isActive = driver['is_active'] == true;
    String? localPhotoUrl = driver['photo_url'] as String?;
    bool uploadingPhoto = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          Future<void> pickAndUpload() async {
            final input = html.FileUploadInputElement()..accept = 'image/*';
            html.document.body?.append(input);
            input.click();

            try {
              await input.onChange.first
                  .timeout(const Duration(minutes: 1));
            } catch (_) {
              input.remove();
              return;
            }
            input.remove();

            if (input.files == null || input.files!.isEmpty) return;

            setDlg(() => uploadingPhoto = true);

            final file = input.files!.first;
            final reader = html.FileReader();
            reader.readAsArrayBuffer(file);
            await reader.onLoad.first;

            final bytes =
                (reader.result as ByteBuffer).asUint8List();
            final token = await FirebaseAuth.instance.currentUser
                ?.getIdToken();

            final uri = Uri.parse(
                '${AppConfig.apiBaseUrl}/admin/drivers/${driver['id']}/photo');
            final request = http.MultipartRequest('POST', uri);
            if (token != null) {
              request.headers['Authorization'] = 'Bearer $token';
            }
            request.files.add(http.MultipartFile.fromBytes(
              'photo',
              bytes,
              filename: file.name,
            ));

            try {
              final streamed = await request.send();
              final response =
                  await http.Response.fromStream(streamed);
              final data =
                  jsonDecode(response.body) as Map<String, dynamic>;

              setDlg(() => uploadingPhoto = false);

              if (data['success'] == true) {
                final newUrl =
                    data['data']?['photoUrl'] as String?;
                if (newUrl != null) {
                  setDlg(() => localPhotoUrl = newUrl);
                  _load();
                }
              }
            } catch (_) {
              setDlg(() => uploadingPhoto = false);
            }
          }

          final initials =
              '${(driver['first_name'] as String? ?? '?')[0]}'
              '${(driver['last_name'] as String? ?? '?')[0]}'
                  .toUpperCase();

          return AlertDialog(
            backgroundColor: AppTheme.cardBackground,
            title: Text(
                'Editar: ${driver['first_name']} ${driver['last_name']}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Foto ────────────────────────────────────
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: AppTheme.surfaceColor,
                          backgroundImage: localPhotoUrl != null
                              ? NetworkImage(localPhotoUrl!)
                              : null,
                          child: localPhotoUrl == null
                              ? Text(
                                  initials,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryRed,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 8),
                        if (uploadingPhoto)
                          const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          )
                        else
                          TextButton.icon(
                            onPressed: pickAndUpload,
                            icon: const Icon(Icons.photo_camera,
                                size: 16),
                            label: const Text('Alterar Foto',
                                style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                                foregroundColor: AppTheme.primaryRed),
                          ),
                      ],
                    ),
                  ),
                  const Divider(),
                  // ── Campos ──────────────────────────────────
                  TextField(
                    controller: firstCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Nome'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: lastCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Sobrenome'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: numCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Número'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedTeamId,
                    decoration:
                        const InputDecoration(labelText: 'Equipe'),
                    dropdownColor: AppTheme.surfaceColor,
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Sem equipe',
                            style: TextStyle(fontSize: 13)),
                      ),
                      ..._teams.map<DropdownMenuItem<String>>((t) {
                        return DropdownMenuItem<String>(
                          value: t['id'].toString(),
                          child: Text(t['name'] ?? '',
                              style:
                                  const TextStyle(fontSize: 13)),
                        );
                      }),
                    ],
                    onChanged: (v) =>
                        setDlg(() => selectedTeamId = v),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Ativo',
                          style: TextStyle(fontSize: 13)),
                      const Spacer(),
                      Switch(
                        value: isActive,
                        activeThumbColor: AppTheme.primaryRed,
                        onChanged: (v) =>
                            setDlg(() => isActive = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final body = <String, dynamic>{
                    'firstName': firstCtrl.text,
                    'lastName': lastCtrl.text,
                    'number':
                        int.tryParse(numCtrl.text) ?? driver['number'],
                    'teamId': selectedTeamId != null
                        ? int.tryParse(selectedTeamId!)
                        : null,
                    'isActive': isActive,
                  };
                  final res = await _api.put(
                      '/admin/drivers/${driver['id']}',
                      body: body);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res.success
                            ? 'Piloto atualizado!'
                            : 'Erro: ${res.message}'),
                        backgroundColor: res.success
                            ? AppTheme.successGreen
                            : AppTheme.primaryRed,
                      ),
                    );
                    if (res.success) _load();
                  }
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );
  }
}
