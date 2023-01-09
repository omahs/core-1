import {expect} from 'chai';
import {ethers} from 'hardhat';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';

import {PermissionManagerTest, PermissionOracleMock} from '../../../typechain';
import {DeployTestPermissionOracle} from '../../test-utils/oracles';

const ROOT_PERMISSION_ID = ethers.utils.id('ROOT_PERMISSION');
const ADMIN_PERMISSION_ID = ethers.utils.id('ADMIN_PERMISSION');
const RESTRICTED_PERMISSIONS_FOR_ANY_ADDR = [
  ROOT_PERMISSION_ID,
  ethers.utils.id('TEST_PERMISSION_1'),
  ethers.utils.id('TEST_PERMISSION_2'),
];

const UNSET_FLAG = ethers.utils.getAddress(
  '0x0000000000000000000000000000000000000000'
);
const ALLOW_FLAG = ethers.utils.getAddress(
  '0x0000000000000000000000000000000000000002'
);

const addressZero = ethers.constants.AddressZero;
const ANY_ADDR = '0xffffffffffffffffffffffffffffffffffffffff';

export enum Operation {
  Grant,
  Revoke,
  Freeze,
  GrantWithOracle,
}

interface ItemSingleTarget {
  operation: Operation;
  who: string;
  permissionId: string;
}

interface ItemMultiTarget {
  operation: Operation;
  where: string;
  who: string;
  oracle: string;
  permissionId: string;
}

