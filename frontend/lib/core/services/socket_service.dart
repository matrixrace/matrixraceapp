import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_config.dart';
import '../network/api_client.dart';

/// Evento de digitação
class TypingEvent {
  final String userId;
  final String conversationType; // 'private' | 'group'
  final String? groupId;
  final bool isTyping;

  TypingEvent({
    required this.userId,
    required this.conversationType,
    this.groupId,
    required this.isTyping,
  });
}

/// Evento de confirmação de leitura
class ReadReceiptEvent {
  final List<String> messageIds;
  final String readBy;
  final String readAt;

  ReadReceiptEvent({
    required this.messageIds,
    required this.readBy,
    required this.readAt,
  });
}

/// Serviço centralizado de Socket.io — Singleton
/// Uma única conexão para todo o app
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  String? _myUserId; // UUID do banco (não o Firebase UID)
  bool _isConnected = false;

  // Streams
  final _newMessageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _newGroupMessageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _messageSentController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _onlineUsersController = StreamController<Set<String>>.broadcast();
  final _typingController = StreamController<TypingEvent>.broadcast();
  final _readReceiptController = StreamController<ReadReceiptEvent>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _sessionResultsController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _raceFinalizedController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get newMessageStream =>
      _newMessageController.stream;
  Stream<Map<String, dynamic>> get newGroupMessageStream =>
      _newGroupMessageController.stream;
  Stream<Map<String, dynamic>> get messageSentStream =>
      _messageSentController.stream;
  Stream<Set<String>> get onlineUsersStream => _onlineUsersController.stream;
  Stream<TypingEvent> get typingStream => _typingController.stream;
  Stream<ReadReceiptEvent> get readReceiptStream =>
      _readReceiptController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<Map<String, dynamic>> get sessionResultsStream => _sessionResultsController.stream;
  Stream<Map<String, dynamic>> get raceFinalizedStream => _raceFinalizedController.stream;

  final Set<String> _onlineUsers = {};
  Set<String> get onlineUsers => _onlineUsers;

  String? get myUserId => _myUserId;
  bool get isConnected => _isConnected;

  bool isOnline(String userId) => _onlineUsers.contains(userId);

  /// Conecta ao servidor Socket.io
  /// Deve ser chamado após o login do usuário
  Future<void> connect() async {
    if (_socket != null && _isConnected) return;

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;

    // Busca o UUID do banco via API /auth/me
    final api = ApiClient();
    final meRes = await api.get('/auth/me');
    if (meRes.success && meRes.data != null) {
      _myUserId = (meRes.data as Map<String, dynamic>)['id'] as String?;
    }

    if (_myUserId == null) return;

    final token = await firebaseUser.getIdToken();
    final socketUrl = AppConfig.apiBaseUrl.replaceAll('/api/v1', '');

    _socket = io.io(socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'auth': {
        'userId': _myUserId,
        'token': token,
      },
      'autoConnect': true,
      'reconnection': true,
      'reconnectionAttempts': 10,
      'reconnectionDelay': 1000,
    });

    _setupListeners();
  }

  void _setupListeners() {
    _socket!.onConnect((_) {
      _isConnected = true;
      // Pede lista de amigos online
      _socket!.emit('get_online_friends');
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      _onlineUsers.clear();
      _onlineUsersController.add(_onlineUsers);
    });

    _socket!.onReconnect((_) {
      _isConnected = true;
      _socket!.emit('get_online_friends');
    });

    // Online/Offline
    _socket!.on('online_friends', (data) {
      final userIds = (data['userIds'] as List?)
              ?.map((id) => id.toString())
              .toSet() ??
          {};
      _onlineUsers.clear();
      _onlineUsers.addAll(userIds);
      _onlineUsersController.add(_onlineUsers);
    });

    _socket!.on('user_online', (data) {
      final userId = data['userId'] as String?;
      if (userId != null) {
        _onlineUsers.add(userId);
        _onlineUsersController.add(Set.from(_onlineUsers));
      }
    });

    _socket!.on('user_offline', (data) {
      final userId = data['userId'] as String?;
      if (userId != null) {
        _onlineUsers.remove(userId);
        _onlineUsersController.add(Set.from(_onlineUsers));
      }
    });

    // Mensagens privadas
    _socket!.on('new_message', (data) {
      _newMessageController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('message_sent', (data) {
      _messageSentController.add(Map<String, dynamic>.from(data));
    });

    // Mensagens de grupo
    _socket!.on('new_group_message', (data) {
      _newGroupMessageController.add(Map<String, dynamic>.from(data));
    });

    // Typing
    _socket!.on('user_typing', (data) {
      _typingController.add(TypingEvent(
        userId: data['userId'] ?? '',
        conversationType: data['conversationType'] ?? 'private',
        groupId: data['groupId'],
        isTyping: true,
      ));
    });

    _socket!.on('user_stopped_typing', (data) {
      _typingController.add(TypingEvent(
        userId: data['userId'] ?? '',
        conversationType: data['groupId'] != null ? 'group' : 'private',
        groupId: data['groupId'],
        isTyping: false,
      ));
    });

    // Read receipts
    _socket!.on('messages_read', (data) {
      final messageIds = (data['messageIds'] as List?)
              ?.map((id) => id.toString())
              .toList() ??
          [];
      _readReceiptController.add(ReadReceiptEvent(
        messageIds: messageIds,
        readBy: data['readBy'] ?? '',
        readAt: data['readAt'] ?? '',
      ));
    });

    // Live results
    _socket!.on('session_results_updated', (data) {
      _sessionResultsController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('race_finalized', (data) {
      _raceFinalizedController.add(Map<String, dynamic>.from(data));
    });

    // Erros
    _socket!.on('error', (data) {
      final msg = data is Map ? data['message'] ?? 'Erro' : data.toString();
      _errorController.add(msg);
    });
  }

  /// Envia mensagem privada
  void sendMessage({required String receiverId, required String content}) {
    _socket?.emit('send_message', {
      'receiverId': receiverId,
      'content': content,
    });
  }

  /// Envia mensagem em grupo
  void sendGroupMessage({required String groupId, required String content}) {
    _socket?.emit('send_group_message', {
      'groupId': groupId,
      'content': content,
    });
  }

  /// Envia mensagem em liga
  void sendLeagueMessage({required String leagueId, required String content}) {
    _socket?.emit('send_league_message', {
      'leagueId': leagueId,
      'content': content,
    });
  }

  /// Entrar na sala de uma liga
  void joinLeague(String leagueId) {
    _socket?.emit('join_league', {'leagueId': leagueId});
  }

  /// Entrar na sala de um grupo
  void joinGroup(String groupId) {
    _socket?.emit('join_group', {'groupId': groupId});
  }

  /// Indicador de digitando
  Timer? _typingTimer;

  void startTyping({String? receiverId, String? groupId}) {
    _socket?.emit('typing_start', {
      'receiverId': ?receiverId,
      'groupId': ?groupId,
    });

    // Auto-stop após 2s
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      stopTyping(receiverId: receiverId, groupId: groupId);
    });
  }

  void stopTyping({String? receiverId, String? groupId}) {
    _typingTimer?.cancel();
    _socket?.emit('typing_stop', {
      'receiverId': ?receiverId,
      'groupId': ?groupId,
    });
  }

  /// Marca mensagens como lidas
  void markRead(List<String> messageIds, {String? senderId}) {
    if (messageIds.isEmpty) return;
    _socket?.emit('mark_read', {
      'messageIds': messageIds,
      'senderId': ?senderId,
    });
  }

  /// Entra na sala de uma corrida (live updates)
  void joinRace(int raceId) {
    _socket?.emit('join_race', raceId);
  }

  /// Sai da sala de uma corrida
  void leaveRace(int raceId) {
    _socket?.emit('leave_race', raceId);
  }

  /// Desconecta
  void disconnect() {
    _typingTimer?.cancel();
    _socket?.disconnect();
    _socket = null;
    _isConnected = false;
    _onlineUsers.clear();
    _myUserId = null;
  }

  /// Dispose — deve ser chamado quando o app fecha
  void dispose() {
    disconnect();
    _newMessageController.close();
    _newGroupMessageController.close();
    _messageSentController.close();
    _onlineUsersController.close();
    _typingController.close();
    _readReceiptController.close();
    _errorController.close();
    _sessionResultsController.close();
    _raceFinalizedController.close();
  }
}
