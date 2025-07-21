{
  description = "Packer dev environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
          };
        };
      in
        with pkgs; {
          devShells.default = mkShell {
            buildInputs = [
              docker

              alejandra # For formatting nix files

              # Helper functions
              (writeShellScriptBin "packer-build" ''
                #!/usr/bin/env bash

                distro="$1"
                tag="$2"
                if [[ $# -ne 1 ]]; then
                  distro="cyrilschreiber3/packer-maas-dev"
                fi
                if [[ $# -ne 2 ]]; then
                  tag="latest"
                fi

                if [ $distro = "local" ]; then
                  echo "Building local Docker image..."
                  docker build -t local/packer-maas-dev:$tag .
                  distro="local/packer-maas-dev"
                fi

                docker run --rm -it \
                  -v $(pwd):/workspace \
                  -w /workspace \
                  --hostname packer-maas-dev \
                  --entrypoint bash \
                  --device=/dev/kvm \
                  --device=/dev/fuse \
                  --cap-add=SYS_ADMIN \
                  --group-add=$(getent group kvm | cut -d: -f3) \
                $distro:$tag
              '')
            ];

            shellHook = ''
              echo -e "Welcome to the Packer image builder environment!\n"

              if [[ -f "$(which gpg)" ]]; then
                echo "" | gpg --clearsign >> /dev/null
              fi
            '';
          };
        }
    );
}