describe('Core: PermissionManager', function () {
  let pm: PermissionManagerTest;
  let ownerSigner: SignerWithAddress;
  let otherSigner: SignerWithAddress;

  before(async () => {
    const signers = await ethers.getSigners();
    ownerSigner = signers[0];
    otherSigner = signers[1];
  });

  beforeEach(async () => {
    const PM = await ethers.getContractFactory('PermissionManagerTest');
    pm = await PM.deploy();
    await pm.init(ownerSigner.address);
  });

  describe('init', () => {
    it('should allow init call only once', async () => {
      await expect(pm.init(ownerSigner.address)).to.be.revertedWith(
        'Initializable: contract is already initialized'
      );
    });

    it('should emit Granted', async () => {
      const PM = await ethers.getContractFactory('PermissionManagerTest');
      pm = await PM.deploy();
      await expect(pm.init(ownerSigner.address)).to.emit(pm, 'Granted');
    });

    it('should add ROOT_PERMISSION', async () => {
      const permission = await pm.getAuthPermission(
        pm.address,
        ownerSigner.address,
        ROOT_PERMISSION_ID
      );
      expect(permission).to.be.equal(ALLOW_FLAG);
    });
  });

  describe('grant', () => {
    it('should add permission', async () => {
      await pm.grant(pm.address, otherSigner.address, ADMIN_PERMISSION_ID);
      const permission = await pm.getAuthPermission(
        pm.address,
        otherSigner.address,
        ADMIN_PERMISSION_ID
      );
      expect(permission).to.be.equal(ALLOW_FLAG);
    });

    it('reverts if both `_who = ANY_ADDR` and `_where == ANY_ADDR', async () => {
      await expect(
        pm.grant(ANY_ADDR, ANY_ADDR, ROOT_PERMISSION_ID)
      ).to.be.revertedWithCustomError(pm, 'AnyAddressDisallowedForWhoAndWhere');
    });

    it('reverts if permissionId is restricted and `_who = ANY_ADDR` or `_where = ANY_ADDR`', async () => {
      for (let i = 0; i < RESTRICTED_PERMISSIONS_FOR_ANY_ADDR.length; i++) {
        await expect(
          pm.grant(pm.address, ANY_ADDR, RESTRICTED_PERMISSIONS_FOR_ANY_ADDR[i])
        ).to.be.revertedWithCustomError(
          pm,
          'PermissionsForAnyAddressDisallowed'
        );
        await expect(
          pm.grant(ANY_ADDR, pm.address, RESTRICTED_PERMISSIONS_FOR_ANY_ADDR[i])
        ).to.be.revertedWithCustomError(
          pm,
          'PermissionsForAnyAddressDisallowed'
        );
      }
    });

    it('reverts if permissionId is not restricted and`_who = ANY_ADDR` or `_where = ANY_ADDR` and oracle is not present', async () => {
      await expect(
        pm.grant(pm.address, ANY_ADDR, ADMIN_PERMISSION_ID)
      ).to.be.revertedWithCustomError(pm, 'OracleNotPresentForAnyAddress');

      await expect(
        pm.grant(ANY_ADDR, pm.address, ADMIN_PERMISSION_ID)
      ).to.be.revertedWithCustomError(pm, 'OracleNotPresentForAnyAddress');
    });

    it('should emit Granted', async () => {
      await expect(
        pm.grant(pm.address, otherSigner.address, ADMIN_PERMISSION_ID)
      ).to.emit(pm, 'Granted');
    });

    it('should revert with already granted', async () => {
      await pm.grant(pm.address, otherSigner.address, ADMIN_PERMISSION_ID);
      await expect(
        pm.grant(pm.address, otherSigner.address, ADMIN_PERMISSION_ID)
      )
        .to.be.revertedWithCustomError(pm, 'PermissionAlreadyGranted')
        .withArgs(pm.address, otherSigner.address, ADMIN_PERMISSION_ID);
    });

    it('should revert if frozen', async () => {
      await pm.freeze(pm.address, ADMIN_PERMISSION_ID);
      await expect(
        pm.grant(pm.address, otherSigner.address, ADMIN_PERMISSION_ID)
      )
        .to.be.revertedWithCustomError(pm, 'PermissionFrozen')
        .withArgs(pm.address, ADMIN_PERMISSION_ID);
    });

    it('should not allow grant', async () => {
      await expect(
        pm
          .connect(otherSigner)
          .grant(pm.address, otherSigner.address, ADMIN_PERMISSION_ID)
      )
        .to.be.revertedWithCustomError(pm, 'Unauthorized')
        .withArgs(
          pm.address,
          pm.address,
          otherSigner.address,
          ROOT_PERMISSION_ID
        );
    });

    it('should not allow for non ROOT', async () => {
      await pm.grant(pm.address, ownerSigner.address, ADMIN_PERMISSION_ID);
      await expect(
        pm
          .connect(otherSigner)
          .grant(pm.address, otherSigner.address, ROOT_PERMISSION_ID)
      )
        .to.be.revertedWithCustomError(pm, 'Unauthorized')
        .withArgs(
          pm.address,
          pm.address,
          otherSigner.address,
          ROOT_PERMISSION_ID
        );
    });
  });

  describe('grantWithOrpme', () => {
    it('should add permission', async () => {
      await pm.grantWithOracle(
        pm.address,
        otherSigner.address,
        ADMIN_PERMISSION_ID,
        ALLOW_FLAG
      );
      const permission = await pm.getAuthPermission(
        pm.address,
        otherSigner.address,
        ADMIN_PERMISSION_ID
      );
      expect(permission).to.be.equal(ALLOW_FLAG);
    });

    it('should emit Granted', async () => {
      await expect(
        pm.grantWithOracle(
          pm.address,
          otherSigner.address,
          ADMIN_PERMISSION_ID,
          ALLOW_FLAG
        )
      ).to.emit(pm, 'Granted');
    });

    it('should emit Granted when oracle is present and `who = ANY_ADDR` or `where = ANY_ADDR`', async () => {
      await expect(
        pm.grantWithOracle(
          pm.address,
          ANY_ADDR,
          ADMIN_PERMISSION_ID,
          pm.address // not oracle, but enough for the call to succeed.
        )
      ).to.emit(pm, 'Granted');

      await expect(
        pm.grantWithOracle(
          ANY_ADDR,
          pm.address,
          ADMIN_PERMISSION_ID,
          pm.address // not oracle, but enough for the call to succeed.
        )
      ).to.emit(pm, 'Granted');
    });

    it('should revert with already granted', async () => {
      await pm.grantWithOracle(
        pm.address,
        otherSigner.address,
        ADMIN_PERMISSION_ID,
        ALLOW_FLAG
      );
      await expect(
        pm.grantWithOracle(
          pm.address,
          otherSigner.address,
          ADMIN_PERMISSION_ID,
          ALLOW_FLAG
        )
      )
        .to.be.revertedWithCustomError(pm, 'PermissionAlreadyGranted')
        .withArgs(pm.address, otherSigner.address, ADMIN_PERMISSION_ID);
    });

    it('should revert when oracle is not present for `who = ANY_ADDR` or `where = ANY_ADDR` and permissionId is not restricted', async () => {
      await expect(
        pm.grantWithOracle(
          pm.address,
          ANY_ADDR,
          ADMIN_PERMISSION_ID,
          ALLOW_FLAG
        )
      ).to.be.revertedWithCustomError(pm, 'OracleNotPresentForAnyAddress');
    });

    it('should revert if frozen', async () => {
      await pm.freeze(pm.address, ADMIN_PERMISSION_ID);
      await expect(
        pm.grantWithOracle(
          pm.address,
          otherSigner.address,
          ADMIN_PERMISSION_ID,
          ALLOW_FLAG
        )
      )
        .to.be.revertedWithCustomError(pm, 'PermissionFrozen')
        .withArgs(pm.address, ADMIN_PERMISSION_ID);
    });

    it('should set PermissionOracle', async () => {
      const signers = await ethers.getSigners();
      await pm.grantWithOracle(
        pm.address,
        otherSigner.address,
        ADMIN_PERMISSION_ID,
        signers[2].address
      );
      expect(
        await pm.getAuthPermission(
          pm.address,
          otherSigner.address,
          ADMIN_PERMISSION_ID
        )
      ).to.be.equal(signers[2].address);
    });

    it('should not allow grant', async () => {
      await expect(
        pm
          .connect(otherSigner)
          .grantWithOracle(
            pm.address,
            otherSigner.address,
            ADMIN_PERMISSION_ID,
            ALLOW_FLAG
          )
      )
        .to.be.revertedWithCustomError(pm, 'Unauthorized')
        .withArgs(
          pm.address,
          pm.address,
          otherSigner.address,
          ROOT_PERMISSION_ID
        );
    });

    it('should not allow for non ROOT', async () => {
      await pm.grantWithOracle(
        pm.address,
        ownerSigner.address,
        ADMIN_PERMISSION_ID,
        ALLOW_FLAG
      );
      await expect(
        pm
          .connect(otherSigner)
          .grantWithOracle(
            pm.address,
            otherSigner.address,
            ROOT_PERMISSION_ID,
            ALLOW_FLAG
          )
      )
        .to.be.revertedWithCustomError(pm, 'Unauthorized')
        .withArgs(
          pm.address,
          pm.address,
          otherSigner.address,
          ROOT_PERMISSION_ID
        );
    });
  });

  describe('revoke', () => {
    it('should revoke', async () => {
      await pm.grant(pm.address, otherSigner.address, ADMIN_PERMISSION_ID);
      await pm.revoke(pm.address, otherSigner.address, ADMIN_PERMISSION_ID);
      const permission = await pm.getAuthPermission(
        pm.address,
        otherSigner.address,
        ADMIN_PERMISSION_ID
      );
      expect(permission).to.be.equal(UNSET_FLAG);
    });

    it('should emit Revoked', async () => {
      await pm.grant(pm.address, otherSigner.address, ADMIN_PERMISSION_ID);
      await expect(
        pm.revoke(pm.address, otherSigner.address, ADMIN_PERMISSION_ID)
      ).to.emit(pm, 'Revoked');
    });

    it('should revert if not granted', async () => {
      await pm.grant(pm.address, otherSigner.address, ADMIN_PERMISSION_ID);
      await expect(
        pm
          .connect(otherSigner)
          .revoke(pm.address, otherSigner.address, ADMIN_PERMISSION_ID)
      )
        .to.be.revertedWithCustomError(pm, 'Unauthorized')
        .withArgs(
          pm.address,
          pm.address,
          otherSigner.address,
          ROOT_PERMISSION_ID
        );
    });

    it('should revert if frozen', async () => {
      await pm.grant(pm.address, otherSigner.address, ADMIN_PERMISSION_ID);
      await pm.freeze(pm.address, ADMIN_PERMISSION_ID);
      await expect(
        pm.revoke(pm.address, otherSigner.address, ADMIN_PERMISSION_ID)
      )
        .to.be.revertedWithCustomError(pm, 'PermissionFrozen')
        .withArgs(pm.address, ADMIN_PERMISSION_ID);
    });

    it('should revert if already revoked', async () => {
      await pm.grant(pm.address, otherSigner.address, ADMIN_PERMISSION_ID);
      await pm.revoke(pm.address, otherSigner.address, ADMIN_PERMISSION_ID);
      await expect(
        pm.revoke(pm.address, otherSigner.address, ADMIN_PERMISSION_ID)
      )
        .to.be.revertedWithCustomError(pm, 'PermissionAlreadyRevoked')
        .withArgs(pm.address, otherSigner.address, ADMIN_PERMISSION_ID);
    });

    it('should not allow', async () => {
      await expect(
        pm
          .connect(otherSigner)
          .revoke(pm.address, otherSigner.address, ADMIN_PERMISSION_ID)
      )
        .to.be.revertedWithCustomError(pm, 'Unauthorized')
        .withArgs(
          pm.address,
          pm.address,
          otherSigner.address,
          ROOT_PERMISSION_ID
        );
    });

    it('should not allow for non ROOT', async () => {
      await pm.grant(pm.address, otherSigner.address, ADMIN_PERMISSION_ID);
      await expect(
        pm
          .connect(otherSigner)
          .revoke(pm.address, otherSigner.address, ADMIN_PERMISSION_ID)
      )
        .to.be.revertedWithCustomError(pm, 'Unauthorized')
        .withArgs(
          pm.address,
          pm.address,
          otherSigner.address,
          ROOT_PERMISSION_ID
        );
    });
  });

  describe('freeze', () => {
    it('should freeze', async () => {
      await pm.freeze(pm.address, ADMIN_PERMISSION_ID);
      const frozen = await pm.isFrozen(pm.address, ADMIN_PERMISSION_ID);
      expect(frozen).to.be.equal(true);
    });

    it('should emit Frozen', async () => {
      await expect(pm.freeze(pm.address, ADMIN_PERMISSION_ID)).to.emit(
        pm,
        'Frozen'
      );
    });

    it('should revert if already frozen', async () => {
      await pm.freeze(pm.address, ADMIN_PERMISSION_ID);
      await expect(pm.freeze(pm.address, ADMIN_PERMISSION_ID))
        .to.be.revertedWithCustomError(pm, 'PermissionFrozen')
        .withArgs(pm.address, ADMIN_PERMISSION_ID);
    });

    it('should not allow', async () => {
      await expect(
        pm.connect(otherSigner).freeze(pm.address, ADMIN_PERMISSION_ID)
      )
        .to.be.revertedWithCustomError(pm, 'Unauthorized')
        .withArgs(
          pm.address,
          pm.address,
          otherSigner.address,
          ROOT_PERMISSION_ID
        );
    });

    it('should not allow for non ROOT', async () => {
      await pm.grant(pm.address, otherSigner.address, ADMIN_PERMISSION_ID);
      await expect(
        pm.connect(otherSigner).freeze(pm.address, ADMIN_PERMISSION_ID)
      )
        .to.be.revertedWithCustomError(pm, 'Unauthorized')
        .withArgs(
          pm.address,
          pm.address,
          otherSigner.address,
          ROOT_PERMISSION_ID
        );
    });

    it('reverts if `_where` is `ANY_ADDR`', async () => {
      await expect(
        pm.freeze(ANY_ADDR, ADMIN_PERMISSION_ID)
      ).to.be.revertedWithCustomError(pm, 'FreezeOnAnyAddressDisallowed');
    });
  });

  describe('bulk on multiple target', () => {
    it('should bulk grant ADMIN_PERMISSION on different targets', async () => {
      const signers = await ethers.getSigners();
      await pm.grant(pm.address, signers[0].address, ADMIN_PERMISSION_ID);
      const bulkItems: ItemMultiTarget[] = [
        {
          operation: Operation.Grant,
          where: signers[1].address,
          who: signers[2].address,
          oracle: addressZero,
          permissionId: ADMIN_PERMISSION_ID,
        },
        {
          operation: Operation.Grant,
          where: signers[2].address,
          who: signers[3].address,
          oracle: addressZero,
          permissionId: ADMIN_PERMISSION_ID,
        },
      ];

      await pm.bulkOnMultiTarget(bulkItems);
      for (const item of bulkItems) {
        const permission = await pm.getAuthPermission(
          item.where,
          item.who,
          item.permissionId
        );
        expect(permission).to.be.equal(ALLOW_FLAG);
      }
    });

    it('should bulk freeze', async () => {
      const signers = await ethers.getSigners();
      await pm.grant(
        pm.address,
        signers[0].address,
        ethers.utils.id('PERMISSION_ID_1')
      );
      await pm.grant(
        pm.address,
        signers[0].address,
        ethers.utils.id('PERMISSION_ID_2')
      );
      const bulkItems: ItemMultiTarget[] = [
        {
          operation: Operation.Freeze,
          where: signers[1].address,
          who: signers[2].address,
          oracle: addressZero,
          permissionId: ethers.utils.id('PERMISSION_ID_1'),
        },
        {
          operation: Operation.Freeze,
          where: signers[2].address,
          who: signers[3].address,
          oracle: addressZero,
          permissionId: ethers.utils.id('PERMISSION_ID_2'),
        },
      ];
      await pm.bulkOnMultiTarget(bulkItems);
      for (const item of bulkItems) {
        const permission = await pm.isFrozen(item.where, item.permissionId);
        expect(permission).to.be.equal(true);
      }
    });

    it('should bulk revoke', async () => {
      const signers = await ethers.getSigners();
      await pm.grant(
        signers[1].address,
        signers[0].address,
        ADMIN_PERMISSION_ID
      );
      await pm.grant(
        signers[2].address,
        signers[0].address,
        ADMIN_PERMISSION_ID
      );
      const bulkItems: ItemMultiTarget[] = [
        {
          operation: Operation.Revoke,
          where: signers[1].address,
          who: signers[0].address,
          oracle: addressZero,
          permissionId: ADMIN_PERMISSION_ID,
        },
        {
          operation: Operation.Revoke,
          where: signers[2].address,
          who: signers[0].address,
          oracle: addressZero,
          permissionId: ADMIN_PERMISSION_ID,
        },
      ];
      await pm.bulkOnMultiTarget(bulkItems);
      for (const item of bulkItems) {
        const permission = await pm.getAuthPermission(
          item.where,
          item.who,
          item.permissionId
        );
        expect(permission).to.be.equal(UNSET_FLAG);
      }
    });

    it('should grant with oracle', async () => {
      const signers = await ethers.getSigners();
      await pm.grant(pm.address, signers[0].address, ADMIN_PERMISSION_ID);
      const bulkItems: ItemMultiTarget[] = [
        {
          operation: Operation.GrantWithOracle,
          where: signers[1].address,
          who: signers[0].address,
          oracle: signers[3].address,
          permissionId: ADMIN_PERMISSION_ID,
        },
        {
          operation: Operation.GrantWithOracle,
          where: signers[2].address,
          who: signers[0].address,
          oracle: signers[4].address,
          permissionId: ADMIN_PERMISSION_ID,
        },
      ];
      await pm.bulkOnMultiTarget(bulkItems);
      for (const item of bulkItems) {
        const permission = await pm.getAuthPermission(
          item.where,
          item.who,
          item.permissionId
        );
        expect(permission).to.be.equal(item.oracle);
      }
    });

    it('throws Unauthorized error when caller does not have ROOT_PERMISSION_ID permission', async () => {
      const signers = await ethers.getSigners();
      const bulkItems: ItemMultiTarget[] = [
        {
          operation: Operation.Grant,
          where: signers[1].address,
          who: signers[0].address,
          oracle: addressZero,
          permissionId: ADMIN_PERMISSION_ID,
        },
      ];

      await expect(pm.connect(signers[2]).bulkOnMultiTarget(bulkItems))
        .to.be.revertedWithCustomError(pm, 'Unauthorized')
        .withArgs(
          pm.address,
          signers[1].address,
          signers[2].address,
          ROOT_PERMISSION_ID
        );
    });
  });
  describe('bulk on single target', () => {
    it('should bulk grant ADMIN_PERMISSION', async () => {
      const signers = await ethers.getSigners();
      const bulkItems: ItemSingleTarget[] = [
        {
          operation: Operation.Grant,
          who: signers[1].address,
          permissionId: ADMIN_PERMISSION_ID,
        },
        {
          operation: Operation.Grant,
          who: signers[2].address,
          permissionId: ADMIN_PERMISSION_ID,
        },
        {
          operation: Operation.Grant,
          who: signers[3].address,
          permissionId: ADMIN_PERMISSION_ID,
        },
      ];
      await pm.bulkOnSingleTarget(pm.address, bulkItems);
      for (const item of bulkItems) {
        const permission = await pm.getAuthPermission(
          pm.address,
          item.who,
          item.permissionId
        );
        expect(permission).to.be.equal(ALLOW_FLAG);
      }
    });

    it('should bulk freeze', async () => {
      const signers = await ethers.getSigners();
      const bulkItems: ItemSingleTarget[] = [
        {
          operation: Operation.Freeze,
          who: signers[1].address,
          permissionId: ethers.utils.id('PERMISSION_ID_1'),
        },
        {
          operation: Operation.Freeze,
          who: signers[2].address,
          permissionId: ethers.utils.id('PERMISSION_ID_2'),
        },
        {
          operation: Operation.Freeze,
          who: signers[3].address,
          permissionId: ethers.utils.id('PERMISSION_ID_3'),
        },
      ];
      await pm.bulkOnSingleTarget(pm.address, bulkItems);
      for (const item of bulkItems) {
        const permission = await pm.isFrozen(pm.address, item.permissionId);
        expect(permission).to.be.equal(true);
      }
    });

    it('should bulk revoke', async () => {
      const signers = await ethers.getSigners();
      await pm.grant(pm.address, signers[1].address, ADMIN_PERMISSION_ID);
      await pm.grant(pm.address, signers[2].address, ADMIN_PERMISSION_ID);
      await pm.grant(pm.address, signers[3].address, ADMIN_PERMISSION_ID);
      const bulkItems: ItemSingleTarget[] = [
        {
          operation: Operation.Revoke,
          who: signers[1].address,
          permissionId: ADMIN_PERMISSION_ID,
        },
        {
          operation: Operation.Revoke,
          who: signers[2].address,
          permissionId: ADMIN_PERMISSION_ID,
        },
        {
          operation: Operation.Revoke,
          who: signers[3].address,
          permissionId: ADMIN_PERMISSION_ID,
        },
      ];
      await pm.bulkOnSingleTarget(pm.address, bulkItems);
      for (const item of bulkItems) {
        const permission = await pm.getAuthPermission(
          pm.address,
          item.who,
          item.permissionId
        );
        expect(permission).to.be.equal(UNSET_FLAG);
      }
    });

    it('should handle bulk mixed', async () => {
      const signers = await ethers.getSigners();
      await pm.grant(pm.address, signers[1].address, ADMIN_PERMISSION_ID);
      const bulkItems: ItemSingleTarget[] = [
        {
          operation: Operation.Revoke,
          who: signers[1].address,
          permissionId: ADMIN_PERMISSION_ID,
        },
        {
          operation: Operation.Grant,
          who: signers[2].address,
          permissionId: ADMIN_PERMISSION_ID,
        },
        {
          operation: Operation.Freeze,
          who: signers[3].address,
          permissionId: ADMIN_PERMISSION_ID,
        },
      ];

      await pm.bulkOnSingleTarget(pm.address, bulkItems);
      expect(
        await pm.getAuthPermission(
          pm.address,
          signers[1].address,
          ADMIN_PERMISSION_ID
        )
      ).to.be.equal(UNSET_FLAG);
      expect(
        await pm.getAuthPermission(
          pm.address,
          signers[2].address,
          ADMIN_PERMISSION_ID
        )
      ).to.be.equal(ALLOW_FLAG);
      expect(await pm.isFrozen(pm.address, ADMIN_PERMISSION_ID)).to.be.equal(
        true
      );
    });

    it('should revert on error', async () => {
      const signers = await ethers.getSigners();
      await pm.grant(pm.address, signers[1].address, ADMIN_PERMISSION_ID);
      const bulkItems: ItemSingleTarget[] = [
        {
          operation: Operation.Revoke,
          who: signers[1].address,
          permissionId: ADMIN_PERMISSION_ID,
        },
        {
          operation: Operation.Grant,
          who: signers[2].address,
          permissionId: ADMIN_PERMISSION_ID,
        },
        {
          operation: Operation.Freeze,
          who: signers[3].address,
          permissionId: ADMIN_PERMISSION_ID,
        },
        {
          operation: Operation.Freeze,
          who: signers[3].address,
          permissionId: ADMIN_PERMISSION_ID,
        },
      ];

      await expect(pm.bulkOnSingleTarget(pm.address, bulkItems))
        .to.be.revertedWithCustomError(pm, 'PermissionFrozen')
        .withArgs(pm.address, ADMIN_PERMISSION_ID);
      expect(
        await pm.getAuthPermission(
          pm.address,
          signers[1].address,
          ADMIN_PERMISSION_ID
        )
      ).to.be.equal(ALLOW_FLAG);
      expect(
        await pm.getAuthPermission(
          pm.address,
          signers[2].address,
          ADMIN_PERMISSION_ID
        )
      ).to.be.equal(UNSET_FLAG);
      expect(await pm.isFrozen(pm.address, ADMIN_PERMISSION_ID)).to.be.equal(
        false
      );
    });

    it('should not allow', async () => {
      const bulkItems: ItemSingleTarget[] = [
        {
          operation: Operation.Grant,
          who: otherSigner.address,
          permissionId: ADMIN_PERMISSION_ID,
        },
      ];
      await expect(
        pm.connect(otherSigner).bulkOnSingleTarget(pm.address, bulkItems)
      )
        .to.be.revertedWithCustomError(pm, 'Unauthorized')
        .withArgs(
          pm.address,
          pm.address,
          otherSigner.address,
          ROOT_PERMISSION_ID
        );
    });

    it('should not allow for non ROOT', async () => {
      await pm.grant(pm.address, otherSigner.address, ADMIN_PERMISSION_ID);
      const bulkItems: ItemSingleTarget[] = [
        {
          operation: Operation.Grant,
          who: otherSigner.address,
          permissionId: ADMIN_PERMISSION_ID,
        },
      ];
      await expect(
        pm.connect(otherSigner).bulkOnSingleTarget(pm.address, bulkItems)
      )
        .to.be.revertedWithCustomError(pm, 'Unauthorized')
        .withArgs(
          pm.address,
          pm.address,
          otherSigner.address,
          ROOT_PERMISSION_ID
        );
    });
  });

  describe('isGranted', () => {
    it('should return true if the permission is granted to the user', async () => {
      await pm.grant(pm.address, otherSigner.address, ADMIN_PERMISSION_ID);
      const isGranted = await pm.callStatic.isGranted(
        pm.address,
        otherSigner.address,
        ADMIN_PERMISSION_ID,
        []
      );
      expect(isGranted).to.be.equal(true);
    });

    it('should return false if the permissions is not granted to the user', async () => {
      const isGranted = await pm.callStatic.isGranted(
        pm.address,
        otherSigner.address,
        ADMIN_PERMISSION_ID,
        []
      );
      expect(isGranted).to.be.equal(false);
    });

    it('should return true for permissions granted to any address on a specific target contract using the `ANY_ADDR` flag', async () => {
      const anyAddr = await pm.getAnyAddr();
      const oracle = await DeployTestPermissionOracle();
      await pm.grantWithOracle(
        pm.address,
        anyAddr,
        ADMIN_PERMISSION_ID,
        oracle.address
      );
      await pm.grantWithOracle(
        anyAddr,
        pm.address,
        ADMIN_PERMISSION_ID,
        oracle.address
      );
      const isGranted_1 = await pm.callStatic.isGranted(
        pm.address,
        anyAddr,
        ADMIN_PERMISSION_ID,
        oracle.address
      );
      const isGranted_2 = await pm.callStatic.isGranted(
        pm.address,
        anyAddr,
        ADMIN_PERMISSION_ID,
        oracle.address
      );
      expect(isGranted_1).to.be.equal(true);
      expect(isGranted_2).to.be.equal(true);
    });

    it('should be callable by anyone', async () => {
      const isGranted = await pm
        .connect(otherSigner)
        .callStatic.isGranted(
          pm.address,
          otherSigner.address,
          ADMIN_PERMISSION_ID,
          []
        );
      expect(isGranted).to.be.equal(false);
    });
  });

  describe('isFrozen', () => {
    it('should return true', async () => {
      await pm.freeze(pm.address, ADMIN_PERMISSION_ID);
      const isFrozen = await pm.callStatic.isFrozen(
        pm.address,
        ADMIN_PERMISSION_ID
      );
      expect(isFrozen).to.be.equal(true);
    });

    it('should return false', async () => {
      const isFrozen = await pm.callStatic.isFrozen(
        pm.address,
        ADMIN_PERMISSION_ID
      );
      expect(isFrozen).to.be.equal(false);
    });

    it('should be callable by anyone', async () => {
      const isFrozen = await pm
        .connect(otherSigner)
        .callStatic.isFrozen(pm.address, ADMIN_PERMISSION_ID);
      expect(isFrozen).to.be.equal(false);
    });
  });

  describe('_hasPermission', () => {
    let permissionOracle: PermissionOracleMock;

    beforeEach(async () => {
      permissionOracle = await DeployTestPermissionOracle();
    });

    it('should call IPermissionOracle.isGranted', async () => {
      await pm.grantWithOracle(
        pm.address,
        otherSigner.address,
        ADMIN_PERMISSION_ID,
        permissionOracle.address
      );
      expect(
        await pm.callStatic.isGranted(
          pm.address,
          otherSigner.address,
          ADMIN_PERMISSION_ID,
          []
        )
      ).to.be.equal(true);

      await permissionOracle.setWillPerform(false);
      expect(
        await pm.callStatic.isGranted(
          pm.address,
          otherSigner.address,
          ADMIN_PERMISSION_ID,
          []
        )
      ).to.be.equal(false);
    });
  });

  describe('helpers', () => {
    it('should hash PERMISSIONS', async () => {
      const packed = ethers.utils.solidityPack(
        ['string', 'address', 'address', 'address'],
        ['PERMISSION', ownerSigner.address, pm.address, ROOT_PERMISSION_ID]
      );
      const hash = ethers.utils.keccak256(packed);
      const contractHash = await pm.getPermissionHash(
        pm.address,
        ownerSigner.address,
        ROOT_PERMISSION_ID
      );
      expect(hash).to.be.equal(contractHash);
    });

    it('should hash IMMUTABLE', async () => {
      const packed = ethers.utils.solidityPack(
        ['string', 'address', 'address'],
        ['IMMUTABLE', pm.address, ROOT_PERMISSION_ID]
      );
      const hash = ethers.utils.keccak256(packed);
      const contractHash = await pm.getFrozenPermissionHash(
        pm.address,
        ROOT_PERMISSION_ID
      );
      expect(hash).to.be.equal(contractHash);
    });
  });
});
