#!/bin/bash

REVISION="20150731"
AUTHOR="j_r0dd"

echo -e "\033[0;31m******************************************************\033[0m"
echo -e "\033[0;31m******************************************************\033[0m"
echo -e "\033[0;31m**                                                  **\033[0m"
echo -e "\033[0;31m**  This installs Plex Home Theater as an           **\033[0m"
echo -e "\033[0;31m**  appliance. It has been tested on multiple       **\033[0m"
echo -e "\033[0;31m**  Ubuntu variants. This script has many checks    **\033[0m"
echo -e "\033[0;31m**  in place and should be completely safe even     **\033[0m"
echo -e "\033[0;31m**  if ran multiple times. It is intended for       **\033[0m"
echo -e "\033[0;31m**  the Intel NUC, but has only been tested by me   **\033[0m"
echo -e "\033[0;31m**  on model NUC5i3RYK. This has also been          **\033[0m"
echo -e "\033[0;31m**  confirmed working on other non-NUC boards with  **\033[0m"
echo -e "\033[0;31m**  Intel graphics. If you find a tweak or fix out  **\033[0m"
echo -e "\033[0;31m**  there and want it to be added to this script    **\033[0m"
echo -e "\033[0;31m**  send me a PM on the Plex forums.                **\033[0m"
echo -e "\033[0;31m**                                                  **\033[0m"
echo -e "\033[0;31m******************************************************\033[0m"
echo -e "\033[0;31m******************************************************\033[0m"

DATE=$(date +%Y%m%d)
LOGFILE="pht-${DATE}.log"
exec &> >(tee -a ${LOGFILE})

echo "You are running script version ${REVISION} by ${AUTHOR}"

