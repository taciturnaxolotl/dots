{
  lib,
  buildGoModule,
  installShellFiles,
  coreutils,
  git,
  gh,
  # Defaults baked into the binary; overridden from atelier.shell.tangled.
  plcId ? "did:plc:krxbvxvis5skq7jj6eot23ul",
  githubUser ? "taciturnaxolotl",
  knotHost ? "knot.dunkirk.sh",
  domain ? "dunkirk.sh",
  defaultBranch ? "main",
  credentialsFile ? "/run/agenix/bluesky",
}:

buildGoModule (finalAttrs: {
  pname = "ghrpc";
  version = "0.1.0";

  src = ./ghrpc;

  vendorHash = "sha256-uGBSqTwEdha9KP9srFSS8AVARkC2qPtNmX7+YHMntDs=";

  nativeBuildInputs = [ installShellFiles ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${finalAttrs.version}"
    "-X main.defaultPLCID=${plcId}"
    "-X main.defaultGitHubUser=${githubUser}"
    "-X main.defaultKnotHost=${knotHost}"
    "-X main.defaultDomain=${domain}"
    "-X main.defaultBranch=${defaultBranch}"
    "-X main.defaultCredsFile=${credentialsFile}"
    "-X main.gitBin=${lib.getExe git}"
    "-X main.ghBin=${lib.getExe gh}"
    "-X main.mktempBin=${coreutils}/bin/mktemp"
    "-X main.rmBin=${coreutils}/bin/rm"
    "-X main.catBin=${coreutils}/bin/cat"
  ];

  # fang generates the man page and completions from the command tree itself.
  postInstall = ''
    $out/bin/ghrpc man > ghrpc.1
    installManPage ghrpc.1
    installShellCompletion --cmd ghrpc \
      --bash <($out/bin/ghrpc completion bash) \
      --zsh <($out/bin/ghrpc completion zsh) \
      --fish <($out/bin/ghrpc completion fish)

    # Shell integration: a child cannot cd its parent, so the wrapper function
    # does it. Source these rather than hand-copying the function.
    mkdir -p $out/share/ghrpc
    for shell in zsh bash fish; do
      $out/bin/ghrpc shell $shell > $out/share/ghrpc/init.$shell
    done
  '';

  meta = {
    description = "Create repositories on GitHub and Tangled, with embedded project templates";
    mainProgram = "ghrpc";
    platforms = lib.platforms.unix;
  };
})
