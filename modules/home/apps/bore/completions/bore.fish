# fish completion for bore

# Helper function to get saved tunnel names
function __bore_saved_tunnels
    if test -f bore.toml
        grep '^\[' bore.toml | sed 's/^\[\(.*\)\]$/\1/'
    end
end

# Complete flags
complete -c bore -s l -l list -d 'List active tunnels'
complete -c bore -s s -l saved -d 'List saved tunnels from bore.toml'
complete -c bore -s p -l protocol -d 'Specify protocol' -xa 'http tcp udp'
complete -c bore -l label -d 'Assign a label to the tunnel' -r
complete -c bore -s a -l auth -d 'Require Indiko authentication'
complete -c bore -l save -d 'Save tunnel configuration to bore.toml'

# Complete subdomain from saved tunnels (first argument)
complete -c bore -n '__fish_is_first_token' -a '(__bore_saved_tunnels)' -d 'Saved tunnel'

# Port is always a number (second argument)
complete -c bore -n 'test (count (commandline -opc)) -eq 2' -d 'Local port'