read -r -p "Ready to begin installation? [y/N]" RESPONSE
if [[ ! ${RESPONSE} =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "Exiting..."
    exit 1
fi

echo "Checking if being run by sudo"
if [[ ${EUID} != 0 ]]; then
    echo "Script must be run as sudo!"
    echo "Exiting..."
    exit 1
  elif [[ ${EUID} = ${UID} && ${SUDO_USER} = "" ]]; then
    echo "Script must be run as current user via 'sudo', not as the root user!"
    echo "Exiting..."
    exit 1
  else
    echo "This script is being ran as $SUDO_USER"
fi

DISTRO=$(lsb_release -is)
SUPVERS=(14.04 14.10 15.04)
VERSION=$(lsb_release -rs)
if [[ ${DISTRO} == Ubuntu ]]; then
    if [[ ${SUPVERS[*]} =~ ${VERSION} ]]; then
        echo "Your Ubuntu version is $VERSION"
      else
        echo "You are not running a supported version of Ubuntu" 
        read -r -p "Are you sure you want to proceed? [y/N]" RESPONSE
        if [[ ${RESPONSE} =~ ^([yY][eE][sS]|[yY])$ ]]; then
            echo "Beginning installation"
          else
            echo "Exiting..."
            exit 1
        fi
    fi
  else
    echo "You are on an unsupported distro"
    echo "Exiting..."
    exit 1
fi

MODEL=$(dmidecode -s baseboard-product-name)
echo Checking hardware...                                                                                                                                                                       
if [[ ! ${MODEL} =~ NUC ]]; then
    echo "This script currently only verifies Broadwell NUC model numbers. Your board model number is ${MODEL}."
    read -r -p "Your system is not a Broadwell NUC. Are you sure you want to proceed? [y/N] " RESPONSE
    if [[ ${RESPONSE} =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo "Beginning installation"
      else
        echo "Exiting..."
        exit 1
    fi
  else
    echo "You have a Broadwell NUC and your board model number is ${MODEL}"
    echo "Beginning installation"
fi

function install_pht {
echo "Installing PHT"
echo "Checking if the PHT repo is installed"
if [[ -n $(find /etc/apt/sources.list.d/ -name plexapp*) ]]; then
    echo "The Plex repo is already installed"
  else
    add-apt-repository -y ppa:plexapp/plexht
    apt-get update -y
    echo "The Plex repo has been installed"
fi

echo "Checking if PHT is installed"
if [[ -z $(dpkg-query -s plexhometheater | grep -o "ok installed") ]]; then
    apt-get install -y plexhometheater
    echo "PHT installed"
  else
    echo "PHT was already installed"
fi
}

function systemd_method {
JUNK=(lightdm consolekit pm-utils upower)
echo "Removing unneeded packages" 
for package in ${JUNK[@]}; do
    if [[ -n $(dpkg-query -s ${package} | grep -o "ok installed") ]]; then
        apt-get remove -y ${package}
        echo "${package} has been removed"
      else
        echo "${package} is not installed"
    fi
done                                                                                            
apt-get autoremove -y
echo "Orphan packages have been removed"

DEPS=(alsa-utils dbus-x11 i965-va-driver intel-gpu-tools libmad0 libmpeg2-4 librtmp1 libva-drm1 libva-egl1 libva-intel-vaapi-driver libva-tpi1 libva-wayland1 linux-firmware mesa-utils plymouth plymouth-label python-software-properties software-properties-common ttf-ancient-fonts vainfo xorg)
apt-get update -y
for package in ${DEPS[@]}; do
    if [[ -n $(dpkg-query -s ${package} | grep -o "ok installed") ]]; then
        echo "${package} was previously installed"
      else
        apt-get install -y ${package}
        echo "${package} has been installed"
    fi
done
apt-get dist-upgrade -y

install_pht

PLEXDEFAULT="/opt/plexhometheater/share/XBMC/addons/skin.plex/720p/LeftSideMenu.xml"
PLEXSKINS=$(find /home/$SUDO_USER/.plexht/ -name LeftSideMenu.xml)
SUSPENDPATCH="sed -i 's/Plex.Suspend/System.Exec(\"systemctl,suspend\")/g'"
POWEROFFPATCH="sed -i 's/Plex.Powerdown/System.Exec(\"systemctl,poweroff\")/g'"
REBOOTPATCH="sed -i 's/System.Exec(reboot)/System.Exec(\"systemctl,reboot\")/g'"
SUSPENDFIX="sed -i 's|System.Exec("dbus-send,--system,--print-reply,--dest='org.freedesktop.login1',/org/freedesktop/login1,org.freedesktop.login1.Manager.Suspend,boolean:true")|System.Exec("systemctl,suspend")|g'"
POWEROFFFIX="sed -i 's|System.Exec("dbus-send,--system,--print-reply,--dest='org.freedesktop.login1',/org/freedesktop/login1,org.freedesktop.login1.Manager.PowerOff,boolean:true")|System.Exec("systemctl,poweroff")|g'"
REBOOTFIX="sed -i 's|System.Exec("dbus-send,--system,--print-reply,--dest='org.freedesktop.login1',/org/freedesktop/login1,org.freedesktop.login1.Manager.Reboot,boolean:true")|System.Exec("systemctl,reboot")|g'"

echo "Checking the power options in Plex"
echo "Checking if previous patch was applied"
for files in ${PLEXDEFAULT} ${PLEXSKINS}; do
    if [[ -n $(grep "org.freedesktop.login1" ${files}) ]]; then
        echo "Previous patch was detected. Updating."
        if [[ -n $(grep "Manager.Suspend" ${files}) ]]; then
            eval ${SUSPENDFIX} ${files}
            echo "Suspend function has been updated in ${files}"
        fi
        if [[ -n $(grep "Manager.PowerOff" ${files}) ]]; then
            eval ${POWEROFFFIX} ${files}
            echo "Powerdown function has been updated in ${files}"
        fi
        if [[ -n $(grep "Manager.Reboot" ${files}) ]]; then
            eval ${REBOOTFIX} ${files}
            echo "Reboot function has been updated in ${files}"
        fi
    fi
done

for files in ${PLEXDEFAULT} ${PLEXSKINS}; do
    if [[ -z $(grep -E "Plex.Suspend|Plex.Powerdown|System.Exec\(reboot\)" ${files}) ]]; then
        echo "Plex power options have previously been patched in ${files}"
      else
        if [[ -n $(grep "Plex.Suspend" ${files}) ]]; then
            eval ${SUSPENDPATCH} ${files}
            echo "Suspend function has been patched in ${files}"
        fi
        if [[ -n $(grep "Plex.Powerdown" ${files}) ]]; then
            eval ${POWEROFFPATCH} ${files}
            echo "Powerdown function has been patched in ${files}"
        fi
        if [[ -n $(grep "System.Exec(reboot)" ${files}) ]]; then
            eval ${REBOOTPATCH} ${files}
            echo "Reboot function has been patched in ${files}"
        fi
    fi
done

XWRAPCFG="/etc/X11/Xwrapper.config"
CURRENTALLOWED=$(grep "allowed_users" /etc/X11/Xwrapper.config | cut -f2- -d'=')
echo "Checking who is allowed to start X"
if [[ -n $(grep "anybody" ${XWRAPCFG}) ]]; then
    echo "X is already configured to allow anybody to start"
  else
    echo "${CURRENTALLOWED} has permissions to start X. Fixing."
    sed -i 's/^\(allowed_users=\).*/\1anybody/' ${XWRAPCFG}
    dpkg-reconfigure -f noninteractive x11-common
    echo "Anybody can now start X"
fi

SYSTEMDDIR="/etc/systemd/system"
PHTSERVICE="plexhometheater.service"
DMSERVICE="display-manager.service"
PHT="${SYSTEMDDIR}/${PHTSERVICE}"
DM="${SYSTEMDDIR}/${DMSERVICE}"
PHTPATCH=$(cat << EOF
[Unit]
Description = pht standalone using xinit
After = systemd-user-sessions.service network.target sound.target network-online.target

[Service]
User = $SUDO_USER
Group = plex
Type = simple
PAMName = login
Environment = "XBMC_HOME=/opt/plexhometheater/share/XBMC"
Environment = "AE_ENGINE=SOFT"
ExecStart = /usr/bin/xinit /usr/bin/dbus-launch --exit-with-session /opt/plexhometheater/bin/plexhometheater --standalone -- :0 -nolisten tcp -nocursor
Restart = always

[Install]
WantedBy = multi-user.target
EOF
)
echo "Checking for existing PHT service"
if [[ ! -f ${PHT} ]]; then
    echo "${PHT} does not exist. Creating."
    echo "${PHTPATCH}" > ${PHT}
    ln -sf ${PHT} ${DM}
    echo "Plex has been symlinked to ${DMSERVICE}"
    systemctl enable ${PHTSERVICE}
    echo "Systemd service has been enabled"
  else
    echo "${PHT} already exists"
    echo "Checking symlink"
    if [[ -L ${DM} && $(readlink ${DM}) != ${PHT} ]]; then
        ln -sf ${PHT} ${DM}
        echo "Symlink has been updated"
      else
        echo "Proper display-manager symlink already exists"
    fi
    if [[ ! -L ${SYSTEMDDIR}/multi-user.target.wants/${PHTSERVICE} ]]; then
        systemctl enable ${PHTSERVICE}
        echo "Plex service has been enabled"
      else
        echo "Plex service is already enabled"
    fi
fi

CIRSERVICE="/etc/systemd/system/nuvoton_cir.service"
CIRPATCH=$(cat << 'EOF'
[Unit]
Description=Nuvoton CIR fix

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c 'modprobe -r nuvoton_cir; sleep 1; echo "auto" > /sys/bus/acpi/devices/NTN0530\:00/physical_node/resources; modprobe nuvoton_cir'

[Install]
WantedBy=multi-user.target
EOF
)
echo "Checking IR capabilities"
if [[ -d /sys/bus/acpi/devices/NTN0530\:00 ]]; then
    if [[ $(lsmod | grep "nuvoton_cir" | wc -l) -gt 0 ]]; then
        echo "IR is already working properly"
      else
        if [[ ! -f ${CIRSERVICE} ]]; then
            echo "${CIRPATCH}" > ${CIRSERVICE}
            echo "Created ${CIRSERVICE}"
            systemctl enable nuvoton_cir.service
            systemctl start nuvoton_cir.service
          else
            echo "${CIRSERVICE} already exists"
        fi
    fi
  else
    echo "Did not detect the Nuvoton CIR on your system. Not configuring."
fi
}

function lightdm_method {
if [[ ${VERSION} == 15.04 ]]; then
    echo "Checking for existing systemd service"
    if [[ -f /etc/systemd/system/multi-user.target.wants/plexhometheater.service ]]; then
        systemctl disable plexhometheater.service
        echo "Plex systemd service has been disabled"
      else
        echo "Plex systemd service does not exist"
    fi
fi

DEPS=(alsa-utils i965-va-driver intel-gpu-tools libmad0 libmpeg2-4 librtmp1 libva-drm1 libva-egl1 libva-intel-vaapi-driver libva-tpi1 libva-wayland1 linux-firmware mesa-utils plymouth plymouth-label python-software-properties ttf-ancient-fonts vainfo)
apt-get update -y
for package in ${DEPS[@]}; do
    if [[ -n $(dpkg-query -s ${package} | grep -o "ok installed") ]]; then
        echo "${package} was previously installed"
      else
        apt-get install -y ${package}
        echo "${package} has been installed"
    fi
done
apt-get dist-upgrade -y

install_pht

PLEXDEFAULT="/opt/plexhometheater/share/XBMC/addons/skin.plex/720p/LeftSideMenu.xml"
PLEXSKINS=$(find /home/$SUDO_USER/.plexht/ -name LeftSideMenu.xml)
SUSPENDPATCH="sed -i 's/Plex.Suspend/System.Exec(\"pm-suspend\")/g'"
POWEROFFPATCH="sed -i 's/Plex.Powerdown/System.Exec(\"poweroff\")/g'"
REBOOTPATCH="sed -i 's/System.Exec(reboot)/System.Exec(\"reboot\")/g'"
SUSPENDFIX="sed -i 's|System.Exec("dbus-send,--system,--print-reply,--dest='org.freedesktop.login1',/org/freedesktop/login1,org.freedesktop.login1.Manager.Suspend,boolean:true")|System.Exec("pm-suspend")|g'"
POWEROFFFIX="sed -i 's|System.Exec("dbus-send,--system,--print-reply,--dest='org.freedesktop.login1',/org/freedesktop/login1,org.freedesktop.login1.Manager.PowerOff,boolean:true")|System.Exec("poweroff")|g'"
REBOOTFIX="sed -i 's|System.Exec("dbus-send,--system,--print-reply,--dest='org.freedesktop.login1',/org/freedesktop/login1,org.freedesktop.login1.Manager.Reboot,boolean:true")|System.Exec("reboot")|g'"

echo "Checking the power options in Plex"
echo "Checking if previous patch was applied"
for files in ${PLEXDEFAULT} ${PLEXSKINS}; do
    if [[ -n $(grep "org.freedesktop.login1" ${files}) ]]; then
        echo "Previous patch was detected. Updating."
        if [[ -n $(grep "Manager.Suspend" ${files}) ]]; then
            eval ${SUSPENDFIX} ${files}
            echo "Suspend function has been updated in ${files}"
        fi
        if [[ -n $(grep "Manager.PowerOff" ${files}) ]]; then
            eval ${POWEROFFFIX} ${files}
            echo "Powerdown function has been updated in ${files}"
        fi
        if [[ -n $(grep "Manager.Reboot" ${files}) ]]; then
            eval ${REBOOTFIX} ${files}
            echo "Reboot function has been updated in ${files}"
        fi
    fi
done

for files in ${PLEXDEFAULT} ${PLEXSKINS}; do
    if [[ -z $(grep -E "Plex.Suspend|Plex.Powerdown|System.Exec\(reboot\)" ${files}) ]]; then
        echo "Plex power options have previously been patched in ${files}"
      else
        if [[ -n $(grep "Plex.Suspend" ${files}) ]]; then
            eval ${SUSPENDPATCH} ${files}
            echo "Suspend function has been patched in ${files}"
        fi
        if [[ -n $(grep "Plex.Powerdown" ${files}) ]]; then
            eval ${POWEROFFPATCH} ${files}
            echo "Powerdown function has been patched in ${files}"
        fi
        if [[ -n $(grep "System.Exec(reboot)" ${files}) ]]; then
            eval ${REBOOTPATCH} ${files}
            echo "Reboot function has been patched in ${files}"
        fi
    fi
done

XSESSIONSDIR="/usr/share/xsessions"
PLEXDESKTOP="${XSESSIONSDIR}/Plex.desktop"
DESKTOPPATCH=$(cat << EOF
[Desktop Entry]
Name=Plex
Comment=This session will start Plex Home Theater
Exec=plexhometheater.sh
TryExec=plexhometheater.sh
Type=Application
EOF
)
echo "Checking for desktop file"
if [[ ! -f ${PLEXDESKTOP} ]]; then
    if [[ ! -d ${XSESSIONSDIR} ]]; then
        mkdir -p ${XSESSIONSDIR}
    fi
    echo "${DESKTOPPATCH}" > ${PLEXDESKTOP}
    echo "Desktop file created"
  else
    echo "Desktop file already exists. Checking contents."
    if [[ -n $(grep "plex-standalone" ${PLEXDESKTOP}) ]]; then
        sed -i 's/plex-standalone/plexhometheater.sh/g' ${PLEXDESKTOP}
        echo "${PLEXDESKTOP} has been updated"
      else
        echo "Desktop file does not need to be updated"
    fi
fi

STARTUPSCRIPT="/usr/bin/plexhometheater.sh"
STARTUPPATCH=$(cat <<-'EOF'
--- plexhometheater.sh	2015-05-15 11:42:44.550503476 -0400
+++ plexhometheater.sh.new	2015-05-15 12:02:30.819189070 -0400
@@ -1,5 +1,42 @@
 #!/bin/sh
 export XBMC_HOME=/opt/plexhometheater/share/XBMC
 #Use export AE_ENGINE=SOFT to disable pulse audio
-#export AE_ENGINE=SOFT
-/opt/plexhometheater/bin/plexhometheater
+export AE_ENGINE=SOFT
+APP="/opt/plexhometheater/bin/plexhometheater --standalone $@"
+
+LOOP=1
+CRASHCOUNT=0
+LASTSUCCESSFULSTART=$(date +%s)
+
+while [ $(( $LOOP )) = "1" ]
+do
+  $APP
+  RET=$?
+  NOW=$(date +%s)
+  if [ $(( ($RET >= 64 && $RET <=66) || $RET == 0 )) = "1" ]; then # clean exit
+    LOOP=0
+    case "$RET" in
+      0)
+        LOOP=1 ;; #PHT was closed, so restart it
+      64)
+        /sbin/poweroff ;; #User requested a shutdown
+      65)
+        LOOP=1 ;; #User requested a soft reboot
+      66)
+        /sbin/reboot ;; #User requested a hard reboot
+    esac
+  else # crash
+    DIFF=$((NOW-LASTSUCCESSFULSTART))
+    if [ $(($DIFF > 60 )) = "1" ]; then # Not on startup, ignore
+      LASTSUCESSFULSTART=$NOW
+      CRASHCOUNT=0
+    else # at startup, look sharp
+      CRASHCOUNT=$((CRASHCOUNT+1))
+      if [ $(($CRASHCOUNT >= 3)) = "1" ]; then # Too many, bail out
+        LOOP=0
+        echo "${APP} has exited uncleanly 3 times in the last ${DIFF} seconds."
+        echo "Something is probably wrong"
+      fi
+    fi
+  fi
+done
EOF
)
echo "Checking PHT startup script"
if [[ -n $(grep "sudo" ${STARTUPSCRIPT}) ]]; then
    sed -i 's/\/usr\/bin\/sudo\s//g' ${STARTUPSCRIPT}
    echo "Updated previous patch" 
  elif [[ -n $(patch ${STARTUPSCRIPT} <<< "${STARTUPPATCH}" --dry-run | grep "Reversed") ]]; then
    echo "PHT startup script was previously patched"
  elif [[ -n $(patch ${STARTUPSCRIPT} <<< "${STARTUPPATCH}" --dry-run | grep "FAILED") ]]; then
    echo "PHT startup script has manually been edited. Ignoring."
  else
    patch ${STARTUPSCRIPT} <<< "${STARTUPPATCH}"
    echo "PHT startup script has been patched"
fi                                                                                                                                                                                                

LIGHTDMCONF="/etc/lightdm/lightdm.conf"
LIGHTDMPATCH=$(cat << EOF
[SeatDefaults]
xserver-command=/usr/bin/X -bs -nolisten tcp -nocursor
autologin-user=${SUDO_USER}
autologin-user-timeout=0
user-session=Plex
greeter-session=lightdm-gtk-greeter
allow-guest=false
default-user=${SUDO_USER}
EOF
)
echo "Checking if lightdm is installed"
if [[ -n $(dpkg-query -s lightdm | grep -o "ok installed") ]]; then
    echo "Lightdm is installed. Checking for existing conf file."
    if [[ -f ${LIGHTDMCONF} ]]; then
        if [[ -n $(grep "Plex" ${LIGHTDMCONF}) ]]; then
            if [[ -z $(grep "nocursor" ${LIGHTDMCONF}) ]]; then
                sed -i '/tcp/s/$/ \-nocursor/' ${LIGHTDMCONF}
                echo "Hiding cursor"
              else
                echo "Conf file was previously patched"
            fi
          else
            echo "Unpatched conf file exists. Making a backup."
            mv ${LIGHTDMCONF}{,.bak}
            echo "Creating new conf file"
            echo "${LIGHTDMPATCH}" > ${LIGHTDMCONF}
        fi
      else
        echo "No existing conf file found. Creating conf file."
        echo "${LIGHTDMPATCH}" > ${LIGHTDMCONF}
    fi
  else
    echo "Lightdm is not installed. Installing, this may take a while."
    apt-get install -y lightdm
    mv ${LIGHTDMCONF}{,.bak}
    echo "${LIGHTDMPATCH}" > ${LIGHTDMCONF}
fi

echo "Checking IR capabilities"
CIRSCRIPT="/etc/rc2.d/S18fix-cir"
CIRPATCH=$(cat << 'EOF'
#! /bin/sh
modprobe -r nuvoton_cir
sleep 1
echo "auto" > /sys/bus/acpi/devices/NTN0530\:00/physical_node/resources
modprobe nuvoton_cir
EOF
)
if [[ -d /sys/bus/acpi/devices/NTN0530\:00 ]]; then
    if [[ $(lsmod | grep "nuvoton_cir" | wc -l) -gt 0 ]]; then
        echo "IR is already working properly"
      else
        echo "${CIRPATCH}" > ${CIRSCRIPT}
        chmod 755 ${CIRSCRIPT}
        echo "Created ${CIRSCRIPT}"
    fi
  else
    echo "Did not detect the Nuvoton CIR on your system. Not configuring."
fi
}

