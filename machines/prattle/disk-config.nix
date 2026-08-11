{
  disko.devices = {
    disk = {
      # /dev/sdX is assigned by enumeration order, not by which disk is which,
      # and it has already drifted once: the disk holding disk-main-* is sdc,
      # not the sda this file used to name. Disko formats whatever `main`
      # points at, so a stale name here is a wiped pool member. by-id only.
      # Swap `main` to the new SSD's by-id when it goes in.
      main = {
        type = "disk";
        device = "/dev/disk/by-id/ata-Hitachi_HTS543212L9SA02_090130FBEB00LGGJ35RF";
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
                format = "ext4";
                mountpoint = "/";
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
