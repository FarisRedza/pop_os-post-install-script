#!/bin/bash

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
	local system_apps="gparted virt-manager"

	local system_utilities="apt-file dpkg-repack openssh-server gpart uidmap extrepo alien tldr neofetch htop tmux podman-docker"

	local hardware_utilities="btrfs-progs exfatprogs"

	local media_utilities="heif-thumbnailer icoextract-thumbnailer"

	local development="debmake python3-venv python3-dev python3-tk"

	local extras="fonts-ibm-plex"

	local pop="synaptic ubuntu-restricted-extras webp-pixbuf-loader playerctl gnome-user-share gnome-sushi code lm-sensors"

	local debian="bash-completion command-not-found curl wget thermald linux-headers-amd64 distrobox ibus-typing-booster apt-config-icons-hidpi apt-config-icons-large-hidpi libavcodec-extra ttf-mscorefonts-installer unrar gstreamer1.0-libav gstreamer1.0-plugins-ugly gstreamer1.0-vaapi"

	if [ $DISTRO = "POP" ]
	then
		local distro=$pop
	elif [ $DISTRO = "DEBIAN" ]
	then
		local distro=$debian
	fi

	sudo apt-get install -y $system_apps $system_utilities $hardware_utilities $media_utilities $development $extras $distro

	# Enable DVD playback
	sudo apt-get -y install libdvd-pkg
	sudo dpkg-reconfigure libdvd-pkg

	sudo apt-get install -y --no-install-recommends steam-devices
}

function add_ppa_and_install_packages {
	# sudo add-apt-repository ppa:farisredza/ppa
 	repoman # temporary workaround until I know how to setup repo to look the same as adding with repoman
 	sudo apt-get update
  	sudo apt-get install -y quiet-shutdown pop-launcher-plugin-spell pop-launcher-plugin-uni joycond
}

function enable_timeshift {
	sudo apt-get install -y timeshift 
	gnome-disks
	sudo timeshift-gtk
}

function install_joycond_package {
	github_latest_release_deb FarisRedza joycond
	sudo apt-get install ./joycond*.deb
	rm -rfv joycond*.deb
}

