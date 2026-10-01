FROM quay.io/fedora/fedora-bootc:latest as builder
RUN /usr/libexec/bootc-base-imagectl build-rootfs --manifest=minimal /target-rootfs

FROM scratch
COPY --from=builder /target-rootfs/ /
COPY tmp /tmp
COPY usr /usr
COPY etc /etc

RUN <<EORUN

set -xeuo pipefail

dnf -qy install \
    @core \
    @standard \
    @base-graphical \
    linux-firmware \
    glibc-all-langpacks \
    --exclude dracut-config-rescue \
    --exclude rsyslog

dnf install -qy NetworkManager-wifi bluez
dnf install -qy pipewire
dnf install -qy wine-ntsync steam-devices
dnf install -qy flatpak
dnf install -qy tuned-ppd
dnf install -qy @printing

dnf install -qy https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm 
dnf install -qy xorg-x11-drv-nvidia-cuda dkms

chmod +x /tmp/build-akmods.sh
/tmp/build-akmods.sh

rm -fr /tmp/bin /tmp/build-akmods.sh /tmp/fake-uname /tmp/akmods
dnf remove -qy akmod-nvidia dkms 
dnf -qy autoremove
userdel akmods

curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | \
        tee /etc/yum.repos.d/nvidia-container-toolkit.repo

dnf install -qy nvidia-container-toolkit-base

dnf install -qy ibus-panel ibus-libpinyin 

dnf install -qy niri --setopt=install_weak_deps=False
dnf install -qy xdg-desktop-portal-gtk xdg-desktop-portal-gnome gnome-keyring nautilus "gvfs-*"
dnf install -qy noctalia 

dnf install -qy fuse fuse-libs

dnf install -qy default-fonts gnome-icon-theme 

dnf install -qy gnome-disk-utility 
dnf install -qy git-credential-libsecret git-credential-oauth pinentry-gnome3 gnupg2-scdaemon
dnf install -qy podman-compose 
dnf install -qy foot fish 

dnf install -qy --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release
dnf install -qy starship
dnf install -qy lazygit git-delta

dnf install -qy noctalia-greeter
mkdir /var/lib/noctalia-greeter

systemctl enable greetd
systemctl enable noctalia-greeter-sync-perms

authselect enable-feature with-systemd-homed
systemctl enable systemd-homed

systemctl mask bootc-fetch-apply-updates.timer
systemctl enable rpm-ostreed-automatic.timer

chmod +x /tmp/build-initramfs.sh
chmod +x /tmp/adjust-os-release.sh
/tmp/build-initramfs.sh
/tmp/adjust-os-release.sh

dnf clean all
rm /var/{log,cache,lib}/* -rf

rm -rf /tmp/*
mkdir -p /var/tmp

rm -rf /opt && ln -s /var/opt /opt

find /run -mindepth 1 \
  ! -path '/run/systemd' \
  ! -path '/run/systemd/resolve' \
  ! -path '/run/systemd/resolve/stub-resolv.conf' \
  ! -path '/run/secrets' \
  ! -path '/run/secrets/*' \
  ! -path '/run/.containerenv' \
  -delete

bootc container lint --no-truncate

EORUN

# Define required labels for this bootc image to be recognized as such.
LABEL containers.bootc 1
LABEL ostree.bootable 1
# https://pagure.io/fedora-kiwi-descriptions/pull-request/52
ENV container=oci
# Optional labels that only apply when running this image as a container. These keep the default entry point running under systemd.
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]