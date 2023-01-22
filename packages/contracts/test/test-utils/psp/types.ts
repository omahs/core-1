import {Operation} from '../../core/permission/permission-manager';
import {BytesLike, utils, constants} from 'ethers';
import {PluginSetupProcessor, PluginRepoRegistry, PluginSetupProcessor__factory} from '../../../typechain';

export type PermissionOperation = {
  operation: Operation;
  where: string;
  who: string;
  condition: string;
  permissionId: BytesLike;
};

export enum PreparationType {
  None,
  Install,
  Update,
  Uninstall,
}

export type PreparedInstallEvent = {
  sender: string;
  dao: string;
  setupId: BytesLike;
  pluginSetupRepo: string;
  versionTag: [number, number];
  data: BytesLike;
  plugin: string;
  permissions: PermissionOperation[];
  helpers: string[];
};

// PluginRepo, release, build
export type PluginRepoPointer = [string, number, number];
