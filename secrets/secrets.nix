let
  kierank = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCzEEjvbL/ttqmYoDjxYQmDIq36BabROJoXgQKeh9liBxApwp+2PmgxROzTg42UrRc9pyrkq5kVfxG5hvkqCinhL1fMiowCSEs2L2/Cwi40g5ZU+QwdcwI8a4969kkI46PyB19RHkxg54OUORiIiso/WHGmqQsP+5wbV0+4riSnxwn/JXN4pmnE//stnyAyoiEZkPvBtwJjKb3Ni9n3eNLNs6gnaXrCtaygEZdebikr9kS2g9mM696HvIFgM6cdR/wZ7DcLbG3IdTXuHN7PC3xxL+Y4ek5iMreQIPmuvs4qslbthPGYoYbYLUQiRa9XO5s/ksIj5Z14f7anHE6cuTQVpvNWdGDOigyIVS5qU+4ZF7j+rifzOXVL48gmcAvw/uV68m5Wl/p0qsC/d8vI3GYwEsWG/EzpAlc07l8BU2LxWgN+d7uwBFaJV9VtmUDs5dcslsh8IbzmtC9gq3OLGjklxTfIl6qPiL8U33oc/UwqzvZUrI2BlbagvIZYy6rP+q0=";
in
{
  "wifi.age".publicKeys = [
    kierank
  ];
  "resend.age".publicKeys = [
    kierank
  ];
  "wakatime.age".publicKeys = [
    kierank
  ];
  "bluesky.age".publicKeys = [
    kierank
  ];
  "iodine.age".publicKeys = [
    kierank
  ];
  "crush.age".publicKeys = [
    kierank
  ];
  "context7.age".publicKeys = [
    kierank
  ];
  "cloudflare.age".publicKeys = [
    kierank
  ];
  "cachet.age".publicKeys = [
    kierank
  ];
  "hn-alerts.age".publicKeys = [
    kierank
  ];
  "github-knot-sync.age".publicKeys = [
    kierank
  ];
  "emojibot.age".publicKeys = [
    kierank
  ];
  "battleship-arena.age".publicKeys = [
    kierank
  ];
  "bore/auth-token.age".publicKeys = [
    kierank
  ];
  "bore/cookie-hash-key.age".publicKeys = [
    kierank
  ];
  "bore/cookie-block-key.age".publicKeys = [
    kierank
  ];
  "bore/client-secret.age".publicKeys = [
    kierank
  ];
  "l4.age".publicKeys = [
    kierank
  ];
  "control.age".publicKeys = [
    kierank
  ];
  "restic/env.age".publicKeys = [
    kierank
  ];
  "restic/repo.age".publicKeys = [
    kierank
  ];
  "restic/password.age".publicKeys = [
    kierank
  ];
  "tranquil-pds.age".publicKeys = [
    kierank
  ];
  "zai.age".publicKeys = [
    kierank
  ];
  "pbnj.age".publicKeys = [
    kierank
  ];
  "tangled-session.age".publicKeys = [
    kierank
  ];
  "herald.age".publicKeys = [
    kierank
  ];
  "herald-dkim.age".publicKeys = [
    kierank
  ];
}
