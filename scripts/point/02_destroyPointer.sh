#!/usr/bin/env bash
set -e

export CARDANO_NODE_SOCKET_PATH=$(cat ../data/path_to_socket.sh)
cli=$(cat ../data/path_to_cli.sh)
network=$(cat ../data/network.sh)

burnAmt=0
# update the starting lock time
variable=${burnAmt}; jq --argjson variable "$variable" '.fields[0].int=$variable' ../data/mint/burn-redeemer.json > ../data/mint/burn-redeemer-new.json
mv ../data/mint/burn-redeemer-new.json ../data/mint/burn-redeemer.json

# get params
${cli} conway query protocol-parameters ${network} --out-file ../tmp/protocol.json

#
newm_address=$(cat ../wallets/newm-wallet/payment.addr)
newm_pkh=$(${cli} conway address key-hash --payment-verification-key-file ../wallets/newm-wallet/payment.vkey)

#
collat_address=$(cat ../wallets/collat-wallet/payment.addr)
collat_pkh=$(${cli} conway address key-hash --payment-verification-key-file ../wallets/collat-wallet/payment.vkey)

# #
# artist_address=$(cat ../wallets/artist-wallet/payment.addr)
# artist_pkh=$(${cli} conway address key-hash --payment-verification-key-file ../wallets/artist-wallet/payment.vkey)

# multisig
keeper1_pkh=$(${cli} conway address key-hash --payment-verification-key-file ../wallets/keeper1-wallet/payment.vkey)
keeper2_pkh=$(${cli} conway address key-hash --payment-verification-key-file ../wallets/keeper2-wallet/payment.vkey)
keeper3_pkh=$(${cli} conway address key-hash --payment-verification-key-file ../wallets/keeper3-wallet/payment.vkey)


# the minting script policy
policy_id=$(cat ../../hashes/pointer_policy.hash)
token_name=$(cat ../tmp/pointer.token)

echo -e "\033[0;36m Gathering NEWM UTxO Information  \033[0m"
${cli} conway query utxo \
    ${network} \
    --address ${newm_address} \
    --out-file ../tmp/newm_utxo.json

TXNS=$(jq length ../tmp/newm_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${newm_address} \033[0m \n";
   exit;
fi
alltxin=""
TXIN=$(jq -r --arg alltxin "" 'keys[] | . + $alltxin + " --tx-in"' ../tmp/newm_utxo.json)
newm_tx_in=${TXIN::-8}
echo "NEWM UTxO:" $newm_tx_in

BURN_ASSET="-1 ${policy_id}.${token_name}"
echo $BURN_ASSET
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

script_ref_utxo=$(${cli} conway transaction txid --tx-file ../tmp/pointer-reference-utxo.signed)
data_ref_utxo=$(${cli} conway transaction txid --tx-file ../tmp/referenceable-tx.signed )

# Add metadata to this build function for nfts with data
echo -e "\033[0;36m Building Tx \033[0m"
FEE=$(${cli} conway transaction build \
    --protocol-params-file ../tmp/protocol.json \
    --out-file ../tmp/tx.draft \
    --change-address ${newm_address} \
    --tx-in-collateral="${collat_utxo}" \
    --read-only-tx-in-reference="${data_ref_utxo}#0" \
    --tx-in ${newm_tx_in} \
    --required-signer-hash ${collat_pkh} \
    --mint="${BURN_ASSET}" \
    --mint-tx-in-reference="${script_ref_utxo}#1" \
    --mint-plutus-script-v3 \
    --policy-id="${policy_id}" \
    --mint-reference-tx-in-redeemer-file ../data/mint/burn-redeemer.json \
    ${network})

IFS=':' read -ra VALUE <<< "${FEE}"
IFS=' ' read -ra FEE <<< "${VALUE[1]}"
echo -e "\033[1;32m Fee:\033[0m" $FEE
#
# exit
#
echo -e "\033[0;36m Signing \033[0m"
${cli} conway transaction sign \
    --signing-key-file ../wallets/newm-wallet/payment.skey \
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