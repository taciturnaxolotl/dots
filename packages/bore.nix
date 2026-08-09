{
  lib,
  buildGoModule,
  installShellFiles,
  pandoc,
  frp,
  # Defaults baked into the binary; overridden from atelier.bore.
  serverAddr ? "bore.dunkirk.sh",
  serverPort ? 7000,
  domain ? "bore.dunkirk.sh",
  authTokenFile ? "",
}:

buildGoModule (finalAttrs: {
  pname = "bore";
  version = "2.0.0";

  src = ./bore;

  vendorHash = "sha256-j5W+7iMzx0nDNVCTKbY8+4IJHzOOUqMlYWn1JjUlbrc=";

  nativeBuildInputs = [
    installShellFiles
    pandoc
  ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${finalAttrs.version}"
    "-X main.serverAddr=${serverAddr}"
    "-X main.serverPort=${toString serverPort}"
    "-X main.domain=${domain}"
    "-X main.authTokenFile=${authTokenFile}"
    "-X main.frpcBin=${frp}/bin/frpc"
  ];

  # The man page is written by hand: a generated one cannot explain bore.toml,
  # and mango renders short flags as "--l --list". Completions still come from
  # the command tree. -smart stops pandoc turning "--flag" into an en dash.
  postInstall = ''
    pandoc -s -f markdown-smart -t man ${./bore/bore.1.md} -o bore.1
    installManPage bore.1
    installShellCompletion --cmd bore \
      --bash <($out/bin/bore completion bash) \
      --zsh <($out/bin/bore completion zsh) \
      --fish <($out/bin/bore completion fish)
  '';

  meta = {
    description = "Expose a local port to the internet through bore";
    homepage = "https://bore.dunkirk.sh";
    mainProgram = "bore";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
