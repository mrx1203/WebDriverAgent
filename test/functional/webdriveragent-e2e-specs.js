import chai from 'chai';
import chaiAsPromised from 'chai-as-promised';
<<<<<<< HEAD
import { createDevice, deleteDevice } from 'node-simctl';
import { getVersion } from 'appium-xcode';
import { getSimulator } from 'appium-ios-simulator';
import { killAllSimulators, shutdownSimulator } from './helpers/simulator';
import request from 'request-promise';
=======
import Simctl from 'node-simctl';
import { getVersion } from 'appium-xcode';
import { getSimulator } from 'appium-ios-simulator';
import { killAllSimulators, shutdownSimulator } from './helpers/simulator';
>>>>>>> appium
import { SubProcess } from 'teen_process';
import { PLATFORM_VERSION, DEVICE_NAME } from './desired';
import { retryInterval } from 'asyncbox';
import { WebDriverAgent } from '../..';
<<<<<<< HEAD
=======
import axios from 'axios';
>>>>>>> appium


const SIM_DEVICE_NAME = 'webDriverAgentTest';

const MOCHA_TIMEOUT = 60 * 1000 * (process.env.CI ? 0 : 4);

chai.should();
chai.use(chaiAsPromised);

let testUrl = 'http://localhost:8100/tree';

function getStartOpts (device) {
  return {
    device,
    platformVersion: PLATFORM_VERSION,
    host: 'localhost',
    port: 8100,
<<<<<<< HEAD
    realDevice: false
=======
    realDevice: false,
    showXcodeLog: true,
    wdaLaunchTimeout: 60 * 3 * 1000,
>>>>>>> appium
  };
}


describe('WebDriverAgent', function () {
  this.timeout(MOCHA_TIMEOUT);

  let xcodeVersion;
  before(async function () {
    // Don't do these tests on Sauce Labs
    if (process.env.CLOUD) {
      this.skip();
    }

    xcodeVersion = await getVersion(true);
  });
  describe('with fresh sim', function () {
    let device;
<<<<<<< HEAD
    before(async function () {
      let simUdid = await createDevice(
=======
    let simctl;

    before(async function () {
      simctl = new Simctl();
      simctl.udid = await simctl.createDevice(
>>>>>>> appium
        SIM_DEVICE_NAME,
        DEVICE_NAME,
        PLATFORM_VERSION
      );
<<<<<<< HEAD
      device = await getSimulator(simUdid);
=======
      device = await getSimulator(simctl.udid);
>>>>>>> appium
    });

    after(async function () {
      this.timeout(MOCHA_TIMEOUT);

      await shutdownSimulator(device);

<<<<<<< HEAD
      await deleteDevice(device.udid);
=======
      await simctl.deleteDevice();
>>>>>>> appium
    });

    describe('with running sim', function () {
      this.timeout(6 * 60 * 1000);
      beforeEach(async function () {
        await killAllSimulators();
        await device.run();
      });
      afterEach(async function () {
        try {
          await retryInterval(5, 1000, async function () {
            await shutdownSimulator(device);
          });
        } catch (ign) {}
      });

      it('should launch agent on a sim', async function () {
        const agent = new WebDriverAgent(xcodeVersion, getStartOpts(device));

        await agent.launch('sessionId');
<<<<<<< HEAD
        await request(testUrl).should.be.eventually.rejectedWith(/unknown command/);
=======
        await axios({url: testUrl}).should.be.eventually.rejected;
>>>>>>> appium
        await agent.quit();
      });

      it('should fail if xcodebuild fails', async function () {
        // short timeout
        this.timeout(35 * 1000);

        const agent = new WebDriverAgent(xcodeVersion, getStartOpts(device));

        agent.xcodebuild.createSubProcess = async function () { // eslint-disable-line require-await
          let args = [
            '-workspace',
            `${this.agentPath}dfgs`,
            // '-scheme',
            // 'XCTUITestRunner',
            // '-destination',
            // `id=${this.device.udid}`,
            // 'test'
          ];
          return new SubProcess('xcodebuild', args, {detached: true});
        };

        await agent.launch('sessionId')
          .should.eventually.be.rejectedWith('xcodebuild failed');

        await agent.quit();
      });
    });
  });
});
