# Bash completion for anthropic-manager

_anthropic_manager() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    # Main options
    opts="--init -i --swap -s --delete -d --token -t --list -l --current -c --help -h"
    
    # If previous word was --init, --swap, or --delete, complete with profile names
    if [[ "$prev" == "--init" ]] || [[ "$prev" == "-i" ]] || [[ "$prev" == "--swap" ]] || [[ "$prev" == "-s" ]] || [[ "$prev" == "--delete" ]] || [[ "$prev" == "-d" ]]; then
        local config_dir="${ANTHROPIC_CONFIG_DIR:-$HOME/.config/crush}"
        local profiles=$(find "$config_dir" -maxdepth 1 -type d -name "anthropic.*" 2>/dev/null | sed 's/.*anthropic\.//' | sort)
        COMPREPLY=( $(compgen -W "${profiles}" -- ${cur}) )
        return 0
    fi
    
    # Complete with options
    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    return 0
}

complete -F _anthropic_manager anthropic-manager
