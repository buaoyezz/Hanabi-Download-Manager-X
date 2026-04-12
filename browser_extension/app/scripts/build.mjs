import { readFileSync, rmSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const currentDir = path.dirname(fileURLToPath(import.meta.url));
const appDir = path.resolve(currentDir, '..');
const bundlesDir = path.resolve(appDir, '..');
const packageJsonPath = path.join(appDir, 'package.json');
const wxtCliPath = path.join(appDir, 'node_modules', 'wxt', 'bin', 'wxt.mjs');
const packageJson = JSON.parse(readFileSync(packageJsonPath, 'utf8'));
const extensionVersion = String(packageJson.version ?? '0.0.0');

const targetDefinitions = {
  chrome: {
    browser: 'chrome',
    outputDir: 'chrome_extension',
    label: 'Chrome / Edge',
  },
  firefox: {
    browser: 'firefox',
    outputDir: 'firefox_extension',
    label: 'Firefox',
  },
};

const requestedTarget = process.argv[2] ?? 'all';

if (requestedTarget !== 'all' && !(requestedTarget in targetDefinitions)) {
  console.error(
    `Unknown browser target "${requestedTarget}". Use chrome, firefox, or all.`,
  );
  process.exit(1);
}

const targets =
  requestedTarget === 'all'
    ? ['chrome', 'firefox']
    : [requestedTarget];

for (const target of targets) {
  const definition = targetDefinitions[target];
  const bundlePath = path.join(bundlesDir, definition.outputDir);

  rmSync(bundlePath, { recursive: true, force: true });

  console.log(
    `[build] ${definition.label} -> ${definition.outputDir} (v${extensionVersion})`,
  );

  const result = spawnSync(
    process.execPath,
    [wxtCliPath, 'build', '-b', definition.browser, '--mv3'],
    {
      cwd: appDir,
      stdio: 'inherit',
    },
  );

  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}

console.log(
  `[build] complete -> ${targets
    .map((target) => targetDefinitions[target].outputDir)
    .join(', ')}`,
);
