import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';

import '../models/plugin_store_models.dart';

class PluginSignatureVerifier {
  const PluginSignatureVerifier();

  Future<String> computeSha256(File file) async {
    return sha256.convert(await file.readAsBytes()).toString();
  }

  Future<String> verifyHashIfPresent(File file, String expectedHash) async {
    final actual = await computeSha256(file);
    final normalized = _normalizeHash(expectedHash);
    if (normalized == null) {
      return actual;
    }
    if (actual.toLowerCase() != normalized.toLowerCase()) {
      throw StateError('Plugin package hash mismatch');
    }
    return actual;
  }

  Future<void> verifyStoreEntrySignature({
    required File file,
    required PluginStoreEntry entry,
    required PluginStoreIndex index,
    String? packageSha256,
  }) async {
    if (!entry.hasSignature) {
      return;
    }

    final signingKey = index.findSigningKey(entry.signingKeyId);
    if (signingKey == null || !signingKey.isUsable) {
      throw StateError(
        'Plugin signature key not found: ${entry.signingKeyId ?? '(missing)'}',
      );
    }

    final payload = buildStoreSignaturePayload(
      entry,
      packageSha256 ?? await computeSha256(file),
    );
    final algorithm = signingKey.algorithm.trim().toLowerCase();

    switch (algorithm) {
      case 'ed25519':
        await _verifyEd25519(
          payload: payload,
          signatureValue: entry.signature,
          publicKeyValue: signingKey.publicKey,
        );
        return;
      default:
        throw StateError(
          'Unsupported plugin signature algorithm: ${signingKey.algorithm}',
        );
    }
  }

  String buildStoreSignaturePayload(
    PluginStoreEntry entry,
    String packageSha256,
  ) {
    final buffer = StringBuffer()
      ..writeln('hanabi-plugin-store-signature-v1')
      ..writeln('id=${entry.id}')
      ..writeln('version=${entry.version}')
      ..writeln('sha256=${packageSha256.toLowerCase()}');

    final minAppVersion = entry.minAppVersion?.trim();
    if (minAppVersion != null && minAppVersion.isNotEmpty) {
      buffer.writeln('minAppVersion=$minAppVersion');
    }

    return buffer.toString();
  }

  Future<void> _verifyEd25519({
    required String payload,
    required String signatureValue,
    required String publicKeyValue,
  }) async {
    final signatureBytes = _decodeBinary(
      signatureValue,
      fieldName: 'plugin signature',
    );
    final publicKeyBytes = _decodeBinary(
      publicKeyValue,
      fieldName: 'plugin public key',
    );
    final verified = await Ed25519().verify(
      utf8.encode(payload),
      signature: Signature(
        signatureBytes,
        publicKey: SimplePublicKey(
          publicKeyBytes,
          type: KeyPairType.ed25519,
        ),
      ),
    );
    if (!verified) {
      throw StateError('Plugin signature verification failed');
    }
  }

  List<int> _decodeBinary(
    String value, {
    required String fieldName,
  }) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw StateError('$fieldName is empty');
    }

    final raw = trimmed
        .replaceAll(RegExp(r'-----BEGIN [^-]+-----'), '')
        .replaceAll(RegExp(r'-----END [^-]+-----'), '')
        .replaceAll(RegExp(r'\s+'), '');

    if (raw.startsWith('base64:')) {
      return _decodeBase64(raw.substring('base64:'.length), fieldName);
    }
    if (raw.startsWith('hex:')) {
      return _decodeHex(raw.substring('hex:'.length), fieldName);
    }
    if (_looksLikeHex(raw)) {
      return _decodeHex(raw, fieldName);
    }
    return _decodeBase64(raw, fieldName);
  }

  List<int> _decodeBase64(String value, String fieldName) {
    try {
      return base64Decode(value);
    } catch (_) {
      throw StateError('$fieldName is not valid base64');
    }
  }

  List<int> _decodeHex(String value, String fieldName) {
    final normalized = value.trim();
    if (!_looksLikeHex(normalized)) {
      throw StateError('$fieldName is not valid hex');
    }
    final result = <int>[];
    for (var i = 0; i < normalized.length; i += 2) {
      result.add(int.parse(normalized.substring(i, i + 2), radix: 16));
    }
    return result;
  }

  bool _looksLikeHex(String value) {
    return value.length.isEven && RegExp(r'^[0-9a-fA-F]+$').hasMatch(value);
  }

  String? _normalizeHash(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (trimmed.startsWith('sha256:')) {
      return trimmed.substring('sha256:'.length).trim();
    }
    return trimmed;
  }
}
