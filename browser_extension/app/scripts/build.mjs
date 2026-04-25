import { copyFileSync, existsSync, readFileSync, rmSync } from 'node:fs';
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
    outputZip: 'chrome_extension.zip',
    label: 'Chrome / Edge',
  },
  firefox: {
    browser: 'firefox',
    outputDir: 'firefox_extension',
    outputZip: 'firefox_extension.zip',
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

function runWxtCommand(args) {
  const result = spawnSync(process.execPath, [wxtCliPath, ...args], {
    cwd: appDir,
    stdio: 'inherit',
  });

  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}

for (const target of targets) {
  const definition = targetDefinitions[target];
  const bundlePath = path.join(bundlesDir, definition.outputDir);
  const bundleZipPath = path.join(bundlesDir, definition.outputZip);
  const wxtZipPath = path.join(
    bundlesDir,
    `hanabi-browser-extension-${extensionVersion}-${definition.browser}.zip`,
  );

  rmSync(bundlePath, { recursive: true, force: true });
  rmSync(bundleZipPath, { force: true });

  console.log(
    `[build] ${definition.label} -> ${definition.outputDir} (v${extensionVersion})`,
  );

  runWxtCommand(['build', '-b', definition.browser, '--mv3']);

  console.log(`[package] ${definition.label} -> ${definition.outputZip}`);
  runWxtCommand(['zip', '-b', definition.browser, '--mv3']);

  if (!existsSync(wxtZipPath)) {
    console.error(`Expected packaged archive was not created: ${wxtZipPath}`);
    process.exit(1);
  }

  copyFileSync(wxtZipPath, bundleZipPath);
}

console.log(
  `[build] complete -> ${targets
    .map(
      (target) =>
        `${targetDefinitions[target].outputDir}, ${targetDefinitions[target].outputZip}`,
    )
    .join(', ')}`,
);
