import {BytesLike} from 'ethers';
import {defaultAbiCoder} from 'ethers/lib/utils';
import {keccak256} from 'ethers/utils';

import {PermissionOperation, PluginRepoPointer, PreparationType} from './types';

export function hashHelpers(helpers: string[]) {
  return keccak256(defaultAbiCoder.encode(['address[]'], [helpers]));
}

export function hashPermissions(permissions: PermissionOperation[]) {
  return keccak256(
    defaultAbiCoder.encode(
      ['tuple(uint8,address,address,address,bytes32)[]'],
      [permissions]
    )
  );
}

export function getPluginInstallationId(dao: string, plugin: string) {
  return keccak256(
    defaultAbiCoder.encode(['address', 'address'], [dao, plugin])
  );
}

export function getSetupId(
  pluginRepoPointer: PluginRepoPointer,
  helpers: string[],
  permissions: PermissionOperation[],
  data: BytesLike,
  preparationType: PreparationType
) {
  return keccak256(
    defaultAbiCoder.encode(
      [
        'tuple(uint8, uint16)',
        'address',
        'bytes32',
        'bytes32',
        'bytes32',
        'uint8',
      ],
      [
        [pluginRepoPointer[1], pluginRepoPointer[2]],
        pluginRepoPointer[0],
        hashPermissions(permissions),
        hashHelpers(helpers),
        keccak256(data),
        preparationType,
      ]
    )
  );
}
