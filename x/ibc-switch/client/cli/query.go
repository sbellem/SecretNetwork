package cli

import (
	"github.com/cosmos/cosmos-sdk/client"
	"github.com/cosmos/cosmos-sdk/client/flags"
	"github.com/spf13/cobra"

	"github.com/scrtlabs/SecretNetwork/x/ibc-switch/types"
)

// todo remove
//"github.com/osmosis-labs/osmosis/osmoutils/osmocli"
//"github.com/osmosis-labs/osmosis/v15/x/ibc-rate-limit/client/queryproto"

// GetQueryCmd returns the cli query commands for this module.
//func GetQueryCmdOsmosis() *cobra.Command {
//	cmd := osmocli.QueryIndexCmd(types.ModuleName)
//
//	cmd.AddCommand(
//		osmocli.GetParams[*queryproto.ParamsRequest](
//			types.ModuleName, queryproto.NewQueryClient),
//	)
//
//	return cmd
//}

func GetQueryCmd() *cobra.Command {
	queryCmd := &cobra.Command{
		Use:                        types.ModuleName,
		Aliases:                    []string{"switch"},
		Short:                      "Querying commands for the ibc-switch module",
		DisableFlagParsing:         true,
		SuggestionsMinimumDistance: 2,
		RunE:                       client.ValidateCmd,
	}
	queryCmd.AddCommand(
		GetCmdParams(),
	)
	return queryCmd
}

// GetCmdListCode lists all wasm code uploaded
func GetCmdParams() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "params",
		Short: "List all parameters of the ibc-switch module",
		Long:  "List all parameters of the ibc-switch module",
		Args:  cobra.ExactArgs(0),
		RunE: func(cmd *cobra.Command, args []string) error {
			clientCtx, err := client.GetClientQueryContext(cmd)
			if err != nil {
				return err
			}

			queryClient := types.NewQueryClient(clientCtx)
			res, err := queryClient.Params(cmd.Context(), &types.QueryParamsRequest{})
			if err != nil {
				return err
			}

			return clientCtx.PrintProto(&res.Params)
		},
	}

	flags.AddQueryFlagsToCmd(cmd)
	return cmd
}
