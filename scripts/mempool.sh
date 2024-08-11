#!/usr/bin/env bash
set -e

#
export CARDANO_NODE_SOCKET_PATH=$(cat ./data/path_to_socket.sh)
cli=$(cat ./data/path_to_cli.sh)
network=$(cat ./data/network.sh)

#
${cli} query protocol-parameters ${network} --out-file ./tmp/protocol.json
${cli} query tip ${network} | jq
${cli} query tx-mempool info ${network} | jq
${cli} query tx-mempool next-tx ${network} | jq
