import {
  ChangeAdminResult,
  ExecuteResult,
  InstantiateOptions,
  InstantiateResult,
  MigrateResult,
  SigningCosmWasmClient,
  SigningCosmWasmClientOptions,
  UploadResult,
} from "@cosmjs/cosmwasm-stargate";
import {
  Coin,
  EncodeObject as Msg,
  OfflineSigner,
} from "@cosmjs/proto-signing";
import { BroadcastTxResponse, StdFee } from "@cosmjs/stargate";
import { Tendermint34Client } from "@cosmjs/tendermint-rpc";
import { TxRaw } from "cosmjs-types/cosmos/tx/v1beta1/tx";

export interface SecretJsSigningOptions {
  broadcastTimeoutMs?: number;
  broadcastPollIntervalMs?: number;
}

export class SecretJs extends SigningCosmWasmClient {
  /**
   * Creates a client.
   */
  public static async connectWithSigner(
    endpoint: string,
    signer: OfflineSigner,
    options: SecretJsSigningOptions = {}
  ): Promise<SecretJs> {
    const tmClient = await Tendermint34Client.connect(endpoint);

    if (!options.broadcastTimeoutMs) {
      options.broadcastTimeoutMs = 6_000;
    }

    return new SecretJs(tmClient, signer, {
      prefix: "secret",
      ...options,
    });
  }

  /**
   * Creates a client in offline mode.
   *
   * This should only be used in niche cases where you know exactly what you're doing,
   * e.g. when building an offline signing application.
   *
   * When you try to use online functionality with such a signer, an
   * exception will be raised.
   */
  public static async offline(
    signer: OfflineSigner,
    options: SecretJsSigningOptions = {}
  ): Promise<SecretJs> {
    return new SecretJs(undefined, signer, options);
  }

  protected constructor(
    tmClient: Tendermint34Client | undefined,
    signer: OfflineSigner,
    options: SigningCosmWasmClientOptions
  ) {
    super(tmClient, signer, options);
  }

  /**
   * Creates a transaction with the given messages, fee and memo. Then signs and broadcasts the transaction.
   *
   * @param signerAddress The address that will sign transactions using this instance. The signer must be able to sign with this address.
   * @param messages
   * @param fee
   * @param memo
   */
  public async signAndBroadcast(
    signerAddress: string,
    messages: readonly Msg[],
    fee: StdFee,
    memo = ""
  ): Promise<BroadcastTxResponse> {
    const txRaw = await this.sign(signerAddress, messages, fee, memo);
    const txBytes = TxRaw.encode(txRaw).finish();
    return this.broadcastTx(
      txBytes,
      this.broadcastTimeoutMs,
      this.broadcastPollIntervalMs
    );
  }

  /**
   * @deprecated The method should not be used
   */
  public async upload(
    senderAddress: string,
    wasmCode: Uint8Array,
    fee: StdFee,
    memo = ""
  ): Promise<UploadResult> {
    //@ts-ignore
    return;
  }

  /**
   * @deprecated The method should not be used
   */
  public async instantiate(
    senderAddress: string,
    codeId: number,
    msg: Record<string, unknown>,
    label: string,
    fee: StdFee,
    options: InstantiateOptions = {}
  ): Promise<InstantiateResult> {
    //@ts-ignore
    return;
  }

  /**
   * @deprecated The method should not be used
   */
  public async updateAdmin(
    senderAddress: string,
    contractAddress: string,
    newAdmin: string,
    fee: StdFee,
    memo = ""
  ): Promise<ChangeAdminResult> {
    //@ts-ignore
    return;
  }

  /**
   * @deprecated The method should not be used
   */
  public async clearAdmin(
    senderAddress: string,
    contractAddress: string,
    fee: StdFee,
    memo = ""
  ): Promise<ChangeAdminResult> {
    //@ts-ignore
    return;
  }

  /**
   * @deprecated The method should not be used
   */
  public async migrate(
    senderAddress: string,
    contractAddress: string,
    codeId: number,
    migrateMsg: Record<string, unknown>,
    fee: StdFee,
    memo = ""
  ): Promise<MigrateResult> {
    //@ts-ignore
    return;
  }

  /**
   * @deprecated The method should not be used
   */
  public async execute(
    senderAddress: string,
    contractAddress: string,
    msg: Record<string, unknown>,
    fee: StdFee,
    memo = "",
    funds?: readonly Coin[]
  ): Promise<ExecuteResult> {
    //@ts-ignore
    return;
  }

  /**
   * @deprecated The method should not be used
   */
  public async sendTokens(
    senderAddress: string,
    recipientAddress: string,
    amount: readonly Coin[],
    fee: StdFee,
    memo = ""
  ): Promise<BroadcastTxResponse> {
    //@ts-ignore
    return;
  }

  /**
   * @deprecated The method should not be used
   */
  public async delegateTokens(
    delegatorAddress: string,
    validatorAddress: string,
    amount: Coin,
    fee: StdFee,
    memo = ""
  ): Promise<BroadcastTxResponse> {
    //@ts-ignore
    return;
  }

  /**
   * @deprecated The method should not be used
   */
  public async undelegateTokens(
    delegatorAddress: string,
    validatorAddress: string,
    amount: Coin,
    fee: StdFee,
    memo = ""
  ): Promise<BroadcastTxResponse> {
    //@ts-ignore
    return;
  }

  /**
   * @deprecated The method should not be used
   */
  public async withdrawRewards(
    delegatorAddress: string,
    validatorAddress: string,
    fee: StdFee,
    memo = ""
  ): Promise<BroadcastTxResponse> {
    //@ts-ignore
    return;
  }
}
