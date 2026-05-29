import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kPortKey = 'wifi_transfer_port';

@LazySingleton()
class WifiTransferService {
  HttpServer? _server;
  bool _running = false;
  int _port = 0;
  String _localIp = '';
  final _logController = StreamController<TransferLogEntry>.broadcast();
  final _statusController = StreamController<bool>.broadcast();
  final _supportedExtensions = {'txt', 'epub', 'pdf', 'md', 'markdown'};

  bool get isRunning => _running;
  int get port => _port;
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

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kPortKey, _port);

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
    request.response.write(_uploadPageHtml);
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

const _uploadPageHtml = '''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Zephyr Reader - WiFi 传书</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;
  background:#1a1c1e;color:#e4e7e7;min-height:100vh;display:flex;flex-direction:column;align-items:center}
.container{max-width:600px;width:100%;padding:40px 20px}
h1{font-size:24px;font-weight:600;margin-bottom:8px;text-align:center}
.sub{color:#9aa0a6;text-align:center;margin-bottom:32px;font-size:14px}
.upload-zone{border:2px dashed #3c4043;border-radius:16px;padding:48px 24px;
  text-align:center;cursor:pointer;transition:all .2s;background:#202124}
.upload-zone:hover,.upload-zone.dragover{border-color:#8ab4f8;background:#282a2d}
.upload-zone .icon{font-size:48px;margin-bottom:16px}
.upload-zone .text{font-size:16px;margin-bottom:8px}
.upload-zone .hint{font-size:13px;color:#9aa0a6}
.upload-zone input{display:none}
.file-list{margin-top:24px}
.file-item{display:flex;align-items:center;justify-content:space-between;
  padding:12px 16px;background:#202124;border-radius:10px;margin-bottom:8px}
.file-item .name{font-size:14px;flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;margin-right:12px}
.file-item .size{font-size:12px;color:#9aa0a6;margin-right:12px}
.status-ok{color:#81c995}
.status-error{color:#f28b82}
.status-uploading{color:#8ab4f8}
.footer{text-align:center;margin-top:32px;font-size:12px;color:#9aa0a6}
</style>
</head>
<body>
<div class="container">
<h1>📤 WiFi 传书</h1>
<p class="sub">将文件拖拽到下方区域，或点击选择文件</p>
<div class="upload-zone" id="dropZone">
  <div class="icon">📂</div>
  <div class="text">拖拽文件到此处</div>
  <div class="hint">支持 TXT、EPUB、PDF、Markdown 格式</div>
  <input type="file" id="fileInput" accept=".txt,.epub,.pdf,.md,.markdown" multiple>
</div>
<div class="file-list" id="fileList"></div>
<div class="footer">Zephyr Reader &middot; 文件仅在本地网络中传输</div>
</div>
<script>
const dropZone=document.getElementById('dropZone');
const fileInput=document.getElementById('fileInput');
const fileList=document.getElementById('fileList');

dropZone.addEventListener('click',()=>fileInput.click());
dropZone.addEventListener('dragover',e=>{e.preventDefault();dropZone.classList.add('dragover')});
dropZone.addEventListener('dragleave',()=>dropZone.classList.remove('dragover'));
dropZone.addEventListener('drop',e=>{e.preventDefault();dropZone.classList.remove('dragover');
  if(e.dataTransfer.files.length) uploadFiles(e.dataTransfer.files)});
fileInput.addEventListener('change',()=>{if(fileInput.files.length) uploadFiles(fileInput.files)});

async function uploadFiles(files){
  for(const file of files){
    addFileItem(file.name,formatSize(file.size),'uploading','上传中…');
    try{
      const form=new FormData();form.append('file',file);
      const res=await fetch('/upload',{method:'POST',body:form});
      const data=await res.json();
      if(data.status==='ok'){
        updateFileItem(file.name,'ok','✓ 已接收');
      }else{
        updateFileItem(file.name,'error','✗ '+(data.error||'上传失败'));
      }
    }catch(e){
      updateFileItem(file.name,'error','✗ 上传失败');
    }
  }
}

function addFileItem(name,size,status,msg){
  const div=document.createElement('div');div.className='file-item';div.id='file-'+name.replace(/[^a-z0-9]/gi,'_');
  div.innerHTML='<span class="name">'+escapeHtml(name)+'</span><span class="size">'+size+'</span><span class="status-'+status+'">'+msg+'</span>';
  fileList.prepend(div);
}
function updateFileItem(name,status,msg){
  const el=document.getElementById('file-'+name.replace(/[^a-z0-9]/gi,'_'));
  if(el){el.querySelector('span:last-child').className='status-'+status;el.querySelector('span:last-child').textContent=msg}
}
function formatSize(b){if(b<1024)return b+'B';if(b<1048576)return(b/1024).toFixed(1)+'KB';return(b/1048576).toFixed(1)+'MB'}
function escapeHtml(s){const d=document.createElement('div');d.appendChild(document.createTextNode(s));return d.innerHTML}
</script>
</body>
</html>
''';
