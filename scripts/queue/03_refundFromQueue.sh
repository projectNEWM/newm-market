#!/usr/bin/env bash
set -e

export CARDANO_NODE_SOCKET_PATH=$(cat ../data/path_to_socket.sh)
cli=$(cat ../data/path_to_cli.sh)
testnet_magic=$(cat ../data/testnet.magic)

# staking contract
stake_script_path="../../contracts/stake_contract.plutus"

# bundle sale contract
queue_script_path="../../contracts/queue_contract.plutus"
script_address=$(${cli} address build --payment-script-file ${queue_script_path} --stake-script-file ${stake_script_path} --testnet-magic ${testnet_magic})

# collat, buyer, reference
which_buyer="buyer1"
buyer_address=$(cat ../wallets/${which_buyer}-wallet/payment.addr)
buyer_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/${which_buyer}-wallet/payment.vkey)

#
batcher_address=$(cat ../wallets/batcher-wallet/payment.addr)
batcher_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/batcher-wallet/payment.vkey)

#
collat_address=$(cat ../wallets/collat-wallet/payment.addr)
collat_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/collat-wallet/payment.vkey)

# oracle feed
feed_addr="addr_test1wzn5ee2qaqvly3hx7e0nk3vhm240n5muq3plhjcnvx9ppjgf62u6a"
feed_pid=$(jq -r ' .feedPid' ../../config.json)
feed_tkn=$(jq -r '.feedTkn' ../../config.json)

# payment token
newm_pid="769c4c6e9bc3ba5406b9b89fb7beb6819e638ff2e2de63f008d5bcff"
newm_tkn="744e45574d"

echo -e "\033[0;36m Gathering Oracle Script UTxO Information  \033[0m"
${cli} query utxo \
    --address ${feed_addr} \
    --testnet-magic ${testnet_magic} \
    --out-file ../tmp/feed_utxo.json