if [[ ${VERSION} == 15.04 ]]; then
    while [[ -z ${RESPONSE} || ${RESPONSE} != lightdm && ${RESPONSE} != systemd ]]; do
        read -r -p "What version do you want to install? [systemd/lightdm] " RESPONSE
        if [[ ${RESPONSE} == lightdm ]]; then
            echo "Installing lightdm version"
            lightdm_method
          elif [[ ${RESPONSE} == systemd ]]; then
            echo "Installing systemd version"
            systemd_method
        fi
    done
  else
    echo "Installing lightdm version. If you want the systemd version please upgrade to 15.04."
    lightdm_method
fi

echo "Modifying user groups"
usermod -a -G cdrom,audio,video,plugdev,users,dialout,dip,plex,sudo $SUDO_USER

SUDOPATCH="${SUDO_USER} ALL=(ALL) NOPASSWD: /sbin/halt, /sbin/reboot, /sbin/poweroff"
SUDOERS="/etc/sudoers"
echo "Checking if previous sudoers patch needs to be reversed"
if [[ -z $(grep "${SUDOPATCH}" ${SUDOERS}) ]]; then
    echo "${SUDO_USER} is not in sudoers"
  else
    echo "Removing ${SUDO_USER} from sudoers"
    chmod 600 ${SUDOERS}
    sed -i '/halt/d' ${SUDOERS}
    chmod 440 ${SUDOERS}
