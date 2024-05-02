#!/bin/bash
set -e

export CARDANO_NODE_SOCKET_PATH=$(cat ../data/path_to_socket.sh)
cli=$(cat ../data/path_to_cli.sh)
testnet_magic=$(cat ../data/testnet.magic)

# Check if less than 3 arguments are supplied
if [[ $# -lt 5 ]] ; then
    echo "
    asset_pid=${1}
    script_tx_in=${2}
    script_lovelace=${3}
    user_tx_in=${4}
    user_lovelace=${5}
    token_string=${6}
    "
    exit 1
fi


asset_pid=${1}
asset_tkn=""546869735f49735f415f566572795f4c6f6e675f537472696e675f5f5f5f5f5f""
asset_amt=9223372036854775807

script_tx_in=${2}
script_lovelace=${3}
user_tx_in=${4}
user_lovelace=${5}
collat_utxo="c1242e96efe0c72c3f5fe1de8913271c4bcd98e6b16d0ed4795a1fc2cd4c1b5e#0"
token_string=${6}

echo Adding ${asset_amt} ${asset_pid}.${asset_tkn}

python -c "
import json
data=json.load(open('../data/add-nft-redeemer.json', 'r'))
data['fields'][0]['list'][0]['fields'][0]['bytes'] = '$asset_pid'
data['fields'][0]['list'][0]['fields'][1]['bytes'] = '$asset_tkn'
data['fields'][0]['list'][0]['fields'][2]['int'] = $asset_amt
json.dump(data, open('../data/add-nft-redeemer.json', 'w'), indent=2)
"

# stake key
stake_key=$(jq -r '.stakeKey' ../../config.json)

# perma lock contract
perma_lock_nft_script_path="../../contracts/perma_lock_nft_contract.plutus"
perma_lock_nft_script_address=$(${cli} address build --payment-script-file ${perma_lock_nft_script_path} --stake-address ${stake_key} --testnet-magic ${testnet_magic})

# user wallet
user_path="user-wallet"
user_address=$(cat ../wallets/${user_path}/payment.addr)
user_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/${user_path}/payment.vkey)

# collat wallet
collat_address=$(cat ../wallets/collat-wallet/payment.addr)
collat_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/collat-wallet/payment.vkey)


if [ -z "$token_string" ]; then
    tokens="${asset_amt} ${asset_pid}.${asset_tkn}"
    # You can also perform other actions here if needed
    # calc the min ada required for the worst case value and datum
    min_utxo_value=$(${cli} transaction calculate-min-required-utxo \
        --babbage-era \
        --protocol-params-file ../tmp/protocol.json \
        --tx-out-inline-datum-file ../data/datum.json \
        --tx-out="${perma_lock_nft_script_address} + 5000000 + ${tokens}" | tr -dc '0-9')
    
    difference=$((${min_utxo_value} - ${script_lovelace}))
    if [ "$difference" -eq "0" ]; then
        echo "Minimum ADA Constant"
        new_user_min_utxo=$((${user_lovelace}))
    else
        echo "Minimum ADA Increasing by" ${difference}
        new_user_min_utxo=$((${user_lovelace} - ${difference}))
    fi

    perma_lock_nft_script_address_out="${perma_lock_nft_script_address} + ${min_utxo_value} + ${tokens}"
    user_address_out="${user_address} + ${new_user_min_utxo}"

else
    tokens="${asset_amt} ${asset_pid}.${asset_tkn} + ${token_string}"
    # You can also perform other actions here if needed
    # calc the min ada required for the worst case value and datum
    min_utxo_value=$(${cli} transaction calculate-min-required-utxo \
        --babbage-era \
        --protocol-params-file ../tmp/protocol.json \
        --tx-out-inline-datum-file ../data/datum.json \
        --tx-out="${perma_lock_nft_script_address} + 5000000 + ${tokens}" | tr -dc '0-9')

    difference=$((${min_utxo_value} - ${script_lovelace}))
    if [ "$difference" -eq "0" ]; then
        echo "Minimum ADA Constant"
        new_user_min_utxo=$((${user_lovelace}))
    else
        echo "Minimum ADA Increasing by" ${difference}
        new_user_min_utxo=$((${user_lovelace} - ${difference}))
    fi
    
    perma_lock_nft_script_address_out="${perma_lock_nft_script_address} + ${min_utxo_value} + ${tokens}"
    user_address_out="${user_address} + ${new_user_min_utxo}"

fi
echo "Script OUTPUT: "${perma_lock_nft_script_address_out}


