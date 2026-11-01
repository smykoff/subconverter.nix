English | [Русский](README.ru.md)

# subconverter.nix

Nix flake that packages [subconverter](https://github.com/tindy2013/subconverter) — a utility
that converts proxy subscription links between formats (Clash, Surge, Quantumult X, sing-box,
SIP008, …).

Upstream ships only prebuilt binaries and its build pulls in submodules and statically linked
third-party libraries, so this flake repackages the official release archives instead of
building from source.

## Supported platforms

| System           | Status                                        |
|------------------|-----------------------------------------------|
| `x86_64-linux`   | tested                                        |
| `aarch64-linux`  | untested                                      |
| `aarch64-darwin` | untested                                      |
| `x86_64-darwin`  | untested, needs nixpkgs 26.05 (see below)     |

Builds for other architectures (`linux32`, `armv7`) exist upstream but are not packaged, because
Nix only knows the four systems above.

nixpkgs 26.11 (current `nixos-unstable`) dropped support for `x86_64-darwin` entirely. On Intel
macOS, pin the `nixpkgs` input to `nixpkgs-26.05-darwin`:

```nix
inputs.subconverter = {
  url = "github:<REPO>";
  inputs.nixpkgs.follows = "nixpkgs"; # or keep the default and override below
};
inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
```

## Usage

Run without installing:

```sh
nix run github:<REPO>
```

Install into the user profile:

```sh
nix profile install github:<REPO>
```

### NixOS (flakes)

```nix
{
  inputs.subconverter.url = "github:<REPO>";

  outputs = { nixpkgs, subconverter, ... }: {
    nixosConfigurations.host = nixpkgs.lib.nixosSystem {
      modules = [
        ({ pkgs, ... }: {
          environment.systemPackages = [
            subconverter.packages.${pkgs.system}.default
          ];
        })
      ];
    };
  };
}
```

Or via the overlay:

```nix
nixpkgs.overlays = [ subconverter.overlays.default ];
environment.systemPackages = [ pkgs.subconverter ];
```

### Running as a service

```nix
systemd.services.subconverter = {
  wantedBy = [ "multi-user.target" ];
  after = [ "network.target" ];
  serviceConfig = {
    DynamicUser = true;
    StateDirectory = "subconverter";
    Environment = "SUBCONVERTER_HOME=/var/lib/subconverter";
    ExecStart = "${pkgs.subconverter}/bin/subconverter";
    Restart = "on-failure";
  };
};
```

## Configuration

subconverter reads `pref.toml` (or `pref.yml`/`pref.ini`) and the `base/`, `config/`, `rules/`,
`snippets/` and `profiles/` trees **from its own working directory** — it `chdir`s into the
directory of the executable and into the directory of the `-f` argument. The package lives in
the read-only Nix store, so `bin/subconverter` is a small launcher that:

1. uses `${SUBCONVERTER_HOME:-${XDG_CONFIG_HOME:-~/.config}/subconverter}` as the working directory;
2. on first start (no `pref.*` there yet) copies the bundled `base/`, `config/`, `rules/`,
   `snippets/`, `profiles/` and `pref.example.toml` into it as `pref.toml`;
3. starts the real binary with `-f <that pref file>`, forwarding your arguments.

So edit `~/.config/subconverter/pref.toml` to change the listening address, the port (25500 by
default), `api_access_token`, remote rulesets and so on. Delete the directory to re-seed it from
the currently installed release.

Passing your own `-f`/`--file` disables all of the above and lets subconverter use the directory
you point it at.

Notes:

- subconverter has no `--version`/`--help` switch: every invocation starts the HTTP server. The
  version is printed in the startup log and served at `/version`.
- The Linux binaries are statically linked, so nothing needs `programs.nix-ld` on NixOS.
- Binaries are not patched; only the launcher decides where the configuration lives.
- `rules/` is a snapshot of the rulesets bundled with the release. Keep the default
  `overwrite_original_rules = false` or point rulesets elsewhere if you want them updated.

## Updating

Versions and hashes live in `sources.json`. Regenerate it with:

```sh
bash scripts/update.sh
```

The script asks the GitHub releases API for the newest tag, compares it with `sources.json` and,
if it changed, re-fetches the download URLs and hashes for all four platforms. A scheduled
GitHub Actions workflow (`.github/workflows/update.yml`) runs it daily, builds the package and
commits the result.
