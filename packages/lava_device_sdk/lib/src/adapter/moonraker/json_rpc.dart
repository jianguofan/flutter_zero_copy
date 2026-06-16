import 'dart:convert';
import 'dart:typed_data';

class JsonRpcRequest {
  final int id;
  final String method;
  final Map<String, dynamic>? params;

  const JsonRpcRequest({
    required this.id,
    required this.method,
    this.params,
  });

  String encode() {
    return jsonEncode({
      'jsonrpc': '2.0',
      'method': method,
      'params': params,
      'id': id,
    });
  }
}

class JsonRpcResponse {
  final int id;
  final Map<String, dynamic>? result;
  final Map<String, dynamic>? error;

  const JsonRpcResponse({required this.id, this.result, this.error});

  bool get isError => error != null;

  /// Try to parse a JSON-RPC response from raw bytes.
  /// Returns null if the payload is not a valid JSON-RPC response.
  static JsonRpcResponse? tryParse(Uint8List payload) {
    try {
      final str = utf8.decode(payload);
      final json = jsonDecode(str) as Map<String, dynamic>;
      if (json['jsonrpc'] == '2.0' && json.containsKey('id')) {
        return JsonRpcResponse(
          id: json['id'] as int,
          result: json['result'] as Map<String, dynamic>?,
          error: json['error'] as Map<String, dynamic>?,
        );
      }
    } catch (_) {}
    return null;
  }
}
