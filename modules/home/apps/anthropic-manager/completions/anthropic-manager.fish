# Fish completion for anthropic-manager

# Helper function to get profile list
function __anthropic_manager_profiles
    set -l config_dir (test -n "$ANTHROPIC_CONFIG_DIR"; and echo $ANTHROPIC_CONFIG_DIR; or echo "$HOME/.config/crush")
    if test -d "$config_dir"
        find "$config_dir" -maxdepth 1 -type d -name "anthropic.*" 2>/dev/null | sed 's/.*anthropic\.//' | sort
    end
end

# Main options
complete -c anthropic-manager -s h -l help -d "Show help information"
complete -c anthropic-manager -s i -l init -d "Initialize a new profile" -xa "(__anthropic_manager_profiles)"
complete -c anthropic-manager -s s -l swap -d "Switch to a profile" -xa "(__anthropic_manager_profiles)"
complete -c anthropic-manager -s d -l delete -d "Delete a profile" -xa "(__anthropic_manager_profiles)"
complete -c anthropic-manager -s t -l token -d "Print current bearer token"
complete -c anthropic-manager -s l -l list -d "List all profiles"
complete -c anthropic-manager -s c -l current -d "Show current profile"
