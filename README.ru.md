[English](README.md) | Русский

# subconverter.nix

Nix-флейк с пакетом [subconverter](https://github.com/tindy2013/subconverter) — утилитой для
конвертации подписок между форматами (Clash, Surge, Quantumult X, sing-box, SIP008, …).

Upstream публикует только готовые бинарники, а его сборка тянет сабмодули и статически
слинкованные сторонние библиотеки, поэтому флейк перепаковывает официальные архивы релизов,
а не собирает программу из исходников.

## Поддерживаемые платформы

| Система          | Статус                                            |
|------------------|---------------------------------------------------|
| `x86_64-linux`   | проверено                                         |
| `aarch64-linux`  | не проверено                                      |
| `aarch64-darwin` | не проверено                                      |
| `x86_64-darwin`  | не проверено, нужен nixpkgs 26.05 (см. ниже)      |

Сборки под другие архитектуры (`linux32`, `armv7`) у upstream есть, но здесь они не
упакованы: Nix знает только четыре системы выше.

nixpkgs 26.11 (текущий `nixos-unstable`) полностью убрал поддержку `x86_64-darwin`. На Intel
macOS привяжите вход `nixpkgs` к `nixpkgs-26.05-darwin`:

```nix
inputs.subconverter = {
  url = "github:smykoff/subconverter.nix";
  inputs.nixpkgs.follows = "nixpkgs";
};
inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
```

## Использование

Запуск без установки:

```sh
nix run github:smykoff/subconverter.nix
```

Установка в профиль пользователя:

```sh
nix profile install github:smykoff/subconverter.nix
```

### NixOS (flakes)

```nix
{
  inputs.subconverter.url = "github:smykoff/subconverter.nix";

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

Или через оверлей:

```nix
nixpkgs.overlays = [ subconverter.overlays.default ];
environment.systemPackages = [ pkgs.subconverter ];
```

### Запуск как служба

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

## Настройка

subconverter читает `pref.toml` (или `pref.yml`/`pref.ini`) и каталоги `base/`, `config/`,
`rules/`, `snippets/`, `profiles/` **из своего рабочего каталога**: он делает `chdir` в каталог
исполняемого файла, а затем в каталог, указанный в `-f`. Сам пакет лежит в read-only хранилище
Nix, поэтому `bin/subconverter` — небольшой лаунчер, который:

1. берёт `${SUBCONVERTER_HOME:-${XDG_CONFIG_HOME:-~/.config}/subconverter}` как рабочий каталог;
2. при первом запуске (когда `pref.*` там ещё нет) копирует туда поставляемые с релизом
   `base/`, `config/`, `rules/`, `snippets/`, `profiles/`, а `pref.example.toml` — как `pref.toml`;
3. запускает настоящий бинарник с `-f <этот pref-файл>`, передавая ему ваши аргументы.

То есть адрес прослушивания, порт (по умолчанию 25500), `api_access_token`, удалённые правила
и прочее меняются в `~/.config/subconverter/pref.toml`. Удалите этот каталог, чтобы он заново
заполнился из установленного релиза.

Если передать свои `-f`/`--file`, лаунчер ничего не делает и subconverter работает с указанным
вами каталогом.

Замечания:

- У subconverter нет ключей `--version`/`--help`: любой запуск поднимает HTTP-сервер. Версия
  видна в логе запуска и отдаётся по пути `/version`.
- Linux-бинарники статически слинкованы, поэтому `programs.nix-ld` на NixOS не нужен.
- Бинарники не патчатся: где лежит конфигурация, решает только лаунчер.
- `rules/` — снимок наборов правил из релиза. Оставьте значение по умолчанию
  `overwrite_original_rules = false` или укажите другие источники, если хотите их обновлять.

## Обновление

Версии и хеши хранятся в `sources.json`. Перегенерировать его можно так:

```sh
bash scripts/update.sh
```

Скрипт спрашивает у GitHub releases API последний тег, сравнивает с `sources.json` и, если тег
изменился, заново получает ссылки и хеши для всех четырёх платформ. Workflow GitHub Actions
(`.github/workflows/update.yml`) запускает его раз в сутки, собирает пакет и коммитит результат.
