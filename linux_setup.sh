#!/usr/bin/env bash

USER=$(whoami)
SCRIPT="Linux_Setup"

function select_distro {
	PS3='Select distribution: '
	options=("Pop!_OS" "Debian")
	select opt in "${options[@]}"
	do
	    case $opt in
		"Pop!_OS")
		    echo "Selecting Pop!_OS"
			DISTRO="POP"
			touch ~/pop
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

function enable_timeshift {
	sudo apt-get install -y timeshift 
	gnome-disks
	sudo timeshift-gtk
}

function remove_packages {
	local debian="gnome-games libreoffice-common evolution-common shotwell-common transmission-common zutty mlterm-common xiterm+thai"

	local pop="libreoffice-common"
	
	if [ $DISTRO = "POP" ]
	then
		local distro=$pop
	elif [ $DISTRO = "DEBIAN" ]
	then
		local distro=$debian
	fi

	sudo apt-get autopurge -y $distro
}

function install_packages {
	local system_apps="gparted virt-manager setzer"

	local system_utilities="apt-file gpart tldr"

	local hardware_utilities="btrfs-progs exfatprogs"

	local media_utilities=""

	local development="python3-venv"

	local extras="fonts-ibm-plex"

	local pop="synaptic ubuntu-restricted-extras webp-pixbuf-loader playerctl gnome-user-share gnome-sushi code"

	local debian="bash-completion command-not-found thermald distrobox fastfetch network-manger-*-gnome ibus-typing-booster libavcodec-extra ttf-mscorefonts-installer unrar gstreamer1.0-libav gstreamer1.0-plugins-ugly gstreamer1.0-vaapi"

	if [ $DISTRO = "POP" ]
	then
		local distro=$pop
	elif [ $DISTRO = "DEBIAN" ]
	then
        setup_extrepo
        install_firefox
        install_vscode
		setup_flatpak
		local distro=$debian
	fi

    install_p3xonenote
    install_via
	setup_nix
    setup_docker

	sudo apt-get install -y $system_apps $system_utilities $hardware_utilities $media_utilities $development $extras $distro

	# Enable DVD playback
	sudo apt-get -y install libdvd-pkg
	sudo dpkg-reconfigure libdvd-pkg

	sudo apt-get install -y --no-install-recommends steam-devices
}

function setup_extrepo {
    sudo apt-get install -y extrepo

}

function setup_flatpak {
	sudo apt-get install -y gnome-software-plugin-flatpak
	flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
}

function install_p3xonenote {
	github_latest_release_deb patrikx3 onenote
 	sudo apt-get install -y ./p3x-onenote*.deb
  	rm -rfv ./p3x-onenote*.deb
}

function install_via {
	github_latest_release_deb the-via releases
 	sudo apt-get install -y ./via*.deb
  	rm -rfv ./via*.deb
}

function setup_nix {
	sudo apt-get install -y nix-setup-systemd
	sudo usermod -aG nix-users $USER
	newgrp nix-users

	# Nix integrations
	mkdir ~/.config/nixpkgs
	echo '{ allowUnfree = true; }' > ~/.config/nixpkgs/config.nix

	# Nix desktop icons
	printf '# Nix package desktop icons\nXDG_DATA_DIRS="/home/faris/.nix-profile/share:$XDG_DATA_DIRS"' > ~/.config/environment.d/nixIcons.conf
}

function setup_docker {
    sudo apt-get install -y docker.io
    sudo usermod -aG docker $USER
    newgrp docker
}

function install_firefox {
	sudo extrepo enable mozilla

	sudo apt-get update
	sudo apt-get install -y firefox firefox-l10n-en-gb
}

function install_nix_packages {
	# Add unstable channel
	nix-channel --add https://nixos.org/channels/nixpkgs-unstable unstable
	nix-channel --update

	local android="nixpkgs.android-tools"

	local development=""

	local game_utilities="nixpkgs.ckan"

	local utilities=""

	local pop="nixpkgs.rbw nixpkgs.distrobox nixpkgs.fastfetch"

	local debian=""

	if [ $DISTRO = "POP" ]
	then
		local distro=$pop
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

function install_flatpaks {
	flatpak update -y

	local utilities="com.github.tchx84.Flatseal com.mattjakeman.ExtensionManager ca.desrt.dconf-editor com.usebottles.bottles org.gnome.FontManager org.gnome.GHex it.mijorus.gearlever com.anydesk.Anydesk"

	local development="org.gnome.design.IconLibrary io.github.MakovWait.Godots io.github.dvlv.boxbuddyrs"

	local office="org.libreoffice.LibreOffice com.github.jeromerobert.pdfarranger com.github.flxzt.rnote fr.romainvigier.MetadataCleaner md.obsidian.Obsidian org.cvfosammmm.Setzer com.github.tenderowl.frog io.github.diegoivan.pdf_metadata_editor"

	local misc="com.gitlab.newsflash com.spotify.Client com.todoist.Todoist de.haeckerfelix.Fragments org.freecadweb.FreeCAD org.nickvision.tubeconverter org.remmina.Remmina org.videolan.VLC com.prusa3d.PrusaSlicer com.bitwarden.desktop app.drey.Dialect de.schmidhuberj.DieBahn"

	local graphics="io.gitlab.adhami3310.Converter io.gitlab.theevilskeleton.Upscaler com.github.huluti.Curtail org.darktable.Darktable org.gimp.GIMP org.gnome.gThumb org.inkscape.Inkscape org.kde.krita org.blender.Blender"

	local social="com.github.IsmaelMartinez.teams_for_linux com.discordapp.Discord com.sindresorhus.Caprine org.ferdium.Ferdium org.mozilla.Thunderbird us.zoom.Zoom"

	local games="io.mrarm.mcpelauncher com.github.k4zmu2a.spacecadetpinball org.gnome.Aisleriot org.gnome.Chess org.gnome.Mines org.gnome.Mahjongg org.gnome.Quadrapassel org.gnome.Sudoku org.gnome.TwentyFortyEight"

    local game_launchers="com.valvesoftware.Steam com.heroicgameslauncher.hgl org.prismlauncher.PrismLauncher net.pcsx2.PCSX2 org.DolphinEmu.dolphin-emu info.cemu.Cemu com.dosbox_x.DOSBox-X"

	local game_utilities="com.github.Matoking.protontricks net.davidotek.pupgui2 org.freedesktop.Platform.VulkanLayer.MangoHud"

	local pop="org.gtk.Gtk3theme.Pop org.gtk.Gtk3theme.Pop-dark org.goldendict.GoldenDict org.gnome.Maps org.gnome.clocks io.github.flattool.Warehouse "

	local debian="org.gtk.Gtk3theme.adw-gtk3 org.gtk.Gtk3theme.adw-gtk3-dark com.github.hugolabe.Wike org.gnome.PowerStats"

	if [ $DISTRO = "POP" ]
	then
		local distro=$pop
	elif [ $DISTRO = "DEBIAN" ]
	then
		local distro=$debian
	fi

	flatpak install flathub -y $utilities $development $office $misc $graphics $social $games $game_launchers $game_utilities $distro

	gaming_setup	
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

if [ ! -f ~/system_install ]
then
    sudo apt-get update
    sudo apt-get full-upgrade -y

    enable_timeshift

    remove_packages
    install_packages
    install_nix_packages

    touch ~/system_install
fi
if [ -f ~/system_install]
then
    install_flatpaks

fi