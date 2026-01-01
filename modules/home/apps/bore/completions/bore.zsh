#compdef bore

_bore() {
    local -a tunnels
    local curcontext="$curcontext" state line
    typeset -A opt_args

    # Read saved tunnels from bore.toml if it exists
    if [[ -f "bore.toml" ]]; then
        tunnels=(${(f)"$(grep '^\[' bore.toml | sed 's/^\[\(.*\)\]$/\1/')"})
    fi

    _arguments -C \
        '1: :->subdomain' \
        '2: :->port' \
        '--list[List active tunnels]' \
        '-l[List active tunnels]' \
        '--saved[List saved tunnels from bore.toml]' \
        '-s[List saved tunnels from bore.toml]' \
        '--protocol[Specify protocol]:protocol:(http tcp udp)' \
        '-p[Specify protocol]:protocol:(http tcp udp)' \
        '--label[Assign a label to the tunnel]:label:' \
        '--auth[Require Indiko authentication]' \
        '-a[Require Indiko authentication]' \
        '--save[Save tunnel configuration to bore.toml]' \
        && return 0

    case $state in
        subdomain)
            if [[ ${#tunnels[@]} -gt 0 ]]; then
                _describe 'saved tunnels' tunnels
            else
                _message 'subdomain (e.g., myapp)'
            fi
            ;;
        port)
            _message 'local port (e.g., 8000)'
            ;;
    esac

    return 0
}

_bore "$@"
