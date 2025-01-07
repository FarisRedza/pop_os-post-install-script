#!/usr/bin/env bash

USER=$(whoami)
SCRIPT="linux_setup"

function select_distro {
	PS3='Select distribution: '
	options=("Pop!_OS" "Ubuntu" "Debian")
	select opt in "${options[@]}"
	do
	    case $opt in
		"Pop!_OS")
		    echo "Selecting Pop!_OS"
			DISTRO="POP"
			touch ~/pop
		    break
		    ;;
		"Ubuntu")
		    echo "Selecting Ubuntu"
			DISTRO="UBUNTU"
			touch ~/ubuntu
		    break
		    ;;
		"Debian")
		    echo "Selecting Debian"
			DISTRO="DEBIAN"
			touch ~/debian
		    break
		    ;;
		*) echo "invalid option $REPLY";;
	    esac
	done
}

function check_distro {
	if [ -f ~/pop ]
	then
		DISTRO="POP"
	elif [ -f ~/ubuntu ]
	then
		DISTRO="UBUNTU"
	elif [ -f ~/debian ]
	then
		DISTRO="DEBIAN"
	fi
 }

function github_latest_release_deb() {
	local username=$1
	local repository=$2

	# Get the latest release information from GitHub API using jq
	local latest_release=$(curl -s "https://api.github.com/repos/$username/$repository/releases/latest")

	# Identify the architecture of the system
	local architecture=$(dpkg --print-architecture)

	cd ~/
    
	# Loop through assets to find the appropriate deb file
	local deb_url=""
	while IFS= read -r line; do
		local asset_url=$(echo "$line" | jq -r '.browser_download_url')
		local asset_name=$(echo "$line" | jq -r '.name')
		if [[ $asset_url == *".deb" ]]; then
			# Check if the deb file name contains the architecture
			if [[ $asset_name == *"$architecture"* ]]; 
			then
				deb_url=$asset_url
			break
			fi
		fi
	done <<< "$(echo "$latest_release" | jq -c '.assets[]')"

	# If no architecture-specific deb file was found, download the first one
	if [ -z "$deb_url" ]; then
		deb_url=$(echo "$latest_release" | jq -r '.assets[] | select(.browser_download_url | endswith(".deb")) | .browser_download_url' | head -n 1)
	fi

	# Check if a deb file was found
	if [ -n "$deb_url" ];
	then
		# Use wget to download the deb file
		wget "$deb_url"
	else
		echo "No deb file found in the latest release."
	fi
	cd -
}

function setup_timeshift {
	echo "Setting up timeshift"
	sudo apt-get install -y timeshift 
	gnome-disks
	sudo timeshift-gtk
	echo "Timeshift setup complete"
}

function remove_packages {
	echo "Removing packages"
	local debian="gnome-games libreoffice-common evolution-common shotwell-common transmission-common zutty mlterm-common xiterm+thai"

	local pop="libreoffice-common"

	local ubuntu=""
	
	if [ $DISTRO = "POP" ]
	then
		local distro=$pop
	elif [ $DISTRO = "UBUNTU" ]
	then
		local distro=$ubuntu
	elif [ $DISTRO = "DEBIAN" ]
	then
		local distro=$debian
	fi

	sudo apt-get autopurge -y $distro
	echo "Package removal complete"
}

function install_packages {
	echo "Installing packages"
	install_via
	setup_nix
	setup_docker

	local system_apps="gparted virt-manager"

	local system_utilities="apt-file gpart"

	local hardware_utilities="btrfs-progs exfatprogs"

	local media_utilities=""

	local development="python3-venv"

	local extras="fonts-ibm-plex"

	local pop="synaptic gnome-{sushi,user-share} webp-pixbuf-loader playerctl code tldr ubuntu-restricted-extras"

	local ubuntu="synaptic gnome-{sushi,user-share} libfuse2t64 curl nautilus-hide fastfetch distrobox ibus-typing-booster network-manager-{strongswan,{fortisslvpn,iodine,l2tp,openconnect,ssh,sstp,vpnc}-gnome} {gnome-epub,icoextract}-thumbnailer ubuntu-restricted-extras"

	local debian="bash-completion command-not-found thermald libfuse2 tldr nautilus-hide fastfetch distrobox ibus-typing-booster network-manager-{strongswan,{fortisslvpn,iodine,l2tp,openconnect,ssh,sstp,vpnc}-gnome} {gnome-epub,icoextract}-thumbnailer libavcodec-extra ttf-mscorefonts-installer unrar gstreamer1.0-libav gstreamer1.0-plugins-ugly gstreamer1.0-vaapi"

	if [ $DISTRO = "POP" ]
	then
		sudo apt-get install -y --no-install-recommends steam-devices
		install_p3xonenote
		local distro=$pop
	elif [ $DISTRO = "UBUNTU" ]
	then
		setup_extrepo
		setup_flatpak
		local distro=$ubuntu
	elif [ $DISTRO = "DEBIAN" ]
	then
		sudo apt-get install -y --no-install-recommends steam-devices
		setup_extrepo
		install_firefox
		install_vscode
		install_p3xonenote
		setup_flatpak
		local distro=$debian
	fi

	eval "sudo apt-get install -y $system_apps $system_utilities $hardware_utilities $media_utilities $development $extras $distro"

	# Enable DVD playback
	sudo apt-get -y install libdvd-pkg
	sudo dpkg-reconfigure libdvd-pkg
	echo "Package installation complete"
}

