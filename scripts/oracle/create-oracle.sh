#!/usr/bin/bash
set -e
#
export CARDANO_NODE_SOCKET_PATH=$(cat ../data/path_to_socket.sh)
cli=$(cat ../data/path_to_cli.sh)
testnet_magic=$(cat ../data/testnet.magic)

backup="../data/oracle/copy.oracle-datum.json"
frontup="../data/oracle/oracle-datum.json"

# curl -X POST "https://api.koios.rest/api/v1/address_utxos" \
#     -H "accept: application/json"\
#     -H "content-type: application/json" \
#     -d '{"_addresses":["addr1wy32q7067yt9c2em8kx5us4vhxzv4xve24u6j8ptlc5mzqcahrwzt"], "_extended":true}' \
#     | jq -r 'to_entries[] | select(.value.asset_list[0].asset_name=="4f7261636c6546656564") | .value.inline_datum.value' > ../data/oracle/oracle-datum.json

# Addresses
sender_path="../wallets/oracle-wallet/"
sender_address=$(cat ${sender_path}payment.addr)

# oracle contract
oracle_script_path="../../contracts/oracle_contract.plutus"
script_address=$(${cli} address build --payment-script-file ${oracle_script_path} --testnet-magic ${testnet_magic})

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

echo -e "\033[0;36m Building Tx \033[0m"
FEE=$(${cli} transaction build \
    --babbage-era \
    --out-file ../tmp/tx.draft \
    --change-address ${sender_address} \
    --tx-in ${seller_tx_in} \
    --tx-out="${oracle_address_out}" \
    --tx-out-inline-datum-file ../data/oracle/oracle-datum.json \
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