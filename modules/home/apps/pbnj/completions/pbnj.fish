# pbnj completions for fish

set -l commands init config list delete delete-all
set -l languages go python javascript typescript rust ruby java c cpp csharp php bash html css json yaml xml sql markdown swift kotlin scala nix lua vim toml

complete -c pbnj -f

# Commands
complete -c pbnj -n "not __fish_seen_subcommand_from $commands" -a init -d "Configure pbnj instance"
complete -c pbnj -n "not __fish_seen_subcommand_from $commands" -a config -d "Show current configuration"
complete -c pbnj -n "not __fish_seen_subcommand_from $commands" -a list -d "List recent pastes"
complete -c pbnj -n "not __fish_seen_subcommand_from $commands" -a delete -d "Delete a paste"
complete -c pbnj -n "not __fish_seen_subcommand_from $commands" -a delete-all -d "Delete all pastes"

# File completion for default
complete -c pbnj -n "not __fish_seen_subcommand_from $commands" -F

# Options
complete -c pbnj -s L -l language -d "Override language" -xa "$languages"
complete -c pbnj -s f -l filename -d "Set filename" -r
complete -c pbnj -s p -l private -d "Create private paste"
complete -c pbnj -s k -l key -d "Add secret key" -r
complete -c pbnj -s u -l update -d "Update existing paste" -r
complete -c pbnj -s n -l no-copy -d "Don't copy URL"
complete -c pbnj -s l -l list -d "List pastes"
complete -c pbnj -s h -l help -d "Show help"
