import {expect} from 'chai';
import {ethers} from 'hardhat';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';

import {TestSharedPlugin, TestIdGatingOracle, DAO} from '../../../../typechain';
import {deployNewDAO} from '../../../test-utils/dao';

const ID_GATED_ACTION_PERMISSION_ID = ethers.utils.id(
  'ID_GATED_ACTION_PERMISSION'
);

describe('SharedPlugin', function () {
  let signers: SignerWithAddress[];
  let testPlugin: TestSharedPlugin;
  let managingDao: DAO;
  let dao1: DAO;
  let dao2: DAO;
  let ownerAddress: string;
  let expectedUnauthorizedErrorArguments: string[];

  beforeEach(async () => {
    signers = await ethers.getSigners();
    ownerAddress = await signers[0].getAddress();

    // Deploy the managing DAO and two other DAOs
    const DAO = await ethers.getContractFactory('DAO');
    managingDao = await deployNewDAO(ownerAddress);
    dao1 = await deployNewDAO(ownerAddress);
    dao2 = await deployNewDAO(ownerAddress);

    // Deploy the `TestSharedPlugin`
    const TestSharedPlugin = await ethers.getContractFactory(
      'TestSharedPlugin'
    );
    testPlugin = await TestSharedPlugin.deploy();
    await testPlugin.initialize(managingDao.address);

    expectedUnauthorizedErrorArguments = [
      managingDao.address,
      testPlugin.address,
      testPlugin.address,
      ownerAddress,
      ID_GATED_ACTION_PERMISSION_ID,
    ];
  });

  it('increments IDs', async () => {
    expect(
      await testPlugin.callStatic.createNewObject(dao1.address)
    ).to.be.equal(0);

    const tx = await testPlugin.createNewObject(dao1.address);
    await tx.wait();
    await ethers.provider.send('evm_mine', []);

    expect(
      await testPlugin.callStatic.createNewObject(dao1.address)
    ).to.be.equal(1);
  });

  describe('idGatedAction:', async () => {
    let oracle: TestIdGatingOracle;

    beforeEach(async () => {});
    it('executes if the ID is allowed', async () => {
      const allowedId = 0;

      // Deploy `TestIdGatingOracle` and set the allowed ID in the constructor
      const Oracle = await ethers.getContractFactory('TestIdGatingOracle');
      oracle = await Oracle.deploy(allowedId);

      // Grants signers[0] the permission to do ID gated actions with the deployed `TestIdGatingOracle` oracle
      dao1.grantWithOracle(
        testPlugin.address,
        ownerAddress,
        ID_GATED_ACTION_PERMISSION_ID,
        oracle.address
      );

      // Deploy a new object in the `TestPlugin` which will have the ID 0
      const tx = await testPlugin.createNewObject(dao1.address);
      await tx.wait();
      await ethers.provider.send('evm_mine', []);

      // Check that the ID gated action can be executed
      await expect(testPlugin.callStatic.idGatedAction(allowedId)).to.not.be
        .reverted;
    });

    it('reverts if the ID does not exist', async () => {
      const allowedId = 0;
      const nonExistingId = 1;

      // Deploy the oracle and set the allowed ID
      const Oracle = await ethers.getContractFactory('TestIdGatingOracle');
      oracle = await Oracle.deploy(allowedId);

      // Grants signers[0] the permission to do ID gated actions with the deployed `TestIdGatingOracle` oracle
      dao1.grantWithOracle(
        testPlugin.address,
        ownerAddress,
        ID_GATED_ACTION_PERMISSION_ID,
        oracle.address
      );

      // The call fails because no object with ID 1 exists
      await expect(testPlugin.callStatic.idGatedAction(nonExistingId))
        .to.be.revertedWithCustomError(testPlugin, 'ObjectIdNotAssigned')
        .withArgs(nonExistingId);

      // Create object with ID 0
      let tx = await testPlugin.createNewObject(dao1.address);
      await tx.wait();
      await ethers.provider.send('evm_mine', []);

      // The call still fails because no object with ID 1 exists
      await expect(testPlugin.callStatic.idGatedAction(nonExistingId))
        .to.be.revertedWithCustomError(testPlugin, 'ObjectIdNotAssigned')
        .withArgs(nonExistingId);

      // The call executes for the allowed ID 0
      await expect(testPlugin.callStatic.idGatedAction(allowedId)).to.not.be
        .reverted;
    });

    it('reverts if the ID is not allowed', async () => {
      // deploy oracle and set allowed ID
      const allowedId = 1;
      const existingButNotAllowedId = 0;

      const Oracle = await ethers.getContractFactory('TestIdGatingOracle');
      oracle = await Oracle.deploy(allowedId);

      // Grants signers[0] the permission to do ID gated actions on `testPlugin` via `oracle`
      dao1.grantWithOracle(
        testPlugin.address,
        ownerAddress,
        ID_GATED_ACTION_PERMISSION_ID,
        oracle.address
      );
      dao2.grantWithOracle(
        testPlugin.address,
        ownerAddress,
        ID_GATED_ACTION_PERMISSION_ID,
        oracle.address
      );

      // Create ID-gated object associated with `dao1`
      let tx = await testPlugin.createNewObject(dao1.address);
      await tx.wait();
      tx = await testPlugin.createNewObject(dao2.address);
      await tx.wait();

      await ethers.provider.send('evm_mine', []);

      // The call is allowed for the allowed ID
      await expect(testPlugin.callStatic.idGatedAction(allowedId)).to.not.be
        .reverted;

      // The call fails if the ID differs
      await expect(testPlugin.callStatic.idGatedAction(existingButNotAllowedId))
        .to.be.revertedWithCustomError(testPlugin, 'DaoUnauthorized')
        .withArgs(...expectedUnauthorizedErrorArguments);
    });

    it('reverts if the permission is missing', async () => {
      // Deploy oracle and set allowed ID
      const allowedId = 0;

      const Oracle = await ethers.getContractFactory('TestIdGatingOracle');
      oracle = await Oracle.deploy(allowedId);

      // Create ID-gated object associated with `dao1`
      const tx = await testPlugin.createNewObject(dao1.address);
      await tx.wait();
      await ethers.provider.send('evm_mine', []);

      await expect(testPlugin.callStatic.idGatedAction(allowedId))
        .to.be.revertedWithCustomError(testPlugin, 'DaoUnauthorized')
        .withArgs(...expectedUnauthorizedErrorArguments);
    });

    it('reverts if the permission is set in the wrong DAO', async () => {
      // Deploy oracle and set allowed ID
      const allowedId = 0;

      const Oracle = await ethers.getContractFactory('TestIdGatingOracle');
      oracle = await Oracle.deploy(allowedId);

      // Grants signers[0] the permission to do ID gated actions with the deployed `TestIdGatingOracle` oracle
      dao2.grantWithOracle(
        testPlugin.address,
        ownerAddress,
        ID_GATED_ACTION_PERMISSION_ID,
        oracle.address
      );

      // Create ID-gated object associated with `dao1`
      const tx = await testPlugin.createNewObject(dao1.address);
      await tx.wait();
      await ethers.provider.send('evm_mine', []);

      await expect(testPlugin.callStatic.idGatedAction(allowedId))
        .to.be.revertedWithCustomError(testPlugin, 'DaoUnauthorized')
        .withArgs(...expectedUnauthorizedErrorArguments);
    });

    it('reverts if the object belongs to the wrong DAO', async () => {
      // Deploy oracle and set allowed ID
      const allowedId = 0;

      const Oracle = await ethers.getContractFactory('TestIdGatingOracle');
      oracle = await Oracle.deploy(allowedId);

      // Grants signers[0] the permission to do ID gated actions with the deployed `TestIdGatingOracle` oracle
      dao1.grantWithOracle(
        testPlugin.address,
        ownerAddress,
        ID_GATED_ACTION_PERMISSION_ID,
        oracle.address
      );

      // Create ID-gated object associated with `dao1`
      const tx = await testPlugin.createNewObject(dao2.address);
      await tx.wait();
      await ethers.provider.send('evm_mine', []);

      await expect(testPlugin.callStatic.idGatedAction(allowedId))
        .to.be.revertedWithCustomError(testPlugin, 'DaoUnauthorized')
        .withArgs(...expectedUnauthorizedErrorArguments);
    });
  });
});
