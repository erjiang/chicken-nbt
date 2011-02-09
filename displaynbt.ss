;;
;; displaynbt is a simple wrapper around chicken-nbt that simply pretty-prints
;; the result of readNBT on the given file.
;;

;; Then, we import the "nbt" module, which gives us "nbt:read" and
;; "nbt:read-uncompressed".
(use nbt)

;; SRFI 1 gives us "last"
(use srfi-1)

;; Finally, we simply parse the filename (which is assumed to be the last
;; command-line argument), and then pretty-print the result
(pretty-print (nbt:read (last (command-line-arguments))))
