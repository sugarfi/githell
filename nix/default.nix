let
    pkgs = import <nixpkgs> {};
in
pkgs.mkShell {
    name = "githell-dev";
    buildInputs = with pkgs; [ crystal shards pkg-config openssl gitMinimal ];
}
