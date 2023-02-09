import {
  Address,
  Bytes,
  store,
  ethereum,
  log,
  BigInt
} from '@graphprotocol/graph-ts';

import {
  MetadataSet,
  Executed,
  Deposited,
  NativeTokenDeposited,
  Granted,
  Revoked,
  TrustedForwarderSet,
  SignatureValidatorSet,
  StandardCallbackRegistered,
  CallbackReceived
} from '../../generated/templates/DaoTemplate/DAO';
import {
  Dao,
  ContractPermissionId,
  Permission,
  StandardCallback
} from '../../generated/schema';

import {ADDRESS_ZERO} from '../utils/constants';

import {handleERC721Action, handleERC721Received} from '../utils/tokens/erc721';
import {handleERC20Action, handleERC20Deposit} from '../utils/tokens/erc20';
import {handleETHAction, handleETHDeposit} from '../utils/tokens/eth';
import {
  ERC20_transfer,
  ERC20_transferFrom,
  ERC721_safeTransferFromNoData,
  ERC721_safeTransferFromWithData,
  ERC721_transferFrom,
  onERC721Received
} from '../utils/tokens/common';

export function handleMetadataSet(event: MetadataSet): void {
  let daoId = event.address.toHexString();
  let metadata = event.params.metadata.toString();
  _handleMetadataSet(daoId, metadata);
}

export function _handleMetadataSet(daoId: string, metadata: string): void {
  let entity = Dao.load(daoId);
  if (entity) {
    entity.metadata = metadata;
    entity.save();
  }
}

export function handleCallbackReceived(event: CallbackReceived): void {
  let functionSig = event.params.sig;

  if (functionSig.equals(Bytes.fromHexString(onERC721Received))) {
    handleERC721Received(
      event.params.sender,
      event.address,
      event.params.data,
      event.block.timestamp,
      event.transaction.hash
    );
  }
}

export function handleExecuted(event: Executed): void {
  let actions = event.params.actions;

  for (let index = 0; index < actions.length; index++) {
    const action = actions[index];

    let proposalId = event.params.actor
      .toHexString()
      .concat('_')
      .concat(event.params.callId.toHexString());

    if (action.data.toHexString() == '0x') {
      handleETHAction(
        event.address,
        event.address,
        action.to,
        action.value,
        'Eth Withdraw',
        proposalId,
        event.block.timestamp,
        event.transaction.hash
      );
      return;
    }

    let methodSig = action.data.toHexString().slice(0, 10);

    if (
      methodSig == ERC721_transferFrom ||
      methodSig == ERC721_safeTransferFromNoData ||
      methodSig == ERC721_safeTransferFromWithData
    ) {
      handleERC721Action(
        action.to,
        event.address,
        action.data,
        proposalId,
        event.block.timestamp,
        event.transaction.hash
      );
      return;
    }

    if (methodSig == ERC20_transfer || methodSig == ERC20_transferFrom) {
      handleERC20Action(
        action.to,
        event.address,
        proposalId,
        action.data,
        event.block.timestamp,
        event.transaction.hash
      );
      return;
    }
  }
}

// ERC20 + ETH
export function handleDeposited(event: Deposited): void {
  if (event.params.token.toHexString() != ADDRESS_ZERO) {
    handleERC20Deposit(
      event.address,
      event.params.token,
      event.params.sender,
      event.address,
      // event.params._reference, TODO: pass it
      event.params.amount,
      event.transaction.hash,
      event.block.timestamp
    );
    return;
  }

  handleETHDeposit(
    event.address,
    event.params.sender,
    event.address,
    event.params.amount,
    event.params._reference,
    event.block.timestamp,
    event.transaction.hash
  );
}

export function handleNativeTokenDeposited(event: NativeTokenDeposited): void {
  handleETHDeposit(
    event.address,
    event.params.sender,
    event.address,
    event.params.amount,
    'Eth Deposit',
    event.block.timestamp,
    event.transaction.hash
  );
}

export function handleGranted(event: Granted): void {
  // ContractPermissionId
  let daoId = event.address.toHexString();
  let contractPermissionIdEntityId =
    event.params.where.toHexString() +
    '_' +
    event.params.permissionId.toHexString();
  let contractPermissionIdEntity = ContractPermissionId.load(
    contractPermissionIdEntityId
  );
  if (!contractPermissionIdEntity) {
    contractPermissionIdEntity = new ContractPermissionId(
      contractPermissionIdEntityId
    );
    contractPermissionIdEntity.dao = daoId;
    contractPermissionIdEntity.where = event.params.where;
    contractPermissionIdEntity.permissionId = event.params.permissionId;
    contractPermissionIdEntity.save();
  }

  // Permission
  let permissionId =
    contractPermissionIdEntityId + '_' + event.params.who.toHexString();
  let permissionEntity = new Permission(permissionId);
  permissionEntity.dao = daoId;
  permissionEntity.contractPermissionId = contractPermissionIdEntityId;
  permissionEntity.where = event.params.where;
  permissionEntity.who = event.params.who;
  permissionEntity.actor = event.params.here;
  permissionEntity.condition = event.params.condition;
  permissionEntity.save();
}

export function handleRevoked(event: Revoked): void {
  // permission
  let permissionId =
    event.params.where.toHexString() +
    '_' +
    event.params.permissionId.toHexString() +
    '_' +
    event.params.who.toHexString();
  let permissionEntity = Permission.load(permissionId);
  if (permissionEntity) {
    store.remove('Permission', permissionId);
  }
}

export function handleTrustedForwarderSet(event: TrustedForwarderSet): void {
  let daoId = event.address.toHexString();
  let entity = Dao.load(daoId);
  if (entity) {
    entity.trustedForwarder = event.params.forwarder;
    entity.save();
  }
}

export function handleSignatureValidatorSet(
  event: SignatureValidatorSet
): void {
  let daoId = event.address.toHexString();
  let entity = Dao.load(daoId);
  if (entity) {
    entity.signatureValidator = event.params.signatureValidator;
    entity.save();
  }
}

export function handleStandardCallbackRegistered(
  event: StandardCallbackRegistered
): void {
  let daoId = event.address.toHexString();
  let entityId = `${daoId}_${event.params.interfaceId.toHexString()}`;
  let entity = StandardCallback.load(entityId);
  if (!entity) {
    entity = new StandardCallback(entityId);
    entity.dao = daoId;
  }
  entity.interfaceId = event.params.interfaceId;
  entity.callbackSelector = event.params.callbackSelector;
  entity.magicNumber = event.params.magicNumber;
  entity.save();
}