TXNS=$(jq length ../tmp/feed_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${feed_addr} \033[0m \n";
   exit;
fi
alltxin=""
TXIN=$(jq -r --arg alltxin "" --arg policy_id "$feed_pid" --arg token_name "$feed_tkn" 'to_entries[] | select(.value.value[$policy_id][$token_name] == 1) | .key | . + $alltxin + " --tx-in"' ../tmp/feed_utxo.json)
feed_tx_in=${TXIN::-8}
echo Feed UTxO: $feed_tx_in
feed_datum=$(jq -r --arg policy_id "$feed_pid" --arg token_name "$feed_tkn" 'to_entries[] | select(.value.value[$policy_id][$token_name] == 1) | .value.inlineDatum' ../tmp/feed_utxo.json)
start_time=$(echo $feed_datum | jq -r '.fields[0].fields[0].map[1].v.int')
end_time=$(echo $feed_datum | jq -r '.fields[0].fields[0].map[2].v.int')
# subtract a second from it so its forced to be contained
timestamp=$(python -c "import datetime; print(datetime.datetime.utcfromtimestamp(${start_time} / 1000 + 1).strftime('%Y-%m-%dT%H:%M:%SZ'))")
start_slot=$(${cli} query slot-number --testnet-magic ${testnet_magic} ${timestamp})
timestamp=$(python -c "import datetime; print(datetime.datetime.utcfromtimestamp(${end_time} / 1000 - 1).strftime('%Y-%m-%dT%H:%M:%SZ'))")
end_slot=$(${cli} query slot-number --testnet-magic ${testnet_magic} ${timestamp})
echo Oracle Start: $start_slot
echo Oralce End: $end_slot


echo -e "\033[0;36m Gathering Batcher UTxO Information  \033[0m"
${cli} query utxo \
    --address ${batcher_address} \
    --testnet-magic ${testnet_magic} \
    --out-file ../tmp/batcher_utxo.json
# transaction variables
TXNS=$(jq length ../tmp/batcher_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${batcher_address} \033[0m \n";
   exit;
fi
TXIN=$(jq -r --arg alltxin "" 'to_entries[] | .key | . + $alltxin + " --tx-in"' ../tmp/batcher_utxo.json)
batcher_tx_in=${TXIN::-8}
echo Batcher UTXO ${batcher_tx_in}
echo -e "\033[0;37m\nGenerating Batcher Output\033[0m"
batcher_starting_lovelace=$(jq '[.[] | .value.lovelace] | add' ../tmp/batcher_utxo.json)
batcher_starting_incentive=$(jq --arg newm_pid ${newm_pid} --arg newm_tkn ${newm_tkn} '[.[] | .value[$newm_pid][$newm_tkn]] | add // 0' ../tmp/batcher_utxo.json)
echo Batcher Starting Value: ${batcher_starting_incentive} ${newm_pid}.${newm_tkn}

# the queue utxo has 2 incentive units
incentive_amt=$(jq -r '.fields[2].fields[2].int' ../data/queue/queue-datum.json)
incentive="$((${incentive_amt} + ${batcher_starting_incentive})) ${newm_pid}.${newm_tkn}"

token_name="5ca1ab1e000affab1e000ca11ab1e0005e77ab1e"
batcher_policy_id=$(cat ../../hashes/batcher.hash)
batcher_token="1 ${batcher_policy_id}.${token_name}"
batcher_address_out="${batcher_address} + ${batcher_starting_lovelace} + ${incentive} + ${batcher_token}"
echo -e "\nBatcher OUTPUT: "${batcher_address_out}

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
TXIN=$(jq -r --arg alltxin "" --arg buyerPkh "${buyer_pkh}" 'to_entries[] | select(.value.inlineDatum.fields[0].fields[0].bytes == $buyerPkh) | .key | . + $alltxin + " --tx-in"' ../tmp/script_utxo.json)
script_tx_in=${TXIN::-8}
echo Script TxId: $script_tx_in
# exit

# this needs to be dynamic
sale_pid=$(jq -r '.fields[1].fields[0].bytes' ../data/sale/sale-datum.json)
sale_tkn=$(jq -r '.fields[1].fields[1].bytes' ../data/sale/sale-datum.json)

sale_amt=$(jq -r --arg pid "${sale_pid}" --arg tkn "${sale_tkn}" 'to_entries[] | select(.value.value[$pid] // empty | keys[0] == $tkn) | .value.value[$pid][$tkn]' ../tmp/script_utxo.json)
cost_amt=$(jq -r --arg pid "${newm_pid}" --arg tkn "${newm_tkn}" 'to_entries[] | select(.value.value[$pid] // empty | keys[0] == $tkn) | .value.value[$pid][$tkn]' ../tmp/script_utxo.json)
returning_sale_value="${sale_amt} ${sale_pid}.${sale_tkn}"
returning_cost_value="$((${cost_amt} - ${incentive_amt})) ${newm_pid}.${newm_tkn}"
returning_lovelace_value=$(jq -r --arg pid "${sale_pid}" --arg tkn "${sale_tkn}" 'to_entries[] | select(.value.value[$pid] // empty | keys[0] == $tkn) | .value.value.lovelace' ../tmp/script_utxo.json)

buyer_address_out="${buyer_address} + ${returning_lovelace_value} + ${returning_cost_value} + ${returning_sale_value}"
echo -e "\nRefund OUTPUT: "${buyer_address_out}

#
# exit
#

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

script_ref_utxo=$(${cli} transaction txid --tx-file ../tmp/queue-reference-utxo.signed )
data_ref_utxo=$(${cli} transaction txid --tx-file ../tmp/referenceable-tx.signed )
last_sale_utxo=$(${cli} transaction txid --tx-file ../tmp/last-sale-utxo.signed )

execution_unts="(0, 0)"

echo -e "\033[0;36m Building Tx \033[0m"
${cli} transaction build-raw \
    --babbage-era \
    --protocol-params-file ../tmp/protocol.json \
    --out-file ../tmp/tx.draft \
    --invalid-before ${start_slot} \
    --invalid-hereafter ${end_slot} \
    --tx-in-collateral="${collat_utxo}" \
    --read-only-tx-in-reference="${data_ref_utxo}#0" \
    --read-only-tx-in-reference="${last_sale_utxo}#2" \
    --read-only-tx-in-reference ${feed_tx_in} \
    --tx-in ${batcher_tx_in} \
    --tx-in ${script_tx_in} \
    --spending-tx-in-reference="${script_ref_utxo}#1" \
    --spending-plutus-script-v2 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-execution-units="${execution_unts}" \
    --spending-reference-tx-in-redeemer-file ../data/queue/refund-redeemer.json \
    --tx-out="${batcher_address_out}" \
    --tx-out="${buyer_address_out}" \
    --required-signer-hash ${batcher_pkh} \
    --required-signer-hash ${collat_pkh} \
    --fee 0

python3 -c "import sys, json; sys.path.append('../py/'); from tx_simulation import from_file; exe_units=from_file('../tmp/tx.draft', False, debug=False);print(json.dumps(exe_units))" > ../data/exe_units.json

cat ../data/exe_units.json
if [ "$(cat ../data/exe_units.json)" = '[{}]' ]; then
    echo "Validation Failed."
    exit 1
else
    echo "Validation Success."
fi

cpu=$(jq -r '.[0].cpu' ../data/exe_units.json)
mem=$(jq -r '.[0].mem' ../data/exe_units.json)

execution_unts="(${cpu}, ${mem})"
computation_fee=$(echo "0.0000721*${cpu} + 0.0577*${mem}" | bc)
computation_fee_int=$(printf "%.0f" "$computation_fee")

FEE=$(${cli} transaction calculate-min-fee \
--tx-body-file ../tmp/tx.draft \
--protocol-params-file ../tmp/protocol.json \
--witness-count 3)
fee=$(echo $FEE | rev | cut -c 9- | rev)

total_fee=$((${fee} + ${computation_fee_int}))
echo Tx Fee: $total_fee
change_value=$((${returning_lovelace_value} - ${total_fee}))
buyer_address_out="${buyer_address} + ${change_value} + ${returning_cost_value} + ${returning_sale_value}"
echo "Refund OUTPUT: "${buyer_address_out}

# exit

${cli} transaction build-raw \
    --babbage-era \
    --protocol-params-file ../tmp/protocol.json \
    --out-file ../tmp/tx.draft \
    --invalid-before ${start_slot} \
    --invalid-hereafter ${end_slot} \
    --tx-in-collateral="${collat_utxo}" \
    --read-only-tx-in-reference="${data_ref_utxo}#0" \
    --read-only-tx-in-reference="${last_sale_utxo}#2" \
    --read-only-tx-in-reference ${feed_tx_in} \
    --tx-in ${batcher_tx_in} \
    --tx-in ${script_tx_in} \
    --spending-tx-in-reference="${script_ref_utxo}#1" \
    --spending-plutus-script-v2 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-execution-units="${execution_unts}" \
    --spending-reference-tx-in-redeemer-file ../data/queue/refund-redeemer.json \
    --tx-out="${batcher_address_out}" \
    --tx-out="${buyer_address_out}" \
    --required-signer-hash ${batcher_pkh} \
    --required-signer-hash ${collat_pkh} \
    --fee ${total_fee}

#
# exit
#
echo -e "\033[0;36m Signing \033[0m"
${cli} transaction sign \
    --signing-key-file ../wallets/batcher-wallet/payment.skey \
    --signing-key-file ../wallets/collat-wallet/payment.skey \
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