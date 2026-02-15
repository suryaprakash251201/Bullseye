import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sshServiceProvider = Provider<SSHService>((ref) {
  return SSHService();
});

/// Represents an active SSH connection session (wraps dartssh2 SSHClient)
class SSHConnectionSession {
  final SSHClient client;
  final String host;
  final int port;
  final String username;
  SSHSession? _shell;

  SSHConnectionSession({
    required this.client,
    required this.host,
    required this.port,
    required this.username,
  });

  SSHSession? get shell => _shell;
  bool get isConnected => !client.isClosed;

  void setShell(SSHSession shell) {
    _shell = shell;
  }

  void close() {
    _shell?.close();
    client.close();
  }
}

/// Production-grade SSH service using dartssh2
class SSHService {
  SSHConnectionSession? _currentSession;

  SSHConnectionSession? get currentSession => _currentSession;
  bool get isConnected => _currentSession?.isConnected ?? false;

  /// Connect to an SSH server with password authentication
  Future<SSHConnectionSession> connectWithPassword({
    required String host,
    required int port,
    required String username,
    required String password,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    await disconnect(); // Close any existing session

    final normalizedHost = host.trim();
    final normalizedUser = username.trim();
    if (normalizedHost.isEmpty) {
      throw SSHServiceException('Host is required');
    }
    if (port < 1 || port > 65535) {
      throw SSHServiceException('Port must be between 1 and 65535');
    }
    if (normalizedUser.isEmpty) {
      throw SSHServiceException('Username is required');
    }
    if (password.isEmpty) {
      throw SSHServiceException('Password is required');
    }

    SSHClient? client;
    try {
      final socket = await SSHSocket.connect(
        normalizedHost,
        port,
        timeout: timeout,
      );

      client = SSHClient(
        socket,
        username: normalizedUser,
        keepAliveInterval: const Duration(seconds: 15),
        onPasswordRequest: () => password,
        onUserInfoRequest: (request) {
          if (request.prompts.isEmpty) {
            return <String>[];
          }
          return request.prompts.map((_) => password).toList();
        },
      );

      await client.authenticated.timeout(
        timeout,
        onTimeout: () => throw SSHServiceException('Authentication timed out'),
      );

      _currentSession = SSHConnectionSession(
        client: client,
        host: normalizedHost,
        port: port,
        username: normalizedUser,
      );

      return _currentSession!;
    } catch (e) {
      client?.close();
      if (e is SSHServiceException) rethrow;
      throw SSHServiceException(_normalizeConnectionError(e));
    }
  }

  /// Connect to an SSH server with private key authentication
  Future<SSHConnectionSession> connectWithKey({
    required String host,
    required int port,
    required String username,
    required String privateKey,
    String? passphrase,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    await disconnect();

    final normalizedHost = host.trim();
    final normalizedUser = username.trim();
    if (normalizedHost.isEmpty) {
      throw SSHServiceException('Host is required');
    }
    if (port < 1 || port > 65535) {
      throw SSHServiceException('Port must be between 1 and 65535');
    }
    if (normalizedUser.isEmpty) {
      throw SSHServiceException('Username is required');
    }
    if (privateKey.trim().isEmpty) {
      throw SSHServiceException('Private key is required');
    }

    SSHClient? client;
    try {
      final socket = await SSHSocket.connect(
        normalizedHost,
        port,
        timeout: timeout,
      );

      final keyPairs = SSHKeyPair.fromPem(privateKey, passphrase);

      client = SSHClient(
        socket,
        username: normalizedUser,
        identities: keyPairs,
        keepAliveInterval: const Duration(seconds: 15),
      );

      await client.authenticated.timeout(
        timeout,
        onTimeout: () => throw SSHServiceException('Authentication timed out'),
      );

      _currentSession = SSHConnectionSession(
        client: client,
        host: normalizedHost,
        port: port,
        username: normalizedUser,
      );

      return _currentSession!;
    } catch (e) {
      client?.close();
      if (e is SSHServiceException) rethrow;
      throw SSHServiceException(_normalizeConnectionError(e));
    }
  }

  /// Execute a single command and return the output
  Future<SSHCommandResult> executeCommand(String command) async {
    if (_currentSession == null || !_currentSession!.isConnected) {
      throw SSHServiceException('Not connected to any server');
    }

    try {
      final result = await _currentSession!.client.run(command);
      final stdout = utf8.decode(result);
      return SSHCommandResult(
        command: command,
        stdout: stdout,
        stderr: '',
        exitCode: 0,
      );
    } catch (e) {
      return SSHCommandResult(
        command: command,
        stdout: '',
        stderr: e.toString(),
        exitCode: -1,
      );
    }
  }

  /// Start an interactive shell session
  Future<SSHSession> startShell({
    SSHPtyConfig pty = const SSHPtyConfig(
      type: 'xterm-256color',
      width: 80,
      height: 40,
    ),
  }) async {
    if (_currentSession == null || !_currentSession!.isConnected) {
      throw SSHServiceException('Not connected to any server');
    }

    final shell = await _currentSession!.client.shell(pty: pty);
    _currentSession!.setShell(shell);
    return shell;
  }

  /// Write data to the interactive shell
  void writeToShell(String data) {
    final shell = _currentSession?.shell;
    if (shell == null) {
      throw SSHServiceException('No active shell session');
    }
    shell.write(Uint8List.fromList(utf8.encode(data)));
  }

  /// Get the shell output stream
  Stream<Uint8List>? get shellOutput {
    return _currentSession?.shell?.stdout;
  }

  /// Get the shell stderr stream
  Stream<Uint8List>? get shellStderr {
    return _currentSession?.shell?.stderr;
  }

  /// Resize the shell terminal
  void resizeShell(int width, int height) {
    _currentSession?.shell?.resizeTerminal(width, height);
  }

  /// Disconnect from the current session
  Future<void> disconnect() async {
    _currentSession?.close();
    _currentSession = null;
  }

  void dispose() {
    disconnect();
  }

  String _normalizeConnectionError(Object error) {
    final message = error.toString();
    final lower = message.toLowerCase();

    if (lower.contains('connection refused')) {
      return 'Connection refused';
    }
    if (lower.contains('timed out')) {
      return 'Connection timed out';
    }
    if (lower.contains('authentication') || lower.contains('auth fail')) {
      return 'Authentication failed';
    }
    if (lower.contains('no route to host') || lower.contains('network is unreachable')) {
      return 'Host unreachable';
    }
    return message;
  }
}

/// Result of executing an SSH command
class SSHCommandResult {
  final String command;
  final String stdout;
  final String stderr;
  final int exitCode;

  SSHCommandResult({
    required this.command,
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });

  bool get isSuccess => exitCode == 0;
  String get output => stdout.isNotEmpty ? stdout : stderr;
}

/// Custom exception for SSH service errors
class SSHServiceException implements Exception {
  final String message;
  SSHServiceException(this.message);

  @override
  String toString() => 'SSHServiceException: $message';
}
