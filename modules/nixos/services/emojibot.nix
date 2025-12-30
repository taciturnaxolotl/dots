# Emojibot - Slack emoji management service
#
# Stateless service, no database backup needed

let
  mkService = import ../../lib/mkService.nix;
in

mkService {
  name = "emojibot";
  description = "Emojibot Slack emoji management service";
  defaultPort = 3002;
  runtime = "bun";
  entryPoint = "src/index.ts";

  extraConfig = cfg: {
    # Stateless - no data declarations needed
    # Files are just the app code which is in git
  };
}