function setup_nix {
	sudo rm -rfv ~/.config/nixpkgs ~/.nix-defexpr ~/.nix-profile

	sh <(curl -L https://nixos.org/nix/install) --daemon

	# Nix integrations
	mkdir ~/.config/nixpkgs
	echo '{ allowUnfree = true; }' > ~/.config/nixpkgs/config.nix

	# Nix desktop icons
	printf '# Nix package desktop icons\nXDG_DATA_DIRS="/home/faris/.nix-profile/share:$XDG_DATA_DIRS"' > ~/.config/environment.d/nixIcons.conf
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
	# Add unstable channel
	nix-channel --add https://nixos.org/channels/nixpkgs-unstable unstable
	nix-channel --update

	local android="nixpkgs.android-tools nixpkgs.scrcpy"

	local development=""

	local game_utilities="nixpkgs.ckan"

	local utilities=""

	local pop="nixpkgs.distrobox"

	local debian=""

	if [ $DISTRO = "POP" ]
	then
		local distro=$pop
	elif [ $DISTRO = "DEBIAN" ]
	then
		local distro=$debian
	fi

	nix-env -iA $android $development $game_utilities $utilities $distro

	# if [ $DISTRO = "DEBIAN" ];
	# then
	# 	# Symlink theme
	# 	sudo ln -s ~/.nix-profile/share/themes/adw-gtk3* /usr/share/themes
	# fi

	# if [ $DISTRO = "POP" ]
	# then
	# 	# Fix podman permissions
	# 	podman system migrate

	# 	# Distrobox setup
	# # 	mkdir -pv ~/.config/containers
	# # 	printf '{
	# #     "default": [
	# #         {
	# #             "type": "insecureAcceptAnything"
	# #         }
	# #     ]
	# # }
	# # ' >> ~/.config/containers/policy.json

	# 	mkdir -pv ~/.config/systemd/user
	# 	ln -s ~/.nix-profile/lib/systemd/user/podman.service ~/.config/systemd/user/podman.service
	# 	ln -s ~/.nix-profile/lib/systemd/user/podman.socket ~/.config/systemd/user/podman.socket
	# 	ln -s ~/.nix-profile/lib/systemd/user/podman-auto-update.service ~/.config/systemd/user/podman-auto-update.service
	# 	ln -s ~/.nix-profile/lib/systemd/user/podman-auto-update.timer ~/.config/systemd/user/podman-auto-update.timer
	# 	ln -s ~/.nix-profile/lib/systemd/user/podman-kube\@.service ~/.config/systemd/user/podman-kube\@.service
	# 	ln -s ~/.nix-profile/lib/systemd/user/podman-restart.service ~/.config/systemd/user/podman-restart.service

	# 	systemctl --user enable --now podman.socket
	# fi

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

	local utilities="com.github.tchx84.Flatseal com.mattjakeman.ExtensionManager ca.desrt.dconf-editor com.usebottles.bottles org.gnome.FontManager org.gnome.GHex it.mijorus.gearlever io.github.flattool.Warehouse com.anydesk.Anydesk"

	local development="com.github.marhkb.Pods org.gnome.design.IconLibrary org.gnome.Devhelp io.github.MakovWait.Godots"

	local office="org.libreoffice.LibreOffice com.github.jeromerobert.pdfarranger com.github.flxzt.rnote fr.romainvigier.MetadataCleaner md.obsidian.Obsidian org.cvfosammmm.Setzer com.github.tenderowl.frog io.github.diegoivan.pdf_metadata_editor"

	local misc="com.gitlab.newsflash com.spotify.Client com.todoist.Todoist de.haeckerfelix.Fragments org.freecadweb.FreeCAD org.nickvision.tubeconverter org.remmina.Remmina org.videolan.VLC com.prusa3d.PrusaSlicer"

	local graphics="io.gitlab.adhami3310.Converter io.gitlab.theevilskeleton.Upscaler com.github.huluti.Curtail org.darktable.Darktable org.gimp.GIMP org.gnome.gThumb org.inkscape.Inkscape org.kde.krita org.blender.Blender"

	local social="com.github.IsmaelMartinez.teams_for_linux com.discordapp.Discord com.sindresorhus.Caprine org.ferdium.Ferdium org.mozilla.Thunderbird us.zoom.Zoom"

	local games="com.github.k4zmu2a.spacecadetpinball io.mrarm.mcpelauncher org.gnome.Aisleriot org.gnome.Chess org.gnome.Mines org.gnome.Mahjongg org.gnome.Quadrapassel org.gnome.Sudoku org.gnome.TwentyFortyEight"

	local game_utilities="com.github.Matoking.protontricks com.valvesoftware.Steam net.davidotek.pupgui2 net.lutris.Lutris org.prismlauncher.PrismLauncher net.pcsx2.PCSX2 org.DolphinEmu.dolphin-emu info.cemu.Cemu org.freedesktop.Platform.VulkanLayer.MangoHud com.dosbox_x.DOSBox-X"

	local pop="org.gtk.Gtk3theme.Pop org.gtk.Gtk3theme.Pop-dark com.github.GradienceTeam.Gradience org.goldendict.GoldenDict org.gnome.Maps org.gnome.clocks"

	local debian="org.gtk.Gtk3theme.adw-gtk3 org.gtk.Gtk3theme.adw-gtk3-dark com.github.hugolabe.Wike org.gnome.PowerStats"

	if [ $DISTRO = "POP" ]
	then
		local distro=$pop
	elif [ $DISTRO = "DEBIAN" ]
	then
		local distro=$debian
	fi

	flatpak install flathub -y $utilities $development $office $misc $graphics $social $games $game_utilities $distro

	vlc_pause_click_plugin
	game_drive_setup	
}

function install_beta_flatpaks {
	flatpak remote-add --user --if-not-exists --title="Flathub Beta" flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo
	flatpak update -y
	flatpak install flathub-beta -y org.zotero.Zotero
}

function vlc_pause_click_plugin {
	local arch="$(flatpak info --show-metadata org.videolan.VLC \
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
	local branch="$(flatpak info --show-metadata org.videolan.VLC \
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
	flatpak install -y "runtime/org.videolan.VLC.Plugin.pause_click/$arch/$branch"
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
	# Customise Desktop 
	gsettings set org.gnome.desktop.interface clock-show-weekday true
	gsettings set org.gnome.desktop.interface clock-format '24h'
	gsettings set org.gnome.desktop.interface show-battery-percentage true

	# Customise Nautilus
	gsettings set org.gnome.nautilus.preferences show-create-link true
	gsettings set org.gnome.nautilus.preferences show-delete-permanently true
	gsettings set org.gnome.nautilus.list-view use-tree-view true

	if [ $DISTRO = "POP" ]
	then
		ln -s /usr/share/icons/Pop ~/.local/share/icons/
 		gsettings set org.gnome.shell.extensions.ding show-volumes true
		gsettings set org.gnome.shell.extensions.dash-to-dock click-action 'minimize-or-previews'
		gsettings set org.gnome.shell.extensions.dash-to-dock dock-fixed false
		gsettings set org.gnome.shell.extensions.dash-to-dock intellihide true
		gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'
		gsettings set org.gnome.shell.extensions.pop-shell fullscreen-launcher true

		# Customise Gedit
		gsettings set org.gnome.gedit.preferences.editor display-overview-map true
	elif [ $DISTRO = "DEBIAN" ]
	then
		# gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'
		gsettings set org.gnome.software packaging-format-preference "['flatpak', 'deb']"

		# Customise TextEditor
		gsettings set org.gnome.TextEditor highlight-current-line true
		gsettings set org.gnome.TextEditor show-line-numbers true
		gsettings set org.gnome.TextEditor show-map true
	fi

	# Customise Privacy
	gsettings set org.gnome.desktop.privacy remove-old-temp-files true
	gsettings set org.gnome.desktop.privacy remove-old-trash-files true

	if [ $DISTRO = "POP" ]
	then
		# Set GTK3 theme
		flatpak override --user --filesystem=xdg-data/themes

		# Set GTK4 theme
		mkdir -pv ~/.config/gtk-4.0
		flatpak override --user --filesystem=xdg-config/gtk-4.0
		flatpak run com.github.GradienceTeam.Gradience
	fi
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

# Debian functions
function add_repos {
	local release="bookworm"
	local sources="/etc/apt/sources.list"

	# Loop through each line in the file
	echo "Enabling contrib and non-free repositories"
	while IFS= read -r line; do
		# Check if the line contains certain strings
		if [[ $line == *"$release main"* || $line == *"$release-updates main"* || $line == *"$release-security main"* ]]; then
	        	# If the line contains the search strings, append the desired string to the end
        		line+=" contrib non-free"
		fi
		# Output the modified line
		echo "$line"
	done < "$sources" > temp_file  # Redirect the output to a temporary file

	# Replace the original file with the modified content
	sudo mv temp_file "$sources"
	
	local backports_string="# Backports allow you to install newer versions of software made available for this release
deb http://deb.debian.org/debian bookworm-backports main non-free-firmware
deb-src http://deb.debian.org/debian bookworm-backports main non-free-firmware"

	echo "Enabling backports repository"
	file_content=$(<"$sources")
	if [[ $file_content == *"$backports_string"* ]]; then
		echo "Backports repository already enabled"
	else
		echo "$backports_string" >> "$sources"
	fi

	sudo apt-get update
}

function nvidia_drivers {
	# Add nvidia repo
	wget https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/cuda-keyring_1.1-1_all.deb
	sudo apt-get install -y ./cuda-keyring_1.1-1_all.deb
	rm -rfv cuda-keyring_1.1-1_all.deb

	sudo apt-get update
}

function upgrade_kernel {
	sudo apt install -y -t stable-backports linux-image-amd64 linux-headers-amd64
	sudo apt-get full-upgrade -y
}

function tune_performance {
	# Enable ZRAM
	sudo apt-get install -y zram-tools
	echo -e "ALGO=zstd\nPERCENT=60" | sudo tee -a /etc/default/zramswap
	sudo service zramswap reload

	# Increase swappiness to force use of ZRAM
	echo 'vm.swappiness=180' | sudo tee -a /etc/sysctl.d/99-swappiness.conf

	# Increase vm.max_map_count
	echo 'vm.max_map_count = 2147483642' | sudo tee -a /etc/sysctl.d/80-gamecompatibility.conf
}

function install_firefox {
	# sudo install -d -m 0755 /etc/apt/keyrings
	# wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null
	# echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | sudo tee -a /etc/apt/sources.list.d/mozilla.list > /dev/null

	sudo extrepo enable mozilla

	sudo apt-get update
	sudo apt-get install -y firefox firefox-l10n-en-gb
}

function install_vscode {
	# wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
	# sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
	# sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
	# rm -f packages.microsoft.gpg

	sudo extrepo enable vscode

 	sudo apt-get update
  	sudo apt-get install -y code
 }

function setup_flatpak {
	sudo apt-get install -y gnome-software-plugin-flatpak
	flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
}

function setup_snap {
	sudo apt-get install -y gnome-software-plugin-snap
	sudo snap install core
}

function edit_grub {
    # sudo cp /etc/default/grub /etc/default/grub.bak
    file="/etc/default/grub"
    
    # Line to search for
    search_line="GRUB_TIMEOUT=5"
    
    # Line to replace with
    replace_line="GRUB_TIMEOUT=0"
    
    # New lines to add after the replaced line
    new_lines='GRUB_TIMEOUT_STYLE=hidden\nGRUB_HIDDEN_TIMEOUT=0\nGRUB_HIDDEN_TIMEOUT_QUIET=true'
    
    # Check if the file contains the search line
    if grep -q "$search_line" "$file"; then
        # Replace the search line with the new line and add new lines after it
        sudo sed -i "/$search_line/c\\$replace_line\n$new_lines" "$file"
        echo "Replacement done!"
    else
        echo "Search line not found."
    fi
    search_line='GRUB_CMDLINE_LINUX_DEFAULT="quiet"'
    replace_line='GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"'
    if grep -q "$search_line" "$file"; then
        # Replace the search line with the new line and add new lines after it
        sudo sed -i "/$search_line/c\\$replace_line" "$file"
        echo "Replacement done!"
    else
        echo "Search line not found."
    fi
    sudo update-grub
}

function install_snaps {
	sudo snap install code --classic
}

if [ ! -f ~/step1_complete ]
then
	select_distro

	if [ $DISTRO = "POP" ]
	then
		check_new_install
	fi

	sudo apt-get update
	sudo apt-get full-upgrade -y
	remove_packages

	if [ $DISTRO = "DEBIAN" ]
	then
		add_repos
	fi

	install_packages
	
	if [ $DISTRO = "DEBIAN" ]
	then
		nvidia_drivers
		upgrade_kernel
		tune_performance
	fi

	if [ $DISTRO = "POP" ]
	then
		add_ppa_and_install_packages
	fi

	enable_timeshift
	mk_dot_dirs

	if [ $DISTRO = "DEBIAN" ]
	then
		install_firefox
  		install_vscode
    	install_joycond_package
		setup_flatpak
		automatic_updates
		edit_grub
	fi

	setup_nix
 	install_via
 	install_p3xonenote
	autostart_script

	touch ~/step1_complete
	if [ $DISTRO = "DEBIAN" ]
	then
		touch ~/step2_complete
	fi
	systemctl reboot
fi

if [ -f ~/step1_complete ] && [ ! -f ~/step2_complete ]
then
	check_distro

	install_nix_packages

	if [ ! -f ~/new_install ] && [ $DISTRO = "POP" ]
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
	check_distro
	
 	if [ DISTRO="DEBIAN" ]
	then
		install_nix_packages
	fi

	install_flatpaks
	install_beta_flatpaks
	install_appimages
	install_matlab
	customisations

	if [ $DISTRO = "POP" ]
	then
		install_launcher_plugins
 		setup_style_switcher
	fi
	
	# Enable Eduroam
	firefox -url 'https://cloud.securew2.com/public/12133/eduroam/'

	customise_firefox

	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

	rm -rfv ~/.config/autostart/$SCRIPT.desktop
	rm -rfv ~/step1_complete
	rm -rfv ~/step2_complete
	rm -rfv ~/new_install
	if [ $DISTRO = "POP" ]
	then
		rm -rfv ~/pop
	elif [ $DISTRO = "DEBIAN" ]
	then
		rm -rfv ~/debian
	fi
	systemctl reboot
fi
