# Use a Ubuntu-based base image
FROM ubuntu:latest

# Update the package index and install general packages
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    wget \
    git \
    lsb-release \
    gpg \
    make \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Add packer GPG key and repository
RUN wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release --codename --short) main" | tee /etc/apt/sources.list.d/hashicorp.list \
    && apt-add-repository -y "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"

# Install Packer and build dependencies
RUN apt-get update && apt-get install -y \
    packer \
    qemu-system \
    qemu-utils \
    ovmf \
    cloud-image-utils \
    fuse3 \
    fuse2fs \
    libnbd-bin \
    libnbd0 \
    nbdkit \
    parted \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory
WORKDIR /workspace

# Define the entrypoint
ENTRYPOINT ["bash"]