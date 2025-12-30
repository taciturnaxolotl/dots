# fish completion for atelier-backup

# Disable file completion
complete -c atelier-backup -f

# Commands (first argument only)
complete -c atelier-backup -n '__fish_is_first_token' -a 'status' -d 'Show backup status for all services'
complete -c atelier-backup -n '__fish_is_first_token' -a 'list' -d 'List snapshots for a service'
complete -c atelier-backup -n '__fish_is_first_token' -a 'backup' -d 'Trigger manual backup'
complete -c atelier-backup -n '__fish_is_first_token' -a 'restore' -d 'Interactive restore wizard'
complete -c atelier-backup -n '__fish_is_first_token' -a 'dr' -d 'Disaster recovery mode'

# Flags
complete -c atelier-backup -s h -l help -d 'Show help'
