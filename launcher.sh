#!/bin/sh
# Wrapper around the upstream subconverter binary.
#
# subconverter chdirs into its own directory and expects pref.toml/pref.yml/
# pref.ini, base/, config/, rules/, snippets/ and profiles/ to live there, and
# it writes to that directory (pref file, generated rulesets). The program
# itself lives in the read-only Nix store, so on the first run this wrapper
# seeds a writable working directory and then always starts subconverter with
# an explicit `-f` pointing into it.
#
# Set SUBCONVERTER_HOME to use another directory; if the caller passes
# `-f`/`--file`, the wrapper stays out of the way entirely.

set -e

data_dir=${SUBCONVERTER_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/subconverter}

for arg in "$@"; do
  case $arg in
    -f | --file)
      exec "@out@/opt/subconverter/subconverter" "$@"
      ;;
  esac
done

pref=
for found in pref.toml pref.yml pref.ini; do
  if [ -e "$data_dir/$found" ]; then
    pref=$data_dir/$found
    break
  fi
done

if [ -z "$pref" ]; then
  mkdir -p "$data_dir"

  for dir in base config rules snippets profiles; do
    if [ ! -e "$data_dir/$dir" ]; then
      # The store is read-only, so the copies arrive without write permission.
      cp -r "@out@/opt/subconverter/$dir" "$data_dir/$dir"
      chmod -R u+w "$data_dir/$dir"
    fi
  done

  for tpl in "@examples@"/pref.example.toml "@examples@"/pref.example.yml "@examples@"/pref.example.ini; do
    if [ -f "$tpl" ]; then
      pref=$data_dir/pref.${tpl##*.}
      cp "$tpl" "$pref"
      chmod u+w "$pref"
      break
    fi
  done
fi

if [ -n "$pref" ]; then
  exec "@out@/opt/subconverter/subconverter" -f "$pref" "$@"
fi

exec "@out@/opt/subconverter/subconverter" "$@"
