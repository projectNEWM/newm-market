#!/usr/bin/bash
set -e
#
export CARDANO_NODE_SOCKET_PATH=$(cat ../data/path_to_socket.sh)
cli=$(cat ../data/path_to_cli.sh)
testnet_magic=$(cat ../data/testnet.magic)

# Addresses
sender_path="../wallets/oracle-wallet/"
sender_address=$(cat ${sender_path}payment.addr)
sender_pkh=$(cat ${sender_path}payment.hash)

# oracle contract
oracle_script_path="../../contracts/oracle_contract.plutus"
script_address=$(${cli} address build --payment-script-file ${oracle_script_path} --testnet-magic ${testnet_magic})

# collat
collat_address=$(cat ../wallets/collat-wallet/payment.addr)
collat_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/collat-wallet/payment.vkey)

feed_addr="addr_test1wzn5ee2qaqvly3hx7e0nk3vhm240n5muq3plhjcnvx9ppjgf62u6a"
feed_pid=$(jq -r ' .feedPid' ../../config.json)
feed_tkn=$(jq -r '.feedTkn' ../../config.json)

echo -e "\033[0;36m Gathering Script UTxO Information  \033[0m"
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

echo Start: $start_slot
echo End: $end_slot

# policy_id=$(jq -r ' .oracleFeedPid' ../../config.json)
# token_name=$(jq -r '.oracleFeedTkn' ../../config.json)
# asset="1 ${policy_id}.${token_name}"

min_value=$(${cli} transaction calculate-min-required-utxo \
    --babbage-era \
    --protocol-params-file ../tmp/protocol.json \
    --tx-out-inline-datum-file ../data/oracle/oracle-datum.json \
    --tx-out="${script_address} + 5000000" | tr -dc '0-9')
    # --tx-out="${script_address} + 5000000 + ${asset}" | tr -dc '0-9')

oracle_address_out="${script_address} + ${min_value}"
echo "Oracle OUTPUT: "${oracle_address_out}

#
# exit
#

# get script utxo
echo -e "\033[0;36m Gathering Script UTxO Information  \033[0m"
${cli} query utxo \
    --address ${script_address} \
    --testnet-magic ${testnet_magic} \
    --out-file ../tmp/script_utxo.json
TXNS=$(jq length ../tmp/script_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${script_address} \033[0m \n";
   exit;
fi
alltxin=""
# TXIN=$(jq -r --arg alltxin "" --arg policy_id "$policy_id" --arg token_name "$token_name" 'to_entries[] | select(.value.value[$policy_id][$token_name] == 1) | .key | . + $alltxin + " --tx-in"' ../tmp/script_utxo.json)
TXIN=$(jq -r --arg alltxin "" 'keys[] | . + $alltxin + " --tx-in"' ../tmp/script_utxo.json)
script_tx_in=${TXIN::-8}
echo Oracle UTxO: $script_tx_in

# exit

echo -e "\033[0;36m Gathering UTxO Information  \033[0m"
${cli} query utxo \
    --testnet-magic ${testnet_magic} \
    --address ${sender_address} \
    --out-file ../tmp/sender_utxo.json

TXNS=$(jq length ../tmp/sender_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${sender_address} \033[0m \n";
   exit;
fi
alltxin=""
TXIN=$(jq -r --arg alltxin "" 'keys[] | . + $alltxin + " --tx-in"' ../tmp/sender_utxo.json)
seller_tx_in=${TXIN::-8}

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

script_ref_utxo=$(${cli} transaction txid --tx-file ../tmp/oracle-reference-utxo.signed )


echo -e "\033[0;36m Building Tx \033[0m"
FEE=$(${cli} transaction build \
    --babbage-era \
    --out-file ../tmp/tx.draft \
    --invalid-before ${start_slot} \
    --invalid-hereafter ${end_slot} \
    --change-address ${sender_address} \
    --tx-in-collateral ${collat_utxo} \
    --read-only-tx-in-reference ${feed_tx_in} \
    --tx-in ${seller_tx_in} \
    --tx-in ${script_tx_in} \
    --spending-tx-in-reference="${script_ref_utxo}#1" \
    --spending-plutus-script-v2 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-redeemer-file ../data/oracle/update-redeemer.json \
    --tx-out="${oracle_address_out}" \
    --tx-out-inline-datum-file ../data/oracle/oracle-datum.json \
    --required-signer-hash ${sender_pkh} \
    --required-signer-hash ${collat_pkh} \
    --testnet-magic ${testnet_magic})

IFS=':' read -ra VALUE <<< "${FEE}"
IFS=' ' read -ra FEE <<< "${VALUE[1]}"
FEE=${FEE[1]}
echo -e "\033[1;32m Fee: \033[0m" $FEE
#
# exit
#
echo -e "\033[0;36m Signing \033[0m"
${cli} transaction sign \
    --signing-key-file ${sender_path}payment.skey \
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