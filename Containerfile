FROM quay.io/fedora/fedora-bootc:latest

# Standard metapackages for setting up a standard GUI install
RUN dnf -qy install \
    @core \
    @standard \
    @base-graphical \
    glibc-all-langpacks \
    --exclude dracut-config-rescue \
    --exclude rsyslog && dnf clean all

# Drivers and System configuration

    # Networking and bluetooth
    RUN dnf install -qy NetworkManager-wifi bluez && dnf clean all

    # Audio support 
    RUN dnf install -qy pipewire && dnf clean all

    # Quality of life for gaming
    RUN dnf install -qy wine-ntsync steam-devices && dnf clean all

    # Flatpak support
    RUN dnf install -qy flatpak && dnf clean all

    # For power management
    RUN dnf install -qy tuned-ppd && dnf clean all

    ## Printers
    RUN dnf install -qy @printing && dnf clean all

    ## Install nvidia drivers
    ### We also force akmods to be built in this step
    COPY --chmod=755 tmp/build-akmods.sh /tmp

    RUN dnf install -qy https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm \
        && dnf install -qy xorg-x11-drv-nvidia-cuda dkms \
        && /tmp/build-akmods.sh \
        && rm -fr /tmp/bin /tmp/build-akmods.sh /tmp/fake-uname /tmp/akmods \
        && dnf remove -qy akmod-nvidia dkms && dnf -qy autoremove \
        && userdel akmods && dnf clean all

    # Inject kargs to prevent nouveau/nova modules from being loaded
    COPY --chmod=755 usr/lib/bootc/kargs.d/nvidia.toml /usr/lib/bootc/kargs.d/nvidia.toml

    # Nvidia container integration using CDI
    RUN curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | \
        tee /etc/yum.repos.d/nvidia-container-toolkit.repo
    RUN dnf install -qy nvidia-container-toolkit-base && dnf clean all

    # Language ime for Chinese
    RUN dnf install -qy ibus-panel ibus-libpinyin && dnf clean all

# Setup compositor
## [TODO] Replace gkr with oo7, since that will be the primary keyring in the future, and plays nicer with greetd PAM
RUN dnf install -qy niri --setopt=install_weak_deps=False \
    && dnf install -qy xdg-desktop-portal-gtk xdg-desktop-portal-gnome gnome-keyring nautilus "gvfs-*" \
    && dnf install -qy noctalia \
    && dnf clean all

# Some AppImages (osu) are still using the FUSE v2 runtime
RUN dnf install -qy fuse fuse-libs && dnf clean all

# Fonts and themes
RUN dnf install -qy default-fonts gnome-icon-theme && dnf clean all

# Utilities
RUN dnf install -qy gnome-disk-utility && dnf clean all
RUN dnf install -qy git-credential-libsecret git-credential-oauth pinentry-gnome3 gnupg2-scdaemon && dnf clean all
RUN dnf install -qy podman-compose && dnf clean all
RUN dnf install -qy foot fish && dnf clean all

# Terra utilities
RUN dnf install -qy --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release && dnf clean all
RUN dnf install -qy starship && dnf clean all
RUN dnf install -qy lazygit git-delta && dnf clean all

# Greeter
RUN dnf install -qy noctalia-greeter && dnf clean all
RUN mkdir /var/lib/noctalia-greeter

COPY etc/greetd /etc/greetd/
RUN systemctl enable greetd

COPY usr/lib/systemd/system/noctalia-greeter-sync-perms.service /usr/lib/systemd/system/noctalia-greeter-folder-perms.service
RUN systemctl enable noctalia-greeter-folder-perms

RUN authselect enable-feature with-systemd-homed
RUN systemctl enable systemd-homed

# This service forcefully restarts the computer, which is disruptive
RUN systemctl mask bootc-fetch-apply-updates.timer

# This autoupdate service only stages deployments without rebooting the system
RUN systemctl enable rpm-ostreed-automatic.timer

# Forcefully build a new initramfs that contains the essential kernel modules
# This allows things like the firmware and drivers to be loaded earlier, preventing the kernel fallbacks from loading at all
## Example: simple-fb is loaded, occupying eDP-1 on my system, before amdgpu takes eDP-2. 
##          Loading amdgpu more eagerly prevents simple-fb from spawning, and the display is properly connected to eDP-1
COPY --chmod=755 tmp/build-initramfs.sh /tmp
RUN /tmp/build-initramfs.sh

COPY --chmod=755 tmp/adjust-os-release.sh /tmp
RUN /tmp/adjust-os-release.sh

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

RUN du -h /var/ | sort -h

RUN bootc container lint --no-truncate