FROM quay.io/fedora/fedora-bootc:latest

# Standard metapackages for setting up a standard GUI install
RUN dnf -qy install \
    @core \
    @hardware-support \
    @standard \
    @base-graphical \
    glibc-all-langpacks \
    --exclude dracut-config-rescue \
    --exclude rsyslog

# Drivers and System configuration

    # Networking and bluetooth
    RUN dnf install -qy NetworkManager-wifi
    RUN dnf install -qy bluez

    # Audio support 
    RUN dnf install -qy pipewire

    # Quality of life for gaming
    RUN dnf install -qy wine-ntsync
    RUN dnf install -qy steam-devices

    RUN dnf install -qy flatpak # Duh...

    # For power management
    RUN dnf install -qy tuned-ppd

    ## Printers
    RUN dnf install -qy @printing

    ## Install nvidia drivers
    RUN dnf install -qy https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    RUN dnf install -qy xorg-x11-drv-nvidia-cuda

    # Force akmods to built
    RUN dnf install -qy dkms
    COPY --chmod=755 build-akmods.sh /tmp
    RUN /tmp/build-akmods.sh
    RUN rm -fr /tmp/bin /tmp/build-akmods.sh /tmp/fake-uname /tmp/akmods

    # Remove akmod build tools
    ## [NOTE] The expectation is that the kmod is already built, so we really don't need this anymore
    RUN dnf remove -qy akmod-nvidia dkms
    RUN dnf -qy autoremove
    RUN userdel akmods

    # Inject kargs to prevent nouveau/nova modules from being loaded
    COPY --chmod=755 usr/lib/bootc/kargs.d/nvidia.toml /usr/lib/bootc/kargs.d/nvidia.toml

    # Nvidia container integration using CDI
    RUN curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | \
        tee /etc/yum.repos.d/nvidia-container-toolkit.repo
    RUN dnf install -qy nvidia-container-toolkit-base

    RUN dnf install -qy ibus-panel ibus-libpinyin

# Setup compositor
RUN dnf install -qy niri --setopt=install_weak_deps=False 
RUN dnf install -qy xdg-desktop-portal-gtk xdg-desktop-portal-gnome gnome-keyring nautilus "gvfs-*"
  # [TODO] Replace gkr with oo7, since that will be the primary keyring in the future, and plays nicer with greetd PAM
RUN dnf install -qy noctalia
# [TODO] Try out umbriel compositor?

# Some AppImages (osu) are still using the FUSE v2 runtime
RUN dnf install -qy fuse fuse-libs

# Fonts and themes
RUN dnf install -qy default-fonts gnome-icon-theme

# Utilities
RUN dnf install -qy gnome-disk-utility
RUN dnf install -qy git-credential-libsecret git-credential-oauth pinentry-gnome3 gnupg2-scdaemon
RUN dnf install -qy podman-compose
RUN dnf install -qy foot fish

# Terra utilities
RUN dnf install -qy --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release
RUN dnf install -qy starship
RUN dnf install -qy lazygit git-delta

# Greeter

RUN dnf install -qy noctalia-greeter
RUN mkdir /var/lib/noctalia-greeter

COPY etc/greetd /etc/greetd/
RUN systemctl enable greetd

COPY usr/lib/systemd/system/noctalia-greeter-sync-perms.service /usr/lib/systemd/system/noctalia-greeter-folder-perms.service
RUN systemctl enable noctalia-greeter-folder-perms

RUN authselect enable-feature with-systemd-homed
RUN systemctl enable systemd-homed

COPY --chmod=755 initramfs.sh /tmp
RUN /tmp/initramfs.sh

COPY --chmod=755 adjust-os-release.sh /tmp
RUN /tmp/adjust-os-release.sh

RUN dnf clean all

RUN find /run -mindepth 1 \
  ! -path '/run/systemd' \
  ! -path '/run/systemd/resolve' \
  ! -path '/run/systemd/resolve/stub-resolv.conf' \
  ! -path '/run/secrets' \
  ! -path '/run/secrets/*' \
  ! -path '/run/.containerenv' \
  -delete

RUN rm -rf /tmp/*
RUN mkdir -p /var/tmp

RUN rm -rf /var/log/* &&\
    rm -rf /var/cache/*

# Needs to be here to make the main image build strict (no /opt there)
# This is for downstream images/stuff like k0s
RUN rm -rf /opt && ln -s /var/opt /opt


RUN bootc container lint --no-truncate