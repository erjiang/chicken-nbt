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

;; bignum support is needed for dealing with long longs
(use numbers)

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
;    #;(cond
;      ;; TAG_Compound
;      ([= type 10]
;       `(compound ,(readName) ,(readCompound)))
;      ;; TAG_End
;      ([= type 0]
;       '())
;      ;; TAG_Byte
;      ([= type 1]
;       `(byte ,(readName) ,(readByte)))
;      ;; TAG_Short
;      ([= type 2]
;       `(short ,(readName) ,(readShort)))
;      ;; TAG_Int
;      ([= type 3]
;       `(int ,(readName) ,(readInt)))
;      ;; TAG_Long
;      ([= type 4]
;       `(long ,(readName) ,(readLong)))
;      ;; TAG_Float
;      ([= type 5]
;       `(float ,(readName) ,(readFloat)))
;      ;; TAG_Double
;      ([= type 6]
;       `(double ,(readName) ,(readDouble)))
;      ;; TAG_String
;      ;; A TAG_String is really just two strings: a name and a payload
;      ([= type 8]
;       `(string ,(readName) ,(readName)))
;      ([= type 9]
;       `(list . ,(readList)))
;      (else
;        ;(error "Unrecognized type" type))
;        `(unrecognized ,type)))

  ;;
  ;; readName reads in a UTF8 string. It is used for reading the names off
  ;; of named tags.
  ;;
  (define (readName)
    ;; We need to get the length of the name. The length is stored as a
    ;; two-byte integer
    (let ([strlen (readShort)])
      (read-string strlen)))

  ;;
  ;; readCompound reads a compound tag into a list using recursion until it
  ;; hits the end of the compound tag.
  ;;
  (define (readCompound)
    (letrec ([continueCompound
               (lambda ()
                 (let ([result (readTag (read-byte))])
                   (if (null? result)
                     '()
                     (cons result (continueCompound)))))])
      (continueCompound)))

  ;;
  ;; readByte reads in a 1-byte (8-bit) integer
  ;;
  (define readByte read-byte)

  ;; 
  ;; readShort reads in a two-byte (16-bit) integer
  ;;
  (define (readShort)
    (+ (fxshl (read-byte) 8)
         (read-byte)))

  ;;
  ;; readInt reads in a 4-byte (32-bit) integer
  ;;
  (define (readInt)
    (+ (arithmetic-shift (read-byte) 24)
       (arithmetic-shift (read-byte) 16)
       (arithmetic-shift (read-byte) 8)
       (read-byte)))

  ;; 
  ;; We can't necessarily use fxshl here, because fixnum operations may only
  ;; work for 32-bit numbers.
  ;;
  (define (readLong)
    (+ (arithmetic-shift (read-byte) 56)
       (arithmetic-shift (read-byte) 48)
       (arithmetic-shift (read-byte) 40)
       (arithmetic-shift (read-byte) 32)
       (arithmetic-shift (read-byte) 24)
       (arithmetic-shift (read-byte) 16)
       (arithmetic-shift (read-byte) 8)
       (read-byte)))

  ;;
  ;; These are some unfun C routines to convert 4 int-promoted bytes to a float
  ;; by manually assembling the float using bitwise operators
  ;;
  ;; Caveat! These will only work on platforms in which floats are 32-bit Big
  ;; Endian IEEE754-2008 numbers and doubles are 64-bit Big Endian IEEE754-2008
  ;; numbers!
  ;;
  (define (readFloat)
    (let ([c-read-float
            (foreign-lambda* float
              ((int i1)
               (int i2)
               (int i3)
               (int i4))
  ;; Diagram of a 32-bit IEEE 754 float
  ;;    sign     exponent            fraction
  ;;       ||===============|=============================================|
  ;;      |_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|
  ;;      |_______________|_______________|_______________|_______________| 
  ;;
  ;; The last little *(float*)&i part taken from the q3_sqrt code :D
;              uint8_t b1 = (uint8_t) i1;
;               uint8_t b2 = (uint8_t) i2;
;               uint8_t b3 = (uint8_t) i3;
;               uint8_t b4 = (uint8_t) i4;
;
;               uint32_t i = 0;
;
;               i = b1;
;               i = (i << 8) | b2;
;               i = (i << 8) | b3;
;               i = (i << 8) | b4;
;
;               float f = *(float*)&i;
;
              " C_return(42);")])
        (let* ([i1 (read-byte)]
               [i2 (read-byte)]
               [i3 (read-byte)]
               [i4 (read-byte)])
          (c-read-float i1 i2 i3 i4))))

  (define (readDouble)
    (+ (readFloat) (readFloat)))

  ;;
  ;; This is an ugly hack to first declare pre-types, and then set! it to types
  ;; later because apparently, Chicken doesn't deal too well with internal
  ;; defines: http://paste.lisp.org/display/119362
  (define pre-types #f)

  ;;
  ;; readList reads a list tag into a list using recursion until it reaches the
  ;; end of the list, as specified by the TAG_Int length tag
  ;;
  (define (readList)
    (printf "starting readList with pre-types ~s...\n" pre-types)
    (let* ([type (read-byte)]
           [len (readInt)]
           [blah (printf "got type ~s and len ~s\n" type len)]
           ;;
           ;; typedef is a row pulled out of our type table (see below), that
           ;; takes the form:
           ;;     `(4 long ,readLong)
           ;;
           [ulbah (printf "got pre-types ~s\n" pre-types)]
           [typedef (assq type pre-types)]
           [lbah (printf "got typedef ~s\n" typedef)]
           [name (cadr typedef)]
           [reader (caddr typedef)])
      (printf "readList with typedef ~s\n" typedef)
      (letrec ([continueList
                 (lambda (n)
                   (if (= n 0)
                     '()
                     (cons `(name ,(reader))
                       (continueList (- n 1)))))])
        (continueList len))))

  ;;
  ;; A table of tag IDs, their names, and their corresponding read procedures
  ;;
  (define types `((0  end   ,(lambda () (error "TAG_End")))
                  (1  byte  ,readByte)
                  (2  short ,readShort)
                  (3  int   ,readInt)
                  (4  long  ,readLong)
                  (5  float ,readFloat)
                  (6  double ,readDouble)
                 ;(7  byte-array ,readByteArray)
                  (8  string ,readName)
                  (9  list   ,readList)
                  (10 compound ,readCompound)))

  ;;
  ;; readTag reads in a tag of the given tag type. It basically looks up the
  ;; corresponding name and procedure out of the table types (above).
  ;;
  (define (readTag type)
    (printf "Gonna read type ~s\n" type)
    ;; special case for end tag
    (if (= type 0) '()
      (let* ([typedef (assq type types)]
             [name (cadr typedef)]
             [reader (caddr typedef)])
        (printf "readTag about to launch ~s for type ~s\n" typedef type)
        `(,name ,(readName) ,(reader)))))

  ;; Make sure top-level tag is compound.
  (if (= (read-byte) 10)
    ;; kick off the NBT parsing!
    (begin
      ;; see ugly-hack note at "pre-types"
      (set! pre-types types)
      `(compound ,(readName) . ,(readCompound)))
    (begin
      (error "Top-level tag is not a compound tag!"))))

(define (last ls)
  (if (null? (cdr ls))
    (car ls)
    (last (cdr ls))))

(if (null? (command-line-arguments))
  (display "Must give path to level.dat\n")
  (main (last (command-line-arguments))))
