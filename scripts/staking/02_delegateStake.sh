#!/usr/bin/env bash
set -e

export CARDANO_NODE_SOCKET_PATH=$(cat ../data/path_to_socket.sh)
cli=$(cat ../data/path_to_cli.sh)
network=$(cat ../data/network.sh)

# get params
${cli} conway query protocol-parameters ${network} --out-file ../tmp/protocol.json

# collateral for stake contract
collat_address=$(cat ../wallets/collat-wallet/payment.addr)
collat_pkh=$(${cli} conway address key-hash --payment-verification-key-file ../wallets/collat-wallet/payment.vkey)

# multisig
keeper1_pkh=$(${cli} conway address key-hash --payment-verification-key-file ../wallets/keeper1-wallet/payment.vkey)
keeper2_pkh=$(${cli} conway address key-hash --payment-verification-key-file ../wallets/keeper2-wallet/payment.vkey)
keeper3_pkh=$(${cli} conway address key-hash --payment-verification-key-file ../wallets/keeper3-wallet/payment.vkey)

# payee
newm_address=$(cat ../wallets/newm-wallet/payment.addr)
#
# exit
#
echo -e "\033[0;36m Gathering Payee UTxO Information  \033[0m"
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
TXIN=$(jq -r --arg alltxin "" 'to_entries[] | select(.value.value | length < 2) | .key | . + $alltxin + " --tx-in"' ../tmp/newm_utxo.json)
newm_tx_in=${TXIN::-8}

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
collat_utxo=$(jq -r 'keys[0]' ../tmp/collat_utxo.json)

script_ref_utxo=$(${cli} conway transaction txid --tx-file ../tmp/stake-reference-utxo.signed )
data_ref_utxo=$(${cli} conway transaction txid --tx-file ../tmp/referenceable-tx.signed )

echo -e "\033[0;36m Building Tx \033[0m"
FEE=$(${cli} conway transaction build \
    --out-file ../tmp/tx.draft \
    --change-address ${newm_address} \
    --read-only-tx-in-reference="${data_ref_utxo}#0" \
    --tx-in-collateral="${collat_utxo}" \
    --tx-in ${newm_tx_in} \
    --certificate ../../certs/deleg.cert \
    --certificate-tx-in-reference="${script_ref_utxo}#1" \
    --certificate-plutus-script-v3 \
    --certificate-reference-tx-in-redeemer-file ../data/staking/delegate-redeemer.json \
    --required-signer-hash ${collat_pkh} \
    --required-signer-hash ${keeper1_pkh} \
    --required-signer-hash ${keeper2_pkh} \
    --required-signer-hash ${keeper3_pkh} \
    ${network})

IFS=':' read -ra VALUE <<< "${FEE}"
IFS=' ' read -ra FEE <<< "${VALUE[1]}"
echo -e "\033[1;32m Fee:\033[0m" $FEE
#
# exit
#
echo -e "\033[0;36m Signing \033[0m"
${cli} conway transaction sign \
    --signing-key-file ../wallets/newm-wallet/payment.skey \
    --signing-key-file ../wallets/collat-wallet/payment.skey \
    --signing-key-file ../wallets/keeper1-wallet/payment.skey \
    --signing-key-file ../wallets/keeper2-wallet/payment.skey \
    --signing-key-file ../wallets/keeper3-wallet/payment.skey \
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