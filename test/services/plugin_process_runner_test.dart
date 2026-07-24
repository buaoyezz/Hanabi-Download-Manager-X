import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_manager_x/models/plugin_manifest.dart';
import 'package:hanabi_download_manager_x/services/plugin_process_runner.dart';
import 'package:path/path.dart' as path;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late InstalledPlugin plugin;
  late PluginProcessRunner runner;

  setUp(() async {
    tempDirectory =
        await Directory.systemTemp.createTemp('hanabi_plugin_test_');
    final entry = File(path.join(tempDirectory.path, 'main.ps1'));
    await entry.writeAsString(_pluginFixture);
    plugin = InstalledPlugin(
      manifest: PluginManifest(
        id: 'hanabi.example.runner',
        name: 'Runner fixture',
        version: '1.0.0',
        author: 'Hanabi',
        entry: 'main.ps1',
        capabilities: const ['download:custom'],
        runtime: PluginRuntimeConfig(
          executable: 'powershell',
          arguments: const [
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            '{entry}',
          ],
          environment: const {'FIXTURE_VALUE': 'from-manifest'},
          timeoutSeconds: 10,
        ),
      ),
      directory: tempDirectory.path,
      state: PluginInstallState.enabled,
      enabled: true,
    );
    runner = PluginProcessRunner(
      logDirectoryResolver: (_) => path.join(tempDirectory.path, 'logs'),
      dataDirectoryResolver: (_) => path.join(tempDirectory.path, 'data'),
    );
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('passes host context, reserved environment and plugin parameters',
      () async {
    final result = await runner.invoke(
      plugin,
      method: 'fixture.inspect',
      params: const {'value': 42},
    );

    expect(result.success, isTrue, reason: result.error);
    final payload = Map<String, dynamic>.from(result.result! as Map);
    expect(payload['params'], {'value': 42});
    expect(payload['apiVersion'], '1.0');
    expect(payload['pluginId'], plugin.id);
    expect(payload['requestMethod'], 'fixture.inspect');
    expect(payload['fixtureValue'], 'from-manifest');
    expect(Directory(payload['dataDir'] as String).existsSync(), isTrue);
    expect(
        File(path.join(tempDirectory.path, 'logs', 'runtime.log')).existsSync(),
        isTrue);
  });

  test('preserves JSON-RPC error code and data', () async {
    final result = await runner.invoke(
      plugin,
      method: 'fixture.fail',
      params: const {},
    );

    expect(result.success, isFalse);
    expect(result.error, 'Fixture failure');
    expect(result.errorCode, -32042);
    expect(result.errorData, {'retryable': false});
  });

  test('rejects responses containing both result and error', () async {
    final result = await runner.invoke(
      plugin,
      method: 'fixture.invalid',
      params: const {},
    );

    expect(result.success, isFalse);
    expect(result.error, contains('exactly one of result or error'));
  });
}

const _pluginFixture = r'''
$request = [Console]::In.ReadToEnd() | ConvertFrom-Json
if ($request.method -eq 'fixture.fail') {
    $response = [ordered]@{
        jsonrpc = '2.0'
        id = $request.id
        error = [ordered]@{
            code = -32042
            message = 'Fixture failure'
            data = [ordered]@{ retryable = $false }
        }
    }
} elseif ($request.method -eq 'fixture.invalid') {
    $response = [ordered]@{
        jsonrpc = '2.0'
        id = $request.id
        result = [ordered]@{ ok = $true }
        error = [ordered]@{ code = -32000; message = 'invalid' }
    }
} else {
    $response = [ordered]@{
        jsonrpc = '2.0'
        id = $request.id
        result = [ordered]@{
            params = $request.params
            apiVersion = $request.meta.apiVersion
            pluginId = $env:HANABI_PLUGIN_ID
            requestMethod = $env:HANABI_REQUEST_METHOD
            fixtureValue = $env:FIXTURE_VALUE
            dataDir = $env:HANABI_PLUGIN_DATA_DIR
        }
    }
}
$response | ConvertTo-Json -Depth 10 -Compress
''';
