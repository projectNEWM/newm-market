#!/bin/bash
set -e

export CARDANO_NODE_SOCKET_PATH=$(cat ../data/path_to_socket.sh)
cli=$(cat ../data/path_to_cli.sh)
network=$(cat ../data/network.sh)

# staking contract
stake_script_path="../../contracts/stake_contract.plutus"

# bundle sale contract
sale_script_path="../../contracts/sale_contract.plutus"
script_address=$(${cli} conway address build --payment-script-file ${sale_script_path} --stake-script-file ${stake_script_path} ${network})

# collat, artist, reference
artist_address=$(cat ../wallets/artist-wallet/payment.addr)
artist_pkh=$(${cli} conway address key-hash --payment-verification-key-file ../wallets/artist-wallet/payment.vkey)

#
collat_address=$(cat ../wallets/collat-wallet/payment.addr)
collat_pkh=$(${cli} conway address key-hash --payment-verification-key-file ../wallets/collat-wallet/payment.vkey)

pointer_pid=$(cat ../../hashes/pointer_policy.hash)
pid=$(jq -r '.fields[1].fields[0].bytes' ../data/sale/sale-datum.json)
tkn=$(jq -r '.fields[1].fields[1].bytes' ../data/sale/sale-datum.json)
pointer_tkn=$(cat ../tmp/pointer.token)
total_amt=100000000

default_asset="${total_amt} ${pid}.${tkn}"

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
TXIN=$(jq -r --arg alltxin "" --arg tkn "${tkn}" 'to_entries[] | select(.value.inlineDatum.fields[1].fields[1].bytes == $tkn) | .key | . + $alltxin + " --tx-in"' ../tmp/script_utxo.json)
script_tx_in=${TXIN::-8}
echo Sale UTxO: $script_tx_in

LOVELACE_VALUE=$(jq -r --arg alltxin "" --arg artistPkh "${artist_pkh}" --arg pid "${pid}" --arg tkn "${tkn}" 'to_entries[] | select(.value.value[$pid] // empty | keys[0] == $tkn) | .value.value.lovelace' ../tmp/script_utxo.json)
utxo_value=$LOVELACE_VALUE
echo LOVELACE: $LOVELACE_VALUE

# exit
CURRENT_VALUE=$(jq -r --arg alltxin "" --arg artistPkh "${artist_pkh}" --arg pid "${pid}" --arg tkn "${tkn}" 'to_entries[] | select(.value.value[$pid] // empty | keys[0] == $tkn) | .value.value[$pid][$tkn]' ../tmp/script_utxo.json)
returning_asset="${CURRENT_VALUE} ${pid}.${tkn}"

POINTER_VALUE=$(jq -r --arg alltxin "" --arg artistPkh "${artist_pkh}" --arg pid "${pointer_pid}" --arg tkn "${pointer_tkn}" 'to_entries[] | select(.value.value[$pid] // empty | keys[0] == $tkn) | .value.value[$pid][$tkn]' ../tmp/script_utxo.json)

if [ ! -z "$POINTER_VALUE" ]; then
    echo "The pointer is on the utxo."
    exit 1
fi

if [[ CURRENT_VALUE -le 0 ]] ; then
    artist_address_out="${artist_address} + ${utxo_value}"
else
    artist_address_out="${artist_address} + ${utxo_value} + ${returning_asset}"
fi

echo "Return OUTPUT: "${artist_address_out}
#
# exit
#
echo -e "\033[0;36m Gathering Seller UTxO Information  \033[0m"
${cli} conway query utxo \
    ${network} \
    --address ${artist_address} \
    --out-file ../tmp/artist_utxo.json
TXNS=$(jq length ../tmp/artist_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${artist_address} \033[0m \n";
   exit;
fi
alltxin=""
TXIN=$(jq -r --arg alltxin "" 'keys[] | . + $alltxin + " --tx-in"' ../tmp/artist_utxo.json)
artist_tx_in=${TXIN::-8}

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

script_ref_utxo=$(${cli} conway transaction txid --tx-file ../tmp/sale-reference-utxo.signed )
data_ref_utxo=$(${cli} conway transaction txid --tx-file ../tmp/referenceable-tx.signed )

# exit
echo -e "\033[0;36m Building Tx \033[0m"
FEE=$(${cli} conway transaction build \
    --out-file ../tmp/tx.draft \
    --change-address ${artist_address} \
    --read-only-tx-in-reference="${data_ref_utxo}#0" \
    --tx-in-collateral="${collat_utxo}" \
    --tx-in ${artist_tx_in} \
    --tx-in ${script_tx_in} \
    --spending-tx-in-reference="${script_ref_utxo}#1" \
    --spending-plutus-script-v3 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-redeemer-file ../data/sale/remove-redeemer.json \
    --tx-out="${artist_address_out}" \
    --required-signer-hash ${artist_pkh} \
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
    --signing-key-file ../wallets/artist-wallet/payment.skey \
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