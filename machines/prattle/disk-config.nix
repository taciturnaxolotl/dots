{
  disko.devices = {
    disk = {
      # /dev/sdX is assigned by enumeration order, not by which disk is which,
      # and it has already drifted once: the disk holding disk-main-* is sdc,
      # not the sda this file used to name. Disko formats whatever `main`
      # points at, so a stale name here is a wiped pool member. by-id only.
      main = {
        type = "disk";
        device = "/dev/disk/by-id/ata-INTEL_SSDSC2KB240G8_BTYF913507GA240AGN";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "bcachefs";
                mountpoint = "/";
                extraArgs = [ "--compression=zstd" ];
              };
            };
          };
        };
      };
      storage1 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-HGST_HDN726060ALE614_K1HHZH5B";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "storage";
              };
            };
          };
        };
      };
      storage2 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-HGST_HDN726060ALE614_K1HHZD8B";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "storage";
              };
            };
          };
        };
      };
    };
    zpool = {
      storage = {
        type = "zpool";
        mode = "mirror";
        options = {
          ashift = "12";
          autotrim = "on";
        };
        rootFsOptions = {
          compression = "zstd";
          atime = "off";
          xattr = "sa";
          acltype = "posixacl";
          mountpoint = "none";
        };
        datasets = {
          data = {
            type = "zfs_fs";
            mountpoint = "/storage";
            options.mountpoint = "legacy";
          };
        };
      };
    };
  };
}
