#!/usr/bin/env bash
set -e

tkn() {
    python3 -c "import secrets; print(''.join([secrets.choice('0123456789abcdef') for _ in range(64)]))"
}

export CARDANO_NODE_SOCKET_PATH=$(cat ../../data/path_to_socket.sh)
cli=$(cat ../../data/path_to_cli.sh)
testnet_magic=$(cat ../../data/testnet.magic)

# minting policy
mint_path1="./policy1.script"
mint_path2="./policy2.script"

batcher_address=$(cat ../../wallets/batcher-wallet/payment.addr)
batcher_pkh=$(${cli} address key-hash --payment-verification-key-file ../../wallets/batcher-wallet/payment.vkey)

policy_id1=$(cardano-cli transaction policyid --script-file ${mint_path1})
policy_id2=$(cardano-cli transaction policyid --script-file ${mint_path2})

# assets
token_name1=$(python3 -c "import secrets; print(''.join([secrets.choice('0123456789abcdef') for _ in range(64)]))")
token_name2=$(python3 -c "import secrets; print(''.join([secrets.choice('0123456789abcdef') for _ in range(64)]))")

mint_asset1="1 ${policy_id1}.$(tkn) + 1 ${policy_id1}.$(tkn) + 1 ${policy_id1}.$(tkn) + 1 ${policy_id1}.$(tkn) + 1 ${policy_id1}.$(tkn) + 1 ${policy_id1}.$(tkn) + 1 ${policy_id1}.$(tkn) + 1 ${policy_id1}.$(tkn) + 1 ${policy_id1}.$(tkn) + 1 ${policy_id1}.$(tkn)"
mint_asset2="1 ${policy_id2}.$(tkn) + 1 ${policy_id2}.$(tkn) + 1 ${policy_id2}.$(tkn) + 1 ${policy_id2}.$(tkn) + 1 ${policy_id2}.$(tkn) + 1 ${policy_id2}.$(tkn) + 1 ${policy_id2}.$(tkn) + 1 ${policy_id2}.$(tkn) + 1 ${policy_id2}.$(tkn) + 1 ${policy_id2}.$(tkn) + 1 ${policy_id2}.$(tkn)"

# mint utxo
utxo_value=$(${cli} transaction calculate-min-required-utxo \
    --babbage-era \
    --protocol-params-file ../../tmp/protocol.json \
    --tx-out="${batcher_address} + 2000000 + ${mint_asset1} + ${mint_asset2}" | tr -dc '0-9')

batcher_address_out="${batcher_address} + ${utxo_value} + ${mint_asset1} + ${mint_asset2}"
echo "Mint OUTPUT: "${batcher_address_out}
#
# exit
#
echo -e "\033[0;36m Gathering User UTxO Information  \033[0m"
${cli} query utxo \
    --testnet-magic ${testnet_magic} \
    --address ${batcher_address} \
    --out-file ../../tmp/batcher_utxo.json

TXNS=$(jq length ../../tmp/batcher_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${batcher_address} \033[0m \n";
   exit;
fi
alltxin=""
TXIN=$(jq -r --arg alltxin "" 'keys[] | . + $alltxin + " --tx-in"' ../../tmp/batcher_utxo.json)
batcher_tx_in=${TXIN::-8}

# slot contraints
slot=$(${cli} query tip --testnet-magic ${testnet_magic} | jq .slot)
current_slot=$(($slot - 1))
final_slot=$(($slot + 2500))

# exit
echo -e "\033[0;36m Building Tx \033[0m"
FEE=$(${cli} transaction build \
    --babbage-era \
    --out-file ../../tmp/tx.draft \
    --invalid-before ${current_slot} \
    --invalid-hereafter ${final_slot} \
    --change-address ${batcher_address} \
    --tx-in ${batcher_tx_in} \
    --tx-out="${batcher_address_out}" \
    --mint-script-file ${mint_path1} \
    --mint-script-file ${mint_path2} \
    --mint="${mint_asset1} + ${mint_asset2}" \
    --testnet-magic ${testnet_magic})

IFS=':' read -ra VALUE <<< "${FEE}"
IFS=' ' read -ra FEE <<< "${VALUE[1]}"
FEE=${FEE[1]}
echo -e "\033[1;32m Fee: \033[0m" $FEE
#
exit
#
echo -e "\033[0;36m Signing \033[0m"
${cli} transaction sign \
    --signing-key-file ../../wallets/batcher-wallet/payment.skey \
    --tx-body-file ../../tmp/tx.draft \
    --out-file ../../tmp/tx.signed \
    --testnet-magic ${testnet_magic}
#    
exit
#
echo -e "\033[0;36m Submitting \033[0m"
${cli} transaction submit \
    --testnet-magic ${testnet_magic} \
    --tx-file ../../tmp/tx.signed
