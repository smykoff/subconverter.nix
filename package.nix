{
  lib,
  stdenv,
  fetchurl,
  # Upstream ships fully static Linux binaries, so this hook normally does
  # nothing; it is kept as a safety net in case a future release links
  # dynamically and needs its interpreter patched.
  autoPatchelfHook,
}:

let
  inherit (stdenv.hostPlatform) system isDarwin;

  sources = builtins.fromJSON (builtins.readFile ./sources.json);
  platformSrc = sources.${system} or (throw "subconverter: unsupported system ${system}");
in
stdenv.mkDerivation {
  pname = "subconverter";
  version = sources.version;

  src = fetchurl { inherit (platformSrc) url hash; };

  nativeBuildInputs = lib.optionals (!isDarwin) [ autoPatchelfHook ];

  # Bundles may contain native code for other platforms; never fail on it.
  autoPatchelfIgnoreMissingDeps = [ "*" ];

  # The macOS binary is linked against the system libraries and signed
  # upstream; rewriting load commands would only break it.
  dontFixup = isDarwin;
  dontBuild = true;
  sourceRoot = ".";

  unpackPhase = ''
    mkdir src
    tar -xzf "$src" -C src --strip-components=1
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt/subconverter $out/share/subconverter $out/bin
    cp -a src/. $out/opt/subconverter/

    # On startup subconverter copies pref.example.* to pref.* in its own
    # directory. The store is read-only, so keep the templates outside the
    # program directory; the launcher seeds a writable working directory.
    find $out/opt/subconverter -maxdepth 1 -name 'pref.example.*' \
      -exec mv {} $out/share/subconverter/ \;

    install -m755 ${./launcher.sh} $out/bin/subconverter
    substituteInPlace $out/bin/subconverter \
      --replace-fail '@out@' "$out" \
      --replace-fail '@examples@' "$out/share/subconverter"

    runHook postInstall
  '';

  meta = {
    description = "Utility to convert between various subscription formats";
    homepage = "https://github.com/tindy2013/subconverter";
    license = lib.licenses.gpl3Plus;
    # Derived from sources.json so meta and the packaged builds cannot drift apart.
    platforms = builtins.attrNames (builtins.removeAttrs sources [ "version" ]);
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "subconverter";
  };
}
