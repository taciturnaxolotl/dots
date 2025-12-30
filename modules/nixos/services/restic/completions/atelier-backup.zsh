#compdef atelier-backup

_atelier-backup() {
    local curcontext="$curcontext" state line
    typeset -A opt_args

    _arguments -C \
        '1: :->command' \
        '--help[Show help]' \
        '-h[Show help]' \
        && return 0

    case $state in
        command)
            local -a commands
            commands=(
                'status:Show backup status for all services'
                'list:List snapshots for a service'
                'backup:Trigger manual backup'
                'restore:Interactive restore wizard'
                'dr:Disaster recovery mode'
            )
            _describe 'command' commands
            ;;
    esac

    return 0
}

_atelier-backup "$@"
