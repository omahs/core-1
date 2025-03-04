import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {verifyContract} from '../../utils/etherscan';
import {getContractAddress} from '../helpers';

function shouldInclude(deployedContracts: any, deployment: any, deployed: any) {
  if (deployment.includes('_Proxy')) {
    return false;
  }

  if (deployed.args[0]) {
    if (
      deployedContracts[`${deployment}_Implementation`] &&
      deployed.args[0] ==
        deployedContracts[`${deployment}_Implementation`].address
    ) {
      return false;
    }
  }

  return true;
}

function delay(ms: number) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  console.log('\nVerifying contracts');

  const {deployments, ethers, run} = hre;

  const minutesDelay = 180000; // 3 minutes - Etherscan needs some time to process before trying to verify.

  console.log(
    `Waiting for ${
      minutesDelay / 60000
    } minutes, so Etherscan is aware of contracts before verifying`
  );

  // await delay(minutesDelay);

  // Prepare verify Array
  // So each verify is fired in a secuence
  // and await results
  const verifyObjArray: {address: string; args: any[any]}[] = [];

  console.log(`Reading deployments for netwrok: ${hre.network.name}`);
  const deployedContracts = await deployments.all();

  for (const deployment in deployedContracts) {
    const deployed = deployedContracts[deployment];

    if (shouldInclude(deployedContracts, deployment, deployed)) {
      verifyObjArray.push({
        address: deployed.address,
        args: deployed.args,
      });
    }
  }

  // Get the bases that are not deployed directly, but deployed via other contracts
  const DAOFactoryContract = await ethers.getContractAt(
    'DAOFactory',
    (
      await deployments.get('DAOFactory')
    ).address
  );
  const daoBase = await DAOFactoryContract.daoBase();
  verifyObjArray.push({address: daoBase, args: []});

  const AddresslistVotingSetupContract = await ethers.getContractAt(
    'AddresslistVotingSetup',
    (
      await deployments.get('AddresslistVotingSetup')
    ).address
  );
  const addresslistVotingBase =
    await AddresslistVotingSetupContract.getImplementationAddress();
  verifyObjArray.push({address: addresslistVotingBase, args: []});

  const TokenVotingSetupContract = await ethers.getContractAt(
    'TokenVotingSetup',
    (
      await deployments.get('TokenVotingSetup')
    ).address
  );
  const tokenVotingBase =
    await TokenVotingSetupContract.getImplementationAddress();
  verifyObjArray.push({address: tokenVotingBase, args: []});

  const governanceERC20Base =
    await TokenVotingSetupContract.governanceERC20Base();
  verifyObjArray.push({
    address: governanceERC20Base,
    args: [ethers.constants.AddressZero, '', ''],
  });

  const governanceWrappedERC20Base =
    await TokenVotingSetupContract.governanceWrappedERC20Base();
  verifyObjArray.push({
    address: governanceWrappedERC20Base,
    args: [ethers.constants.AddressZero, '', ''],
  });

  const PluginRepoFactoryContract = await ethers.getContractAt(
    'PluginRepoFactory',
    (
      await deployments.get('PluginRepoFactory')
    ).address
  );
  const pluginRepoBase = await PluginRepoFactoryContract.pluginRepoBase();
  verifyObjArray.push({address: pluginRepoBase, args: []});

  console.log('Starting to verify now ... .. .');

  for (let index = 0; index < verifyObjArray.length; index++) {
    const element = verifyObjArray[index];

    console.log(
      `Verifying address ${element.address} with constructor argument ${element.args}.`
    );
    await verifyContract(element.address, element.args);

    // Etherscan Max rate limit is 1/5s,
    // use 6s just to be safe.
    console.log(
      `Delaying 6s, so we dont reach Etherscan's Max rate limit of 1/5s.`
    );
    delay(6000);
  }
};
export default func;
func.tags = ['Verify'];
func.runAtTheEnd = true;
func.skip = (hre: HardhatRuntimeEnvironment) =>
  Promise.resolve(
    hre.network.name === 'localhost' ||
      hre.network.name === 'hardhat' ||
      hre.network.name === 'coverage'
  );
