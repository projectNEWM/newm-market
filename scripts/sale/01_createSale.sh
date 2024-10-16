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

# artist address
artist_address=$(cat ../wallets/artist-wallet/payment.addr)

pid=$(jq -r '.fields[1].fields[0].bytes' ../data/sale/sale-datum.json)
tkn=$(jq -r '.fields[1].fields[1].bytes' ../data/sale/sale-datum.json)
total_amt=100000000

default_asset="${total_amt} ${pid}.${tkn}"

# cost value + incentive + bundle
worst_case_token="9223372036854775807 015d83f25700c83d708fbf8ad57783dc257b01a932ffceac9dcd0c3d.015d83f25700c83d708fbf8ad57783dc257b01a932ffceac9dcd0c3d00000000
+ 9223372036854775807 115d83f25700c83d708fbf8ad57783dc257b01a932ffceac9dcd0c3d.015d83f25700c83d708fbf8ad57783dc257b01a932ffceac9dcd0c3d00000000
+ 9223372036854775807 215d83f25700c83d708fbf8ad57783dc257b01a932ffceac9dcd0c3d.015d83f25700c83d708fbf8ad57783dc257b01a932ffceac9dcd0c3d00000000
"
utxo_value=$(${cli} conway transaction calculate-min-required-utxo \
    --protocol-params-file ../tmp/protocol.json \
    --tx-out-inline-datum-file ../data/sale/worst-case-sale-datum.json \
    --tx-out="${script_address} + 5000000 + ${worst_case_token}" | tr -dc '0-9')

echo Min UTxO w/o: ${utxo_value}

self_start_fee=$(jq '.fields[4].fields[2].int' ../data/reference/reference-datum.json)
min_ada=$((${utxo_value} + ${self_start_fee}))

script_address_out="${script_address} + ${min_ada} + ${default_asset}"
echo "Sale OUTPUT: "${script_address_out}
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

# exit
echo -e "\033[0;36m Building Tx \033[0m"
FEE=$(${cli} conway transaction build \
    --out-file ../tmp/tx.draft \
    --change-address ${artist_address} \
    --tx-in ${artist_tx_in} \
    --tx-out="${script_address_out}" \
    --tx-out-inline-datum-file ../data/sale/sale-datum.json  \
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
