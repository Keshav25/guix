(define-module (base-system)
  #:use-module (gnu)
  #:use-module (srfi srfi-1)
  #:use-module (gnu system nss)
  #:use-module (gnu system locale)
  #:use-module (gnu services pm)
  #:use-module (gnu services cups)
  #:use-module (gnu services desktop)
  #:use-module (gnu services docker)
  #:use-module (gnu services networking)
  #:use-module (gnu services dbus)
  #:use-module (gnu services virtualization)
  #:use-module (gnu services ssh)
  #:use-module (gnu packages wm)
  #:use-module (gnu packages cups)
  #:use-module (gnu packages vim)
  #:use-module (gnu packages fonts)
  #:use-module (gnu packages gtk)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages cmake)
  #:use-module (gnu packages xorg)
  #:use-module (gnu packages emacs)
  #:use-module (gnu packages vim)
  #:use-module (gnu packages curl)
  #:use-module (gnu packages file-systems)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages mtools)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages audio)
  #:use-module (gnu packages gnuzilla)
  #:use-module (gnu packages pulseaudio)
  #:use-module (gnu packages web-browsers)
  #:use-module (gnu packages version-control)
  #:use-module (gnu packages package-management)
  #:use-module (nongnu packages linux)
  #:use-module (nongnu system linux-initrd))

(use-service-modules nix)
(use-service-modules desktop xorg)
(use-package-modules certs)
(use-package-modules shells)

;; Allow members of the "video" group to change the screen brightness.
(define %backlight-udev-rule
  (udev-rule
   "90-backlight.rules"
   (string-append "ACTION==\"add\", SUBSYSTEM==\"backlight\", "
				  "RUN+=\"/run/current-system/profile/bin/chgrp video /sys/class/backlight/%k/brightness\""
				  "\n"
				  "ACTION==\"add\", SUBSYSTEM==\"backlight\", "
				  "RUN+=\"/run/current-system/profile/bin/chmod g+w /sys/class/backlight/%k/brightness\"")))

(define %my-desktop-services
  (modify-services %desktop-services
				   (elogind-service-type config =>
										 (elogind-configuration (inherit config)
																(handle-lid-switch-external-power 'suspend)))
				   (udev-service-type config =>
									  (udev-configuration (inherit config)
														  (rules (cons %backlight-udev-rule
																	   (udev-configuration-rules config)))))))

(define %xorg-libinput-config
  "Section \"InputClass\"
  Identifier \"Touchpads\"
  Driver \"libinput\"
  MatchDevicePath \"/dev/input/event*\"
  MatchIsTouchpad \"on\"

  Option \"Tapping\" \"on\"
  Option \"TappingDrag\" \"on\"
  Option \"DisableWhileTyping\" \"on\"
  Option \"MiddleEmulation\" \"on\"
  Option \"ScrollMethod\" \"twofinger\"
EndSection
Section \"InputClass\"
  Identifier \"Keyboards\"
  Driver \"libinput\"
  MatchDevicePath \"/dev/input/event*\"
  MatchIsKeyboard \"on\"
EndSection
")

(define-public base-operating-system
  (operating-system
   (host-name "thinkpad")
   (timezone "America/New_York")
   (locale "en_US.utf8")
   
   (kernel linux)
   (firmware (list linux-firmware))
   (initrd microcode-initrd)

   (keyboard-layout (keyboard-layout "us" "altgr-intl" #:model "thinkpad"))

   (bootloader (bootloader-configuration
				(bootloader grub-bootloader)
				(targets (list "/dev/sda"))
				(keyboard-layout keyboard-layout)))

   (swap-devices (list (swap-space
						(target (uuid
								 "7229f203-1a94-4d1e-8399-fc548c666a10")))))

   (file-systems (cons*
				  (file-system
				   (mount-point "/tmp")
				   (device "none")
				   (type "tmpfs")
				   (check? #f))
				  %base-file-systems))

   (users (cons (user-account
				 (name "kesh")
				 (comment "Keshav Italia")
				 (group "users")
				 (home-directory "/home/kesh")
				 (supplementary-groups '(
										 "wheel"
										 "netdev"
										 "kvm"
										 "tty"
										 "input"
										 "docker"
										 "realtime"
										 "lp" ;;bluetooth
										 "audio"
										 "video")))
				%base-user-accounts))

   (groups (cons (user-group (system? #t) (name "realtime"))
				 %base-groups))
   
   (packages (append (list
					  git
					  curl
					  stow
					  ntfs-3g
					  exfat-utils
					  fuse-exfat
					  stow
					  vim
					  emacs-next
					  xterm
					  bluez
					  bluez-alsa
					  pulseaudio
					  tlp
					  xf86-input-libinput
					  nss-certs
					  gvfs)
					 %base-packages))

   (services (cons* (service slim-service-type
							 (slim-configuration
							  (xorg-configuration
							   (xorg-configuration
								(keyboard-layout keyboard-layout)
								(extra-config (list %xorg-libinput-config))))))
					(service tlp-service-type
							 (tlp-configuration
							  (cpu-boost-on-ac? #t)
							  (wifi-pwr-on-bat? #t)))
					(pam-limits-service 
					 (list
					  (pam-limits-entry "@realtime" 'both 'rtprio 99)
					  (pam-limits-entry "@realtime" 'both 'memlock 'unlimited)))
					(extra-special-file "/usr/bin/env"
										(file-append coreutils "/bin/env"))
					(service xfce-desktop-service-type)
					(service thermald-service-type)
					(service tor-service-type)
					(service docker-service-type)
					(service libvirt-service-type
							 (libvirt-configuration
							  (unix-sock-group "libvirt")
							  (tls-port "16555")))
					(service cups-service-type
							 (cups-configuration
							  (web-interface? #t)
							  (extensions
							   (list cups-filters))))
					(service nix-service-type)
					(bluetooth-service #:auto-enable? #t)
					(remove (lambda (service)
							  (eq? (service-kind service) gdm-service-type))
							%my-desktop-services)))
   (name-service-switch %mdns-host-lookup-nss)))

