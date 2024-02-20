import Head from "next/head";
import {
  MeshTxBuilder,
  KoiosProvider,
  resolveDataHash,
} from "@meshsdk/core";
import type { Data } from "@meshsdk/core";
import { CardanoWallet, useWallet } from "@meshsdk/react";

import { useState } from "react";

enum States {
  init,
  locking,
  lockingConfirming,
  locked,
  unlocking,
  unlockingConfirming,
  unlocked,
}

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

  // the wallet we need
  const { wallet } = useWallet();

  // click unlock aiken button
  async function unlockAiken() {
    setState(States.unlocking);
    if (!process.env.NEXT_PUBLIC_TOKEN) {
      console.error("No Koios Token.");
      return; // Exit the function or handle it as appropriate
    }
    const koiosProvider = new KoiosProvider('preprod', process.env.NEXT_PUBLIC_TOKEN);

    // hardcode for demo
    const scriptRefTxId = "026ac222531e98efcd2950a12baba80af409a9fa8d359119435c48e6be7ceff0";
    const scriptRefTxIdx = 1;
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
    const contractUTxOs = await koiosProvider.fetchAddressUTxOs(scriptAddress);    
    let contractUTxO = contractUTxOs.find((utxo: any) => {
      return utxo.output.dataHash === datumHash;
    });
    if (!contractUTxO) {
      console.error("No contract UTxO found matching the datum hash.");
      return; // Exit the function or handle it as appropriate
    }
    console.log("Contract UTxO", contractUTxO);
    // this is what is on the contract utxo
    let contractAssets = contractUTxO.output.amount;

    // the asset we are going to lock
    // hardcoded for now
    const targetPid = "0409e2e893b11527311de4455cf699127b71b7870754a8a493c5edfb";
    const targetTkn = "4c54";
    const targetAmt = 123321;
    // concat
    const targetUnit = targetPid + targetTkn;

    // Asset type
    type Asset = {
      unit: string;
      quantity: string;
    };
    
    // need to make things that look like this
    // [{ unit: policyId + tokenName, quantity: "1" }]
    let newContractAssets: Asset[] = [{unit: targetUnit, quantity: targetAmt.toString()}];
    contractAssets.forEach(asset => {
      if (asset.policy_id === targetPid) {
        let quantity = parseInt(asset.quantity, 10) + targetAmt;
        newContractAssets.push({unit: asset.policy_id + asset.asset_name, quantity: quantity.toString()})
      } else {
        newContractAssets.push({unit: asset.policy_id + asset.asset_name, quantity: asset.quantity})
      }
    });
    console.log('New Contract Assets',newContractAssets);

    // we need the users utxos now
    const walletUTxOs = await wallet.getUtxos();
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

    const collateralUTxOs = await wallet.getCollateral();
    const collateralUTxO = collateralUTxOs[0]
    console.log('Collateral', collateralUTxO.input.txHash, collateralUTxO.input.outputIndex);
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
    // this doesnt work with current cors limitations
    console.log("Connect to Provider");
    const mesh = new MeshTxBuilder({
      fetcher: koiosProvider,
      submitter: koiosProvider,
      evaluator: koiosProvider,
    });
    
    console.log("Building Tx");
    let tx_body = mesh;
    // add in the users inputs
    filteredUTxOs.forEach(async utxo => {
      tx_body.txIn(utxo.input.txHash, utxo.input.outputIndex);
    });
    // users outputs will be handled by the change address automatically
    tx_body
    .spendingPlutusScriptV2()
    .txIn(contractUTxO.input.txHash, contractUTxO.input.outputIndex)
    .txInDatumValue(datum)
    .txInRedeemerValue(redeemer)
    .spendingTxInReference(scriptRefTxId, scriptRefTxIdx)
    .txOut(scriptAddress, newContractAssets)
    .txOutInlineDatumValue(datum)
    .changeAddress(changeAddress)
    .txInCollateral(collateralUTxO.input.txHash, collateralUTxO.input.outputIndex);
    
    // // user outputs should be handled by change address
    console.log('tx body', tx_body);
    await tx_body.complete()
    console.log("Sign Tx");
    const signed_tx = tx_body.completeSigning();
    console.log('signed tx', signed_tx);
  }

  return (
    <button type="button" onClick={() => unlockAiken()}>
      Unlock Asset
    </button>
  );
}
