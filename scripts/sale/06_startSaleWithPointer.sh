#!/usr/bin/env bash
set -e

export CARDANO_NODE_SOCKET_PATH=$(cat ../data/path_to_socket.sh)
cli=$(cat ../data/path_to_cli.sh)
network=$(cat ../data/network.sh)

# staking contract
stake_script_path="../../contracts/stake_contract.plutus"

# bundle sale contract
sale_script_path="../../contracts/sale_contract.plutus"
script_address=$(${cli} conway address build --payment-script-file ${sale_script_path} --stake-script-file ${stake_script_path} ${network})

# pointer minter key
newm_pkh=$(${cli} conway address key-hash --payment-verification-key-file ../wallets/newm-wallet/payment.vkey)

# collat, artist, reference
artist_address=$(cat ../wallets/artist-wallet/payment.addr)
artist_pkh=$(${cli} conway address key-hash --payment-verification-key-file ../wallets/artist-wallet/payment.vkey)

#
collat_address=$(cat ../wallets/collat-wallet/payment.addr)
collat_pkh=$(${cli} conway address key-hash --payment-verification-key-file ../wallets/collat-wallet/payment.vkey)

pointer_pid=$(cat ../../hashes/pointer_policy.hash)
pid=$(jq -r '.fields[1].fields[0].bytes' ../data/sale/sale-datum.json)
tkn=$(jq -r '.fields[1].fields[1].bytes' ../data/sale/sale-datum.json)
total_amt=100000000

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
echo $script_tx_in

LOVELACE_VALUE=$(jq -r --arg alltxin "" --arg artistPkh "${artist_pkh}" --arg pid "${pid}" --arg tkn "${tkn}" 'to_entries[] | select(.value.value[$pid] // empty | keys[0] == $tkn) | .value.value.lovelace' ../tmp/script_utxo.json)
echo LOVELACE: $LOVELACE_VALUE
CURRENT_VALUE=$(jq -r --arg alltxin "" --arg artistPkh "${artist_pkh}" --arg pid "${pid}" --arg tkn "${tkn}" 'to_entries[] | select(.value.value[$pid] // empty | keys[0] == $tkn) | .value.value[$pid][$tkn]' ../tmp/script_utxo.json)
echo BUNDLE: $CURRENT_VALUE
returning_asset="${CURRENT_VALUE} ${pid}.${tkn}"

POINTER_VALUE=$(jq -r --arg alltxin "" --arg artistPkh "${artist_pkh}" --arg pid "${pointer_pid}" --arg tkn "${pointer_tkn}" 'to_entries[] | select(.value.value[$pid] // empty | keys[0] == $tkn) | .value.value[$pid][$tkn]' ../tmp/script_utxo.json)

if [ ! -z "$POINTER_VALUE" ]; then
    echo "UTxO has pointer."
    exit 1
fi
prefix_555="ca11ab1e"

# first_utxo=$(jq -r 'keys[0]' ../tmp/script_utxo.json)
first_utxo=${script_tx_in}
string=${first_utxo}
IFS='#' read -ra array <<< "$string"

pointer_name=$(python3 -c "import sys; sys.path.append('../py/'); from getTokenName import token_name; token_name('${array[0]}', ${array[1]}, '${prefix_555}')")
echo -n $pointer_name > ../tmp/pointer.token

pointer_asset="1 ${pointer_pid}.${pointer_name}"
echo POINTER: $pointer_asset
# update the value map inside the start redeemer
jq \
--arg pid "$pointer_pid" \
--arg tkn "$pointer_name" \
'.fields[0].fields[0].bytes=$pid |
.fields[0].fields[1].bytes=$tkn |
.fields[0].fields[2].int=1' \
../data/sale/start-redeemer.json | sponge ../data/sale/start-redeemer.json

# compute the correct start redeemer 

# script_address_out="${script_address} + ${LOVELACE_VALUE} + ${returning_asset} + ${pointer_asset}"
change_value=$((${LOVELACE_VALUE} - 1000000))
script_address_out="${script_address} + ${change_value} + ${returning_asset} + ${pointer_asset}"
echo $script_address_out
#
# exit
#

echo -e "\033[0;36m Gathering Artist UTxO Information  \033[0m"
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
pointer_ref_utxo=$(${cli} conway transaction txid --tx-file ../tmp/pointer-reference-utxo.signed)

execution_unts="(0, 0)"

