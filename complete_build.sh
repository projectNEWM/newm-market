#!/usr/bin/env bash
set -e

function cat_file_or_empty() {
  if [ -e "$1" ]; then
    cat "$1"
  else
    echo ""
  fi
}

# create directories if dont exist
mkdir -p contracts
mkdir -p hashes
mkdir -p certs

# remove old files
rm contracts/* || true
rm hashes/* || true
rm certs/* || true
rm -fr build/ || true

# build out the entire script
echo -e "\033[1;34m Building Contracts \033[0m"

# remove all traces
# aiken build --trace-level silent --filter-traces user-defined

# keep the traces
aiken build --trace-level verbose --filter-traces all

# the reference token
pid=$(jq -r '.starterPid' config.json)
tkn=$(jq -r '.starterTkn' config.json)
pid_cbor=$(python3 -c "import cbor2;hex_string='${pid}';data = bytes.fromhex(hex_string);encoded = cbor2.dumps(data);print(encoded.hex())")
tkn_cbor=$(python3 -c "import cbor2;hex_string='${tkn}';data = bytes.fromhex(hex_string);encoded = cbor2.dumps(data);print(encoded.hex())")

# The pool to stake at
poolId=$(jq -r '.poolId' config.json)

echo -e "\033[1;33m Convert Reference Contract \033[0m"
aiken blueprint apply -o plutus.json -v reference.contract.spend "${pid_cbor}"
aiken blueprint apply -o plutus.json -v reference.contract.spend "${tkn_cbor}"
aiken blueprint convert -v reference.contract.spend > contracts/reference_contract.plutus
cardano-cli conway transaction policyid --script-file contracts/reference_contract.plutus > hashes/reference_contract.hash

# reference hash
ref=$(cat hashes/reference_contract.hash)
ref_cbor=$(python3 -c "import cbor2;hex_string='${ref}';data = bytes.fromhex(hex_string);encoded = cbor2.dumps(data);print(encoded.hex())")

echo -e "\033[1;33m Convert Stake Contract \033[0m"
aiken blueprint apply -o plutus.json -v staking.contract.withdraw "${pid_cbor}"
aiken blueprint apply -o plutus.json -v staking.contract.withdraw "${tkn_cbor}"
aiken blueprint apply -o plutus.json -v staking.contract.withdraw "${ref_cbor}"
aiken blueprint convert -v staking.contract.withdraw > contracts/stake_contract.plutus
cardano-cli conway transaction policyid --script-file contracts/stake_contract.plutus > hashes/stake.hash
cardano-cli conway stake-address registration-certificate --stake-script-file contracts/stake_contract.plutus --key-reg-deposit-amt 2000000 --out-file certs/stake.cert
cardano-cli conway stake-address stake-delegation-certificate --stake-script-file contracts/stake_contract.plutus --stake-pool-id ${poolId} --out-file certs/deleg.cert

echo -e "\033[1;33m Convert Sale Contract \033[0m"
aiken blueprint apply -o plutus.json -v sale.contract.spend "${pid_cbor}"
aiken blueprint apply -o plutus.json -v sale.contract.spend "${tkn_cbor}"
aiken blueprint apply -o plutus.json -v sale.contract.spend "${ref_cbor}"
aiken blueprint convert -v sale.contract.spend > contracts/sale_contract.plutus
cardano-cli conway transaction policyid --script-file contracts/sale_contract.plutus > hashes/sale.hash

echo -e "\033[1;33m Convert Queue Contract \033[0m"
aiken blueprint apply -o plutus.json -v queue.contract.spend "${pid_cbor}"
aiken blueprint apply -o plutus.json -v queue.contract.spend "${tkn_cbor}"
aiken blueprint apply -o plutus.json -v queue.contract.spend "${ref_cbor}"
aiken blueprint convert -v queue.contract.spend > contracts/queue_contract.plutus
cardano-cli conway transaction policyid --script-file contracts/queue_contract.plutus > hashes/queue.hash

echo -e "\033[1;33m Convert Pointer Contract \033[0m"
aiken blueprint apply -o plutus.json -v pointer.contract.mint "${pid_cbor}"
aiken blueprint apply -o plutus.json -v pointer.contract.mint "${tkn_cbor}"
aiken blueprint apply -o plutus.json -v pointer.contract.mint "${ref_cbor}"
aiken blueprint convert -v pointer.contract.mint > contracts/pointer_contract.plutus
cardano-cli conway transaction policyid --script-file contracts/pointer_contract.plutus > hashes/pointer_policy.hash

echo -e "\033[1;33m Convert Band Lock Contract \033[0m"
aiken blueprint apply -o plutus.json -v band.contract.spend "${pid_cbor}"
aiken blueprint apply -o plutus.json -v band.contract.spend "${tkn_cbor}"
aiken blueprint apply -o plutus.json -v band.contract.spend "${ref_cbor}"
aiken blueprint convert -v band.contract.spend > contracts/band_lock_contract.plutus
cardano-cli conway transaction policyid --script-file contracts/band_lock_contract.plutus > hashes/band_lock.hash

echo -e "\033[1;33m Convert Vault Contract \033[0m"
aiken blueprint apply -o plutus.json -v vault.contract.spend "${pid_cbor}"
aiken blueprint apply -o plutus.json -v vault.contract.spend "${tkn_cbor}"
aiken blueprint apply -o plutus.json -v vault.contract.spend "${ref_cbor}"
aiken blueprint convert -v vault.contract.spend > contracts/vault_contract.plutus
cardano-cli conway transaction policyid --script-file contracts/vault_contract.plutus > hashes/vault.hash

echo -e "\033[1;33m Convert Batcher Token Contract \033[0m"
aiken blueprint apply -o plutus.json -v batcher.contract.mint "${ref_cbor}"
aiken blueprint convert -v batcher.contract.mint > contracts/batcher_contract.plutus
cardano-cli conway transaction policyid --script-file contracts/batcher_contract.plutus > hashes/batcher.hash

###############################################################################
############## DATUM AND REDEEMER STUFF #######################################
###############################################################################
echo -e "\033[1;33m Updating Reference Datum \033[0m"
# keepers
pkh1=$(cat_file_or_empty ./scripts/wallets/keeper1-wallet/payment.hash)
pkh2=$(cat_file_or_empty ./scripts/wallets/keeper2-wallet/payment.hash)
pkh3=$(cat_file_or_empty ./scripts/wallets/keeper3-wallet/payment.hash)
pkhs="[{\"bytes\": \"$pkh1\"}, {\"bytes\": \"$pkh2\"}, {\"bytes\": \"$pkh3\"}]"
thres=2
# pool stuff
rewardPkh=$(cat_file_or_empty ./scripts/wallets/reward-wallet/payment.hash)
rewardSc=""
# validator hashes
saleHash=$(cat hashes/sale.hash)
queueHash=$(cat hashes/queue.hash)
bandHash=$(cat hashes/band_lock.hash)
vaultHash=$(cat hashes/vault.hash)
stakeHash=$(cat hashes/stake.hash)

# pointer hash
pointerHash=$(cat hashes/pointer_policy.hash)
batcherHash=$(cat hashes/batcher.hash)

# the purchase upper bound
pqb=$(jq -r '.purchaseQueueBound' config.json)
# the refund upper bound
rqb=$(jq -r '.refundQueueBound' config.json)
# the start upper bound
ssb=$(jq -r '.startSaleBound' config.json)

# This needs to be generated from the hot key in start info.
# Assume the hot key is all the keys for now
hotKey=$(jq -r '.hotKey' config.json)

cp ./scripts/data/reference/reference-datum.json ./scripts/data/reference/backup-reference-datum.json

feed_pkh=$(jq -r ' .feedHash' config.json)
feed_pid=$(jq -r ' .feedPid' config.json)
feed_tkn=$(jq -r '.feedTkn' config.json)

# update reference data
jq \
--arg hotKey "$hotKey" \
--argjson pkhs "$pkhs" \
--argjson thres "$thres" \
--arg poolId "$poolId" \
--arg rewardPkh "$rewardPkh" \
--arg rewardSc "$rewardSc" \
--arg storageHash "$storageHash" \
--arg bandHash "$bandHash" \
--arg saleHash "$saleHash" \
--arg queueHash "$queueHash" \
--arg vaultHash "$vaultHash" \
--arg stakeHash "$stakeHash" \
--argjson pqb "$pqb" \
--argjson rqb "$rqb" \
--argjson ssb "$ssb" \
--arg pointerHash "$pointerHash" \
--arg batcherHash "$batcherHash" \
--arg feed_pkh "$feed_pkh" \
--arg feed_pid "$feed_pid" \
--arg feed_tkn "$feed_tkn" \
'.fields[0].bytes=$hotKey | 
.fields[1].fields[0].list |= ($pkhs | .[0:length]) | 
.fields[1].fields[1].int=$thres | 
.fields[2].fields[0].bytes=$poolId |
.fields[2].fields[1].fields[0].bytes=$rewardPkh |
.fields[2].fields[1].fields[1].bytes=$rewardSc |
.fields[3].fields[0].bytes=$saleHash |
.fields[3].fields[1].bytes=$queueHash |
.fields[3].fields[2].bytes=$bandHash |
.fields[3].fields[3].bytes=$vaultHash |
.fields[3].fields[4].bytes=$stakeHash |
.fields[4].fields[0].int=$pqb |
.fields[4].fields[1].int=$rqb |
.fields[4].fields[2].int=$ssb |
.fields[5].bytes=$pointerHash |
.fields[6].fields[3].bytes=$batcherHash |
.fields[7].fields[0].bytes=$feed_pkh |
.fields[7].fields[1].bytes=$feed_pid |
.fields[7].fields[2].bytes=$feed_tkn
' \
./scripts/data/reference/reference-datum.json | sponge ./scripts/data/reference/reference-datum.json

# Update Staking Redeemer
echo -e "\033[1;33m Updating Stake Redeemer \033[0m"
stakeHash=$(cat_file_or_empty ./hashes/stake.hash)
jq \
--arg stakeHash "$stakeHash" \
'.fields[0].bytes=$stakeHash' \
./scripts/data/staking/delegate-redeemer.json | sponge ./scripts/data/staking/delegate-redeemer.json
jq \
--arg stakeHash "$stakeHash" \
'.fields[0].bytes=$stakeHash' \
./scripts/data/staking/register-redeemer.json | sponge ./scripts/data/staking/register-redeemer.json

backup="./scripts/data/reference/backup-reference-datum.json"
frontup="./scripts/data/reference/reference-datum.json"

# Get the SHA-256 hash values of the files using sha256sum and command substitution
hash1=$(sha256sum "$backup" | awk '{ print $1 }')
hash2=$(sha256sum "$frontup" | awk '{ print $1 }')

# Check if the hash values are equal using string comparison in an if statement
if [ "$hash1" = "$hash2" ]; then
  echo -e "\033[1;46mNo Datum Changes Required.\033[0m"
else
  echo -e "\033[1;43mA Datum Update Is Required.\033[0m"
fi

# end of build
echo -e "\033[1;32m Building Complete! \033[0m"