fi

POLKITDIR="/etc/polkit-1/localauthority/50-local.d"
PKLA="${POLKITDIR}/custom-actions.pkla"
POLKITPATCH=$(cat << EOF
[Actions for plex user]
Identity=unix-user:$SUDO_USER
Action=org.freedesktop.login1.*
ResultAny=yes
ResultInactive=yes
ResultActive=yes

[Untrusted Upgrade]
Identity=unix-user:$SUDO_USER
Action=org.debian.apt.upgrade-packages;org.debian.apt.update-cache
ResultAny=yes
ResultInactive=yes
ResultActive=yes
EOF
)
echo "Checking polkit"
if [[ -f ${PKLA} ]]; then
    if [[ -n $(grep "unix-user:$SUDO_USER" ${PKLA}) ]]; then
        echo "Polkit was previously patched"
      else
        echo "Adding polkit permissions"
        echo "${POLKITPATCH}" > ${PKLA}
    fi
  else
    if [[ ! -d ${POLKITDIR} ]]; then
        mkdir -p ${POLKITDIR}
    fi
    echo "Creating ${PKLA}"
    echo "${POLKITPATCH}" > ${PKLA}
    echo "${PKLA} has been created"
fi

HDMI=$(DISPLAY=:0 xrandr | grep "HDMI" | grep -w "connected" | awk '{print $1}')
XPROFILE="/home/${SUDO_USER}/.xprofile"
RGBFIX="xrandr --output ${HDMI} --set \"Broadcast RGB\" \"Full\""
if [[ -n ${HDMI} ]]; then
    if [[ ! -f ${XPROFILE} ]]; then
        echo "Creating ${XPROFILE} and applying RGB fix"
        echo ${RGBFIX} > ${XPROFILE}
        echo "If you experience color clipping with this enabled run the following command 'sudo sed -i 's/Full/Automatic/' ${XPROFILE}'" 
      elif [[ -z $(grep "${RGBFIX}" ${XPROFILE}) ]]; then
        echo "Applying RGB fix to ${XPROFILE}"
        sed -i "\$a${RGBFIX}" ${XPROFILE}
        echo "If you experience color clipping with this enabled run the following command 'sudo sed -i 's/Full/Automatic/' ${XPROFILE}'"
      else
        echo "${XPROFILE} already contains RGB fix"
    fi
  else
    echo "HDMI is not used so fix does not apply"
