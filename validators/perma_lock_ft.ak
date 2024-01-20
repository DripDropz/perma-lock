//// A contract designed for permanently locking a specific fungible token.
//// The contract is parameterized with a token and a random string. The idea here
//// is having a single utxo or few utxos per contract or as required by the use case.
//// Then the contract is very scalable as many contracts can be made for the same token
//// using different random inputs allowing them to be spent together inside one transaction.
//// The minimum lovelace required for a UTxO in this contract should be based off the worst
//// case token and the empty datum which is about 1.2 ADA. The datum is assumed to be inline.
////

use aiken/transaction.{Input, ScriptContext, Spend, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use assist/count
use assist/find
use assist/payout

/// The redeemer adds an integer amount of the ft to the UTxO.
type Redeemer {
  add_amt: Int,
}

/// Compile the validator for a specific policy id and asset name and some random bytearray.
validator(
  // the policy id to lock
  lock_pid: PolicyId,
  // the token name to lock
  lock_tkn: AssetName,
  // a random string that allows many ft locking contracts to coexist
  _random_string: ByteArray,
) {
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
        // this silent fails for anything coming back that isn't the Void type
        expect _: Void = find.output_datum_by_addr(tx.outputs, this_addr)
        //
        // Add `amt lock_pid.lock_tkn` to this value and send that value back 
        // to this address.
        //
        and {
          // single script input
          count.inputs_by_addr(tx.inputs, this_addr, 1),
          // single script output
          count.outputs_by_addr(tx.outputs, this_addr, 1),
          // only can add tokens to this value
          add_amt > 0,
          // send exactly that value back to this address
          payout.exact(this_addr, that_value, tx.outputs),
        }
      }
      // anything else fails
      _ -> False
    }
  }
}
