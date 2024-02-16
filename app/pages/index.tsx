import Head from "next/head";
import {
  Transaction,
  MeshTxBuilder,
  KoiosProvider,
  resolveDataHash,
} from "@meshsdk/core";
import type { PlutusScript, Data } from "@meshsdk/core";
import { CardanoWallet, MeshBadge, useWallet } from "@meshsdk/react";

import plutusScript from "../data/plutus.json";
import { useState } from "react";
import cbor from "cbor";

enum States {
  init,
  locking,
  lockingConfirming,
  locked,
  unlocking,
  unlockingConfirming,
  unlocked,
}

const koiosProvider = new KoiosProvider('preprod');

export default function Home() {
  const [state, setState] = useState(States.init);

  const { connected } = useWallet();

  return (
    <div className="container">
      <Head>
        <title>DEMO</title>
        <link
          href="https://meshjs.dev/css/template.css"
          rel="stylesheet"
          key="mesh-demo"
        />
      </Head>

      <main className="main">
        <h1 className="title">
          CONNECT WALLET AND CLICK UNLOCK BUTTON
        </h1>

        <div className="demo">
          {!connected && <CardanoWallet />}

          {connected &&
            state != States.locking &&
            state != States.unlocking && (
              <>
                {(state == States.init || state != States.locked) && (
                  <Lock setState={setState} />
                )}
                <Unlock setState={setState} />
              </>
            )}
        </div>

        {connected && (
          <div className="demo">
            {(state == States.locking || state == States.unlocking) && (
              <>Creating transaction...</>
            )}
            {(state == States.lockingConfirming ||
              state == States.unlockingConfirming) && (
                <>Awaiting transaction confirm...</>
              )}
          </div>
        )}

      </main>

    </div>
  );
}

// this bs is from the template
function Lock({ setState }) {
  async function lockAiken() {}
  return (<button type="button" onClick={() => lockAiken()}>No Click</button>);
}

