const path = require('path');
const os = require('os');
const { asyncify } = require('asyncbox');
<<<<<<< HEAD
const { logger, fs, mkdirp } = require('appium-support');
=======
const { logger, fs, mkdirp, zip } = require('appium-support');
>>>>>>> appium
const { exec } = require('teen_process');
const xcode = require('appium-xcode');

const log = new logger.getLogger('WDABuild');
const rootDir = path.resolve(__dirname, '..', '..');

async function buildWebDriverAgent (xcodeVersion) {
  // Get Xcode version
  xcodeVersion = xcodeVersion || await xcode.getVersion();
  log.info(`Building bundle for Xcode version '${xcodeVersion}'`);

<<<<<<< HEAD
=======
  // Clear WebDriverAgent from derived data
  const derivedDataPath = path.resolve(os.homedir(), 'Library', 'Developer',
    'Xcode', 'DerivedData');
  log.info(`Clearing contents of '${derivedDataPath}/WebDriverAgent-*'`);
  for (const wdaPath of
    await fs.glob('WebDriverAgent-*', {cwd: derivedDataPath, absolute: true})
  ) {
    log.info(`Deleting existing WDA: '${wdaPath}'`);
    await fs.rimraf(wdaPath);
  }

>>>>>>> appium
  // Clean and build
  await exec('npx', ['gulp', 'clean:carthage']);
  log.info('Running ./Scripts/build.sh');
  let env = {TARGET: 'runner', SDK: 'sim'};
<<<<<<< HEAD
  await exec('/bin/bash', ['./Scripts/build.sh'], {env, cwd: rootDir});

  // Create bundles folder
  await mkdirp('bundles');
  const pathToBundles = path.resolve(rootDir, 'bundles');

  // Start creating tarball
  const uncompressedDir = path.resolve(rootDir, 'uncompressed');
  await fs.rimraf(uncompressedDir);
  await mkdirp(uncompressedDir);
  log.info('Creating tarball');

  // Move contents of this folder to uncompressed folder
=======
  try {
    await exec('/bin/bash', ['./Scripts/build.sh'], {env, cwd: rootDir});
  } catch (e) {
    log.error(`===FAILED TO BUILD FOR ${xcodeVersion}`);
    log.error(e.stdout);
    log.error(e.stderr);
    log.error(e.message);
    throw e;
  }

  // Create bundles folder
  const pathToBundles = path.resolve(rootDir, 'bundles');
  await mkdirp(pathToBundles);

  // Start creating zip
  const uncompressedDir = path.resolve(rootDir, 'uncompressed');
  await fs.rimraf(uncompressedDir);
  await mkdirp(uncompressedDir);
  log.info('Creating zip');

  // Move contents of the root to folder called "uncompressed"
>>>>>>> appium
  await exec('rsync', [
    '-av', '.', uncompressedDir,
    '--exclude', 'node_modules',
    '--exclude', 'build',
    '--exclude', 'ci-jobs',
    '--exclude', 'lib',
    '--exclude', 'test',
    '--exclude', 'bundles',
<<<<<<< HEAD
  ], {cwd: rootDir});

  // Moved DerivedData/WebDriverAgent-* from Library to uncompressed folder
  const derivedDataPath = path.resolve(os.homedir(), 'Library', 'Developer', 'Xcode', 'DerivedData');
=======
    '--exclude', 'azure-templates',
  ], {cwd: rootDir});

  // Move DerivedData/WebDriverAgent-* from Library to "uncompressed" folder
>>>>>>> appium
  const wdaPath = (await fs.glob(`${derivedDataPath}/WebDriverAgent-*`))[0];
  await mkdirp(path.resolve(uncompressedDir, 'DerivedData'));
  await fs.rename(wdaPath, path.resolve(uncompressedDir, 'DerivedData', 'WebDriverAgent'));

<<<<<<< HEAD
  // Compress the tarball
  const pathToTar = path.resolve(pathToBundles, `webdriveragent-xcode_${xcodeVersion}.tar.gz`);
  env = {COPYFILE_DISABLE: 1};
  await exec('tar', ['-czf', pathToTar, '-C', uncompressedDir, '.'], {env, cwd: rootDir});
  await fs.rimraf(uncompressedDir);
  log.info(`Tarball bundled at "${pathToTar}"`);
=======
  // Compress the "uncompressed" bundle as a Zip
  const pathToZip = path.resolve(pathToBundles, `webdriveragent-xcode_${xcodeVersion}.zip`);
  await zip.toArchive(
    pathToZip, {cwd: path.join(rootDir, 'uncompressed')}
  );
  log.info(`Zip bundled at "${pathToZip}"`);

  // Now just zip the .app and place it in the root directory
  // This zip file will be published to NPM
  const wdaAppBundle = 'WebDriverAgentRunner-Runner.app';
  const appBundlePath = path.join(uncompressedDir, 'DerivedData', 'WebDriverAgent',
    'Build', 'Products', 'Debug-iphonesimulator', wdaAppBundle);
  const appBundleZipPath = path.join(rootDir, `${wdaAppBundle}.zip`);
  await fs.rimraf(appBundleZipPath);
  log.info(`Created './${wdaAppBundle}.zip'`);
  await zip.toArchive(appBundleZipPath, {cwd: appBundlePath});
  log.info(`Zip bundled at "${appBundleZipPath}"`);
  // Clean up the uncompressed directory
  await fs.rimraf(uncompressedDir);
>>>>>>> appium
}

if (require.main === module) {
  asyncify(buildWebDriverAgent);
}

module.exports = buildWebDriverAgent;
