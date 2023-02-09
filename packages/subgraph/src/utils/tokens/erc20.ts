import {Address, BigInt, Bytes, ethereum, log} from '@graphprotocol/graph-ts';
import {
  ERC20Balance,
  ERC20Contract,
  ERC20Transfer
} from '../../../generated/schema';
import {ERC20} from '../../../generated/templates/DaoTemplate/ERC20';
import {ERC20_transfer, ERC20_transferFrom, TransferType} from './common';

export function fetchERC20(address: Address): ERC20Contract | null {
  let erc20 = ERC20.bind(address);

  // Try load entry
  let contract = ERC20Contract.load(address.toHexString());
  if (contract != null) {
    return contract;
  }

  contract = new ERC20Contract(address.toHexString());

  let try_name = erc20.try_name();
  let try_symbol = erc20.try_symbol();
  let totalSupply = erc20.try_totalSupply();
  if (totalSupply.reverted) {
    return null;
  }
  contract.name = try_name.reverted ? '' : try_name.value;
  contract.symbol = try_symbol.reverted ? '' : try_symbol.value;

  contract.save();

  return contract;
}

export function createERC20Transfer(
  daoId: string,
  token: Address,
  from: Address,
  to: Address,
  amount: BigInt,
  txHash: Bytes,
  timestamp: BigInt
): ERC20Transfer {
  let id = daoId
    .concat('-')
    .concat(token.toHexString())
    .concat('-')
    .concat(from.toHexString())
    .concat('-')
    .concat(to.toHexString())
    .concat('-')
    .concat(amount.toString())
    .concat('-')
    .concat(txHash.toHexString());
  let erc20Transfer = new ERC20Transfer(id);
  erc20Transfer.from = from;
  erc20Transfer.to = to;
  erc20Transfer.dao = daoId;
  erc20Transfer.amount = amount;
  erc20Transfer.txHash = txHash;
  erc20Transfer.createdAt = timestamp;

  return erc20Transfer;
}

export function updateERC20Balance(
  token: Address,
  dao: string,
  amount: BigInt,
  timestamp: BigInt,
  type: TransferType
): void {
  let balanceId = dao + '_' + token.toHexString();
  let erc20Balance = ERC20Balance.load(balanceId);
  if (!erc20Balance) {
    erc20Balance = new ERC20Balance(balanceId);
    erc20Balance.dao = dao;
    erc20Balance.token = token.toHexString();
    erc20Balance.balance = BigInt.zero();
  }

  // TODO: IF IT REVERTS, SHALL WE TRY TO use amount ?
  let erc20 = ERC20.bind(token);
  let balance = erc20.try_balanceOf(Address.fromString(dao));
  if (!balance.reverted) {
    erc20Balance.balance = balance.value;
  }

  erc20Balance.lastUpdated = timestamp;
  erc20Balance.save();
}

export function handleERC20Action(
  token: Address,
  dao: Address,
  proposalId: string,
  data: Bytes,
  timestamp: BigInt,
  txHash: Bytes
): void {
  let contract = fetchERC20(token);
  if (!contract) {
    return;
  }

  let decodeABI = '';

  let functionSelector = data.toHexString().substring(0, 10);
  let calldata = data.toHexString().slice(10);

  if (functionSelector == ERC20_transfer) {
    decodeABI = '(address,uint256)';
  }

  if (functionSelector == ERC20_transferFrom) {
    decodeABI = '(address,address,uint256)';
  }

  let decoded = ethereum.decode(decodeABI, Bytes.fromHexString(calldata));

  if (!decoded) {
    return;
  }

  let tuple = decoded.toTuple();

  let from = new Address(0);
  let to = new Address(0);
  let amount = BigInt.zero();

  if (functionSelector == ERC20_transfer) {
    from = dao;
    to = tuple[0].toAddress();
    amount = tuple[1].toBigInt();
  }

  if (functionSelector == ERC20_transferFrom) {
    from = tuple[0].toAddress();
    to = tuple[1].toAddress();
    amount = tuple[2].toBigInt();
  }

  // Ambiguity ! No need to store transfer such as this.s
  if (from == to) {
    return;
  }

  let daoId = dao.toHexString();

  let erc20Transfer = createERC20Transfer(
    daoId,
    token,
    from,
    to,
    amount,
    txHash,
    timestamp
  );
  erc20Transfer.token = contract.id;
  erc20Transfer.proposal = proposalId;

  // If from/to both aren't equal to dao, it means
  // dao must have been approved for the `amount`
  // and played the role of transfering between 2 parties.
  if (from != dao && to != dao) {
    erc20Transfer.type = 'None'; // No idea
    erc20Transfer.save();
    return;
  }

  if (from != dao && to == dao) {
    // 1. some party `y` approved `x` tokenId to the dao.
    // 2. dao calls transferFrom as an action to transfer it from `y` to itself.
    erc20Transfer.type = 'Deposit';

    updateERC20Balance(token, daoId, amount, timestamp, TransferType.Deposit);
  } else {
    // from is dao address, to is some other address
    erc20Transfer.type = 'Withdraw';

    updateERC20Balance(token, daoId, amount, timestamp, TransferType.Withdraw);
  }

  erc20Transfer.save();
}

export function handleERC20Deposit(
  dao: Address,
  token: Address,
  from: Address,
  to: Address,
  amount: BigInt,
  txHash: Bytes,
  timestamp: BigInt
): void {
  let contract = fetchERC20(token);
  if (!contract) {
    return;
  }

  let daoId = dao.toHexString();

  let erc20Transfer = createERC20Transfer(
    daoId,
    token,
    from,
    to,
    amount,
    txHash,
    timestamp
  );
  erc20Transfer.token = contract.id;
  erc20Transfer.type = 'Deposit';

  erc20Transfer.save();

  updateERC20Balance(token, daoId, amount, timestamp, TransferType.Deposit);
}