//
// this handles the sc interaction
// follow this to get an idea on how to do this
//
function Unlock({ setState }) {

  const script: PlutusScript = {
    code: cbor
      .encode(Buffer.from(plutusScript.validators[1].compiledCode, "hex"))
      .toString("hex"),
    version: "V2",
  };

  // the wallet we need
  const { wallet } = useWallet();

  // click unlock aiken button
  async function unlockAiken() {
    setState(States.unlocking);

    // the tx we are going to build

    // hardcode for demo
    const scriptRefTxId = "026ac222531e98efcd2950a12baba80af409a9fa8d359119435c48e6be7ceff0";
    const scriptRefTxIdx = 1;
    const collatAddress = "addr_test1vzqlq2dchjg6kcdh5fkrtmspvxhf2fpfvx7q4mssygw02cg3mfng6";
    const scriptAddress = "addr_test1zrfg36fqc5g6xwz2j2jqw074wlmax4dw3vgel7rhw9h47ydl4gu9er4t0w7udjvt2pqngddn6q4h8h3uv38p8p9cq82qkqs555";
    console.log("Script Address", scriptAddress);

    // get the wallet change address
    const changeAddress = await wallet.getChangeAddress();
    console.log("Change Address", changeAddress);

    // we use the empty datum on the utxo
    const datum: Data = {
      alternative: 0,
      fields: [],
    };
    const datumHash = resolveDataHash(datum);
    console.log("Datum Hash", datumHash);

    // get contract utxos and search for the one with the same datum hash
    // this will neeed to be the round robin part where the utxo selection
    // is based off of our choice
    // const contractUTxOs = await koiosProvider.fetchAddressUTxOs(scriptAddress);

    const contractUTxOs = [{"tx_hash":"46581a8f6c82b9f5d43e96a4bb4a42ad7ce1e8bafd004f324c0ffc170bd05c14","tx_index":0,"address":"addr_test1zrfg36fqc5g6xwz2j2jqw074wlmax4dw3vgel7rhw9h47ydl4gu9er4t0w7udjvt2pqngddn6q4h8h3uv38p8p9cq82qkqs555","value":"1327480","stake_address":"stake_test1uzl65wzu364hh0wxex94qsf5xkeaq2mnmc7xgnsnsjuqr4qruvxwu","payment_cred":"d288e920c511a3384a92a4073fd577f7d355ae8b119ff877716f5f11","epoch_no":125,"block_height":1936461,"block_time":1708047277,"datum_hash":"923918e403bf43c34b4ef6b48eb2ee04babed17320d8d1b9ff9ad086e86f44ec","inline_datum":{"bytes": "d87980", "value": {"fields": [], "constructor": 0}},"reference_script":null,"asset_list":[{"decimals": 0, "quantity": "1233322350", "policy_id": "d441227553a0f1a965fee7d60a0f724b368dd1bddbc208730fccebcf", "asset_name": "546869735f49735f415f566572795f4c6f6e675f537472696e675f5f5f5f5f5f", "fingerprint": "asset1jpyk5cfhlest27675m7xc769ndwp6ftjg6hp8t"}],"is_spent":false}]


    let contractUTxO = contractUTxOs.find((utxo: any) => {
      return utxo.datum_hash === datumHash;
    });
    console.log("Contract UTxO", contractUTxO);

    let contractAssets: Asset[] = [];
    contractUTxO.asset_list.forEach(asset => {
      // console.log(asset);
      contractAssets.push({unit: asset.policy_id + asset.asset_name, quantity: asset.quantity})
    });
    
    // get the wallet utxos to see what to lock
    // this is either a user selection or a look up
    // from list kind of thing.
    // the asset we are going to lock
    // hardcoded for now
    const targetPid = "0409e2e893b11527311de4455cf699127b71b7870754a8a493c5edfb";
    const targetTkn = "4c54";
    const targetAmt = 123321;
    // concat
    const targetUnit = targetPid + targetTkn;

    // contract
    type Asset = {
      unit: string;
      quantity: string;
    };
    
    let newContractAssets: Asset[] = [{unit: targetUnit, quantity: targetAmt.toString()}];
    contractUTxO.asset_list.forEach(asset => {
      console.log('asset',asset);
      if (asset.policy_id === targetPid) {
        // policy id and asset name are strings
        // quanity and amt needs to be ints added then converted back to a string
        let quantity = parseInt(asset.quantity, 10) + targetAmt;
        newContractAssets.push({unit: asset.policy_id + asset.asset_name, quantity: quantity.toString()})
      } else {
        newContractAssets.push({unit: asset.policy_id + asset.asset_name, quantity: asset.quantity})
      }
    });
    // need to make things that look like this
    // [{ unit: policyId + tokenName, quantity: "1" }]

    // we need the users utxos now
    const walletUTxOs = await wallet.getUtxos();
    const collateralUTxOs = await wallet.getCollateral();
    // just grab the first one
    const collateralUTxO = collateralUTxOs[0]
    console.log(collateralUTxO);
    
    // get all the utxos with that token and hope for the best that the change works
    // this needs to be a utxo selection algo that doesnt suck
    let filteredUTxOs = walletUTxOs.filter((utxo) => {
      // Check if the utxo contains the target unit
      const containsTargetUnit = utxo.output.amount.some((asset) => {
        return asset.unit === targetUnit;
      });
      // Check if the utxo only has lovelace
      const hasOnlyLovelace = utxo.output.amount.length === 1 && utxo.output.amount[0].unit === 'lovelace';

      // grab all utxos that have that token and all the utxos that are ada
      return containsTargetUnit || hasOnlyLovelace;
    
    });
    console.log("Wallet UTxO", filteredUTxOs);

    // this will be the token to lock
    // many tokens can be in the list
    const redeemer = {
      list: [
        {
          constructor: 0,
          fields: [
            {"bytes": targetPid},
            {"bytes": targetTkn},
            {"int": targetAmt}
          ]
        }
      ]
    };

    /// NOW BUILD THE TX
    console.log("Connect to Provider");
    const mesh = new MeshTxBuilder({
      fetcher: koiosProvider,
      submitter: koiosProvider,
      evaluator: koiosProvider,
    });
    console.log(newContractAssets);
    
    console.log("Building Tx");
    let tx_body = mesh
    .spendingPlutusScriptV2()
    .txIn(contractUTxO.tx_hash, contractUTxO.tx_index, contractAssets, scriptAddress)
    .txInInlineDatumPresent()
    .txInRedeemerValue(redeemer, {mem: 331583, steps: 100701860}, "Raw")
    .spendingTxInReference(scriptRefTxId, scriptRefTxIdx, "d288e920c511a3384a92a4073fd577f7d355ae8b119ff877716f5f11")
    .txOut(scriptAddress, newContractAssets)
    .txOutInlineDatumValue(datum, "Mesh")
    .changeAddress(changeAddress)
    .txInCollateral(collateralUTxO.input.txHash, collateralUTxO.input.outputIndex, [collateralUTxO.output.amount[0]], collateralUTxO.output.address);
    
    // add in the users inputs
    filteredUTxOs.forEach(async utxo => {
      let walletAssets: Asset[] = [];
      utxo.output.amount.forEach(asset => {
        // console.log(asset);
        walletAssets.push(asset)
      });
      tx_body = tx_body.txIn(utxo.input.txHash, utxo.input.outputIndex, walletAssets, utxo.output.address);
    });
    // user outputs should be handled by change address
    
    console.log(tx_body);
    
    console.log("Complete Tx");
    const signed_tx = await tx_body.completeSync().completeSigning();
    console.log(signed_tx);
    

    // Inside your component or page in index.tsx

    // const response = await fetch('/api/meshProxy', {
    //   method: 'POST',
    //   headers: {
    //     'Content-Type': 'application/json',
    //   },
    //   body: JSON.stringify({
    //     // Your request payload here, if needed
    //   }),
    // });
    // const data = await response.json();
    // console.log(data); // Handle the response

    // await mesh.completeSync();
    // const signedTx = mesh.completeSigning()
    // console.log(signedTx);
  }

  return (
    <button type="button" onClick={() => unlockAiken()}>
      Unlock Asset
    </button>
  );
}
