#!/usr/bin/env bash
set -e

export CARDANO_NODE_SOCKET_PATH=$(cat ../data/path_to_socket.sh)
cli=$(cat ../data/path_to_cli.sh)
network=$(cat ../data/network.sh)

# staking contract
stake_script_path="../../contracts/stake_contract.plutus"

# bundle sale contract
queue_script_path="../../contracts/queue_contract.plutus"
script_address=$(${cli} conway address build --payment-script-file ${queue_script_path} --stake-script-file ${stake_script_path} ${network})

# collat, buyer, reference
buyer_path="buyer1-wallet"
buyer_address=$(cat ../wallets/${buyer_path}/payment.addr)
buyer_pkh=$(${cli} conway address key-hash --payment-verification-key-file ../wallets/${buyer_path}/payment.vkey)
#
collat_address=$(cat ../wallets/collat-wallet/payment.addr)
collat_pkh=$(${cli} conway address key-hash --payment-verification-key-file ../wallets/collat-wallet/payment.vkey)

echo -e "\033[0;36m Gathering Script UTxO Information  \033[0m"
${cli} conway query utxo \
    --address ${script_address} \
    ${network} \
    --out-file ../tmp/script_utxo.json
# transaction variables
TXNS=$(jq length ../tmp/script_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${script_address} \033[0m \n";
   exit;
fi
TXIN=$(jq -r --arg alltxin "" --arg buyerPkh "${buyer_pkh}" 'to_entries[] | select(.value.inlineDatum.fields[0].fields[0].bytes == $buyerPkh) | .key | . + $alltxin + " --tx-in"' ../tmp/script_utxo.json)
script_tx_in=${TXIN::-8}

#
# exit
#
echo -e "\033[0;36m Gathering Buyer UTxO Information  \033[0m"
${cli} conway query utxo \
    ${network} \
    --address ${buyer_address} \
    --out-file ../tmp/buyer_utxo.json
TXNS=$(jq length ../tmp/buyer_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${buyer_address} \033[0m \n";
   exit;
fi
alltxin=""
TXIN=$(jq -r --arg alltxin "" 'keys[] | . + $alltxin + " --tx-in"' ../tmp/buyer_utxo.json)
buyer_tx_in=${TXIN::-8}

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
collat_utxo=$(jq -r 'keys[0]' ../tmp/collat_utxo.json)

script_ref_utxo=$(${cli} conway transaction txid --tx-file ../tmp/queue-reference-utxo.signed )
data_ref_utxo=$(${cli} conway transaction txid --tx-file ../tmp/referenceable-tx.signed )

# exit
echo -e "\033[0;36m Building Tx \033[0m"
FEE=$(${cli} conway transaction build \
    --out-file ../tmp/tx.draft \
    --change-address ${buyer_address} \
    --tx-in-collateral="${collat_utxo}" \
    --read-only-tx-in-reference="${data_ref_utxo}#0" \
    --tx-in ${buyer_tx_in} \
    --tx-in ${script_tx_in} \
    --spending-tx-in-reference="${script_ref_utxo}#1" \
    --spending-plutus-script-v3 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-redeemer-file ../data/queue/cancel-redeemer.json \
    --required-signer-hash ${buyer_pkh} \
    --required-signer-hash ${collat_pkh} \
    ${network})

IFS=':' read -ra VALUE <<< "${FEE}"
IFS=' ' read -ra FEE <<< "${VALUE[1]}"
echo -e "\033[1;32m Fee:\033[0m" $FEE
#
# exit
#
echo -e "\033[0;36m Signing \033[0m"
${cli} conway transaction sign \
    --signing-key-file ../wallets/${buyer_path}/payment.skey \
    --signing-key-file ../wallets/collat-wallet/payment.skey \
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