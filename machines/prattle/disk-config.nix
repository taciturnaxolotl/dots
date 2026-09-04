# Disko owns the root disk and nothing else.
#
# /storage is a four-device tiered bcachefs (both 1T SSDs + both 6T spinners)
# created by hand during the migration and declared in fileSystems. That is
# deliberate: a disko config naming those four devices would put a script in
# this flake whose job is to reformat the library, and the only thing standing
# between it and 286G would be nobody running it. Root is the disposable half;
# it is the half that gets a formatter.
#
# by-id only. /dev/sdX has already drifted once on this machine and disko
# formats whatever this string names.
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/disk/by-id/nvme-KXG60ZNV512G_NVMe_KIOXIA_512GB_30HF30B9F7HL";
    content = {
      type = "gpt";
      partitions = {
        boot = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
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
}
