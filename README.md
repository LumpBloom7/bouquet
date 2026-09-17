# Bouquet

Bouquet is a custom bootc image based on fedora, utilising niri and noctalia as the desktop environment, primarily as a learning exercise and as a forward proactive means to try out bootc, while also cutting out the number of packages unused by myself.

The name is literally only chosen because it is related to flowers. There is no deeper meaning to it.

## Design decisions

The image itself is intentionally minimal, excluding a packages typically included with a workstation/silverblue installation, such as media codecs or a browser. Users are expected to utilise Flatpaks for regular applications, and containers/toolbx for more advanced tools and development. 

The image is primarily catered to my personal machine and usage, so there are some utilities included in the image definition such as Lazygit, Fish or Starship. The proprietary nvidia drivers are also included in the image to accommodate my laptop.

The full definition of installed packages, and configuration can be found in the [Containerfile](https://github.com/LumpBloom7/bouquet/blob/master/Containerfile).

### Experimental decisions

In addition to the above, the image may be configured to embrace newer ways of doing things, sometimes even ahead of fedora. The following are the features enabled or under consideration.

* [Enabled] Utilising [systemd-homed](https://systemd.io/HOME_DIRECTORY/) as the primary way to manage users.
    * Existing `/etc/passwd` based users can still operate.
* [Under-consideration] Using [systemd-boot](https://systemd.io/BOOT/) in place of GRUB as the bootloader

## Usage

> WARNING: Secure boot is currently not supported. I need to check what is required for secureboot to work out of the box W.R.T signing and the nvidia driver. You have been warned.
>
> WARNING 2: While I tried to make sure the transition from Silverblue is seamless, there is a possibility that some essential services are excluded or disabled, preventing normal usage. If you found that you needed to re-enable some essential services, please give me a holler in the issues page.

On any system running a bootc/ostree system, such as Fedora Atomic or Universal Blue, one can simply switch to this image through the following command

```sh
bootc switch https://ghcr.io/lumpbloom7/bouquet-bootc:latest

# or 

rpm-ostree rebase https://ghcr.io/lumpbloom7/bouquet-bootc:latest
```

### Installing persistent packages

If for some reason you are running this image, and want to add additional packages persistant across reboots, you can simply overlay them using `rpm-ostree`, which will create a new deployment with the added package. [Refer to the Fedora Atomic documentation for more details](https://docs.fedoraproject.org/en-US/atomic-desktops/getting-started/#_installing_packages)

```sh
rpm-ostree install <package>
```

#### Installing transient packages

If the desired package is not intended to be permanent, one can enable a transient user overlay, allowing read-write access to `/usr/`

```sh
bootc usr-overlay

# or

rpm-ostree usroverlay
```

Once the overlay is created, the user has full access to modify `/usr/`, and can choose to install packages using `dnf`.

```sh
dnf install <package>
```

> One can also pass the `--transient` argument to `dnf` to allow it to create the usr-overlay, avoiding the need for doing that manually.




