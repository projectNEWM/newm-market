#!/usr/bin/env bash
set -e

export CARDANO_NODE_SOCKET_PATH=$(cat ../data/path_to_socket.sh)
cli=$(cat ../data/path_to_cli.sh)
network=$(cat ../data/network.sh)

# staking contract
stake_script_path="../../contracts/stake_contract.plutus"

# vault contract
vault_script_path="../../contracts/vault_contract.plutus"
script_address=$(${cli} conway address build --payment-script-file ${vault_script_path} --stake-script-file ${stake_script_path} ${network})

# collat, buyer, reference
batcher_path="batcher-wallet"
batcher_address=$(cat ../wallets/${batcher_path}/payment.addr)

# this assumes no entry tokens
script_address_out="${script_address} + 10000000"

echo "Script OUTPUT: "${script_address_out}
#
# exit
#
echo -e "\033[0;36m Gathering Batcher UTxO Information  \033[0m"
${cli} conway query utxo \
    ${network} \
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

# exit
echo -e "\033[0;36m Building Tx \033[0m"
FEE=$(${cli} conway transaction build \
    --out-file ../tmp/tx.draft \
    --change-address ${batcher_address} \
    --tx-in ${batcher_tx_in} \
    --tx-out="${script_address_out}" \
    --tx-out-inline-datum-file ../data/vault/vault-datum.json  \
    --tx-out="${script_address_out}" \
    --tx-out-inline-datum-file ../data/vault/vault-datum.json  \
    ${network})

IFS=':' read -ra VALUE <<< "${FEE}"
IFS=' ' read -ra FEE <<< "${VALUE[1]}"
FEE=${FEE[1]}
echo -e "\033[1;32m Fee: \033[0m" $FEE
#
# exit
#
echo -e "\033[0;36m Signing \033[0m"
${cli} conway transaction sign \
    --signing-key-file ../wallets/${batcher_path}/payment.skey \
    --tx-body-file ../tmp/tx.draft \
    --out-file ../tmp/tx.signed \
    ${network}
#    
# exit
#
echo -e "\033[0;36m Submitting \033[0m"
${cli} conway transaction submit \
    ${network} \
    --tx-file ../tmp/tx.signed

tx=$(${cli} conway transaction txid --tx-file ../tmp/tx.signed)
echo "Tx Hash:" $tx
