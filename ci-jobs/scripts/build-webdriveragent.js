const { asyncify } = require('asyncbox');
const { logger, fs } = require('appium-support');
const { exec } = require('teen_process');
const xcode = require('appium-xcode');

const log = new logger.getLogger('WDA Build');

async function buildWebDriverAgent () {
  // Get Xcode version
  const xcodeVersion = await xcode.getVersion();
  log.info(`Building bundle for Xcode version '${xcodeVersion}'`);

  // Clean and build the dependencies
  await exec('npx', ['gulp', 'clean:carthage']);
  log.info('Running ./Scripts/bootstrap.sh');
  await exec('./Scripts/bootstrap.sh', ['-d']);

  // Create a bundle
  await fs.mkdir('bundles');
  const bundleName = `bundles/webdriveragent-xcode_${xcodeVersion}.zip`;
  log.info(`Creating bundle '${bundleName}'`);
  await exec('zip', ['-r', bundleName, '.']);
}

if (require.main === module) {
  asyncify(buildWebDriverAgent);
}

module.exports = buildWebDriverAgent;
