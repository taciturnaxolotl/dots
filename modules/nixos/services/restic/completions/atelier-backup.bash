# bash completion for atelier-backup

_atelier_backup_completion() {
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Main commands
    local commands="status list backup restore dr --help"

    # Complete flags
    if [[ ${cur} == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- ${cur}) )
        return 0
    fi

    # Complete commands as first argument
    if [[ ${COMP_CWORD} -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "${commands}" -- ${cur}) )
        return 0
    fi

    return 0
}

complete -F _atelier_backup_completion atelier-backup
