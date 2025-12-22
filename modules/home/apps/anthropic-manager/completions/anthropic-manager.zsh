#compdef anthropic-manager

_anthropic_manager() {
    local config_dir="${ANTHROPIC_CONFIG_DIR:-$HOME/.config/crush}"
    local -a profiles
    
    # Get list of profiles
    if [[ -d "$config_dir" ]]; then
        profiles=(${(f)"$(find "$config_dir" -maxdepth 1 -type d -name "anthropic.*" 2>/dev/null | sed 's/.*anthropic\.//' | sort)"})
    fi
    
    _arguments -C \
        '(- *)'{-h,--help}'[Show help information]' \
        '(-i --init)'{-i,--init}'[Initialize a new profile]:profile name:' \
        '(-s --swap)'{-s,--swap}'[Switch to a profile]:profile:($profiles)' \
        '(-d --delete)'{-d,--delete}'[Delete a profile]:profile:($profiles)' \
        '(-t --token)'{-t,--token}'[Print current bearer token]' \
        '(-l --list)'{-l,--list}'[List all profiles]' \
        '(-c --current)'{-c,--current}'[Show current profile]'
}

_anthropic_manager "$@"
