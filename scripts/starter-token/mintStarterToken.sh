#!/usr/bin/env bash
set -e

tkn() {
    python3 -c "import secrets; print(''.join([secrets.choice('0123456789abcdef') for _ in range(64)]))"
}

export CARDANO_NODE_SOCKET_PATH=$(cat ../data/path_to_socket.sh)
cli=$(cat ../data/path_to_cli.sh)
testnet_magic=$(cat ../data/testnet.magic)

# minting policy
mint_path1="./policy.script"

starter_path="../wallets/oracle-wallet/"
starter_address=$(cat ${starter_path}payment.addr)
starter_pkh=$(${cli} address key-hash --payment-verification-key-file ${starter_path}payment.vkey)

python -c "
import json; data=json.load(open('./policy.script', 'r'));
prev_slot = data['scripts'][0]['slot'];
data['scripts'][0]['slot'] = prev_slot + 1;
json.dump(data, open('./policy.script', 'w'), indent=2)
"
policy_id1=$(cardano-cli transaction policyid --script-file ${mint_path1})
token_name1=$(python3 -c "import secrets; print(''.join([secrets.choice('0123456789abcdef') for _ in range(64)]))")
mint_asset1="1 ${policy_id1}.$(tkn)"

# mint utxo
utxo_value=$(${cli} transaction calculate-min-required-utxo \
    --babbage-era \
    --protocol-params-file ../tmp/protocol.json \
    --tx-out="${starter_address} + 2000000 + ${mint_asset1}" | tr -dc '0-9')

starter_address_out="${starter_address} + ${utxo_value} + ${mint_asset1}"
echo "Minting: "${mint_asset1}
echo "Press Enter to continue, or any other key to exit."
read -rsn1 input

if [[ "$input" == "" ]]; then
    echo "Continuing..."
    # Add your code here that should execute if Enter is pressed
else
    echo "Exiting."
    exit 0
fi
#
# exit
#
echo -e "\033[0;36m Gathering User UTxO Information  \033[0m"
${cli} query utxo \
    --testnet-magic ${testnet_magic} \
    --address ${starter_address} \
    --out-file ../tmp/starter_utxo.json

TXNS=$(jq length ../tmp/starter_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${starter_address} \033[0m \n";
   exit;
fi
alltxin=""
TXIN=$(jq -r --arg alltxin "" 'keys[] | . + $alltxin + " --tx-in"' ../tmp/starter_utxo.json)
starter_tx_in=${TXIN::-8}

# slot contraints
slot=$(${cli} query tip --testnet-magic ${testnet_magic} | jq .slot)
current_slot=$(($slot - 1))
final_slot=$(($slot + 600))

# exit
echo -e "\033[0;36m Building Tx \033[0m"
FEE=$(${cli} transaction build \
    --babbage-era \
    --out-file ../tmp/tx.draft \
    --invalid-before ${current_slot} \
    --invalid-hereafter ${final_slot} \
    --change-address ${starter_address} \
    --tx-in ${starter_tx_in} \
    --tx-out="${starter_address_out}" \
    --mint-script-file ${mint_path1} \
    --mint="${mint_asset1}" \
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
    --signing-key-file ${starter_path}payment.skey \
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