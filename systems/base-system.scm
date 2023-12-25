(define-module (base-system)
  #:use-module (gnu)
  #:use-module (srfi srfi-1)
  #:use-module (gnu system nss)
  #:use-module (gnu system locale)
  #:use-module (nongnu packages linux)
  #:use-module (nongnu system linux-initrd))

(use-service-modules desktop xorg pm cups docker networking dbus virtualization ssh nix)

(use-package-modules cups vim wm video version-control terminals disc xrdisorg web-browsers fonts gtk gcc cmake xorg 
		     emacs curl file-systems gnome mtools ssh linux audio gnuzilla pulseaudio package-management certs shells)

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

;; (define-public base-operating-system
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

(file-systems (cons* (file-system
					   (mount-point "/")
					   (device (uuid
								"7730e416-0aed-4436-b810-5ca35295f3c1"
								'btrfs))
					   (type "btrfs"))
					  (file-system
					   (mount-point "/home")
					   (device (uuid
								"9cf1c466-d8ee-44e6-bc94-23e5f869200e"
								'btrfs))
					   (type "btrfs")) %base-file-systems))

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
					  ;; these are just pkgs I absolutely need to bootstrap the OS, other packages are either in home or separate profiles
					  git
					  curl
					  ntfs-3g
					  exfat-utils
					  fuse-exfat
					  vim
					  openssh
					  bluez
					  bluez-alsa
					  gcc
					  binutils
					  cmake
					  pulseaudio
					  emacs-next-tree-sitter
					  alsa-utils
					  font-jetbrains-mono
					  tlp
					  nss-certs
					  gvfs)
					 %base-packages))

   (services (cons* 
					(service tlp-service-type
							 (tlp-configuration
							  (cpu-boost-on-ac? #t)
							  (wifi-pwr-on-bat? #t)))
					(service openssh-service-type)
					(set-xorg-configuration
					 (xorg-configuration (keyboard-layout keyboard-layout)))
					(pam-limits-service 
					 (list
					  (pam-limits-entry "@realtime" 'both 'rtprio 99)
					  (pam-limits-entry "@realtime" 'both 'memlock 'unlimited)))
					(extra-special-file "/usr/bin/env"
										(file-append coreutils "/bin/env"))
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
   (name-service-switch %mdns-host-lookup-nss))
;; )

