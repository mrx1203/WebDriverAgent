import _ from 'lodash';
<<<<<<< HEAD
import { getDevices, shutdown, deleteDevice } from 'node-simctl';
=======
import Simctl from 'node-simctl';
>>>>>>> appium
import { retryInterval } from 'asyncbox';
import { killAllSimulators as simKill } from 'appium-ios-simulator';
import { resetTestProcesses } from '../../../lib/utils';


async function killAllSimulators () {
  if (process.env.CLOUD) {
    return;
  }

<<<<<<< HEAD
  const allDevices = _.flatMap(_.values(await getDevices()));
=======
  const simctl = new Simctl();
  const allDevices = _.flatMap(_.values(await simctl.getDevices()));
>>>>>>> appium
  const bootedDevices = allDevices.filter((device) => device.state === 'Booted');

  for (const {udid} of bootedDevices) {
    // It is necessary to stop the corresponding xcodebuild process before killing
    // the simulator, otherwise it will be automatically restarted
    await resetTestProcesses(udid, true);
<<<<<<< HEAD
    await shutdown(udid);
=======
    simctl.udid = udid;
    await simctl.shutdownDevice();
>>>>>>> appium
  }
  await simKill();
}

async function shutdownSimulator (device) {
  // stop XCTest processes if running to avoid unexpected side effects
  await resetTestProcesses(device.udid, true);
  await device.shutdown();
}

async function deleteDeviceWithRetry (udid) {
<<<<<<< HEAD
  try {
    await retryInterval(10, 1000, deleteDevice, udid);
=======
  const simctl = new Simctl({udid});
  try {
    await retryInterval(10, 1000, simctl.deleteDevice.bind(simctl));
>>>>>>> appium
  } catch (ign) {}
}


export { killAllSimulators, shutdownSimulator, deleteDeviceWithRetry };
