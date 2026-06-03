import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr_reader/core/settings/settings_keys.dart';
const _kPortKey = SettingsKeys.wifiTransferPort;
@singleton
class WifiTransferService {
  final SharedPreferences _prefs;
  String _htmlContent = '';
  HttpServer? _server;
  bool _running = false;
  int _port = 0;
  String _localIp = '';
  final _logController = StreamController<TransferLogEntry>.broadcast();
  final _statusController = StreamController<bool>.broadcast();
  final _supportedExtensions = {'txt', 'epub', 'pdf', 'md', 'markdown'};

  WifiTransferService(this._prefs);
  int get port => _port;
  bool get isRunning => _running;
  String get localIp => _localIp;
  String get url => _running ? 'http://$_localIp:$_port' : '';
  Stream<TransferLogEntry> get logStream => _logController.stream;
  Stream<bool> get statusStream => _statusController.stream;

  void _log(String message, {bool isError = false, String? fileName}) {
    _logController.add(
      TransferLogEntry(
        message: message,
        isError: isError,
        fileName: fileName,
        time: DateTime.now(),
      ),
    );
  }

  Future<void> start() async {
    if (_running) return;

    try {
      _localIp = await _findLocalIp();
      if (_localIp.isEmpty) {
        _log('无法获取本地 IP 地址', isError: true);
        return;
      }

      _port = await _findAvailablePort();
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, _port);
      _running = true;
      _statusController.add(true);

      await _prefs.setInt(_kPortKey, _port);

      _htmlContent = await rootBundle.loadString('assets/html/wifi_upload_page.html');
      _log('服务器已启动: http://$_localIp:$_port');

      await for (final request in _server!) {
        _handleRequest(request);
      }
    } catch (e) {
      _running = false;
      _statusController.add(false);
      _log('启动失败: $e', isError: true);
    }
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _statusController.add(false);
    await _server?.close(force: true);
    _server = null;
    _log('服务器已停止');
  }

  Future<String> _findLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      Logging.error('获取本机 IP 失败', exception: e);
    }
    return '127.0.0.1';
  }

  Future<int> _findAvailablePort() async {
    for (int i = 0; i < 10; i++) {
      try {
        final port = await _tryBind(0);
        return port;
      } catch (e) {
        Logging.error('端口绑定失败，重试', exception: e);
      }
    }
    return 8080;
  }

  Future<int> _tryBind(int port) async {
    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      port == 0 ? 0 : port,
      shared: false,
    );
    final actual = server.port;
    await server.close();
    return actual;
  }

  void _handleRequest(HttpRequest request) {
    final path = request.uri.path;

    try {
      if (request.method == 'GET' && path == '/') {
        _servePage(request);
      } else if (request.method == 'POST' && path == '/upload') {
        _handleUpload(request);
      } else if (request.method == 'GET' && path == '/api/status') {
        _serveJson(request, {'status': 'ok', 'files': 0});
      } else {
        request.response.statusCode = 404;
        request.response.write('Not Found');
        request.response.close();
      }
    } catch (e) {
      _log('请求处理错误: $e', isError: true);
      try {
        request.response.statusCode = 500;
        request.response.write('Internal Server Error');
        request.response.close();
      } catch (e) {
        Logging.error('发送错误响应失败', exception: e);
      }
    }
  }

  void _servePage(HttpRequest request) {
    request.response.headers.contentType = ContentType.html;
    request.response.write(_htmlContent);
    request.response.close();
  }

  void _serveJson(HttpRequest request, Map<String, dynamic> data) {
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(data));
    request.response.close();
  }

  Future<void> _handleUpload(HttpRequest request) async {
    try {
      final contentType = request.headers.contentType?.toString() ?? '';
      final boundaryStart = contentType.indexOf('boundary=');
      if (boundaryStart == -1) {
        _serveJson(request, {'error': 'Invalid multipart request'});
        return;
      }
      final boundary = contentType.substring(boundaryStart + 9).trim();
      final delimiter = '--$boundary';
      final endDelimiter = '--$boundary--';

      final bytes = await request.fold<List<int>>(
        <int>[],
        (prev, chunk) => prev..addAll(chunk),
      );
      final body = String.fromCharCodes(bytes);
      final parts = body.split(delimiter);

      String? fileName;
      List<int>? fileBytes;

      for (final part in parts) {
        if (part.trim().isEmpty || part.contains(endDelimiter)) continue;
        final headerEnd = part.indexOf('\r\n\r\n');
        if (headerEnd == -1) continue;

        final headerBlock = part.substring(0, headerEnd);
        final contentStart = headerEnd + 4;
        var contentBlock = part.substring(contentStart);
        if (contentBlock.endsWith('\r\n')) {
          contentBlock = contentBlock.substring(0, contentBlock.length - 2);
        }
        if (contentBlock.endsWith('\n')) {
          contentBlock = contentBlock.substring(0, contentBlock.length - 1);
        }

        if (headerBlock.contains('filename=')) {
          final nameMatch = RegExp(
            r'''filename\s*=\s*"?(.+?)"?(\s*|$)''',
            caseSensitive: false,
          ).firstMatch(headerBlock);
          if (nameMatch != null) {
            fileName = nameMatch.group(1)?.trim();
          }
          fileBytes = contentBlock.codeUnits;
        }
      }

      if (fileName == null || fileBytes == null || fileBytes.isEmpty) {
        _serveJson(request, {'error': 'No file received'});
        return;
      }

      final ext = p.extension(fileName).toLowerCase().replaceFirst('.', '');
      if (!_supportedExtensions.contains(ext)) {
        _serveJson(request, {
          'error': 'Unsupported format: .$ext (supported: txt, epub, pdf, md)',
        });
        return;
      }

      final tempDir = Directory.systemTemp;
      final savePath = p.join(tempDir.path, 'zephyr_upload_$fileName');
      await File(savePath).writeAsBytes(fileBytes);

      _log(
        '已接收: $fileName (${_formatSize(fileBytes.length)})',
        fileName: fileName,
      );

      _serveJson(request, {
        'status': 'ok',
        'fileName': fileName,
        'size': fileBytes.length,
        'message': '文件已接收，正在导入…',
      });
    } catch (e) {
      _log('上传失败: $e', isError: true);
      try {
        _serveJson(request, {'error': 'Upload failed: $e'});
      } catch (e) {
        Logging.error('发送上传错误响应失败', exception: e);
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void dispose() {
    stop();
    _logController.close();
    _statusController.close();
  }
}

class TransferLogEntry {
  final String message;
  final bool isError;
  final String? fileName;
  final DateTime time;

  const TransferLogEntry({
    required this.message,
    this.isError = false,
    this.fileName,
    required this.time,
  });

  String get formattedTime {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }
}
