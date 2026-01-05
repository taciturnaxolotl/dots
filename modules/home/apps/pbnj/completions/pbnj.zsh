#compdef pbnj

_pbnj() {
    local -a commands
    commands=(
        'init:Configure pbnj instance'
        'config:Show current configuration'
        'list:List recent pastes'
        'delete:Delete a paste'
        'delete-all:Delete all pastes'
    )

    local -a languages
    languages=(go python javascript typescript rust ruby java c cpp csharp php bash html css json yaml xml sql markdown swift kotlin scala nix lua vim toml)

    _arguments -C \
        '1: :->cmd' \
        '*: :->args' \
        '-L+[Override language]:language:($languages)' \
        '--language+[Override language]:language:($languages)' \
        '-f+[Set filename]:filename:_files' \
        '--filename+[Set filename]:filename:_files' \
        '-p[Create private paste]' \
        '--private[Create private paste]' \
        '-k+[Add secret key]:key:' \
        '--key+[Add secret key]:key:' \
        '-u+[Update existing paste]:id:' \
        '--update+[Update existing paste]:id:' \
        '-n[Do not copy URL]' \
        '--no-copy[Do not copy URL]' \
        '-l+[List pastes]:limit:' \
        '--list+[List pastes]:limit:' \
        '-h[Show help]' \
        '--help[Show help]'

    case $state in
        cmd)
            _describe -t commands 'command' commands
            _files
            ;;
        args)
            case $words[2] in
                list)
                    _message 'limit (number)'
                    ;;
                delete)
                    _message 'paste id'
                    ;;
                *)
                    _files
                    ;;
            esac
            ;;
    esac
}

_pbnj "$@"
