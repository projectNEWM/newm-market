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

issuer_path="issuer-wallet"
issuer_address=$(cat ../wallets/${issuer_path}/payment.addr)

# issuer order for
buyer_path="buyer2-wallet"
buyer_address=$(cat ../wallets/${buyer_path}/payment.addr)
buyer_pkh=$(${cli} conway address key-hash --payment-verification-key-file ../wallets/${buyer_path}/payment.vkey)

max_bundle_size=$(jq -r '.fields[3].int' ../data/sale/sale-datum.json)
if [[ $# -eq 0 ]] ; then
    echo -e "\n \033[0;31m Please Supply A Bundle Amount \033[0m \n";
    exit
fi
if [[ ${1} -eq 0 ]] ; then
    echo -e "\n \033[0;31m Bundle Size Must Be Greater Than Zero \033[0m \n";
    exit
fi
if [[ ${1} -gt ${max_bundle_size} ]] ; then
    echo -e "\n \033[0;31m Bundle Size Must Be Less Than Or Equal To ${max_bundle_size} \033[0m \n";
    exit
fi


variable=${buyer_pkh}; jq --arg variable "$variable" '.fields[0].fields[0].bytes=$variable' ../data/queue/queue-datum.json > ../data/queue/queue-datum-new.json
mv ../data/queue/queue-datum-new.json ../data/queue/queue-datum.json


bundleSize=${1}
# update bundle size
variable=${bundleSize}; jq --argjson variable "$variable" '.fields[2].int=$variable' ../data/queue/queue-datum.json > ../data/queue/queue-datum-new.json
mv ../data/queue/queue-datum-new.json ../data/queue/queue-datum.json

# update token info
bundle_pid=$(jq -r '.fields[1].fields[0].bytes' ../data/sale/sale-datum.json)
bundle_tkn=$(jq -r '.fields[1].fields[1].bytes' ../data/sale/sale-datum.json)
variable=${bundle_pid}; jq --arg variable "$variable" '.fields[1].fields[0].bytes=$variable' ../data/queue/queue-datum.json > ../data/queue/queue-datum-new.json
mv ../data/queue/queue-datum-new.json ../data/queue/queue-datum.json
variable=${bundle_tkn}; jq --arg variable "$variable" '.fields[1].fields[1].bytes=$variable' ../data/queue/queue-datum.json > ../data/queue/queue-datum-new.json
mv ../data/queue/queue-datum-new.json ../data/queue/queue-datum.json
# point to a sale
pointer_tkn=$(cat ../tmp/pointer.token)
variable=${pointer_tkn}; jq --arg variable "$variable" '.fields[4].bytes=$variable' ../data/queue/queue-datum.json > ../data/queue/queue-datum-new.json
mv ../data/queue/queue-datum-new.json ../data/queue/queue-datum.json


#
buyer_assets=$(python3 -c "import sys; sys.path.append('../py/'); from convertMapToOutput import get_map; get_map($(jq -r '.fields[2].map' ../data/sale/sale-datum.json), ${bundleSize})")

# the pure ada part
pSize=$(jq '.fields[2].map[] | select(.k.bytes == "") | .v.map[].v.int' ../data/sale/sale-datum.json)
if [[ -z $pSize ]]; then
  pSize=0
fi
payAmt=$((${bundleSize} * ${pSize}))

incentive=" + 1000000 698a6ea0ca99f315034072af31eaac6ec11fe8558d3f48e9775aab9d.7444524950"

queue_value="${buyer_assets}${incentive}"

# this pays for the fees
pub=$(jq '.fields[4].fields[0].int' ../data/reference/reference-datum.json)
rub=$(jq '.fields[4].fields[1].int' ../data/reference/reference-datum.json)
gas=$((${pub} + ${rub}))
echo "Maximum Gas Fee:" $gas

# check if its ada or not
if [ -z "$queue_value" ]; then
    min_utxo_value=$(${cli} conway transaction calculate-min-required-utxo \
        --protocol-params-file ../tmp/protocol.json \
        --tx-out-inline-datum-file ../data/queue/queue-datum.json \
        --tx-out="${script_address} + 5000000" | tr -dc '0-9')
    adaPay=$((${min_utxo_value} + ${payAmt} + ${gas}))
    script_address_out="${script_address} + ${adaPay}"
else
    min_utxo_value=$(${cli} conway transaction calculate-min-required-utxo \
        --protocol-params-file ../tmp/protocol.json \
        --tx-out-inline-datum-file ../data/queue/queue-datum.json \
        --tx-out="${script_address} + 5000000 + ${queue_value}" | tr -dc '0-9')
    adaPay=$((${min_utxo_value} + ${payAmt} + ${gas}))
    script_address_out="${script_address} + ${adaPay} + ${queue_value}"
fi


echo -e "\033[0;36m Gathering Issuer UTxO Information  \033[0m"
${cli} conway query utxo \
    ${network} \
    --address ${issuer_address} \
    --out-file ../tmp/issuer_utxo.json
TXNS=$(jq length ../tmp/issuer_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${issuer_address} \033[0m \n";
   exit;
fi
alltxin=""
TXIN=$(jq -r --arg alltxin "" 'keys[] | . + $alltxin + " --tx-in"' ../tmp/issuer_utxo.json)
issuer_tx_in=${TXIN::-8}

data="../tmp/issuer_utxo.json"
lovelace=$(jq '[.[] | .value."lovelace"] | add' ${data})
# echo "Lovelace: " ${lovelace}


assets=$(python3 -c "import sys; sys.path.append('../../lib/py/'); from getAllTokens import concatenate_values; concatenate_values('${data}')")
# echo $assets
if [ -z "$assets" ]; then  # check if the result is an empty string
    echo "Result is empty. Exiting."
    # exit 1  # exit the script with an error code
fi

assets=$(python3 -c "import sys; sys.path.append('../../lib/py/'); from subtract_value_string import subtract_value; subtract_value('${assets}', 20000000, 1000000)")
# echo $assets

min_utxo_value=$(${cli} conway transaction calculate-min-required-utxo \
        --protocol-params-file ../tmp/protocol.json \
        --tx-out="${issuer_address} + 5000000 + ${assets}" | tr -dc '0-9')

change_address_out="${issuer_address} + ${min_utxo_value} + ${assets}"

echo "Script OUTPUT: "${script_address_out}
# echo "Change OUTPUT: "${change_address_out}
#
# exit
#
    # --tx-out="${change_address_out}" \
echo -e "\033[0;36m Building Tx \033[0m"
FEE=$(${cli} conway transaction build \
    --out-file ../tmp/tx.draft \
    --change-address ${issuer_address} \
    --tx-in ${issuer_tx_in} \
    --tx-out="${script_address_out}" \
    --tx-out-inline-datum-file ../data/queue/queue-datum.json  \
    ${network})

IFS=':' read -ra VALUE <<< "${FEE}"
IFS=' ' read -ra FEE <<< "${VALUE[1]}"
echo -e "\033[1;32m Fee:\033[0m" $FEE
#
# exit
#
echo -e "\033[0;36m Signing \033[0m"
${cli} conway transaction sign \
    --signing-key-file ../wallets/${issuer_path}/payment.skey \
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
