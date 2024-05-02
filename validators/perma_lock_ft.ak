//// This contract is crafted to ensure the permanent immobilization of a specific 
//// fungible token. It is uniquely configured with both a token and a distinct 
//// random string, facilitating the creation of either a singular UTxO or multiple 
//// UTxOs tailored to the particular requirements of the application. This approach 
//// enhances scalability, enabling the generation of numerous contracts for the 
//// identical token, each differentiated by unique random inputs. Such a design 
//// permits these contracts to be aggregated and executed simultaneously within a 
//// single transaction. The minimum amount of lovelace necessary for a UTxO under 
//// this contract is determined by considering the most adverse scenario involving 
//// the token and an empty datum, approximately equating to 1.34 ADA. It is presumed 
//// that the datum will be embedded directly within the contract.
////

use aiken/transaction.{Input, ScriptContext, Spend, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use assist/count
use assist/find
use assist/payout

/// Compile the validator for a specific policy id and asset name and some random bytearray.
validator(
  // the policy id to lock
  lock_pid: PolicyId,
  // the token name to lock
  lock_tkn: AssetName,
  // a random string that allows many ft locking contracts to coexist
  _random_string: ByteArray,
) {
  fn params(_datum: Void, add_amt: Int, context: ScriptContext) -> Bool {
    // must be spending
    expect Spend(out_ref) = context.purpose
    // the transaction being validated
    let Transaction { inputs, outputs, .. } = context.transaction
    // this input being validated
    let this_input: Input = find.input_by_ref(inputs, out_ref)
    // this address being spent from
    let this_addr: Address = this_input.output.address
    // calculate that value returning to this address
    let that_value: Value =
      this_input.output.value |> value.add(lock_pid, lock_tkn, add_amt)
    // this silent fails for anything coming back that isn't the Void type
    expect _: Void = find.output_datum_by_addr(outputs, this_addr)
    //
    // Add `add_amt lock_pid.lock_tkn` to this value and send that value back 
    // to this address. The add amount must be positive and the value being 
    // sent back must be exact.
    //
    and {
      // single script input
      count.inputs_by_addr(inputs, this_addr, 1)?,
      // single script output
      count.outputs_by_addr(outputs, this_addr, 1)?,
      // can only add an amount of token
      (add_amt > 0)?,
      // send exactly that value back to this address
      payout.exact(this_addr, that_value, outputs)?,
    }
  }
}
