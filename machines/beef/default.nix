{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./home-manager.nix
    ../../modules/shared/machine.nix
    ../../modules/darwin/defaults.nix
  ];

  networking.hostName = "beef";

  # Determinate Nix manages its own daemon; disable nix-darwin nix management
  nix.enable = false;

  atelier.machine = {
    enable = true;
    type = "client";
    tailscaleHost = "beef";
  };

  environment.systemPackages = [
    pkgs.nixd
    pkgs.nil
    pkgs.nixfmt
    inputs.agenix.packages.aarch64-darwin.default
    pkgs.nodejs_22
    pkgs.unstable.bun
    pkgs.python3
    pkgs.go
    pkgs.gopls
    pkgs.gotools
    pkgs.go-tools
    pkgs.cargo
    pkgs.jdk
    pkgs.ruby
    pkgs.cmake
    pkgs.unstable.biome
    pkgs.unstable.zola
    pkgs.mill
    pkgs.clang-tools
    pkgs.ninja
    pkgs.calc
    pkgs.nh
  ];

  age.secrets = {
    wakatime = {
      file = ../../secrets/wakatime.age;
      path = "/Users/kierank/.wakatime.cfg";
      owner = "kierank";
    };
    bluesky = {
      file = ../../secrets/bluesky.age;
      owner = "kierank";
    };
    "bore/auth-token" = {
      file = ../../secrets/bore/auth-token.age;
      owner = "kierank";
    };
    pbnj = {
      file = ../../secrets/pbnj.age;
      owner = "kierank";
    };
  };

  # ── BotThisSite solvers ──────────────────────────────────────────────
  # Three agents against botme: the cap.js proof-of-work solver, the Turnstile
  # burst solver, and the dashboard that reads what they write.
  #
  # Everything under solverDir is a prerequisite this file does not manage: the
  # solvers live in their own repo and the venv carries playwright, so nix owns
  # the services and not the source. If either goes missing the job fails, and
  # ThrottleInterval keeps it from crash-looping while it does.
  #
  # These are user agents, not daemons, on purpose. The Turnstile solver drives
  # headed Chrome, which needs the logged-in Aqua session; log out and it stops
  # minting until the next login.
  launchd.user.agents =
    let
      # The two solvers fight for the same cores and the leaderboard counts every
      # captcha type alike, so running both is strictly worse than running the
      # better one. Measured here: cap alone 65 solves/s, Turnstile alone 4.5/s
      # (its all-time average while active), the two together 11-13/s and 0.15/s.
      # Flip this to true to trade ~52 cap solves a second for ~4.5 Turnstile
      # ones, which is only worth it if the cf-turnstile column is the goal.
      runTurnstile = false;

      dir = "/Users/kierank/turnstile-solver";
      py = "${dir}/.venv/bin/python";
      logs = "/Users/kierank/Library/Logs";

      common = {
        RunAtLoad = true;
        KeepAlive = true;
        ThrottleInterval = 60; # a missing checkout must not become a spin loop
        WorkingDirectory = dir;
        # Without this launchd runs the job at background QoS, and on Apple
        # silicon background QoS means the four efficiency cores and nothing
        # else. Sixteen solvers packed onto those cores measured 4.5 solves/s
        # against 69 for the same command run from a shell.
        ProcessType = "Interactive";
      };

      # cap and botme are addressed over the tailnet rather than by their public
      # names. Both run on prattle, and the public path goes out to terebithia
      # and back: measured ~90ms against ~10ms direct.
      tailnet = {
        CAP_HOST = "http://100.105.247.54:3013";
        BOTTHIS_HOST = "http://100.105.247.54:3012";
      };

      # Chrome dies between cycles because CF caps re-solves per session, so a
      # long-lived browser stops minting. Matching on --remote-debugging-pipe
      # hits only playwright's Chrome; matching on "Google Chrome" would take
      # the browser you are reading this in down with it.
      #
      # /usr/bin/pkill rather than a package: nixpkgs' procps on darwin is a
      # stub carrying ps, sysctl, top and watch, and nothing else.
      burstLoop = pkgs.writeShellScript "turnstile-burst-loop" ''
        cd ${dir}
        while true; do
          /usr/bin/pkill -f -- --remote-debugging-pipe || true
          sleep 2
          ${py} turnstile_burst.py --lanes 6 --widgets 6 --age 15 --dur 240 --db stats.db || true
          sleep 2
        done
      '';
    in
    {
      # ~69 solves/s here: twelve performance cores against ~170ms of 2048-bit
      # modular squaring per challenge, with the http pipelined behind it.
      botsolver-cap.serviceConfig = common // {
        ProgramArguments = [
          py
          "${dir}/cap_fast.py"
          "--name"
          "krn"
          # 0 runs until stopped. One line a minute instead of the ~70 a second
          # the per-solve output would write, and frequent enough that a rate
          # change shows up while you are still looking at it.
          "--count"
          "0"
          "--report-every"
          "60"
        ];
        EnvironmentVariables = tailnet // {
          # The instrumentation challenge is evaluated by a node subprocess the
          # solver looks up on PATH, and launchd hands a job almost none.
          PATH = "${pkgs.nodejs_22}/bin:/usr/bin:/bin";
        };
        StandardOutPath = "${logs}/botsolver-cap.log";
        StandardErrorPath = "${logs}/botsolver-cap.log";
      };

      # Reads stats.db and botme's leaderboard; tailnet-reachable on 8791. Runs
      # whether or not the Turnstile solver does, since the history in stats.db
      # and the leaderboard standings are worth watching either way.
      botsolver-dashboard.serviceConfig = common // {
        ProgramArguments = [
          py
          "${dir}/dashboard.py"
          "${dir}/stats.db"
          "--port"
          "8791"
        ];
        StandardOutPath = "${logs}/botsolver-dashboard.log";
        StandardErrorPath = "${logs}/botsolver-dashboard.log";
      };
    }
    // lib.optionalAttrs runTurnstile {
      botsolver-turnstile.serviceConfig = common // {
        ProgramArguments = [ "${burstLoop}" ];
        StandardOutPath = "${logs}/botsolver-turnstile.log";
        StandardErrorPath = "${logs}/botsolver-turnstile.log";
      };
    };

  system.stateVersion = 6;
}
