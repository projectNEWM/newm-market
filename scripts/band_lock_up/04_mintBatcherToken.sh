#!/usr/bin/env bash
set -e

export CARDANO_NODE_SOCKET_PATH=$(cat ../data/path_to_socket.sh)
cli=$(cat ../data/path_to_cli.sh)
network=$(cat ../data/network.sh)

# staking contract
stake_script_path="../../contracts/stake_contract.plutus"

# bundle sale contract
band_lock_script_path="../../contracts/band_lock_contract.plutus"
script_address=$(${cli} conway address build --payment-script-file ${band_lock_script_path} --stake-script-file ${stake_script_path} ${network})

# collat, artist, reference
batcher_address=$(cat ../wallets/batcher-wallet/payment.addr)
batcher_pkh=$(${cli} conway address key-hash --payment-verification-key-file ../wallets/batcher-wallet/payment.vkey)

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
TXIN=$(jq -r --arg alltxin "" --arg pkh "${batcher_pkh}" 'to_entries[] | select(.value.inlineDatum.fields[0].bytes == $pkh) | .key | . + $alltxin + " --tx-in"' ../tmp/script_utxo.json)
script_tx_in=${TXIN::-8}
echo Script UTxO: $script_tx_in

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
echo Batcher UTxO: $batcher_tx_in

first_utxo=$(python3 -c "x = '${script_tx_in}'; y = '${batcher_tx_in}'; print(x if x < y else y)")
IFS='#' read -ra array <<< "$first_utxo"

add_to_data=$(python3 -c "
import sys, json; sys.path.append('../py/'); from token_string import get_token_data, build_token_list;
file_path = '../tmp/script_utxo.json'
data = get_token_data(file_path)
list_of_token_struc = build_token_list(file_path)
print(json.dumps(list_of_token_struc))
")
assets=$(python3 -c "
import sys, json; sys.path.append('../py/'); from token_string import create_token_string;
assets = create_token_string(${add_to_data})
print(assets)
")

batcher_policy_id=$(cat ../../hashes/batcher.hash)
batcher_token_prefix="affab1e0005e77ab1e"
complete_token_prefix="c011ec7ed000a55e75"

batcher_token_name=$(python3 -c "import sys; sys.path.append('../py/'); from getTokenName import token_name; token_name('${array[0]}', ${array[1]}, '${batcher_token_prefix}')")
complete_token_name=$(python3 -c "import sys; sys.path.append('../py/'); from getTokenName import token_name; token_name('${array[0]}', ${array[1]}, '${complete_token_prefix}')")

python3 -c "x = '${batcher_token_name}'; y = '${batcher_token_prefix}'; z = x.replace(y, ''); print(z)" > ../tmp/batcher.token

complete_token="1 ${batcher_policy_id}.${complete_token_name}"

batcher_token="1 ${batcher_policy_id}.${batcher_token_name}"

min_utxo=$(${cli} conway transaction calculate-min-required-utxo \
    --protocol-params-file ../tmp/protocol.json \
    --tx-out-inline-datum-file ../data/band_lock/band-lock-datum.json \
    --tx-out="${script_address} + 5000000 + ${assets} + ${complete_token}" | tr -dc '0-9')

script_address_out="${script_address} + ${min_utxo} + ${assets} + ${complete_token}"
echo Collected Assets Token: $complete_token

min_utxo=$(${cli} conway transaction calculate-min-required-utxo \
    --protocol-params-file ../tmp/protocol.json \
    --tx-out="${batcher_address} + 5000000 + ${batcher_token}" | tr -dc '0-9')
batcher_address_out="${batcher_address} + ${min_utxo} + ${batcher_token}"
echo Batcher Token: $batcher_token
#
# exit
#
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

script_ref_utxo=$(${cli} conway transaction txid --tx-file ../tmp/band-reference-utxo.signed )
batcher_ref_utxo=$(${cli} conway transaction txid --tx-file ../tmp/batcher-reference-utxo.signed )
data_ref_utxo=$(${cli} conway transaction txid --tx-file ../tmp/referenceable-tx.signed )

echo -e "\033[0;36m Building Tx \033[0m"
FEE=$(${cli} conway transaction build \
    --out-file ../tmp/tx.draft \
    --change-address ${batcher_address} \
    --read-only-tx-in-reference="${data_ref_utxo}#0" \
    --tx-in-collateral="${collat_utxo}" \
    --tx-in ${batcher_tx_in} \
    --tx-in ${script_tx_in} \
    --spending-tx-in-reference="${script_ref_utxo}#1" \
    --spending-plutus-script-v3 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-redeemer-file ../data/band_lock/mint-band-redeemer.json \
    --tx-out="${batcher_address_out}" \
    --tx-out="${script_address_out}" \
    --tx-out-inline-datum-file ../data/band_lock/band-lock-datum.json  \
    --required-signer-hash ${batcher_pkh} \
    --required-signer-hash ${collat_pkh} \
    --mint="${batcher_token} + ${complete_token}" \
    --mint-tx-in-reference="${batcher_ref_utxo}#1" \
    --mint-plutus-script-v3 \
    --policy-id="${batcher_policy_id}" \
    --mint-reference-tx-in-redeemer-file ../data/band_lock/mint-batcher-redeemer.json \
    ${network})

IFS=':' read -ra VALUE <<< "${FEE}"
IFS=' ' read -ra FEE <<< "${VALUE[1]}"
echo -e "\033[1;32m Fee:\033[0m" $FEE
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