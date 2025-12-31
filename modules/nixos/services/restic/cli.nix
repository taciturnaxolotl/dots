# atelier-backup CLI - Interactive backup management with gum
#
# Commands:
#   atelier-backup              - Interactive menu
#   atelier-backup status       - Show backup status for all services
#   atelier-backup list         - List snapshots (interactive service selection)
#   atelier-backup restore      - Interactive restore wizard
#   atelier-backup backup       - Trigger manual backup
#   atelier-backup dr           - Disaster recovery mode

{ config, lib, pkgs, ... }:

let
  cfg = config.atelier.backup;
  
  # Collect all services with backup data for the manifest
  atelierServices = lib.filterAttrs (name: svc: 
    (svc.enable or false) && (svc.data or null) != null
  ) (config.atelier.services or {});
  
  hasData = svc: 
    (svc.data.sqlite or null) != null ||
    (svc.data.postgres or null) != null ||
    (svc.data.files or []) != [];
  
  servicesWithData = lib.filterAttrs (name: svc: hasData svc) atelierServices;
  
  # Also include manually registered backup services
  allBackupServices = (lib.attrNames cfg.services) ++ (lib.attrNames servicesWithData);
  
  # Generate manifest for disaster recovery
  backupManifest = pkgs.writeText "backup-manifest.json" (builtins.toJSON {
    version = 1;
    generated = "nixos-rebuild";
    services = lib.mapAttrs (name: svc: {
      dataDir = svc.dataDir or "/var/lib/${name}";
      data = {
        sqlite = svc.data.sqlite or null;
        postgres = svc.data.postgres or null;
        files = svc.data.files or [];
        exclude = svc.data.exclude or [];
      };
    }) servicesWithData // lib.mapAttrs (name: backupCfg: {
      paths = backupCfg.paths;
      exclude = backupCfg.exclude or [];
      manual = true;
    }) cfg.services;
  });
  
  backupCliScript = pkgs.writeShellScript "atelier-backup" ''
    set -e
    
    # Colors via gum
    style() { ${pkgs.gum}/bin/gum style "$@"; }
    confirm() { ${pkgs.gum}/bin/gum confirm "$@"; }
    choose() { ${pkgs.gum}/bin/gum choose "$@"; }
    input() { ${pkgs.gum}/bin/gum input "$@"; }
    spin() { ${pkgs.gum}/bin/gum spin "$@"; }
    
    # Auto-elevate to root if needed
    if [ "$(id -u)" -ne 0 ]; then
      exec sudo "$0" "$@"
    fi
    
    # Restic wrapper with secrets
    restic_cmd() {
      ${pkgs.restic}/bin/restic \
        --repository-file ${config.age.secrets."restic/repo".path} \
        --password-file ${config.age.secrets."restic/password".path} \
        "$@"
    }
    export -f restic_cmd
    
    # Load B2 credentials from environment file
    set -a
    source ${config.age.secrets."restic/env".path}
    set +a
    
    # Available services
    SERVICES="${lib.concatStringsSep " " allBackupServices}"
    MANIFEST="${backupManifest}"
    
    cmd_status() {
      style --bold --foreground 212 "Backup Status"
      echo
      
      for svc in $SERVICES; do
        # Get latest snapshot for this service
        latest=$(restic_cmd snapshots --tag "service:$svc" --json --latest 1 2>/dev/null | ${pkgs.jq}/bin/jq -r '.[0] // empty')
        
        if [ -n "$latest" ]; then
          time=$(echo "$latest" | ${pkgs.jq}/bin/jq -r '.time' | cut -d'T' -f1)
          hostname=$(echo "$latest" | ${pkgs.jq}/bin/jq -r '.hostname')
          style --foreground 35 "✓ $svc"
          style --foreground 117 "    Last backup: $time on $hostname"
        else
          style --foreground 214 "! $svc"
          style --foreground 117 "    No backups found"
        fi
      done
    }
    
    cmd_list() {
      style --bold --foreground 212 "List Snapshots"
      echo
      
      # Let user pick a service
      svc=$(echo "$SERVICES" | tr ' ' '\n' | choose --header "Select service:")
      
      if [ -z "$svc" ]; then
        style --foreground 196 "No service selected"
        exit 1
      fi
      
      style --foreground 117 "Snapshots for $svc:"
      echo
      
      restic_cmd snapshots --tag "service:$svc" --compact
    }
    
    cmd_backup() {
      style --bold --foreground 212 "Manual Backup"
      echo
      
      # Let user pick a service or all
      svc=$(echo "all $SERVICES" | tr ' ' '\n' | choose --header "Select service to backup:")
      
      if [ -z "$svc" ]; then
        style --foreground 196 "No service selected"
        exit 1
      fi
      
      run_backup() {
        local svc_name=$1
        
        # Check if already running
        if systemctl is-active --quiet "restic-backups-$svc_name.service"; then
          style --foreground 214 "! $svc_name backup already in progress"
          style --foreground 117 "  Use: journalctl -u restic-backups-$svc_name.service -f"
          return 1
        fi
        
        style --foreground 117 "Backing up $svc_name..."
        
        # Start following journal before starting service
        journalctl -u "restic-backups-$svc_name.service" -f -n 0 --output=cat &
        journal_pid=$!
        
        # Small delay to ensure journalctl is attached
        sleep 0.2
        
        systemctl start "restic-backups-$svc_name.service"
        
        while systemctl is-active --quiet "restic-backups-$svc_name.service"; do
          sleep 1
        done
        
        kill $journal_pid 2>/dev/null || true
        
        if systemctl is-failed --quiet "restic-backups-$svc_name.service"; then
          style --foreground 196 "✗ $svc_name failed"
          return 1
        else
          style --foreground 35 "✓ $svc_name complete"
          return 0
        fi
      }
      
      if [ "$svc" = "all" ]; then
        for s in $SERVICES; do
          run_backup "$s" || true
          echo
        done
      else
        run_backup "$svc"
      fi
      
    }
    
    cmd_restore() {
      style --bold --foreground 212 "Restore Wizard"
      echo
      
      # Pick service
      svc=$(echo "$SERVICES" | tr ' ' '\n' | choose --header "Select service to restore:")
      
      if [ -z "$svc" ]; then
        style --foreground 196 "No service selected"
        exit 1
      fi
      
      # List snapshots for selection
      style --foreground 117 "Fetching snapshots for $svc..."
      snapshots=$(restic_cmd snapshots --tag "service:$svc" --json 2>/dev/null)
      
      if [ "$(echo "$snapshots" | ${pkgs.jq}/bin/jq 'length')" = "0" ]; then
        style --foreground 196 "No snapshots found for $svc"
        exit 1
      fi
      
      # Format snapshots for selection
      snapshot_list=$(echo "$snapshots" | ${pkgs.jq}/bin/jq -r '.[] | "\(.short_id) - \(.time | split("T")[0]) - \(.paths | join(", "))"')
      
      selected=$(echo "$snapshot_list" | choose --header "Select snapshot:")
      snapshot_id=$(echo "$selected" | cut -d' ' -f1)
      
      if [ -z "$snapshot_id" ]; then
        style --foreground 196 "No snapshot selected"
        exit 1
      fi
      
      # Restore options
      restore_mode=$(choose --header "Restore mode:" "Inspect (restore to /tmp)" "In-place (DANGEROUS)")
      
      case "$restore_mode" in
        "Inspect"*)
          target="/tmp/restore-$svc-$snapshot_id"
          mkdir -p "$target"
          
          style --foreground 117 "Restoring to $target..."
          restic_cmd restore "$snapshot_id" --target "$target"
          
          style --foreground 35 "✓ Restored to $target"
          style --foreground 117 "  Inspect files, then copy what you need"
          ;;
          
        "In-place"*)
          style --foreground 196 --bold "⚠ WARNING: This will overwrite existing data!"
          echo
          
          if ! confirm "Stop $svc and restore data?"; then
            style --foreground 214 "Restore cancelled"
            exit 0
          fi
          
          style --foreground 117 "Stopping $svc..."
          systemctl stop "$svc" 2>/dev/null || true
          
          style --foreground 117 "Restoring snapshot $snapshot_id..."
          restic_cmd restore "$snapshot_id" --target /
          
          style --foreground 117 "Starting $svc..."
          systemctl start "$svc"
          
          style --foreground 35 "✓ Restore complete"
          ;;
      esac
    }
    
    cmd_dr() {
      style --bold --foreground 196 "⚠ DISASTER RECOVERY MODE"
      echo
      style --foreground 214 "This will restore ALL services from backup."
      style --foreground 214 "Only use this on a fresh NixOS install."
      echo
      
      if ! confirm "Continue with full disaster recovery?"; then
        style --foreground 117 "Cancelled"
        exit 0
      fi
      
      style --foreground 117 "Reading backup manifest..."
      
      for svc in $SERVICES; do
        style --foreground 212 "Restoring $svc..."
        
        # Get latest snapshot
        snapshot_id=$(restic_cmd snapshots --tag "service:$svc" --json --latest 1 2>/dev/null | ${pkgs.jq}/bin/jq -r '.[0].short_id // empty')
        
        if [ -z "$snapshot_id" ]; then
          style --foreground 214 "  ! No snapshots found, skipping"
          continue
        fi
        
        # Stop service if running
        systemctl stop "$svc" 2>/dev/null || true
        
        # Restore
        restic_cmd restore "$snapshot_id" --target /
        
        # Start service
        systemctl start "$svc" 2>/dev/null || true
        
        style --foreground 35 "  ✓ Restored from $snapshot_id"
      done
      
      echo
      style --foreground 35 --bold "✓ Disaster recovery complete"
    }
    
    cmd_menu() {
      style --bold --foreground 212 "Atelier Backup"
      echo
      
      action=$(choose \
        "Status - Show backup status" \
        "List - Browse snapshots" \
        "Backup - Trigger manual backup" \
        "Restore - Restore from backup" \
        "DR - Disaster recovery mode")
      
      case "$action" in
        Status*) cmd_status ;;
        List*) cmd_list ;;
        Backup*) cmd_backup ;;
        Restore*) cmd_restore ;;
        DR*) cmd_dr ;;
        *) exit 0 ;;
      esac
    }
    
    # Main
    case "''${1:-}" in
      status) cmd_status ;;
      list) cmd_list ;;
      backup) cmd_backup ;;
      restore) cmd_restore ;;
      dr|disaster-recovery) cmd_dr ;;
      --help|-h)
        echo "Usage: atelier-backup [command]"
        echo
        echo "Commands:"
        echo "  status   Show backup status for all services"
        echo "  list     List snapshots"
        echo "  backup   Trigger manual backup"
        echo "  restore  Interactive restore wizard"
        echo "  dr       Disaster recovery mode"
        echo
        echo "Run without arguments for interactive menu."
        ;;
      "") cmd_menu ;;
      *)
        style --foreground 196 "Unknown command: $1"
        exit 1
        ;;
    esac
  '';

  backupCli = pkgs.stdenv.mkDerivation {
    pname = "atelier-backup";
    version = "1.0.0";
    
    dontUnpack = true;
    
    nativeBuildInputs = [ pkgs.installShellFiles pkgs.pandoc ];
    
    manPageSrc = ./atelier-backup.1.md;
    bashCompletionSrc = ./completions/atelier-backup.bash;
    zshCompletionSrc = ./completions/atelier-backup.zsh;
    fishCompletionSrc = ./completions/atelier-backup.fish;
    
    buildPhase = ''
      ${pkgs.pandoc}/bin/pandoc -s -t man $manPageSrc -o atelier-backup.1
    '';
    
    installPhase = ''
      mkdir -p $out/bin
      cp ${backupCliScript} $out/bin/atelier-backup
      chmod +x $out/bin/atelier-backup
      
      # Install man page
      installManPage atelier-backup.1
      
      # Install completions
      installShellCompletion --bash --name atelier-backup $bashCompletionSrc
      installShellCompletion --zsh --name _atelier-backup $zshCompletionSrc
      installShellCompletion --fish --name atelier-backup.fish $fishCompletionSrc
    '';
    
    meta = with lib; {
      description = "Interactive backup management CLI for atelier services";
      license = licenses.mit;
    };
  };

in {
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ backupCli ];
    
    # Store manifest for reference
    environment.etc."atelier/backup-manifest.json".source = backupManifest;
  };
}