fi

XORGCONFDIR="/etc/X11/xorg.conf.d/"
XORGCONF="${XORGCONFDIR}/20-intel.conf"
XORGPATCH=$(cat << 'EOF'
Section "Device"
Identifier "Intel Graphics"
Option "SwapbuffersWait" "true"
Option "AccelMethod" "sna"
Option "TearFree" "true"
EndSection
EOF
)
echo Checking Xorg
if [[ -f ${XORGCONF} ]]; then
    if [[ -n $(grep '\"TearFree\"\ \"true\"' ${XORGCONF}) ]]; then
        echo "Tear free previously enabled"
      else
        echo "Tear free disabled. Re-enabling..."
        sed -i '/\"TearFree\"\ /s/\"false\"/\"true\"/' ${XORGCONF}
    fi
    if [[ -n $(grep '\"AccelMethod\"\ \"glamor\"' ${XORGCONF}) ]]; then
        sed -i '/\"AccelMethod\"\ /s/\"glamor\"/\"sna\"/' ${XORGCONF}
        echo "Glamor was previously set as the default acceleration. Reverting back to SNA."
    fi
  else
    if [[ ! -d ${XORGCONFDIR} ]]; then
        mkdir -p ${XORGCONFDIR}
    fi
    echo "Creating ${XORGCONF}"
    echo "${XORGPATCH}" > ${XORGCONF}
    echo "${XORGCONF} has been created"
