import '../l10n/app_localizations.dart';

class FailureReasonLocalizer {
  static String localized(AppLocalizations t, String reasonKey) {
    final parts = _parse(reasonKey);
    final type = parts.type;
    final code = parts.code;
    final displayCode = code ?? '?';

    switch (type) {
      case 'unknown':
        return t.logFailureReasonUnknown;
      case 'auth':
        return t.logFailureReasonAuth(displayCode);
      case 'not_found':
        return t.logFailureReasonNotFound(displayCode);
      case 'range':
        return code == null
            ? t.logFailureReasonRange
            : t.logFailureReasonRangeWithCode(displayCode);
      case 'rate_limit':
        return t.logFailureReasonTooManyRequests(displayCode);
      case 'server':
        return t.logFailureReasonServerError(displayCode);
      case 'http':
        return t.logFailureReasonHttpError(displayCode);
      case 'timeout':
        return t.logFailureReasonTimeout;
      case 'connection':
        return t.logFailureReasonConnection;
      case 'dns':
        return t.logFailureReasonDns;
      case 'ssl':
        return t.logFailureReasonSsl;
      case 'checksum':
        return t.logFailureReasonChecksum;
      case 'disk':
        return t.logFailureReasonDisk;
      case 'other':
        return t.logFailureReasonOther;
      default:
        return reasonKey;
    }
  }

  static String? suggestion(AppLocalizations t, String reasonKey) {
    final parts = _parse(reasonKey);
    switch (parts.type) {
      case 'auth':
        return t.downloadFailureHintAuth;
      case 'not_found':
        return t.downloadFailureHintNotFound;
      case 'range':
        return t.downloadFailureHintRange;
      case 'rate_limit':
        return t.downloadFailureHintRateLimit;
      case 'server':
        return t.downloadFailureHintServer;
      case 'http':
        return t.downloadFailureHintHttp;
      case 'timeout':
        return t.downloadFailureHintTimeout;
      case 'connection':
        return t.downloadFailureHintConnection;
      case 'dns':
        return t.downloadFailureHintDns;
      case 'ssl':
        return t.downloadFailureHintSsl;
      case 'checksum':
        return t.downloadFailureHintChecksum;
      case 'disk':
        return t.downloadFailureHintDisk;
      default:
        return null;
    }
  }

  static int? parseCode(String reasonKey) => _parse(reasonKey).code;

  static _ReasonParts _parse(String reasonKey) {
    final parts = reasonKey.split(':');
    final type = parts.isNotEmpty && parts.first.isNotEmpty
        ? parts.first
        : 'unknown';
    final code = parts.length > 1 ? int.tryParse(parts[1]) : null;
    return _ReasonParts(type, code);
  }
}

class _ReasonParts {
  final String type;
  final int? code;

  const _ReasonParts(this.type, this.code);
}
