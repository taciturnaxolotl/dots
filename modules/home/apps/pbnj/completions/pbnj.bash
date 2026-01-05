_pbnj() {
    local cur prev words cword
    _init_completion || return

    local commands="init config list delete delete-all"

    case $prev in
        -L|--language)
            COMPREPLY=($(compgen -W "go python javascript typescript rust ruby java c cpp csharp php bash html css json yaml xml sql markdown swift kotlin scala nix lua vim toml" -- "$cur"))
            return
            ;;
        -f|--filename|-u|--update|-k|--key)
            return
            ;;
        delete|-d)
            return
            ;;
        list)
            return
            ;;
    esac

    case $cur in
        -*)
            COMPREPLY=($(compgen -W "-L --language -f --filename -p --private -k --key -u --update -n --no-copy -l --list -h --help" -- "$cur"))
            return
            ;;
    esac

    if [[ $cword -eq 1 ]]; then
        COMPREPLY=($(compgen -W "$commands" -- "$cur"))
        COMPREPLY+=($(compgen -f -- "$cur"))
        return
    fi

    _filedir
}

complete -F _pbnj pbnj
