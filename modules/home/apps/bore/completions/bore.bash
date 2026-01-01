# bash completion for bore

_bore_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="--list --saved --protocol --label --auth --save -l -s -p -a"

    # Complete flags
    if [[ ${cur} == -* ]]; then
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
        return 0
    fi

    # Complete protocol values after --protocol or -p
    if [[ ${prev} == "--protocol" ]] || [[ ${prev} == "-p" ]]; then
        COMPREPLY=( $(compgen -W "http tcp udp" -- ${cur}) )
        return 0
    fi

    # Complete label value after --label or -l
    if [[ ${prev} == "--label" ]] || [[ ${prev} == "-l" ]]; then
        # Could potentially read from bore.toml for label suggestions
        return 0
    fi

    # Complete saved tunnel names as first argument
    if [[ ${COMP_CWORD} -eq 1 ]] && [[ -f "bore.toml" ]]; then
        local tunnels=$(grep '^\[' bore.toml | sed 's/^\[\(.*\)\]$/\1/')
        COMPREPLY=( $(compgen -W "${tunnels}" -- ${cur}) )
        return 0
    fi

    return 0
}

complete -F _bore_completion bore
