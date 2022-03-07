with import <nixpkgs> {};

stdenv.mkDerivation {
  name = "flux-mixin";

  # The packages in the `buildInputs` list will be added to the PATH in our shell
  buildInputs = with pkgs; [
    jsonnet-bundler
    go-jsonnet
  ];
}
