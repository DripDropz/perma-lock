use aiken/transaction.{Input, ScriptContext, Spend, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{Value}
use assist/count
use assist/find
use assist/payout
use assist/types.{Token}

// redeemer just needs to add in more tokens but we need to
type Redeemer {
  asset: Token,
}

// compile the validator for a specific policy id and asset name to lock permanently
validator {
  fn params(_datum: Void, redeemer: Redeemer, context: ScriptContext) -> Bool {
    when context.purpose is {
      // spend only
      Spend(output_reference) -> {
        // This brings `asset` into scope.
        let Redeemer(asset) = redeemer
        // the entire transaction
        let tx: Transaction = context.transaction
        // this input being validated
        let this_input: Input = find.input_by_ref(tx.inputs, output_reference)
        // this address being spent from
        let this_addr: Address = this_input.output.address
        // this value on this input
        let this_value: Value = this_input.output.value
        // calculate that value returning to this address
        let that_value: Value =
          value.add(this_value, asset.pid, asset.tkn, asset.amt)
        // that datum must go back this address; implicit data validation
        // this silent fails for anything coming back that isn't Void
        expect _: Void = find.output_datum_by_addr(tx.outputs, this_addr)
        //
        // add a token and send it back to the contract
        //
        and {
          // single script input
          count.inputs_by_addr(tx.inputs, this_addr, 1),
          // single script output
          count.outputs_by_addr(tx.outputs, this_addr, 1),
          // only can add tokens to the value
          asset.amt > 0,
          // send at least that value back to the contract, ada can change here
          payout.at_least(this_addr, that_value, tx.outputs),
        }
      }
      // anything else fails
      _ -> False
    }
  }
}