# get script reference
script_ref_utxo=$(${cli} transaction txid --tx-file ../tmp/perma-lock-nft-reference-utxo.signed)

# minting policy
mint_path="../worst_case_minting/policy/policy.script"
python -c "import json; data=json.load(open('${mint_path}', 'r'));prev_slot = data['scripts'][0]['slot']; data['scripts'][0]['slot'] = prev_slot+1; json.dump(data, open('${mint_path}', 'w'), indent=2)"
policy_id=$(cardano-cli transaction policyid --script-file ${mint_path})

echo New Policy Id: ${policy_id}

# This_Is_A_Very_Long_String______
token_name="546869735f49735f415f566572795f4c6f6e675f537472696e675f5f5f5f5f5f"
# assets
mint_asset="9223372036854775807 ${policy_id}.${token_name}"

echo New Mint ${mint_asset}

user_address_out="${user_address_out} + ${mint_asset}"

# exit
execution_unts="(0, 0)"
                 
echo -e "\033[0;36m Building Tx \033[0m"
${cli} transaction build-raw \
    --babbage-era \
    --out-file ../tmp/tx.draft \
    --invalid-before 50105513 \
    --protocol-params-file ../tmp/protocol.json \
    --tx-in-collateral="${collat_utxo}" \
    --tx-in ${user_tx_in} \
    --tx-in ${script_tx_in} \
    --spending-tx-in-reference="${script_ref_utxo}#1" \
    --spending-plutus-script-v2 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-execution-units="${execution_unts}" \
    --spending-reference-tx-in-redeemer-file ../data/add-nft-redeemer.json \
    --tx-out="${perma_lock_nft_script_address_out}" \
    --tx-out-inline-datum-file ../data/datum.json  \
    --tx-out="${user_address_out}" \
    --required-signer-hash ${collat_pkh} \
    --required-signer-hash ${user_pkh} \
    --mint-script-file ${mint_path} \
    --mint="${mint_asset}" \
    --fee 0

python3 -c "import sys, json; sys.path.append('../py/'); from tx_simulation import from_file; exe_units=from_file('../tmp/tx.draft', False);print(json.dumps(exe_units))" > ../data/exe_units.json

cat ../data/exe_units.json
exit

cpu=$(jq -r '.[0].cpu' ../data/exe_units.json)
mem=$(jq -r '.[0].mem' ../data/exe_units.json)

execution_unts="(${cpu}, ${mem})"

FEE=$(${cli} transaction calculate-min-fee --tx-body-file ../tmp/tx.draft --testnet-magic ${testnet_magic} --protocol-params-file ../tmp/protocol.json --tx-in-count 2 --tx-out-count 2 --witness-count 2)
fee=$(echo $FEE | rev | cut -c 9- | rev)

computation_fee=$(echo "0.0000721*${cpu} + 0.0577*${mem}" | bc)
computation_fee_int=$(printf "%.0f" "$computation_fee")

total_fee=$((${fee} + ${computation_fee_int}))
echo FEE: $total_fee
required_lovelace=$((${new_user_min_utxo} - ${total_fee}))
user_address_out="${user_address} + ${required_lovelace} + ${mint_asset}"
echo "User OUTPUT: "${user_address_out}

${cli} transaction build-raw \
    --babbage-era \
    --out-file ../tmp/tx.draft \
    --invalid-before 50105513 \
    --protocol-params-file ../tmp/protocol.json \
    --tx-in-collateral="${collat_utxo}" \
    --tx-in ${user_tx_in} \
    --tx-in ${script_tx_in} \
    --spending-tx-in-reference="${script_ref_utxo}#1" \
    --spending-plutus-script-v2 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-execution-units="${execution_unts}" \
    --spending-reference-tx-in-redeemer-file ../data/add-nft-redeemer.json \
    --tx-out="${perma_lock_nft_script_address_out}" \
    --tx-out-inline-datum-file ../data/datum.json  \
    --tx-out="${user_address_out}" \
    --required-signer-hash ${collat_pkh} \
    --required-signer-hash ${user_pkh} \
    --mint-script-file ${mint_path} \
    --mint="${mint_asset}" \
    --fee ${total_fee}
#
exit
#
echo -e "\033[0;36m Signing \033[0m"
${cli} transaction sign \
    --signing-key-file ../wallets/${user_path}/payment.skey \
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

echo Sleeping
sleep 2m
echo Continue

./30_maxLockNFT.sh ${policy_id}  ${tx}#0 ${min_utxo_value} ${tx}#1 ${required_lovelace} "${tokens}"