fi

function lircd_config {
    LIRCDCONF="/etc/lirc/lircd.conf"
    sed -i "\$a#Configuration for the Windows Media Center Transceivers/Remotes (all) remote:" ${LIRCDCONF}
    sed -i "\$ainclude \"/usr/share/lirc/remotes/mceusb/lircd.conf.mceusb\"\n" ${LIRCDCONF}
    echo "Configured ${LIRCDCONF} with Windows Media Center profile"
    echo "If you are not using a Windows Media Center compatible remote then manually reconfigure with 'sudo dpkg-reconfigure lirc'"
    dpkg-reconfigure -f noninteractive lirc
}
function hardware_config {
    HARDWARECONF="/etc/lirc/hardware.conf"
    sed -i 's/^\(REMOTE=\).*/\1"Windows Media Center Transceivers\/Remotes (all)"/' ${HARDWARECONF}
    sed -i 's/^\(REMOTE_MODULES=\).*/\1"lirc_dev mceusb"/' ${HARDWARECONF}
    sed -i 's/^\(REMOTE_DEVICE=\).*/\1"\/dev\/lirc0"/' ${HARDWARECONF}
    sed -i 's/^\(REMOTE_LIRCD_CONF=\).*/\1"mceusb\/lircd.conf.mceusb"/' ${HARDWARECONF}
    sed -i 's/^\(START_LIRCD=\).*/\1"true"/' ${HARDWARECONF}
    echo "Configured ${HARDWARECONF} with the Windows Media Center profile"
    echo "If you are not using a Windows Media Center compatible remote then manually reconfigure with 'sudo dpkg-reconfigure lirc'"
}
function install_lirc {
    echo "Installing lirc"
    export DEBIAN_FRONTEND=noninteractive
    apt-get install -y lirc
    echo "Configuring lirc"
    lircd_config
    hardware_config
    echo lirc > /sys/class/rc/rc0/protocols
    echo "Lirc has been installed"
}
LIRCDCONF="/etc/lirc/lircd.conf"
HARDWARECONF="/etc/lirc/hardware.conf"
echo "Checking if lirc is installed"
if [[ -n $(dpkg-query -s lirc | grep -o "ok installed") ]]; then
    echo "Lirc is already installed. Checking config files."
    if [[ -n $(grep "#Configuration" ${LIRCDCONF}) ]]; then
        echo "${LIRCDCONF} was previously configured with a profile"
        if [[ -z $(grep '"/usr/share/lirc/remotes/mceusb/lircd.conf.mceusb"' ${LIRCDCONF}) ]]; then
            sed -i 's/\(\/usr\/share\/lirc\/remotes\/mceusb\/lircd.conf.mceusb\)/\"\1\"/' ${LIRCDCONF}
            echo "Updated previous patch"
        fi
      else
        lircd_config
    fi
    if [[ -n $(grep "lircd.conf" ${HARDWARECONF}) ]]; then
        echo "${HARDWARECONF} was previously configured with a profile"
      else
        hardware_config
    fi
  else
    install_lirc
