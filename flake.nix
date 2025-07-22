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
              packer
              pykickstart
              lsb-release

              alejandra # For formatting nix files

              # Helper functions
              (writeShellScriptBin "packer-build" ''
                #!/usr/bin/env bash

                distro="$1"
                tag="$2"
                if [[ $# -ne 1 ]]; then
                  distro="ghcr.io/cyrilschreiber3/packer-maas-dev"
                fi
                if [[ $# -ne 2 ]]; then
                  tag="latest"
                fi

                if [ $distro = "local" ]; then
                  echo "Building local Docker image..."
                  docker build -t local/packer-maas-dev:$tag .
                  distro="local/packer-maas-dev"
                else
                  echo "Using Docker image: $distro:$tag"
                fi

                docker run --rm -it \
                  -v $(pwd)/packer-maas:/workspace \
                  -v $(pwd)/ISOs:/iso \
                  -w /workspace \
                  --name packer-maas-dev \
                  --hostname packer-maas-dev \
                  --entrypoint bash \
                  --device=/dev/kvm \
                  --device=/dev/fuse \
                  --cap-add=SYS_ADMIN \
                  --group-add=$(getent group kvm | cut -d: -f3) \
                  --pull=always \
                $distro:$tag
              '')

              (writeShellScriptBin "maas-push" ''
                #!/usr/bin/env bash

                image="$1"
                if [[ $# -ne 1 ]]; then
                  echo "Usage: maas-push <image>"
                  exit 1
                fi

                if [ ! -f "$image" ]; then
                  echo "Image file not found: $image"
                  exit 1
                fi

                # ask for image information
                read -p "Enter distro family: " distro
                if [[ -z "$distro" ]]; then
                  echo "Error: Distro name is required"
                  exit 1
                fi

                read -p "Enter image name: " name
                if [[ -z "$name" ]]; then
                  echo "Error: Image name is required"
                  exit 1
                fi

                read -p "Enter pretty name: " pretty_name
                if [[ -z "$pretty_name" ]]; then
                  echo "Error: Pretty name is required"
                  exit 1
                fi

                read -p "Enter architecture [amd64/generic]: " arch
                arch=''${arch:-amd64/generic}

                read -p "Enter file type [tgz]: " file_type
                file_type=''${file_type:-tgz}

                echo "Copying image to the MAAS server..."
                scp "$image" ladmin@crucible-pro-01:/home/ladmin/images/

                echo "Logging into MAAS..."
                ssh ladmin@crucible-pro-01 "/snap/bin/maas login admin http://localhost:5240/MAAS/api/2.0/ \$(head -1 /home/ladmin/.maas-api-key)"

                echo "Pushing image to MAAS..."
                ssh ladmin@crucible-pro-01 "/snap/bin/maas admin boot-resources create \
                  name='$distro/$name' \
                  title='$pretty_name' \
                  architecture='$arch' \
                  filetype='$file_type' \
                  content@='/home/ladmin/images/$(basename "$image")'"

                echo "Image '$name' pushed to MAAS successfully. Logging out..."
                ssh ladmin@crucible-pro-01 "/snap/bin/maas logout admin"

                echo "Done."

                echo "Run 'make clean' to remove the image file from the local machine ? [Y/n]: "
                read -r answer
                if [[ -z "$answer" || "$answer" =~ ^[Yy]$ ]]; then
                  make clean
                  echo "Image file removed."
                else
                  echo "Image file retained."
                fi
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
