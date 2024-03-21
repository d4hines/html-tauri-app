{
  inputs = {
    # grab nixpkgs, the main Nix "repository", which is actually just a giant
    # library of Nix code. The exact version will be captured in flake.lock and
    # checked into source  control.
    nixpkgs.url = "github:nixos/nixpkgs";
    # This is a library we can use to generate the ISO to upload to Digital Ocean.
    nixos-generators = {
      url = "github:/nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    deploy = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = {
    self,
    nixpkgs,
    nixos-generators,
    deploy,
    flake-utils,
  }: let
    # This is a trick I use to bake the git revision of the software being packaged/deployed
    # into the package itself. It only works if you don't deploy while the git working tree is dirty!
    rev =
      if self ? rev
      then self.rev
      else "dirty";
    pkgs = import nixpkgs {system = "x86_64-linux";};
    GEMINI = (import ./nix/gemini-server) {inherit rev;};
  in
    flake-utils.lib.eachDefaultSystem
    (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          rustc
          cargo
          cargo-tauri
          rustfmt
          clippy
          curl
          wget
          pkg-config
          dbus
          openssl_3
          glib
          gtk3
          libsoup
          webkitgtk
          librsvg
          systemd
          nodejs
          yarn
        ];
        shellHook = let
          libraries = with pkgs; [
            webkitgtk
            gtk3
            cairo
            gdk-pixbuf
            glib
            dbus
            openssl_3
            librsvg
          ];
        in ''
          export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath libraries}:$LD_LIBRARY_PATH
          export XDG_DATA_DIRS=${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}:$XDG_DATA_DIRS
          export WEBKIT_DISABLE_COMPOSITING_MODE=1  # prevents 'Could not determine the accessibility bus address'. Taken from https://github.com/tauri-apps/tauri/issues/4315
          export RUST_SRC_PATH=${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}
          export TMPDIR=$(mktemp -d "/tmp/gemini-XXXXXXXX") # The nix shell adds a '.' to TMPDRI by default, which breaks spcat
        '';
      };
    })
    // {
      nixosConfigurations = {
        GEMINI = nixpkgs.lib.nixosSystem GEMINI;
      };
      packages.x86_64-linux.gemini-server-do-image = nixos-generators.nixosGenerate {
        inherit pkgs;
        system = "x86_64-linux";
        modules = GEMINI.modules;
        format = "do";
      };
      deploy.nodes.GEMINI = {
        hostname = "159.203.105.249";
        profiles.system = {
          sshUser = "root";
          path = deploy.lib.x86_64-linux.activate.nixos self.nixosConfigurations.GEMINI;
        };
      };
    };
}