fi

function get_files {
	echo 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 | base64 -d | tar -xzv
	
}

function install_plex_splash {
    echo "Moving into themes folder"
    cd /lib/plymouth/themes
    echo "Unpacking files"
    get_files
    echo "Setting as default plymouth theme"
    ln -sf /lib/plymouth/themes/plex-logo/plex-logo.plymouth /etc/alternatives/default.plymouth
    ln -sf /lib/plymouth/themes/plex-text/plex-text.plymouth /etc/alternatives/text.plymouth
    update-initramfs -u
}

echo "Checking if Plex splash screen has been installed"
if [[ -f /lib/plymouth/themes/plex-logo/plex-logo.plymouth ]]; then
    echo "Plex splash screen was previously installed"
  else
    install_plex_splash
    echo "Plex splash screen has been installed"
fi

echo "Checking grub configuration"
GRUBDEF="/etc/default/grub"
GRUBCFG="/boot/grub/grub.cfg"
if [[ -n $(grep "quiet" ${GRUBDEF} && grep "splash" ${GRUBDEF}) ]]; then
    echo "Grub is already configured for splash screen"
  else
    if [[ -z $(grep "splash" ${GRUBDEF}) ]]; then
        sed -i 's/^\(GRUB_CMDLINE_LINUX_DEFAULT="\)/\1splash\ /' ${GRUBDEF}
    fi
    if [[ -z $(grep "quiet" ${GRUBDEF}) ]]; then
        sed -i 's/^\(GRUB_CMDLINE_LINUX_DEFAULT="\)/\1quiet\ /' ${GRUBDEF}
    fi
    sed -i 's/[ \t]"*$/"/' ${GRUBDEF}
    sed -i 's/^\(GRUB_TIMEOUT=\).*/\10/' ${GRUBDEF}
    sed -i '/^#.*GRUB_HIDDEN_TIMEOUT/s/^#//' ${GRUBDEF}
    grub-mkconfig -o ${GRUBCFG}
    echo "Grub has been updated to display a splash screen"
