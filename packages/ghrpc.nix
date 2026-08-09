{
  lib,
  buildGoModule,
  installShellFiles,
  pandoc,
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

  vendorHash = "sha256-MrzBMTbq2bwesWENSDR9PI2wfw76uw+9a0yOYoavu9Y=";

  nativeBuildInputs = [
    installShellFiles
    pandoc
  ];

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

  # The man page is written by hand: the generated one cannot know about
  # templates, licence slots or the shell integration, and renders short flags
  # as "--d --description". Completions still come from the command tree.
  postInstall = ''
    # -smart stops pandoc turning "--flag" into an en dash
    pandoc -s -f markdown-smart -t man ${./ghrpc/ghrpc.1.md} -o ghrpc.1
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
