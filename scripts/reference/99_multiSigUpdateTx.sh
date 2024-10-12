#!/usr/bin/env bash
set -e

export CARDANO_NODE_SOCKET_PATH=$(cat ../data/path_to_socket.sh)
cli=$(cat ../data/path_to_cli.sh)
network=$(cat ../data/network.sh)

# get current params
${cli} conway query protocol-parameters ${network} --out-file ../tmp/protocol.json

# staked smart contract address
script_path="../../contracts/reference_contract.plutus"
script_address=$(${cli} conway address build --payment-script-file ${script_path} ${network})

# collat
collat_address=$(cat ../wallets/collat-wallet/payment.addr)
collat_pkh=$(${cli} conway address key-hash --payment-verification-key-file ../wallets/collat-wallet/payment.vkey)

# starter
newm_address=$(cat ../wallets/newm-wallet/payment.addr)
newm_pkh=$(${cli} conway address key-hash --payment-verification-key-file ../wallets/newm-wallet/payment.vkey)

# multisig
keeper1_pkh=$(cat ../wallets/keeper1-wallet/payment.hash)
keeper2_pkh=$(cat ../wallets/keeper2-wallet/payment.hash)
keeper3_pkh=$(cat ../wallets/keeper3-wallet/payment.hash)

# asset to trade
policy_id=$(jq -r '.starterPid' ../../config.json)
token_name=$(jq -r '.starterTkn' ../../config.json)
asset="1 ${policy_id}.${token_name}"

min_value=$(${cli} conway transaction calculate-min-required-utxo \
    --protocol-params-file ../tmp/protocol.json \
    --tx-out-inline-datum-file ../data/reference/reference-datum.json \
    --tx-out="${script_address} + 5000000 + ${asset}" | tr -dc '0-9')

script_address_out="${script_address} + ${min_value} + ${asset}"
echo "Script OUTPUT: "${script_address_out}
#
# exit
#
# get deleg utxo
echo -e "\033[0;36m Gathering UTxO Information  \033[0m"
${cli} conway query utxo \
    ${network} \
    --address ${newm_address} \
    --out-file ../tmp/newm_utxo.json

TXNS=$(jq length ../tmp/newm_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${newm_address} \033[0m \n";
   exit;
fi
alltxin=""
TXIN=$(jq -r --arg alltxin "" 'keys[] | . + $alltxin + " --tx-in"' ../tmp/newm_utxo.json)
newm_tx_in=${TXIN::-8}

# get script utxo
echo -e "\033[0;36m Gathering Script UTxO Information  \033[0m"
${cli} conway query utxo \
    --address ${script_address} \
    ${network} \
    --out-file ../tmp/script_utxo.json
TXNS=$(jq length ../tmp/script_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${script_address} \033[0m \n";
   exit;
fi
alltxin=""
TXIN=$(jq -r --arg alltxin "" --arg policy_id "$policy_id" --arg token_name "$token_name" 'to_entries[] | select(.value.value[$policy_id][$token_name] == 1) | .key | . + $alltxin + " --tx-in"' ../tmp/script_utxo.json)
script_tx_in=${TXIN::-8}

# collat info
echo -e "\033[0;36m Gathering Collateral UTxO Information  \033[0m"
${cli} conway query utxo \
    ${network} \
    --address ${collat_address} \
    --out-file ../tmp/collat_utxo.json

TXNS=$(jq length ../tmp/collat_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${collat_address} \033[0m \n";
   exit;
fi
collat_tx_in=$(jq -r 'keys[0]' ../tmp/collat_utxo.json)

# script reference utxo
script_ref_utxo=$(${cli} conway transaction txid --tx-file ../tmp/reference-reference-utxo.signed )

echo -e "\033[0;36m Building Tx \033[0m"
FEE=$(${cli} conway transaction build \
    --calculate-plutus-script-cost ../tmp/tx.cost \
    --change-address ${newm_address} \
    --tx-in-collateral ${collat_tx_in} \
    --tx-in ${newm_tx_in} \
    --tx-in ${script_tx_in} \
    --spending-tx-in-reference="${script_ref_utxo}#1" \
    --spending-plutus-script-v3 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-redeemer-file ../data/reference/update-redeemer.json \
    --tx-out="${script_address_out}" \
    --tx-out-inline-datum-file ../data/reference/reference-datum.json \
    --required-signer-hash ${newm_pkh} \
    --required-signer-hash ${collat_pkh} \
    --required-signer-hash ${keeper1_pkh} \
    --required-signer-hash ${keeper2_pkh} \
    --required-signer-hash ${keeper3_pkh} \
    ${network})

fee=$(echo $FEE | grep -o '[0-9]\+')
echo -e "\033[1;32m Fee:\033[0m" $fee

mem=$(cat ../tmp/tx.cost | jq -r '.[0].executionUnits.memory')
cpu=$(cat ../tmp/tx.cost | jq -r '.[0].executionUnits.steps')

execution_units="(${cpu}, ${mem})"
echo -e "\033[1;32m Units:\033[0m" $execution_units


${cli} conway transaction build-raw \
    --out-file ../tmp/tx.draft \
    --protocol-params-file ../tmp/protocol.json \
    --tx-in-collateral="${collat_tx_in}" \
    --tx-in ${newm_tx_in} \
    --tx-in ${script_tx_in} \
    --spending-tx-in-reference="${script_ref_utxo}#1" \
    --spending-plutus-script-v3 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-execution-units="${execution_units}" \
    --spending-reference-tx-in-redeemer-file ../data/reference/update-redeemer.json \
    --tx-out="${script_address_out}" \
    --tx-out-inline-datum-file ../data/reference/reference-datum.json \
    --fee ${fee}