#!/usr/bin/env bash
set -e

export CARDANO_NODE_SOCKET_PATH=$(cat ../data/path_to_socket.sh)
cli=$(cat ../data/path_to_cli.sh)
testnet_magic=$(cat ../data/testnet.magic)

# staking contract
stake_script_path="../../contracts/stake_contract.plutus"

# vault contract
vault_script_path="../../contracts/vault_contract.plutus"
script_address=$(${cli} address build --payment-script-file ${vault_script_path} --stake-script-file ${stake_script_path} --testnet-magic ${testnet_magic})

# collat, artist, reference
batcher_address=$(cat ../wallets/batcher-wallet/payment.addr)
batcher_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/batcher-wallet/payment.vkey)

newm_address=$(cat ../wallets/newm-wallet/payment.addr)
newm_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/newm-wallet/payment.vkey)

#
collat_address=$(cat ../wallets/collat-wallet/payment.addr)
collat_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/collat-wallet/payment.vkey)


echo -e "\033[0;36m Gathering Script UTxO Information  \033[0m"
${cli} query utxo \
    --address ${script_address} \
    --testnet-magic ${testnet_magic} \
    --out-file ../tmp/script_utxo.json
# transaction variables
TXNS=$(jq length ../tmp/script_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${script_address} \033[0m \n";
   exit;
fi
TXIN=$(jq -r --arg alltxin "" --arg pkh "${batcher_pkh}" 'to_entries[] | select(.value.inlineDatum.fields[0].bytes == $pkh) | .key | . + $alltxin + " --tx-in"' ../tmp/script_utxo.json)
script_tx_in=${TXIN::-8}
echo Script UTxO: $script_tx_in

lovelace=$(jq -r --arg alltxin "" --arg pkh "${batcher_pkh}" 'to_entries[] | select(.value.inlineDatum.fields[0].bytes == $pkh) | .value.value.lovelace' ../tmp/script_utxo.json)

min_utxo=10000000

script_address_out="${script_address} + ${min_utxo}"
echo Output: $script_address_out
#
# exit
#
echo -e "\033[0;36m Gathering Batcher UTxO Information  \033[0m"
${cli} query utxo \
    --testnet-magic ${testnet_magic} \
    --address ${batcher_address} \
    --out-file ../tmp/batcher_utxo.json
TXNS=$(jq length ../tmp/batcher_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${batcher_address} \033[0m \n";
   exit;
fi
alltxin=""
TXIN=$(jq -r --arg alltxin "" 'keys[] | . + $alltxin + " --tx-in"' ../tmp/batcher_utxo.json)
batcher_tx_in=${TXIN::-8}

echo -e "\033[0;36m Gathering Collateral UTxO Information  \033[0m"
${cli} query utxo \
    --testnet-magic ${testnet_magic} \
    --address ${collat_address} \
    --out-file ../tmp/collat_utxo.json
TXNS=$(jq length ../tmp/collat_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${collat_address} \033[0m \n";
   exit;
fi
collat_utxo=$(jq -r 'keys[0]' ../tmp/collat_utxo.json)

script_ref_utxo=$(${cli} transaction txid --tx-file ../tmp/vault-reference-utxo.signed )
data_ref_utxo=$(${cli} transaction txid --tx-file ../tmp/referenceable-tx.signed )

# exit
echo -e "\033[0;36m Building Tx \033[0m"
FEE=$(${cli} transaction build \
    --babbage-era \
    --out-file ../tmp/tx.draft \
    --change-address ${batcher_address} \
    --read-only-tx-in-reference="${data_ref_utxo}#0" \
    --tx-in-collateral="${collat_utxo}" \
    --tx-in ${batcher_tx_in} \
    --tx-in ${script_tx_in} \
    --spending-tx-in-reference="${script_ref_utxo}#1" \
    --spending-plutus-script-v2 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-redeemer-file ../data/vault/sub-to-vault-redeemer.json \
    --tx-out="${script_address_out}" \
    --tx-out-inline-datum-file ../data/vault/vault-datum.json  \
    --required-signer-hash ${batcher_pkh} \
    --required-signer-hash ${collat_pkh} \
    --required-signer-hash ${newm_pkh} \
    --testnet-magic ${testnet_magic})

IFS=':' read -ra VALUE <<< "${FEE}"
IFS=' ' read -ra FEE <<< "${VALUE[1]}"
FEE=${FEE[1]}
echo -e "\033[1;32m Fee: \033[0m" $FEE
#
# exit
#
echo -e "\033[0;36m Signing \033[0m"
${cli} transaction sign \
    --signing-key-file ../wallets/batcher-wallet/payment.skey \
    --signing-key-file ../wallets/collat-wallet/payment.skey \
    --signing-key-file ../wallets/newm-wallet/payment.skey \
    --tx-body-file ../tmp/tx.draft \
    --out-file ../tmp/tx.signed \
    --testnet-magic ${testnet_magic}
#    
# exit
#
echo -e "\033[0;36m Submitting \033[0m"
${cli} transaction submit \
    --testnet-magic ${testnet_magic} \
    --tx-file ../tmp/tx.signed

tx=$(cardano-cli transaction txid --tx-file ../tmp/tx.signed)
echo "Tx Hash:" $tx