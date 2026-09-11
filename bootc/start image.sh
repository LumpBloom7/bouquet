 qemu-system-x86_64 \
                                           -M accel=kvm \
                                           -cpu host \
                                           -m 4096 \
                                           -vga virtio -display gtk,gl=on \
                                           -device virtio-gl \
                                           -bios /usr/share/OVMF/OVMF_CODE.fd \
                                           -snapshot output/qcow2/disk.qcow2 \
                                           -audio driver=sdl,model=virtio