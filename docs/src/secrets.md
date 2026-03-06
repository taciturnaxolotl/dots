# Secrets

Secrets are managed using [agenix](https://github.com/ryantm/agenix) — encrypted at rest in the repo and decrypted at activation time to `/run/agenix/`.

## Usage

Create or edit a secret:

```bash
cd secrets && agenix -e myapp.age
```

The secret file contains environment variables, one per line:

```
DATABASE_URL=postgres://...
API_KEY=xxxxx
SECRET_TOKEN=yyyyy
```

## Adding a new secret

1. Add the public key entry to `secrets/secrets.nix`:

```nix
"service-name.age".publicKeys = [ kierank ];
```

2. Create and encrypt the secret:

```bash
agenix -e secrets/service-name.age
```

3. Declare in machine config:

```nix
age.secrets.service-name = {
  file = ../../secrets/service-name.age;
  owner = "service-name";
};
```

4. Reference as `config.age.secrets.service-name.path` in the service module.

## Identity paths

The decryption keys are SSH keys configured per machine:

```nix
age.identityPaths = [
  "/home/kierank/.ssh/id_rsa"
  "/etc/ssh/id_rsa"
];
```
