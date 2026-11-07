# Islet packages and the `[islet]` repository

Islet is shipped as pacman packages, so installed systems update it with
`pacman -Syu` (or **Settings › Updates**, where Islet's own updates are listed first).

| Package         | Contains                                                                  |
|-----------------|---------------------------------------------------------------------------|
| `islet`         | Meta package: pulls in everything below                                   |
| `islet-shell`   | `/usr/share/islet/shell` (Quickshell), default Hyprland config, `.desktop` files, pacman hook |
| `islet-tools`   | `/usr/bin/islet-*` helpers, `islet-autoupdate` units                      |
| `islet-themes`  | Icons, cursors, wallpapers, Plymouth theme, GTK / Firefox styles, Be Vietnam Pro font |
| `islet-keyring` | Public key that signs the repository                                      |

Each package's version is `0.1.r<number of commits touching its files>`, so a
release only makes users download the packages that actually changed.

## Build

```sh
./scripts/build-packages.sh          # → out/repo (signed packages + islet.db)
./scripts/build-iso.sh               # builds the packages, then the ISO installs them from out/repo
```

The signing key lives outside the repo in `~/.local/share/islet-release/gnupg`
(fingerprint `1F68E8C1CC0E9C45AD420574A3756511133F0071`). **Back it up**: without it,
new releases can't be signed with the key that installed systems trust.

## Release

```sh
git commit …                         # the tree must be clean
./scripts/release-repo.sh            # builds, signs and uploads to GitHub Releases, tag "repo"
```

Installed systems read `https://github.com/nobianh78/islet/releases/download/repo`
(see `/etc/pacman.conf`). After an update, the `islet-reload` hook reloads Hyprland and
the shell in every running session; if the screen is locked, the shell waits until it
is unlocked.

## Systems installed before packaging (one time)

Older installs have Islet's files copied in by hand, not owned by any package. Run once:

```sh
sudo pacman-key --add islet.gpg      # packaging/keyring/islet.gpg
sudo pacman-key --lsign-key 1F68E8C1CC0E9C45AD420574A3756511133F0071
# add the [islet] section from iso/islet/airootfs/etc/pacman.conf to /etc/pacman.conf, then:
sudo pacman -Sy --overwrite '/usr/share/islet/*' --overwrite '/usr/share/icons/Islet*' \
     --overwrite '/usr/share/plymouth/themes/islet/*' --overwrite '/usr/share/pixmaps/islet*' \
     --overwrite '/usr/share/fonts/be-vietnam-pro/*' --overwrite '/usr/share/applications/islet-*' islet
```

and replace `~/.config/hypr/hyprland.lua` with the stub from
`iso/islet/airootfs/home/islet/.config/hypr/hyprland.lua` (it loads the packaged config).