function setup_extrepo {
	echo "Setting up extrepo"
	sudo apt-get install -y extrepo
	sudo sed -i 's/# - contrib/- contrib/g' /etc/extrepo/config.yaml
	sudo sed -i 's/# - non-free/- non-free/g' /etc/extrepo/config.yaml
	echo "Extrepo setup complete"
}

function setup_flatpak {
	echo "Setting up flatpak"
	sudo apt-get install -y --no-install-recommends gnome-software-plugin-flatpak
	flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
	if [ $DISTRO = "UBUNTU" ]
	then
		sudo tee /etc/apparmor.d/bwrap > /dev/null << EOF
abi <abi/4.0>,
include <tunables/global>

profile bwrap /usr/bin/bwrap flags=(unconfined) {
  userns,

  # Site-specific additions and overrides. See local/README for details.
  include if exists <local/bwrap>
}
EOF
		sudo systemctl reload apparmor
	fi
	echo "Flatpak setup complete"
}

function install_p3xonenote {
	echo "Installing p3x-onenote"
	github_latest_release_deb patrikx3 onenote
 	sudo apt-get install -y ./p3x-onenote*.deb
  	rm -rfv ./p3x-onenote*.deb
	echo "p3x-onenote installed"
}

function install_via {
	echo "Installing via"
	github_latest_release_deb the-via releases
 	sudo apt-get install -y ./via*.deb
  	rm -rfv ./via*.deb
	echo "via installed"
}

function setup_nix {
	echo "Setting up nix"
	sudo apt-get install -y nix-setup-systemd
	
	echo "Adding user to nix-users"
	sudo usermod -aG nix-users $USER

	# Nix integrations
	mkdir ~/.config/nixpkgs
	echo '{ allowUnfree = true; }' > ~/.config/nixpkgs/config.nix

	# Nix desktop icons
	printf '# Nix package desktop icons\nXDG_DATA_DIRS="/home/faris/.nix-profile/share:$XDG_DATA_DIRS"' > ~/.config/environment.d/nixIcons.conf

	echo "nix setup complete"
}

function setup_docker {
    sudo apt-get install -y docker.io
    sudo usermod -aG docker $USER
}

function setup_nautilus_share {
	sudo apt-get install -y nautilus-share
	sudo usermod -aG sambashare $USER
}

function install_firefox {
	sudo extrepo enable mozilla

	sudo apt-get update
	sudo apt-get install -y firefox firefox-l10n-en-gb
}

function install_nix_packages {
	echo "Adding unstable channel"
	nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs
	nix-channel --update

	local android="nixpkgs.android-tools"

	local development=""

	local game_utilities="nixpkgs.ckan"

	local utilities=""

	local pop="nixpkgs.rbw nixpkgs.distrobox nixpkgs.fastfetch"

	local ubuntu=""

	local debian=""

	if [ $DISTRO = "POP" ]
	then
		local distro=$pop
	elif [ $DISTRO = "UBUNTU" ]
	then
		local distro=$ubuntu
	elif [ $DISTRO = "DEBIAN" ]
	then
		local distro=$debian
	fi

	nix-env -iA $android $development $game_utilities $utilities $distro

	# Distrobox integration
	if grep -Fxq "# Distrobox" ~/.profile
	then
		echo "Distrobox already integrated"
	else
		printf '\n#Distrobox\ncommand_not_found_handle() {\n# do not run if not in a container\n  if [ ! -e /run/.containerenv ] && [ ! -e /.dockerenv ]; then\n    exit 127\n  fi\n  distrobox-host-exec "${@}"\n}\nif [ -n "${ZSH_VERSION-}" ]; then\n  command_not_found_handler() {\n    command_not_found_handle "$@"\n }\nfi' >> ~/.profile
	fi
}

function install_snaps {
	sudo snap refresh

	local utilities="tldr"

	local office="thunderbird"

	local game_launchers="steam"

	sudo snap install $utilities $development $office $game_launchers
	sudo snap install --classic code
	sudo snap install --classic rustup
}

