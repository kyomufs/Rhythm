{
  description = "tulgusch — расписание ТулГУ";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            flutter
            dart
            git
            curl
            unzip
            cmake
            ninja
            clang
            pkg-config
            gtk3
            pango
            cairo
            gdk-pixbuf
            glib
            atk
          ];

          shellHook = ''
            echo "=== tulgusch dev environment ==="
            echo "Run: flutter pub get && flutter run -d linux"
          '';
        };
      }
    );
}