fi

echo "Installing Intel Linux Graphics Drivers"
echo "Checking for Intel's keys"
if [[ -z $(apt-key list | grep "Intel") ]]; then
    wget --no-check-certificate https://download.01.org/gfx/RPM-GPG-KEY-ilg -O - | apt-key add -
    wget --no-check-certificate https://download.01.org/gfx/RPM-GPG-KEY-ilg-2 -O - | apt-key add -
    echo "Intel's keys have been installed"
  else
    echo "Intel's keys were previously installed"
fi

case ${VERSION} in
    15.04)
        echo "There isn't a current Intel Graphics Installer for Ubuntu 15.04. The script will updated when released."
        ;;
    14.10)
        echo "Downloading Intel Graphics Installer v1.1.0"
        wget https://download.01.org/gfx/ubuntu/14.10/main/pool/main/i/intel-linux-graphics-installer/intel-linux-graphics-installer_1.1.0-0intel1_amd64.deb
        dpkg -i intel-linux-graphics-installer_1.1.0-0intel1_amd64.deb
        echo "Running Intel Graphics Installer v1.1.0"
        intel-linux-graphics-installer
        ;;
    14.04)
        echo "Downloading Intel Graphics Installer v1.0.7. This package has been deprecated by Intel. It's best to upgrade to a newer release of Ubuntu."
        wget https://download.01.org/gfx/ubuntu/14.04/main/pool/main/i/intel-linux-graphics-installer/intel-linux-graphics-installer_1.0.7-0intel1_amd64.deb
        dpkg -i intel-linux-graphics-installer_1.0.7-0intel1_amd64.deb
        echo "Running Intel Graphics Installer v1.0.7"
        intel-linux-graphics-installer
        ;;
    *)
        echo "You are on an unsupported version of Ubuntu which has no Intel Graphics Installer"
        ;;
esac

echo "Installation is complete. Rebooting in 10 seconds."
for i in {10..1}; do 
  echo -n "${i}.." && sleep 1; 
done
reboot