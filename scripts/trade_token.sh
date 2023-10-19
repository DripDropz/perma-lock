#!/usr/bin/bash
set -e
#
rm tmp/tx.signed || true
export CARDANO_NODE_SOCKET_PATH=$(cat ./data/path_to_socket.sh)
cli=$(cat ./data/path_to_cli.sh)
testnet_magic=$(cat ./data/testnet.magic)

# Addresses
sender_path="./wallets/user-wallet/"
sender_address=$(cat ${sender_path}payment.addr)
receiver_address="addr_test1qrvnxkaylr4upwxfxctpxpcumj0fl6fdujdc72j8sgpraa9l4gu9er4t0w7udjvt2pqngddn6q4h8h3uv38p8p9cq82qav4lmp"

locking_pid=$(jq -r '.lockingPid' ../start_info.json)
locking_tkn=$(jq -r '.lockingTkn' ../start_info.json)

echo -e "\033[0;36m Gathering UTxO Information  \033[0m"
${cli} query utxo \
    --testnet-magic ${testnet_magic} \
    --address ${sender_address} \
    --out-file ./tmp/sender_utxo.json

TXNS=$(jq length ./tmp/sender_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${sender_address} \033[0m \n";
   exit;
fi
alltxin=""
TXIN=$(jq -r --arg alltxin "" 'keys[] | . + $alltxin + " --tx-in"' ./tmp/sender_utxo.json)
seller_tx_in=${TXIN::-8}

lock_token_amt=$(jq '[.[] | .value["'"${locking_pid}"'"]["'"${locking_tkn}"'"]] | add' ./tmp/sender_utxo.json)
assets="${lock_token_amt} ${locking_pid}.${locking_tkn}"
min_utxo=$(${cli} transaction calculate-min-required-utxo \
    --babbage-era \
    --protocol-params-file ./tmp/protocol.json \
    --tx-out="${receiver_address} + 5000000 + ${assets}" | tr -dc '0-9')

tokens_to_be_traded="${receiver_address} + ${min_utxo} + ${assets}"
echo -e "\nTrading Tokens:\n" ${tokens_to_be_traded}
#
# exit
#
echo -e "\033[0;36m Building Tx \033[0m"
FEE=$(${cli} transaction build \
    --babbage-era \
    --out-file ./tmp/tx.draft \
    --change-address ${sender_address} \
    --tx-in ${seller_tx_in} \
    --tx-out="${tokens_to_be_traded}" \
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
    --tx-body-file ./tmp/tx.draft \
    --out-file ./tmp/tx.signed \
    --testnet-magic ${testnet_magic}
#
# exit
#
echo -e "\033[0;36m Submitting \033[0m"
${cli} transaction submit \
    --testnet-magic ${testnet_magic} \
    --tx-file ./tmp/tx.signed