(define-module (sl510)
  #:use-module (base-system)
  #:use-module (gnu)
  #:use-module (nongnu packages linux))

(operating-system
 (inherit base-operating-system)
 (host-name "thinkpad")
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
					   (type "btrfs")) %base-file-systems)))


