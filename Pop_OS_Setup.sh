#!/bin/bash

USER=$(whoami)
SCRIPT="Pop_OS_Setup"

function check_new_install {
	read -p "New install? [y/n] " response
	case $response in
		[Yy]* )
			echo "Performing full system and user setup"
			touch ~/new_install
		;;
		[Nn]* )
			echo "Performing system setup"
		;;
	esac
}

github_latest_release() {
    local username=$1
    local repository=$2

    # Get the latest release information from GitHub API using jq
    local latest_release=$(curl -s "https://api.github.com/repos/$username/$repository/releases/latest" | jq -r '.assets[0].browser_download_url')

    # Use wget to download the deb file
    wget $latest_release
}


function remove_packages {
	sudo apt-get autopurge -y libreoffice-common
}

function install_packages {
	SYSTEM_APPS="synaptic gparted virt-manager"

	SYSTEM_UTILITIES="apt-file dpkg-repack openssh-server gpart uidmap python3-venv python3-pylatexenc"

	HARDWARE_UTILITIES="btrfs-progs exfatprogs"

	MEDIA_UTILITIES="ubuntu-restricted-extras webp-pixbuf-loader playerctl"

	DEVELOPMENT="code"

	EXTRAS="gnome-user-share gnome-sushi"

	sudo apt-get install -y $SYSTEM_APPS $SYSTEM_UTILITIES $HARDWARE_UTILITIES $MEDIA_UTILITIES $DEVELOPMENT $EXTRAS

	# Enable DVD playback
	sudo apt-get -y install libdvd-pkg
	sudo dpkg-reconfigure libdvd-pkg

	sudo apt-get install -y --no-install-recommends steam-devices
}

