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

bundleSize=$(python3 -c "from random import randint; print(randint(1, 2000000))")


variable=${buyer_pkh}; jq --arg variable "$variable" '.fields[0].fields[0].bytes=$variable' ../data/queue/queue-datum.json > ../data/queue/queue-datum-new.json
mv ../data/queue/queue-datum-new.json ../data/queue/queue-datum.json

# update bundle size
variable=${bundleSize}; jq --argjson variable "$variable" '.fields[1].int=$variable' ../data/queue/queue-datum.json > ../data/queue/queue-datum-new.json
mv ../data/queue/queue-datum-new.json ../data/queue/queue-datum.json

# point to a sale
pointer_tkn=$(cat ../tmp/pointer.token)

variable=${pointer_tkn}; jq --arg variable "$variable" '.fields[3].bytes=$variable' ../data/queue/queue-datum.json > ../data/queue/queue-datum-new.json
mv ../data/queue/queue-datum-new.json ../data/queue/queue-datum.json

# hardcode for now
incentive="2000000 769c4c6e9bc3ba5406b9b89fb7beb6819e638ff2e2de63f008d5bcff.744e45574d"

feed_pkh=$(jq -r ' .feedHash' ../../config.json)
feed_addr=$(../bech32 addr_test <<< 70${feed_pkh})
feed_pid=$(jq -r ' .feedPid' ../../config.json)
feed_tkn=$(jq -r '.feedTkn' ../../config.json)

echo -e "\033[0;36m Gathering Script UTxO Information  \033[0m"
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

feed_datum=$(jq -r --arg policy_id "$feed_pid" --arg token_name "$feed_tkn" 'to_entries[] | select(.value.value[$policy_id][$token_name] == 1) | .value.inlineDatum' ../tmp/feed_utxo.json)
current_price=$(echo $feed_datum | jq -r '.fields[0].fields[0].map[0].v.int')
echo Current NEWM/USD Price: $current_price

margin=$(jq '.fields[7].fields[5].int' ../data/reference/reference-datum.json)
profit_pid=$(jq -r '.fields[7].fields[3].bytes' ../data/reference/reference-datum.json)
profit_tkn=$(jq -r '.fields[7].fields[4].bytes' ../data/reference/reference-datum.json)

# This must be true: e < N*C + P
profit_amt=$(python -c "p = ${margin} // ${current_price};print(p)")
echo Profit Amt: ${profit_amt}
profit="${profit_amt} ${profit_pid}.${profit_tkn}"

# the cost part
cost_pid=$(jq -r '.fields[2].fields[0].bytes' ../data/sale/sale-datum.json)

if [ "$cost_pid" = "555344" ]; then
    usd_amt=$(jq -r '.fields[2].fields[2].int' ../data/sale/sale-datum.json)
    cost_amt=$(python -c "p = ${usd_amt} // ${current_price};print(p)")
    pay_amt=$((${bundleSize} * ${cost_amt}))
    cost="${pay_amt} ${profit_pid}.${profit_tkn}"
else
    cost_tkn=$(jq -r '.fields[2].fields[1].bytes' ../data/sale/sale-datum.json)
    cost_amt=$(jq -r '.fields[2].fields[2].int' ../data/sale/sale-datum.json)
    pay_amt=$((${bundleSize} * ${cost_amt}))
    cost="${pay_amt} ${cost_pid}.${cost_tkn}"
fi

echo Cost: ${pay_amt}

# exit

extra_pct=40 # 100 / 40 = 2.5% change
extra_amt=$(python -c "nc = ${pay_amt};p = ${profit_amt};e = (nc + p)//${extra_pct}; print(e)")
echo Extra Amt: ${extra_amt}
extra="${extra_amt} ${profit_pid}.${profit_tkn}"

# this pays for the fees
pub=$(jq '.fields[4].fields[0].int' ../data/reference/reference-datum.json)
rub=$(jq '.fields[4].fields[1].int' ../data/reference/reference-datum.json)
gas=$((${pub} + ${rub}))
echo "Maximum Gas Fee:" $gas

# cost value + incentive + bundle
worst_case_token="9223372036854775807 015d83f25700c83d708fbf8ad57783dc257b01a932ffceac9dcd0c3d.015d83f25700c83d708fbf8ad57783dc257b01a932ffceac9dcd0c3d00000000
+ 9223372036854775807 115d83f25700c83d708fbf8ad57783dc257b01a932ffceac9dcd0c3d.015d83f25700c83d708fbf8ad57783dc257b01a932ffceac9dcd0c3d00000000
+ 9223372036854775807 215d83f25700c83d708fbf8ad57783dc257b01a932ffceac9dcd0c3d.015d83f25700c83d708fbf8ad57783dc257b01a932ffceac9dcd0c3d00000000
"
min_utxo_value=$(${cli} conway transaction calculate-min-required-utxo \
        --protocol-params-file ../tmp/protocol.json \
        --tx-out-inline-datum-file ../data/queue/queue-datum.json \
        --tx-out="${script_address} + 5000000 + ${worst_case_token}" | tr -dc '0-9')
adaPay=$((${min_utxo_value} + ${gas}))
script_address_out="${script_address} + ${adaPay} + ${cost} + ${incentive} + ${profit} + ${extra}"
total_newm=$((${pay_amt} + 2000000 + ${profit_amt} + ${extra_amt}))
echo $total_newm
echo "Script OUTPUT: "${script_address_out}
#
# exit
#
echo -e "\033[0;36m Gathering Buyer UTxO Information  \033[0m"
buyer_tx_in=${1}
buyer_lovelace=${2}
buyer_newm=${3}

fee=200000
return_lovelace=$((${buyer_lovelace} - ${fee} - ${adaPay}))
return_newm=$((${buyer_newm} - ${total_newm}))
buyer_address_out="${buyer_address} + ${return_lovelace} + ${return_newm} 769c4c6e9bc3ba5406b9b89fb7beb6819e638ff2e2de63f008d5bcff.744e45574d"


# exit
echo -e "\033[0;36m Building Tx \033[0m"
${cli} conway transaction build-raw \
    --protocol-params-file ../tmp/protocol.json \
    --out-file ../tmp/tx.draft \
    --tx-in ${buyer_tx_in} \
    --tx-out="${script_address_out}" \
    --tx-out-inline-datum-file ../data/queue/queue-datum.json  \
    --tx-out="${buyer_address_out}" \
    --fee ${fee}

echo -e "\033[1;32m Fee:\033[0m" $FEE
#
# exit
#
echo -e "\033[0;36m Signing \033[0m"
${cli} conway transaction sign \
    --signing-key-file ../wallets/${buyer_path}/payment.skey \
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

python3 -c "import time, random; time.sleep(random.uniform(0, 5))"
./05_autoPopulateQueue.sh ${tx}#1 $return_lovelace $return_newm