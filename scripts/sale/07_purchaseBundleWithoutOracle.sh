#!/usr/bin/env bash
set -e

export CARDANO_NODE_SOCKET_PATH=$(cat ../data/path_to_socket.sh)
cli=$(cat ../data/path_to_cli.sh)
network=$(cat ../data/network.sh)

# staking contract
stake_script_path="../../contracts/stake_contract.plutus"

# bundle sale contract
sale_script_path="../../contracts/sale_contract.plutus"
sale_script_address=$(${cli} conway address build --payment-script-file ${sale_script_path} --stake-script-file ${stake_script_path} ${network})

# queue contract
queue_script_path="../../contracts/queue_contract.plutus"
queue_script_address=$(${cli} conway address build --payment-script-file ${queue_script_path} --stake-script-file ${stake_script_path} ${network})

# vault contract
vault_script_path="../../contracts/vault_contract.plutus"
vault_script_address=$(${cli} conway address build --payment-script-file ${vault_script_path} --stake-script-file ${stake_script_path} ${network})

# oracle feed
# this needs to be better
feed_pkh=$(jq -r ' .feedHash' ../../config.json)
feed_addr=$(../bech32 addr_test <<< 70${feed_pkh})

feed_pid=$(jq -r ' .feedPid' ../../config.json)
feed_tkn=$(jq -r '.feedTkn' ../../config.json)

# batcher, artist, buyer, collat
batcher_address=$(cat ../wallets/batcher-wallet/payment.addr)
batcher_pkh=$(${cli} conway address key-hash --payment-verification-key-file ../wallets/batcher-wallet/payment.vkey)

artist_address=$(cat ../wallets/artist-wallet/payment.addr)
artist_pkh=$(${cli} conway address key-hash --payment-verification-key-file ../wallets/artist-wallet/payment.vkey)

which_buyer="buyer1"
buyer_address=$(cat ../wallets/${which_buyer}-wallet/payment.addr)
buyer_pkh=$(${cli} conway address key-hash --payment-verification-key-file ../wallets/${which_buyer}-wallet/payment.vkey)

collat_address=$(cat ../wallets/collat-wallet/payment.addr)
collat_pkh=$(${cli} conway address key-hash --payment-verification-key-file ../wallets/collat-wallet/payment.vkey)

# payment token
newm_pid="769c4c6e9bc3ba5406b9b89fb7beb6819e638ff2e2de63f008d5bcff"
newm_tkn="744e45574d"

# Get all the script and batcher utxos
echo -e "\033[0;36m\nGathering Vault Script UTxO Information  \033[0m"
${cli} conway query utxo \
    --address ${vault_script_address} \
    ${network} \
    --out-file ../tmp/vault_script_utxo.json
