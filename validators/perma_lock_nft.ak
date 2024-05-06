//// A contract designed for permanently locking arbitrary tokens to a UTxO. 
//// The idea here is to be able to perma lock nfts, spam, scam, or whatever. 
//// The minimum lovelace required for this solution will gradually increase 
//// as the size of the UTxO grows. Once a UTxO is full, a new UTxO should be 
//// made within the same contract. The random string allows many general 
//// token locks to coexist inside a single transaction.
////

use aiken/transaction.{Input, ScriptContext, Spend, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{Value}
use assist/count
use assist/find
use assist/payout
use assist/types/token.{Tokens}

/// Compile the validator to a random bytearray.
validator(
  // a random string that allows many locking contracts to coexist
  _random_string: ByteArray,
) {
  fn params(_datum: Void, assets: Tokens, context: ScriptContext) -> Bool {
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
      this_input.output.value |> token.add_tokens_to_value(assets)
    // this silent fails for anything coming back that isn't the Void type
    expect _: Void = find.output_datum_by_addr(outputs, this_addr)
    //
    // Add tokens to this value and send at least that value back to this 
    // address. All tokens being added to that value must be positive.
    //
    and {
      // single script input
      count.inputs_by_addr(inputs, this_addr, 1)?,
      // single script output
      count.outputs_by_addr(outputs, this_addr, 1)?,
      // send at least that value back to this address
      payout.at_least(this_addr, that_value, outputs)?,
      // can only add tokens
      token.addition_only(assets)?,
    }
  }
}
