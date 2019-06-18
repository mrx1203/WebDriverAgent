const buildWebDriverAgent = require('./build-webdriveragent');
const { asyncify } = require('asyncbox');
const { fs, logger } = require('appium-support');
const { exec } = require('teen_process');

const log = new logger.getLogger('WDA Build');

async function buildAndUploadWebDriverAgents () {
  // Get all xcode paths from /Applications/
  const xcodePaths = (await fs.readdir('/Applications/'))
    .filter((file) => file.toLowerCase().startsWith('xcode'));

  for (let xcodePath of xcodePaths) {
    // Build webdriveragent for this xcode version
    log.info(`Running xcode-select for '${xcodePath}'`);
    await exec('sudo', ['xcode-select', '-s', xcodePath]);
    await buildWebDriverAgent();
  }
}

if (require.main === module) {
  asyncify(buildAndUploadWebDriverAgents);
}

module.exports = buildAndUploadWebDriverAgents;
