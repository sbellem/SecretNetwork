import { Coin, EncodeObject } from "@cosmjs/proto-signing";

export interface MsgStoreCode extends EncodeObject {
  readonly typeUrl: "/secret.compute.v1beta1.MsgStoreCode";
  readonly value: /** Bech32 account address */
  {
    /** Bech32 account address */
    sender: string;
    /** Base64 encoded Wasm */
    wasm_byte_code: string;
    /** A valid URI reference to the contract's source code. Can be empty. */
    source?: string;
    /** A docker tag. Can be empty. */
    builder?: string;
  };
}

export function isMsgStoreCode(
  encodeObject: EncodeObject
): encodeObject is MsgStoreCode {
  return (
    (encodeObject as MsgStoreCode).typeUrl ===
    "/secret.compute.v1beta1.MsgStoreCode"
  );
}

export interface MsgInstantiateContract extends EncodeObject {
  readonly typeUrl: "/secret.compute.v1beta1.MsgInstantiateContract";
  readonly value: {
    /** Bech32 account address */
    sender: string;
    /** ID of the Wasm code that was uploaded before */
    code_id: string;
    /** Human-readable label for this contract */
    label: string;
    /** Init message as JavaScript object */
    init_msg: any;
    /** Funds to send to the contract */
    init_funds: Coin[];
  };
}

export function isMsgInstantiateContract(
  encodeObject: EncodeObject
): encodeObject is MsgInstantiateContract {
  return (
    (encodeObject as MsgInstantiateContract).typeUrl ===
    "/secret.compute.v1beta1.MsgInstantiateContract"
  );
}

export interface MsgExecuteContract extends EncodeObject {
  readonly typeUrl: "/secret.compute.v1beta1.MsgExecuteContract";
  readonly value: {
    /** Bech32 account address */
    readonly sender: string;
    /** Bech32 contract address */
    readonly contract: string;
    /** Handle message as JavaScript object */
    msg: any;
    /** Funds to send to the contract */
    readonly sent_funds: Coin[];
  };
}

export function isMsgExecuteContract(
  encodeObject: EncodeObject
): encodeObject is MsgExecuteContract {
  return (
    (encodeObject as MsgExecuteContract).typeUrl ===
    "/secret.compute.v1beta1.MsgExecuteContract"
  );
}