function install_flatpaks {
	flatpak update -y

	local utilities="com.github.tchx84.Flatseal com.mattjakeman.ExtensionManager ca.desrt.dconf-editor com.usebottles.bottles org.gnome.FontManager org.gnome.GHex it.mijorus.gearlever com.anydesk.Anydesk"

	local development="org.gnome.design.IconLibrary io.github.MakovWait.Godots io.github.dvlv.boxbuddyrs"

	local office="org.libreoffice.LibreOffice com.github.jeromerobert.pdfarranger com.github.flxzt.rnote fr.romainvigier.MetadataCleaner md.obsidian.Obsidian org.cvfosammmm.Setzer com.github.tenderowl.frog io.github.diegoivan.pdf_metadata_editor"

	local misc="com.gitlab.newsflash com.spotify.Client com.todoist.Todoist de.haeckerfelix.Fragments org.freecadweb.FreeCAD org.nickvision.tubeconverter org.remmina.Remmina org.videolan.VLC com.prusa3d.PrusaSlicer com.bitwarden.desktop app.drey.Dialect de.schmidhuberj.DieBahn"

	local graphics="io.gitlab.adhami3310.Converter io.gitlab.theevilskeleton.Upscaler com.github.huluti.Curtail org.darktable.Darktable org.gimp.GIMP org.gnome.gThumb org.inkscape.Inkscape org.kde.krita org.blender.Blender"

	local social="com.github.IsmaelMartinez.teams_for_linux com.discordapp.Discord com.sindresorhus.Caprine org.ferdium.Ferdium org.mozilla.Thunderbird us.zoom.Zoom"

	local games="io.mrarm.mcpelauncher com.github.k4zmu2a.spacecadetpinball org.gnome.Aisleriot org.gnome.Chess org.gnome.Mines org.gnome.Mahjongg org.gnome.Quadrapassel org.gnome.Sudoku org.gnome.TwentyFortyEight"

    local game_launchers="com.heroicgameslauncher.hgl org.prismlauncher.PrismLauncher net.pcsx2.PCSX2 org.DolphinEmu.dolphin-emu info.cemu.Cemu com.dosbox_x.DOSBox-X"

	local game_utilities="com.github.Matoking.protontricks net.davidotek.pupgui2 org.freedesktop.Platform.VulkanLayer.MangoHud"

	local pop="org.gtk.Gtk3theme.Pop org.gtk.Gtk3theme.Pop-dark com.valvesoftware.Steam org.goldendict.GoldenDict org.gnome.Maps org.gnome.clocks io.github.flattool.Warehouse"

	local ubuntu="com.github.hugolabe.Wike org.gnome.Maps org.gnome.Calendar"

	local debian="org.gtk.Gtk3theme.adw-gtk3 org.gtk.Gtk3theme.adw-gtk3-dark com.valvesoftware.Steam com.github.hugolabe.Wike org.gnome.PowerStats"

	if [ $DISTRO = "POP" ]
	then
		local distro=$pop
	elif [ $DISTRO = "UBUNTU" ]
	then
		local distro=$ubuntu
	elif [ $DISTRO = "DEBIAN" ]
	then
		local distro=$debian
	fi

	flatpak install flathub -y $utilities $development $office $misc $graphics $social $games $game_launchers $game_utilities $distro

	if [ ! $DISTRO = "UBUNTU" ]
	then
		gaming_setup
	fi
}

function gaming_setup {
	mkdir ~/Games

	# Setup Steam drive access
	flatpak override --user --filesystem=/media com.valvesoftware.Steam
	flatpak override --user --filesystem=/mnt com.valvesoftware.Steam
	# Create command for Steam flatpak
	printf '#!/usr/bin/env\n\nflatpak run com.valvesoftware.Steam "$@"' >> ~/.local/bin/steam
	chmod +x ~/.local/bin/steam
	# Allow creating app icons for games
	flatpak override --user --filesystem=xdg-data/applications com.valvesoftware.Steam
	flatpak override --user --filesystem=xdg-data/icons com.valvesoftware.Steam
	# Use global MangoHud config
	flatpak override --user --filesystem=xdg-config/MangoHud com.valvesoftware.Steam
	flatpak override --user --env=MANGOHUD=1 com.valvesoftware.Steam
	# Allow launching flatpak apps
	flatpak override --user --talk-name=org.freedesktop.Flatpak com.valvesoftware.Steam
	# Allow monitoring network status
	flatpak override --user --system-talk-name=org.freedesktop.NetworkManager com.valvesoftware.Steam
}

function autostart_script {
	mkdir ~/.config/autostart
	printf "[Desktop Entry]
Type=Application
Exec=/home/$USER/$SCRIPT.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=$SCRIPT
Terminal=true" >> ~/.config/autostart/$SCRIPT.desktop
}

if [ ! -f ~/system_install ]
then
	select_distro
	sudo apt-get update
	sudo apt-get full-upgrade -y

	setup_timeshift

	remove_packages
	install_packages

	if [ $DISTRO = "UBUNTU" ]
	then
		install_snaps
	fi

	touch ~/system_install
	autostart_script
	systemctl reboot
fi
if [ -f ~/system_install ]
then
	check_distro
	install_flatpaks
	install_nix_packages

	rm -rfv ~/.config/autostart/$SCRIPT.desktop
	rm -rfv ~/system_install
	if [ $DISTRO = "POP" ]
	then
		rm -rfv ~/pop
	elif [ $DISTRO = "UBUNTU" ]
	then
		rm -rfv ~/ubuntu
	elif [ $DISTRO = "DEBIAN" ]
	then
		rm -rfv ~/debian
	fi
	systemctl reboot
fi
