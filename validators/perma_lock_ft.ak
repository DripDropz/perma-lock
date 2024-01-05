use aiken/transaction.{Input, ScriptContext, Spend, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use assist/count
use assist/find
use assist/payout

// redeemer needs to add an integer amount of some token
type Redeemer {
  add_amt: Int,
}

// compile the validator for a specific policy id and asset name to lock permanently
validator(lock_pid: PolicyId, lock_tkn: AssetName) {
  fn params(_datum: Void, redeemer: Redeemer, context: ScriptContext) -> Bool {
    when context.purpose is {
      // spend only
      Spend(output_reference) -> {
        // This brings `add_amt` into scope.
        let Redeemer(add_amt) = redeemer
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
          value.add(this_value, lock_pid, lock_tkn, add_amt)
        // that datum must go back this address; implicit data validation
        // this silent fails for anything coming back that isn't Void
        expect _: Void = find.output_datum_by_addr(tx.outputs, this_addr)
        //
        // add some tokens to this value and send that value back to the contract
        //
        and {
          // single script input
          count.inputs_by_addr(tx.inputs, this_addr, 1),
          // single script output
          count.outputs_by_addr(tx.outputs, this_addr, 1),
          // only can add tokens to this value
          add_amt > 0,
          // send exactly that value back to this address
          // ada doesn't change here!
          payout.exact(this_addr, that_value, tx.outputs),
        }
      }
      // anything else fails
      _ -> False
    }
  }
}
