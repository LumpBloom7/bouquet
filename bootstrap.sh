sudo podman build . -t bootc-fedora-bloom
sudo podman run \
          --rm \
          -it \
          --privileged \
          --pull=newer \
          --security-opt label=type:unconfined_t \
          -v $(pwd)/blueprint.toml:/config.toml:ro\
          -v $(pwd)/output:/output \
          -v /var/lib/containers/storage:/var/lib/containers/storage \
          quay.io/centos-bootc/bootc-image-builder:latest \
          --local \
          --type qcow2 \
          --rootfs btrfs \
          localhost/bootc-fedora-bloom:latest


# alternative 
bcvk to-disk localhost/bootc-fedora-bloom image.img --filesystem btrfs