echo -e "\033[0;36m Building Tx \033[0m"
${cli} conway transaction build-raw \
    --out-file ../tmp/tx.draft \
    --protocol-params-file ../tmp/protocol.json \
    --read-only-tx-in-reference="${data_ref_utxo}#0" \
    --tx-in-collateral="${collat_utxo}" \
    --tx-in ${script_tx_in} \
    --spending-tx-in-reference="${script_ref_utxo}#1" \
    --spending-plutus-script-v3 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-execution-units="${execution_unts}" \
    --spending-reference-tx-in-redeemer-file ../data/sale/start-redeemer.json \
    --tx-out="${script_address_out}" \
    --tx-out-inline-datum-file ../data/sale/sale-datum.json \
    --mint="${pointer_asset}" \
    --mint-tx-in-reference="${pointer_ref_utxo}#1" \
    --mint-plutus-script-v3 \
    --policy-id="${pointer_pid}" \
    --mint-reference-tx-in-execution-units="${execution_unts}" \
    --mint-reference-tx-in-redeemer-file ../data/pointer/mint-redeemer.json \
    --required-signer-hash ${newm_pkh} \
    --required-signer-hash ${collat_pkh} \
    --fee 1000000

python3 -c "import sys, json; sys.path.append('../py/'); from tx_simulation import from_file; exe_units=from_file('../tmp/tx.draft', False, debug=False);print(json.dumps(exe_units))" > ../data/exe_units.json

cat ../data/exe_units.json

cpu=$(jq -r '.[0].cpu' ../data/exe_units.json)
mem=$(jq -r '.[0].mem' ../data/exe_units.json)

sale_execution_unts="(${cpu}, ${mem})"
echo $sale_execution_unts
sale_computation_fee=$(echo "0.0000721*${cpu} + 0.0577*${mem}" | bc)
sale_computation_fee_int=$(printf "%.0f" "$sale_computation_fee")

cpu=$(jq -r '.[1].cpu' ../data/exe_units.json)
mem=$(jq -r '.[1].mem' ../data/exe_units.json)

pointer_execution_unts="(${cpu}, ${mem})"
echo $pointer_execution_unts
pointer_computation_fee=$(echo "0.0000721*${cpu} + 0.0577*${mem}" | bc)
pointer_computation_fee_int=$(printf "%.0f" "$pointer_computation_fee")

# exit

size=$(${cli} conway query ref-script-size \
${network} \
--output-json \
--tx-in="${script_ref_utxo}#1" \
--tx-in="${pointer_ref_utxo}#1" | jq -r '.refInputScriptSize'
)

FEE=$(${cli} conway transaction calculate-min-fee \
--tx-body-file ../tmp/tx.draft \
${network} \
--protocol-params-file ../tmp/protocol.json \
--reference-script-size ${size} \
--witness-count 3)
fee=$(echo $FEE | rev | cut -c 9- | rev)

total_fee=$((${fee} + ${sale_computation_fee_int} + ${pointer_computation_fee_int}))
echo Tx Fee: $total_fee
change_value=$((${LOVELACE_VALUE} - ${total_fee}))
script_address_out="${script_address} + ${change_value} + ${returning_asset} + ${pointer_asset}"

# exit

echo "Return OUTPUT: "${script_address_out}

${cli} conway transaction build-raw \
    --out-file ../tmp/tx.draft \
    --protocol-params-file ../tmp/protocol.json \
    --read-only-tx-in-reference="${data_ref_utxo}#0" \
    --tx-in-collateral="${collat_utxo}" \
    --tx-in ${script_tx_in} \
    --spending-tx-in-reference="${script_ref_utxo}#1" \
    --spending-plutus-script-v3 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-execution-units="${sale_execution_unts}" \
    --spending-reference-tx-in-redeemer-file ../data/sale/start-redeemer.json \
    --tx-out="${script_address_out}" \
    --tx-out-inline-datum-file ../data/sale/sale-datum.json  \
    --mint="${pointer_asset}" \
    --mint-tx-in-reference="${pointer_ref_utxo}#1" \
    --mint-plutus-script-v3 \
    --policy-id="${pointer_pid}" \
    --mint-reference-tx-in-execution-units="${pointer_execution_unts}" \
    --mint-reference-tx-in-redeemer-file ../data/pointer/mint-redeemer.json \
    --required-signer-hash ${newm_pkh} \
    --required-signer-hash ${collat_pkh} \
    --fee ${total_fee}
#
# exit
#
echo -e "\033[0;36m Signing \033[0m"
${cli} conway transaction sign \
    --signing-key-file ../wallets/newm-wallet/payment.skey \
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