# transaction variables
TXNS=$(jq length ../tmp/vault_script_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${vault_script_address} \033[0m \n";
   exit;
fi
TXIN=$(jq -r --arg alltxin "" --arg pkh "${batcher_pkh}" 'to_entries[] | select(.value.inlineDatum.fields[0].bytes == $pkh) | .key | . + $alltxin + " --tx-in"' ../tmp/vault_script_utxo.json)
vault_tx_in=${TXIN::-8}
echo VAULT UTxO: $vault_tx_in

echo -e "\033[0;36m Gathering Batcher UTxO Information  \033[0m"
${cli} conway query utxo \
    --address ${batcher_address} \
    ${network} \
    --out-file ../tmp/batcher_utxo.json
# transaction variables
TXNS=$(jq length ../tmp/batcher_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${batcher_address} \033[0m \n";
   exit;
fi
TXIN=$(jq -r --arg alltxin "" 'to_entries[] | .key | . + $alltxin + " --tx-in"' ../tmp/batcher_utxo.json)
batcher_tx_in=${TXIN::-8}
echo Batcher UTXO: ${batcher_tx_in}

echo -e "\033[0;36m Gathering Queue Script UTxO Information  \033[0m"
${cli} conway query utxo \
    --address ${queue_script_address} \
    ${network} \
    --out-file ../tmp/queue_script_utxo.json
# transaction variables
TXNS=$(jq length ../tmp/queue_script_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${sale_script_address} \033[0m \n";
   exit;
fi
TXIN=$(jq -r --arg alltxin "" --arg buyerPkh "${buyer_pkh}" 'to_entries[] | select(.value.inlineDatum.fields[0].fields[0].bytes == $buyerPkh) | .key | . + $alltxin + " --tx-in"' ../tmp/queue_script_utxo.json)
queue_tx_in=${TXIN::-8}
echo QUEUE UTXO: ${queue_tx_in}

echo -e "\033[0;36m Gathering Sale Script UTxO Information  \033[0m"
${cli} conway query utxo \
    --address ${sale_script_address} \
    ${network} \
    --out-file ../tmp/sale_script_utxo.json
# transaction variables
TXNS=$(jq length ../tmp/sale_script_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${sale_script_address} \033[0m \n";
   exit;
fi
TXIN=$(jq -r --arg alltxin "" --arg artistPkh "${artist_pkh}" 'to_entries[] | select(.value.inlineDatum.fields[0].fields[0].bytes == $artistPkh) | .key' ../tmp/sale_script_utxo.json)
sale_tx_in=$TXIN
echo SALE UTXO ${sale_tx_in}

echo -e "\033[0;36m Gathering Oracle Script UTxO Information  \033[0m"
${cli} conway query utxo \
    --address ${feed_addr} \
    ${network} \
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
echo Collateral UTxO: $collat_utxo

# exit

#
# Get the batcher stuff going
#
echo -e "\033[0;37m\nGenerating Batcher Output\033[0m"
batcher_starting_lovelace=$(jq '[.[] | .value.lovelace] | add' ../tmp/batcher_utxo.json)
batcher_starting_incentive=$(jq --arg newm_pid ${newm_pid} --arg newm_tkn ${newm_tkn} '[.[] | .value[$newm_pid][$newm_tkn]] | add // 0' ../tmp/batcher_utxo.json)
echo Batcher Starting Value: ${batcher_starting_incentive} ${newm_pid}.${newm_tkn}

# the queue utxo has 2 incentive units
incentive_amt=$(jq -r '.fields[2].fields[2].int' ../data/queue/queue-datum.json)
incentive="$((${incentive_amt} + ${batcher_starting_incentive})) ${newm_pid}.${newm_tkn}"
return_incentive_value="${incentive_amt} ${newm_pid}.${newm_tkn}"

# the batcher cert
token_ending=$(cat ../tmp/batcher.token)
token_name="affab1e0005e77ab1e"${token_ending}
batcher_policy_id=$(cat ../../hashes/batcher.hash)
batcher_token="1 ${batcher_policy_id}.${token_name}"
batcher_address_out="${batcher_address} + ${batcher_starting_lovelace} + ${incentive} + ${batcher_token}"
echo "Batcher OUTPUT:" ${batcher_address_out}

# exit

#
# Get the vault stuff going
#
echo -e "\033[0;37m\nGenerating Vault Output\033[0m"
vault_starting_lovelace=$(jq '[.[] | .value.lovelace] | add' ../tmp/vault_script_utxo.json)
vault_starting_profit=$(jq --arg newm_pid ${newm_pid} --arg newm_tkn ${newm_tkn} '[.[] | .value[$newm_pid][$newm_tkn]] | add // 0' ../tmp/vault_script_utxo.json)
echo Vault Starting Value: ${vault_starting_profit} ${newm_pid}.${newm_tkn}
feed_datum=$(jq -r --arg policy_id "$feed_pid" --arg token_name "$feed_tkn" 'to_entries[] | select(.value.value[$policy_id][$token_name] == 1) | .value.inlineDatum' ../tmp/feed_utxo.json)
current_price=$(echo $feed_datum | jq -r '.fields[0].fields[0].map[0].v.int')
echo Current NEWM/USD Price: $current_price
margin=$(jq '.fields[7].fields[5].int' ../data/reference/reference-datum.json)
# Check if margin is zero and exit if it is
if [ "$margin" -ne 0 ]; then
    echo "Margin is zero, exiting."
    exit 1
fi
profit_pid=$(jq -r '.fields[7].fields[3].bytes' ../data/reference/reference-datum.json)
profit_tkn=$(jq -r '.fields[7].fields[4].bytes' ../data/reference/reference-datum.json)
profit_amt=$(python -c "p = ${margin} // ${current_price};print(p)")
echo Profit Amt: ${profit_amt}
start_time=$(echo $feed_datum | jq -r '.fields[0].fields[0].map[1].v.int')
end_time=$(echo $feed_datum | jq -r '.fields[0].fields[0].map[2].v.int')
# subtract a second from it so its forced to be contained
delta=45
timestamp=$(python -c "import datetime; print(datetime.datetime.fromtimestamp((${start_time} / 1000) + ${delta}, tz=datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))")
start_slot=$(${cli} conway query slot-number ${network} ${timestamp})
timestamp=$(python -c "import datetime; print(datetime.datetime.fromtimestamp((${end_time} / 1000) - ${delta}, tz=datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))")
end_slot=$(${cli} conway query slot-number ${network} ${timestamp})
echo Oracle Start: $start_slot
echo Oralce End: $end_slot
ttl=$(python -c "import time; import sys; print(int(${end_time} / 1000) - int(time.time()))")
echo Seconds Left for validity ${ttl}
profit="$((${profit_amt} + ${vault_starting_profit})) ${profit_pid}.${profit_tkn}"
variable=${profit_amt}; jq -r --argjson variable "$variable" '.fields[0].list[0].fields[2].int=$variable' ../data/vault/add-to-vault-redeemer.json | sponge ../data/vault/add-to-vault-redeemer.json
# vault_address_out="${vault_script_address} + ${vault_starting_lovelace} + ${profit}"
# echo "Vault OUTPUT:" ${vault_address_out}

# exit

#
# Get the sale stuff going
#
echo -e "\033[0;37m\nGenerating Sale Output\033[0m"
# the token being sold
sale_pid=$(jq -r '.fields[1].fields[0].bytes' ../data/sale/sale-datum.json)
sale_tkn=$(jq -r '.fields[1].fields[1].bytes' ../data/sale/sale-datum.json)
# the cost token
cost_pid=$(jq -r '.fields[2].fields[0].bytes' ../data/sale/sale-datum.json)
cost_tkn=$(jq -r '.fields[2].fields[1].bytes' ../data/sale/sale-datum.json)
# the pointer token for the sale
pointer_pid=$(cat ../../hashes/pointer_policy.hash)
pointer_tkn=$(cat ../tmp/pointer.token)
pointer_value="1 ${pointer_pid}.${pointer_tkn}"
#
sale_amt=$(jq -r --arg pid "${sale_pid}" --arg tkn "${sale_tkn}" 'to_entries[] | select(.value.value[$pid] // empty | keys[0] == $tkn) | .value.value[$pid][$tkn]' ../tmp/sale_script_utxo.json)
echo Sale Starting Value: $sale_amt ${sale_pid}.${sale_tkn}

wantedNumberOfBundles=$(jq -r '.fields[1].int' ../data/queue/queue-datum.json)
saleBundleAmt=$(jq -r '.fields[1].fields[2].int' ../data/sale/sale-datum.json)
saleCostAmt=$(jq -r '.fields[2].fields[2].int' ../data/sale/sale-datum.json)

totalCostAmt=$((${wantedNumberOfBundles} * ${saleCostAmt}))
totalBundleAmt=$((${wantedNumberOfBundles} * ${saleBundleAmt}))
returnBundleAmt=$((${sale_amt} - ${totalBundleAmt}))

# buyer info
queue_bundle_value="${totalBundleAmt} ${sale_pid}.${sale_tkn}"
sale_bundle_value="${returnBundleAmt} ${sale_pid}.${sale_tkn}"

echo Queue Bundle: $queue_bundle_value
echo Sale Bundle: $sale_bundle_value

sale_profit_amount=$(jq --arg cpid "$cost_pid" --arg ctkn "$cost_tkn" '[.[] | .value[$cpid][$ctkn]] | add' ../tmp/sale_script_utxo.json)
queue_payment_amount=$(jq --arg cpid "$cost_pid" --arg ctkn "$cost_tkn" '[.[] | .value[$cpid][$ctkn]] | add' ../tmp/queue_script_utxo.json)

queue_return_payment_amount=$(($queue_payment_amount - $totalCostAmt - $incentive_amt - $profit_amt))
queue_return_payment_value="${queue_return_payment_amount} ${cost_pid}.${cost_tkn}"

if [ -z "$sale_profit_amount" ]; then
    sale_cost_value="${totalCostAmt} ${cost_pid}.${cost_tkn}"
else
    sale_cost_value="$((${sale_profit_amount} + ${totalCostAmt})) ${cost_pid}.${cost_tkn}"
fi

echo Sale Cost Value: $sale_cost_value
echo Queue Return Payment Value: $queue_return_payment_value

queue_ada_return=$(jq -r '.[].value.lovelace' ../tmp/queue_script_utxo.json)
sale_ada_return=$(jq -r '.[].value.lovelace' ../tmp/sale_script_utxo.json)


if [[ $returnBundleAmt -le 0 ]] ; then
    sale_address_out="${sale_script_address} + ${sale_ada_return} + ${pointer_value} + ${sale_cost_value}"
else
    sale_address_out="${sale_script_address} + ${sale_ada_return} + ${sale_bundle_value} + ${pointer_value} + ${sale_cost_value}"
fi
queue_address_out="${queue_script_address} + ${queue_ada_return} + ${queue_bundle_value} + ${queue_return_payment_value}"

echo "Sale OUTPUT:" ${sale_address_out}
echo "Queue OUTPUT:" ${queue_address_out}

# exit

sale_ref_utxo=$(${cli} conway transaction txid --tx-file ../tmp/sale-reference-utxo.signed )
queue_ref_utxo=$(${cli} conway transaction txid --tx-file ../tmp/queue-reference-utxo.signed )
vault_ref_utxo=$(${cli} conway transaction txid --tx-file ../tmp/vault-reference-utxo.signed )
data_ref_utxo=$(${cli} conway transaction txid --tx-file ../tmp/referenceable-tx.signed )

execution_unts="(0, 0)"

echo -e "\033[0;36m Building Tx \033[0m"
${cli} conway transaction build-raw \
    --protocol-params-file ../tmp/protocol.json \
    --out-file ../tmp/tx.draft \
    --tx-in-collateral="${collat_utxo}" \
    --read-only-tx-in-reference="${data_ref_utxo}#0" \
    --tx-in ${batcher_tx_in} \
    --tx-in ${sale_tx_in} \
    --spending-tx-in-reference="${sale_ref_utxo}#1" \
    --spending-plutus-script-v3 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-execution-units="${execution_unts}" \
    --spending-reference-tx-in-redeemer-file ../data/sale/purchase-redeemer.json \
    --tx-in ${queue_tx_in} \
    --spending-tx-in-reference="${queue_ref_utxo}#1" \
    --spending-plutus-script-v3 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-execution-units="${execution_unts}" \
    --spending-reference-tx-in-redeemer-file ../data/queue/purchase-redeemer.json \
    --tx-out="${sale_address_out}" \
    --tx-out-inline-datum-file ../data/sale/sale-datum.json  \
    --tx-out="${queue_address_out}" \
    --tx-out-inline-datum-file ../data/queue/queue-datum.json  \
    --tx-out="${batcher_address_out}" \
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
#
# exit
#
sale_index=$(python3 -c "
import sys; sys.path.append('../py/'); 
from lexico import sort_lexicographically, get_index_in_order;
ordered_list = sort_lexicographically('${sale_tx_in}', '${queue_tx_in}');
index = get_index_in_order(ordered_list, '${sale_tx_in}');
print(index)"
)
echo $sale_index

cpu=$(jq -r --argjson index "$sale_index" '.[$index].cpu' ../data/exe_units.json)
mem=$(jq -r --argjson index "$sale_index" '.[$index].mem' ../data/exe_units.json)

sale_execution_unts="(${cpu}, ${mem})"
sale_computation_fee=$(echo "0.0000721*${cpu} + 0.0577*${mem}" | bc)
sale_computation_fee_int=$(printf "%.0f" "$sale_computation_fee")
echo $sale_execution_unts

queue_index=$(python3 -c "
import sys; sys.path.append('../py/'); 
from lexico import sort_lexicographically, get_index_in_order;
ordered_list = sort_lexicographically('${sale_tx_in}', '${queue_tx_in}');
index = get_index_in_order(ordered_list, '${queue_tx_in}');
print(index)"
)
echo $queue_index

cpu=$(jq -r --argjson index "$queue_index" '.[$index].cpu' ../data/exe_units.json)
mem=$(jq -r --argjson index "$queue_index" '.[$index].mem' ../data/exe_units.json)

queue_execution_unts="(${cpu}, ${mem})"
queue_computation_fee=$(echo "0.0000721*${cpu} + 0.0577*${mem}" | bc)
queue_computation_fee_int=$(printf "%.0f" "$queue_computation_fee")
echo $queue_execution_unts

FEE=$(${cli} conway transaction calculate-min-fee \
    --tx-body-file ../tmp/tx.draft \
    --protocol-params-file ../tmp/protocol.json \
    --witness-count 3)
fee=$(echo $FEE | rev | cut -c 9- | rev)
echo Tx Fee: $fee
total_fee=$((${fee} + ${sale_computation_fee_int} + ${queue_computation_fee_int}))
echo Total Fee: $total_fee
change_value=$((${queue_ada_return} - ${total_fee}))
queue_address_out="${queue_script_address} + ${change_value} + ${queue_bundle_value} + ${queue_return_payment_value}"
echo "With Fee: Queue Script OUTPUT: "${queue_address_out}
#
# exit
#
${cli} conway transaction build-raw \
    --protocol-params-file ../tmp/protocol.json \
    --out-file ../tmp/tx.draft \
    --tx-in-collateral="${collat_utxo}" \
    --read-only-tx-in-reference="${data_ref_utxo}#0" \
    --tx-in ${batcher_tx_in} \
    --tx-in ${sale_tx_in} \
    --spending-tx-in-reference="${sale_ref_utxo}#1" \
    --spending-plutus-script-v3 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-execution-units="${sale_execution_unts}" \
    --spending-reference-tx-in-redeemer-file ../data/sale/purchase-redeemer.json \
    --tx-in ${queue_tx_in} \
    --spending-tx-in-reference="${queue_ref_utxo}#1" \
    --spending-plutus-script-v3 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-execution-units="${queue_execution_unts}" \
    --spending-reference-tx-in-redeemer-file ../data/queue/purchase-redeemer.json \
    --tx-out="${sale_address_out}" \
    --tx-out-inline-datum-file ../data/sale/sale-datum.json  \
    --tx-out="${queue_address_out}" \
    --tx-out-inline-datum-file ../data/queue/queue-datum.json  \
    --tx-out="${batcher_address_out}" \
    --required-signer-hash ${batcher_pkh} \
    --required-signer-hash ${collat_pkh} \
    --fee ${total_fee}
#
# exit
#
echo -e "\033[0;36m Signing \033[0m"
${cli} conway transaction sign \
    --signing-key-file ../wallets/batcher-wallet/payment.skey \
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

cp ../tmp/tx.signed ../tmp/last-sale-utxo.signed
