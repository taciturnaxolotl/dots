package main

import (
	"fmt"

	"github.com/spf13/cobra"
)

// A process cannot change its parent's working directory, so following the new
// repo has to happen in the shell. ghrpc writes its final directory to the file
// named by GHRPC_DIR_FILE and these wrappers do the cd.
//
// The helper binaries are format holes so a Nix build can pin them to store
// paths; the plain build resolves them from PATH like any other shell script.
const posixInit = `ghrpc() {
  local _ghrpc_tmp _ghrpc_status _ghrpc_dir
  _ghrpc_tmp=$(%[1]s) || return 1
  GHRPC_DIR_FILE="$_ghrpc_tmp" command ghrpc "$@"
  _ghrpc_status=$?
  _ghrpc_dir=$(<"$_ghrpc_tmp")
  %[2]s -f "$_ghrpc_tmp"
  if [ -n "$_ghrpc_dir" ] && [ -d "$_ghrpc_dir" ]; then
    cd "$_ghrpc_dir" || return $_ghrpc_status
  fi
  return $_ghrpc_status
}
`

const fishInit = `function ghrpc
    set -l tmp (%[1]s); or return 1
    GHRPC_DIR_FILE=$tmp command ghrpc $argv
    set -l code $status
    set -l dir (%[3]s $tmp 2>/dev/null)
    %[2]s -f $tmp
    if test -n "$dir" -a -d "$dir"
        cd $dir
    end
    return $code
end
`

func newShellCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "shell [zsh|bash|fish]",
		Short: "Print the shell integration that cds into the new repo",
		Long: `Print a shell function that runs ghrpc and then changes into the
repository it set up. Source it from your shell config:

  source <(ghrpc shell zsh)`,
		Args:      cobra.ExactArgs(1),
		ValidArgs: []string{"zsh", "bash", "fish"},
		RunE: func(cmd *cobra.Command, args []string) error {
			switch args[0] {
			case "fish":
				fmt.Fprintf(cmd.OutOrStdout(), fishInit, mktempBin, rmBin, catBin)
			case "zsh", "bash":
				fmt.Fprintf(cmd.OutOrStdout(), posixInit, mktempBin, rmBin)
			default:
				return fmt.Errorf("unsupported shell %q", args[0])
			}
			return nil
		},
	}
}
