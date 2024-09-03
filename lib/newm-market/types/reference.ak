use aiken/crypto.{ScriptHash, VerificationKeyHash}
use aiken/primitive/bytearray
use cardano/assets.{AssetName, Lovelace, PolicyId}
use cardano/certificate.{StakePoolId}
use types/wallet.{Wallet}

// staking info
pub type Staking {
  pool_id: StakePoolId,
  reward_wallet: Wallet,
}

// keepers are like admins
pub type Keepers {
  pkhs: List<VerificationKeyHash>,
  threshold: Int,
}

/// All keepers must have valid length public key hashes. There must be at
/// at least one keeper and the threshold must be logical with respect to the
/// list of keepers.
///
pub fn is_valid_keepers(keepers: Keepers) -> Bool {
  do_is_valid_keepers(keepers.pkhs, 0, keepers.threshold)
}

fn do_is_valid_keepers(
  keepers: List<VerificationKeyHash>,
  counter: Int,
  threshold: Int,
) -> Bool {
  when keepers is {
    [] -> and {
        counter > 0,
        counter >= threshold,
      }
    [pkh, ..pkhs] ->
      if bytearray.length(pkh) == 28 {
        // valid length count it
        do_is_valid_keepers(pkhs, counter + 1, threshold)
      } else {
        // not a valid pkh
        False
      }
  }
}

// contract validator hashes
pub type Contracts {
  sale: ScriptHash,
  queue: ScriptHash,
  band: ScriptHash,
  vault: ScriptHash,
  stake: ScriptHash,
}

/// All the contract validator hashes must be length 28. The stake validator
/// can be empty or length 28.
pub fn is_valid_contracts(contracts: Contracts) -> Bool {
  and {
    bytearray.length(contracts.sale) == 28,
    bytearray.length(contracts.queue) == 28,
    bytearray.length(contracts.band) == 28,
    bytearray.length(contracts.vault) == 28,
    or {
      bytearray.is_empty(contracts.stake),
      bytearray.length(contracts.stake) == 28,
    },
  }
}

pub type Fees {
  purchase_queue_bound: Lovelace,
  refund_queue_bound: Lovelace,
  start_sale_bound: Lovelace,
}

/// The tx fee must be less than equal to the upper bound.
///
pub fn valid_tx_fee(fee: Lovelace, upper_bound: Lovelace) -> Bool {
  fee <= upper_bound
}

/// Assumes a single monster policy id but many monster prefixes. The batcher
/// policy id may change but the name is always constant.
///
pub type BatcherData {
  monster_pid1: PolicyId,
  monster_pid2: PolicyId,
  monster_prefixes: List<ByteArray>,
  batcher_pid: PolicyId,
}

/// Holds the oracle feed validator key hash and feed token, the profit policy
/// id and token name, and the profit margin.
///
pub type ProfitData {
  feed_vkh: ScriptHash,
  feed_pid: PolicyId,
  feed_tkn: AssetName,
  profit_pid: PolicyId,
  profit_tkn: AssetName,
  profit_margin: Int,
}

/// The reference data to be used inside other contracts.
pub type ReferenceDatum {
  hot_key: VerificationKeyHash,
  keepers: Keepers,
  staking: Staking,
  contracts: Contracts,
  fees: Fees,
  pointer: PolicyId,
  batcher_data: BatcherData,
  profit_data: ProfitData,
}