function add_ppa_and_install_packages {
	sudo add-apt-repository ppa:farisredza/ppa
 	sudo apt-get update
  	sudo apt-get install -y quiet-shutdown pop-launcher-plugin-spell pop-launcher-plugin-uni

function enable_timeshift {
	sudo apt-get install -y timeshift 
	gnome-disks
	sudo timeshift-gtk
}

function install_quiet-shutdown_package {
	github_latest_release FarisRedza quiet-shutdown
	sudo apt-get install ./quiet-shutdown*.deb
	rm -rfv quiet-shutdown*.deb
}

function setup_nix {
	sudo rm -rfv ~/.config/nixpkgs ~/.nix-defexpr ~/.nix-profile

	sh <(curl -L https://nixos.org/nix/install) --daemon
	
	# Add unstable channel
	nix-channel --add https://nixos.org/channels/nixpkgs-unstable unstable
	nix-channel --update

	# Nix integrations
	mkdir ~/.config/nixpkgs
	echo '{ allowUnfree = true; }' > ~/.config/nixpkgs/config.nix

	# Nix desktop icons
	printf '# Nix package desktop icons\nXDG_DATA_DIRS="/home/faris/.nix-profile/share:$XDG_DATA_DIRS"' > ~/.config/environment.d/nixIcons.conf
}

function autostart_script {
	printf "[Desktop Entry]
Type=Application
Exec=/home/$USER/$SCRIPT.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=$SCRIPT
Terminal=true" >> ~/.config/autostart/$SCRIPT.desktop
}

function install_nix_packages {
	ANDROID="nixpkgs.android-tools nixpkgs.scrcpy"

	DEVELOPMENT="nixpkgs.distrobox nixpkgs.podman"

	GAMEUTILITIES="nixpkgs.ckan"

	UTILITIES="nixpkgs.neofetch nixpkgs.tldr nixpkgs.htop nixpkgs.lm_sensors nixpkgs.tmux nixpkgs.hunspell nixpkgs.xclip"

	nix-env -iA $ANDROID $DEVELOPMENT $GAMEUTILITIES $UTILITIES

	# Fix podman permissions
	podman system migrate

	# Distrobox setup
	mkdir -pv ~/.config/containers
	printf '{
    "default": [
        {
            "type": "insecureAcceptAnything"
        }
    ]
}
' >> ~/.config/containers/policy.json

	mkdir -pv ~/.config/systemd/user
	ln -s ~/.nix-profile/lib/systemd/user/podman.service ~/.config/systemd/user/podman.service
	ln -s ~/.nix-profile/lib/systemd/user/podman.socket ~/.config/systemd/user/podman.socket
	ln -s ~/.nix-profile/lib/systemd/user/podman-auto-update.service ~/.config/systemd/user/podman-auto-update.service
	ln -s ~/.nix-profile/lib/systemd/user/podman-auto-update.timer ~/.config/systemd/user/podman-auto-update.timer
	ln -s ~/.nix-profile/lib/systemd/user/podman-kube\@.service ~/.config/systemd/user/podman-kube\@.service
	ln -s ~/.nix-profile/lib/systemd/user/podman-restart.service ~/.config/systemd/user/podman-restart.service

	systemctl --user enable --now podman.socket

	# Distrobox integration
	if grep -Fxq "# Distrobox" ~/.profile
	then
		echo "Distrobox already integrated"
	else
		printf '\n#Distrobox\ncommand_not_found_handle() {\n# do not run if not in a container\n  if [ ! -e /run/.containerenv ] && [ ! -e /.dockerenv ]; then\n    exit 127\n  fi\n  distrobox-host-exec "${@}"\n}\nif [ -n "${ZSH_VERSION-}" ]; then\n  command_not_found_handler() {\n    command_not_found_handle "$@"\n }\nfi' > ~/.profile
	fi
}

function install_flatpaks {
	flatpak update -y

	UTILITIES="com.github.tchx84.Flatseal com.mattjakeman.ExtensionManager ca.desrt.dconf-editor com.usebottles.bottles org.gnome.FontManager org.gnome.GHex it.mijorus.gearlever io.github.flattool.Warehouse com.anydesk.Anydesk"

	DEVELOPMENT="com.github.marhkb.Pods org.gnome.design.IconLibrary org.gnome.Devhelp io.github.MakovWait.Godots"

	OFFICE="org.libreoffice.LibreOffice com.github.jeromerobert.pdfarranger com.github.flxzt.rnote fr.romainvigier.MetadataCleaner md.obsidian.Obsidian org.cvfosammmm.Setzer org.zotero.Zotero com.github.tenderowl.frog io.github.diegoivan.pdf_metadata_editor"

	MISC="com.gitlab.newsflash com.spotify.Client com.todoist.Todoist de.haeckerfelix.Fragments org.freecadweb.FreeCAD org.nickvision.tubeconverter org.remmina.Remmina org.videolan.VLC com.prusa3d.PrusaSlicer"

	GRAPHICS="io.gitlab.adhami3310.Converter io.gitlab.theevilskeleton.Upscaler org.darktable.Darktable org.gimp.GIMP org.gnome.gThumb org.inkscape.Inkscape org.kde.krita com.github.maoschanz.drawing org.blender.Blender"

	SOCIAL="com.github.IsmaelMartinez.teams_for_linux com.discordapp.Discord com.sindresorhus.Caprine org.ferdium.Ferdium org.mozilla.Thunderbird us.zoom.Zoom"

	GAMES="com.github.k4zmu2a.spacecadetpinball io.mrarm.mcpelauncher org.gnome.Aisleriot org.gnome.Chess org.gnome.Mines org.gnome.Mahjongg org.gnome.Quadrapassel"

	GAMEUTILITIES="com.github.Matoking.protontricks com.valvesoftware.Steam net.davidotek.pupgui2 net.lutris.Lutris org.prismlauncher.PrismLauncher net.pcsx2.PCSX2 org.DolphinEmu.dolphin-emu info.cemu.Cemu org.freedesktop.Platform.VulkanLayer.MangoHud com.dosbox_x.DOSBox-X"

	POP="org.gtk.Gtk3theme.Pop org.gtk.Gtk3theme.Pop-dark com.github.GradienceTeam.Gradience org.goldendict.GoldenDict org.gnome.Maps org.gnome.clocks"

	flatpak install -y $UTILITIES $DEVELOPMENT $OFFICE $MISC $GRAPHICS $SOCIAL $GAMES $GAMEUTILITIES $POP

	vlc_pause_click_plugin
	game_drive_setup	
}

function vlc_pause_click_plugin {
	ARCH="$(flatpak info --show-metadata org.videolan.VLC \
			| sed -En '
			/^\[Application\]/ {
				:label
				/^runtime=/ {
					# Leave just the arch
					s|[^/]*/||
					s|/[^/]*||
					p
					q
				}
				n
				/^[^\[]/b label
				q
		}'
	)"
	BRANCH="$(flatpak info --show-metadata org.videolan.VLC \
			| sed -En '
			/^\[Extension org.videolan.VLC.Plugin\]/ {
				:label
				/^versions=/ {
					# Use the second version in the list. This assumes a specific
					# "versions=" format and might break if it changes.
					s/[^;]*;//
					p
					q
				}
				n
				/^[^\[]/b label
				q
		}'
	)"
	flatpak install -y "runtime/org.videolan.VLC.Plugin.pause_click/$ARCH/$BRANCH"
}

function game_drive_setup {
	# Setup Steam and Lutris drive access
	flatpak override --user --filesystem=/media/faris com.valvesoftware.Steam
	flatpak override --user --filesystem=/media/faris net.lutris.Lutris
	if [ -d "/mnt/Games" ]
	then
		ln -s /mnt/Games ~/home/Games
		flatpak override --user --filesystem=/mnt/Games com.valvesoftware.Steam
		flatpak override --user --filesystem=/mnt/Games net.lutris.Lutris
	else
		mkdir ~/Games
		flatpak override --user --filesystem=/home/faris/Games com.valvesoftware.Steam
		flatpak override --user --filesystem=/home/faris/Games net.lutris.Lutris
	fi
	# Steam and Lutris setup and integration
	printf '#!/bin/bash\n\nflatpak run com.valvesoftware.Steam "$@"' >> ~/.local/bin/steam
	chmod +x ~/.local/bin/steam
	# Allow creating app icons for games
	flatpak override --user --filesystem=xdg-data/applications com.valvesoftware.Steam
	flatpak override --user --filesystem=xdg-data/applications net.lutris.Lutris
	flatpak override --user --filesystem=xdg-data/icons com.valvesoftware.Steam
	flatpak override --user --filesystem=xdg-data/icons net.lutris.Lutris
	# Use global MangoHud config
	flatpak override --user --filesystem=xdg-config/MangoHud com.valvesoftware.Steam
	flatpak override --user --filesystem=xdg-config/MangoHud net.lutris.Lutris
	flatpak override --user --env=MANGOHUD=1 com.valvesoftware.Steam
	# Allow launching flatpak apps
	flatpak override --user --talk-name=org.freedesktop.Flatpak com.valvesoftware.Steam
	# Allow monitoring network status
	flatpak override --user --system-talk-name=org.freedesktop.NetworkManager com.valvesoftware.Steam
	
	flatpak override --user --filesystem='~/Games/SteamLibrary' com.github.Matoking.protontricks
}

function install_appimages {
	# Download and install pCloud
	mkdir -pv ~/.local/appimages
	firefox -url 'https://www.pcloud.com/download-free-online-cloud-file-storage.html'

	flatpak run it.mijorus.gearlever
}

function mk_dot_dirs {
	mkdir -pv ~/.config/environment.d
	mkdir -pv ~/.config/autostart
	mkdir -pv ~/.local/bin
	mkdir -pv ~/.local/share/themes
	mkdir -pv ~/.local/share/icons
	mkdir -pv ~/.local/appimages
}

function install_matlab {
	firefox -url 'https://uk.mathworks.com/downloads/'
	unzip ~/Downloads/matlab* -d ~/Downloads/matlab
	~/Downloads/matlab/install
	rm -rf ~/Downloads/matlab*
	sudo apt-get install -y matlab-support
	cp /usr/share/applications/matlab.desktop ~/.local/share/applications
	printf "StartupWMClass=sun-awt-X11-XFramePeer\nStartupWMClass=MATLABWindow\nStartupWMClass=MATLAB R2023b - academic use" >> ~/.local/share/applications/matlab.desktop
	mkdir -pv ~/.local/MATLAB/R2023b/bin/glnxa64/
	echo '-Djogl.disable.openglarbcontext=1' >> ~/.local/MATLAB/R2023b/bin/glnxa64/java.opts
}

function customisations {
	ln -s /usr/share/icons/Pop ~/.local/share/icons/

	# Customise Desktop 
	gsettings set org.gnome.desktop.interface clock-show-weekday true
	gsettings set org.gnome.desktop.interface clock-format '24h'
	gsettings set org.gnome.shell.extensions.dash-to-dock click-action 'minimize-or-previews'
	gsettings set org.gnome.shell.extensions.dash-to-dock dock-fixed false
	gsettings set org.gnome.shell.extensions.dash-to-dock intellihide true
	gsettings set org.gnome.shell.extensions.ding show-volumes true
	gsettings set org.gnome.mutter workspaces-only-on-primary true
	gsettings set org.gnome.desktop.interface show-battery-percentage true
	gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'
	gsettings set org.gnome.shell.extensions.pop-shell fullscreen-launcher true

	# Customise Nautilus
	gsettings set org.gnome.nautilus.preferences show-create-link true
	gsettings set org.gnome.nautilus.preferences show-delete-permanently true
	gsettings set org.gnome.nautilus.list-view use-tree-view true

	# Customise Gedit
	gsettings set org.gnome.gedit.preferences.editor display-overview-map true

	# Customise Privacy
	gsettings set org.gnome.desktop.privacy remove-old-temp-files true
	gsettings set org.gnome.desktop.privacy remove-old-trash-files true

	# Set GTK3 theme
	flatpak override --user --filesystem=xdg-data/themes

	# Set GTK4 theme
	mkdir -pv ~/.config/gtk-4.0
	flatpak override --user --filesystem=xdg-config/gtk-4.0
	flatpak run com.github.GradienceTeam.Gradience
}

function install_launcher_plugins {
	curl -sSf https://raw.githubusercontent.com/canadaduane/pop-dictionary/main/install.sh | sh
	curl --proto '=https' -sSf https://raw.githubusercontent.com/rcastill/pop-launcher-firefox-tabs/master/scripts/install.sh | bash
}

function customise_firefox {
	firefox
	# Customise Firefox and enable gestures
	echo 'MOZ_USE_XINPUT2=1' > ~/.config/environment.d/firefoxTouch.conf
	cd ~/.mozilla/firefox/*.default-release/
	printf 'user_pref("dom.w3c_touch_events.enabled", 1);\nuser_pref("browser.compactmode.show", true);\nuser_pref("browser.uidensity", 1);' >> user.js
	cd -
}

function setup_style_switcher {
	printf "!/bin/bash
style=$1
ln -sfr ~/.config/gtk-4.0/gtk-${style}.css ~/.config/gtk-4.0/gtk.css
" >> ~/.local/bin/style-switcher.sh
	chmod +x ~/.local/bin/style-switcher.sh
}

if [ ! -f ~/step1_complete ]
then
	check_new_install

	sudo apt-get update
	sudo apt-get full-upgrade -y

	remove_packages
	install_packages
	add_ppa_and_install_packages
	enable_timeshift
	mk_dot_dirs
	setup_nix
	autostart_script

	touch ~/step1_complete
	systemctl reboot
fi

if [ -f ~/step1_complete ] && [ ! -f ~/step2_complete ]
then
	install_nix_packages

	if [ ! -f ~/new_install ]
	then
		rm -rfv ~/.config/autostart/$SCRIPT.desktop
		rm -rfv ~/step1_complete
	else
		touch ~/step2_complete
	fi

	systemctl reboot
fi

if [ -f ~/step1_complete ] && [ -f ~/step2_complete ]
then
	install_flatpaks
	install_appimages
	install_matlab
	install_launcher_plugins
	customisations
 	setup_style_switcher

	# Enable Eduroam
	firefox -url 'https://cloud.securew2.com/public/12133/eduroam/'

	customise_firefox

	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

	rm -rfv ~/.config/autostart/$SCRIPT.desktop
	rm -rfv ~/step1_complete
	rm -rfv ~/step2_complete
	rm -rfv ~/new_install
	
	systemctl reboot
fi
