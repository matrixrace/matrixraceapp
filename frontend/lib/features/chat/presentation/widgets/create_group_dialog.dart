import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

/// Dialog para criar um grupo de chat
class CreateGroupDialog extends StatefulWidget {
  const CreateGroupDialog({super.key});

  /// Mostra o dialog e retorna o grupo criado ou null
  static Future<Map<String, dynamic>?> show(BuildContext context) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const CreateGroupDialog(),
    );
  }

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final _api = ApiClient();
  final _nameController = TextEditingController();

  int _step = 0; // 0 = nome, 1 = selecionar amigos
  List<Map<String, dynamic>> _friends = [];
  final Set<String> _selectedIds = {};
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    final res = await _api.get('/friends');
    if (mounted && res.success && res.data != null) {
      setState(() {
        _friends = (res.data as List)
            .map((f) => Map<String, dynamic>.from(f))
            .toList();
      });
    }
  }

  Future<void> _createGroup() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'Digite o nome do grupo');
      return;
    }
    if (_selectedIds.isEmpty) {
      setState(() => _error = 'Selecione pelo menos um amigo');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final res = await _api.post('/chat-groups', body: {
      'name': _nameController.text.trim(),
      'memberIds': _selectedIds.toList(),
    });

    if (!mounted) return;

    if (res.success && res.data != null) {
      Navigator.of(context).pop(Map<String, dynamic>.from(res.data));
    } else {
      setState(() {
        _isLoading = false;
        _error = res.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.group_add, color: AppTheme.primaryGreen),
                  const SizedBox(width: 10),
                  Text(
                    _step == 0 ? 'Novo grupo' : 'Adicionar amigos',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Step 0: Nome do grupo
              if (_step == 0) ...[
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Nome do grupo',
                    hintText: 'Ex: Amigos da F1',
                  ),
                  onSubmitted: (_) {
                    if (_nameController.text.trim().isNotEmpty) {
                      setState(() => _step = 1);
                    }
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _nameController.text.trim().isEmpty
                        ? null
                        : () => setState(() => _step = 1),
                    child: const Text('Próximo'),
                  ),
                ),
              ],

              // Step 1: Selecionar amigos
              if (_step == 1) ...[
                // Nome do grupo preview
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.group,
                          size: 18, color: AppTheme.primaryGreen),
                      const SizedBox(width: 8),
                      Text(
                        _nameController.text.trim(),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () => setState(() => _step = 0),
                        child: const Icon(Icons.edit,
                            size: 16, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  'Selecione os amigos (${_selectedIds.length} selecionado${_selectedIds.length != 1 ? 's' : ''})',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 8),

                // Lista de amigos com checkboxes
                Expanded(
                  child: _friends.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhum amigo encontrado',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _friends.length,
                          itemBuilder: (context, i) {
                            final friend = _friends[i];
                            final id = friend['id'] as String? ?? '';
                            final name =
                                friend['displayName'] as String? ?? 'Amigo';
                            final avatar = friend['avatarUrl'] as String?;
                            final selected = _selectedIds.contains(id);

                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: AppTheme.surfaceColor,
                                backgroundImage: avatar != null
                                    ? NetworkImage(avatar)
                                    : null,
                                child: avatar == null
                                    ? Text(
                                        name[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: AppTheme.primaryGreen,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                    color: AppTheme.textPrimary),
                              ),
                              trailing: Checkbox(
                                value: selected,
                                activeColor: AppTheme.primaryGreen,
                                onChanged: (_) {
                                  setState(() {
                                    if (selected) {
                                      _selectedIds.remove(id);
                                    } else {
                                      _selectedIds.add(id);
                                    }
                                  });
                                },
                              ),
                              onTap: () {
                                setState(() {
                                  if (selected) {
                                    _selectedIds.remove(id);
                                  } else {
                                    _selectedIds.add(id);
                                  }
                                });
                              },
                            );
                          },
                        ),
                ),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createGroup,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Criar grupo'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
