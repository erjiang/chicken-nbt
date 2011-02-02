;;
;; Level.dat inspector
;; ===================
;;
;; Source code written for Chicken Scheme, requiring certain eggs
;; 
;; Pass this program a level.dat file from Minecraft and it will tell you
;; what's inside.
;;

(require-extension z3)
(require-extension utf8)

(define (main leveldat)
  (let* ([in (z3:open-compressed-input-file leveldat)])
    (display 
      ;;
      ;; Let all read operations automatically pull from the gzip reader
      ;;
      (parameterize ([current-input-port in])
        (pretty-print (readNBT))
        (newline)
        0))))

;;
;; readNBT reads in the NBT file and returns a list representing that NBT
;; file structure.
;;
;; Compound tags are represented as lists:
;;     (tag-name (tag1 tag2 tag3 ...))
;;
;; While tag lists (which are fixed-length and single-type only) are
;; vectors:
;;     #(tag1 tag2 tag3 ...)
;;
(define (readNBT)
  ;;
  ;; readCompound reads a compound tag into a list using recursion until it
  ;; hits the end of the compound tag.
  ;;
  (define (readCompound)
    (letrec ([continueCompound
               (lambda ()
                 (let ([result (readTag)])
                   (if (null? result)
                     '()
                     (cons result (continueCompound)))))])
      (cons (readName)
            (continueCompound))))
  ;;
  ;; readName reads in a UTF8 string name. It is used for reading the names off
  ;; of named tags.
  ;;
  (define (readName)
    ;; We need to get the length of the name. The length is stored as a
    ;; two-byte integer
    (let ([strlen (readShort)])
      (read-string strlen)))

  ;;
  ;; readString reads in a TAG_String. This is different from readName because
  ;; a TAG_String consists of two strings: the name and the payload.
  ;;
  (define (readString)
    (list (readName) (readName)))

  ;; 
  ;; readShort reads in a two-byte (16-bit) integer
  ;;
  (define (readShort)
    (fx+ (arithmetic-shift (read-byte) 8)
                       (read-byte)))

  ;;
  ;; readTag reads in an arbitrary tag. It is basically a switch statement over
  ;; the different tag types.
  ;;
  (define (readTag)
    (let ([type (read-byte)])
      (cond
        ;; TAG_Compound
        ([= type 10]
         `(compound ,(readCompound)))
        ;; TAG_End
        ([= type 0]
         '())
        ;; TAG_Short
        ([= type 2]
         `(short . ,(readShort)))
        ;; TAG_String
        ([= type 8]
         `(string ,(readString)))
        (else
          (error "Unrecognized type" type))
        )))

  ;; Make sure top-level tag is compound.
  (if (= (read-byte) 10)
    ;; kick off the NBT parsing!
    `(compound . ,(readCompound))
    (begin
      (error "Top-level tag is not a compound tag!"))))


(define (last ls)
  (if (null? (cdr ls))
    (car ls)
    (last (cdr ls))))

(if (null? (command-line-arguments))
  (display "Must give path to level.dat\n")
  (main (last (command-line-arguments))))
