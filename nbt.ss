;;
;; chicken-nbt
;; ===================
;;
;; A Minecraft NBT reader
;; -------------------
;;
;; Source code written for Chicken Scheme, requiring certain eggs
;; 
;;

;;
;; This file provides the "nbt" module, which exports "nbt:read"
;; and "nbt:read-uncompressed".
;;
(module nbt (nbt:read nbt:read-uncompressed)

;;
;; Requirements
;; ------------
;;
(import scheme chicken foreign extras)

;;
;; The *z3* egg is needed for gzip support
;;
(require-extension z3)

;;
;; The *numbers* module is needed for dealing with long integers
;;
(use numbers)

;;
;; *SRFI 4* is used for u8vectors
;;
(use srfi-4)

;;
;; nbt:read
;; --------
;;
;; **nbt:read** is a wrapper around do-readNBT that reads in a gzipped NBT file.
;; We first open a special z3 input port that uncompresses the data on the fly,
;; and then we let the current-input-port be that z3 port for the NBT-reading
;; phase.
;;
(define (nbt:read filename)
  (let ([in (z3:open-compressed-input-file filename)])
    (parameterize ([current-input-port in])
      (do-readNBT))))

;;
;; nbt:read-uncompressed
;; ---------------------
;;
;; **nbt:read-uncompressed** is a wrapper around do-readNBT that, well, reads an
;; uncompressed NBT file.
;;
(define (nbt:read-uncompressed filename)
  (with-input-from-file filename do-readNBT))

;;
;; do-readNBT
;; ----------
;;
;; **do-readNBT** reads in the NBT file and returns a list representing that
;; NBT file structure.
;;
;; Compound tags are represented as lists:
;;
;;     (tag-name (tag1 tag2 tag3 ...))
;;
;; While tag lists (which are fixed-length and single-type only) are
;; vectors:
;;
;;     #(tag1 tag2 tag3 ...)
;;
(define (do-readNBT)

  ;;
  ;; **readName** reads in a UTF8 string. It is used for reading the names off
  ;; of named tags.
  ;;
  ;; *Note that importing utf8.egg will actually break this procedure!*
  ;; The length of the string is defined as exactly how many *bytes* long the
  ;; string is, NOT how many utf8 chars long it is.
  ;;
  (define (readName)
    ;; We need to get the length of the name. The length is stored as a
    ;; two-byte integer
    (let ([strlen (readShort)])
      (read-string strlen)))

  ;;
  ;; **readCompound** reads a compound tag into a list using recursion until it
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
  ;; **readByte** reads in a 1-byte (8-bit) *signed* integer
  ;;
  (define (readByte)
    (let ([val (read-byte)])
      (if (>= val 128)
        (- val 256)
        val)))

  ;; 
  ;; **readShort** reads in a two-byte (16-bit) integer
  ;;
  (define (readShort)
    (let ([val (+ (fxshl (read-byte) 8)
                  (read-byte))])
      ;; account for signed value
      (if (> val 32767)
        (- val 65536)
        val)))

  ;;
  ;; readInt reads in a 4-byte (32-bit) integer
  ;;
  (define (readInt)
    (let ([val (+ (arithmetic-shift (read-byte) 24)
       (arithmetic-shift (read-byte) 16)
       (arithmetic-shift (read-byte) 8)
       (read-byte))])
      ;; account for signed integer
      (if (>= val (expt 2 31))
        (- val (expt 2 32))
        val)))

  ;; 
  ;; We can't necessarily use fxshl here, because fixnum operations may only
  ;; work for 32-bit numbers.  Additionally, csc bignums (via "numbers") doesn't
  ;; seem to like subtracting big immediates, so we branch depending on whether
  ;; the first byte indicates that the whole number is positive or negative.
  ;;
  (define (readLong)
    (let ([first-byte (read-byte)])
      (if (>= first-byte 128)
        ;; we cannot literally write -2^63 because it's big
        (+ (- (expt 2 63))
           (arithmetic-shift (- first-byte 128) 56)
           (arithmetic-shift (read-byte) 48)
           (arithmetic-shift (read-byte) 40)
           (arithmetic-shift (read-byte) 32)
           (arithmetic-shift (read-byte) 24)
           (arithmetic-shift (read-byte) 16)
           (arithmetic-shift (read-byte) 8)
           (read-byte))
        (+ (arithmetic-shift first-byte  56)
           (arithmetic-shift (read-byte) 48)
           (arithmetic-shift (read-byte) 40)
           (arithmetic-shift (read-byte) 32)
           (arithmetic-shift (read-byte) 24)
           (arithmetic-shift (read-byte) 16)
           (arithmetic-shift (read-byte) 8)
           (read-byte)))))

  ;;
  ;; **readFloat** reads in a 32-bit Big Endian IEEE 754 float.
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
  ;;
  ;;     sign   exponent            fraction
  ;;       ||===============|=============================================|
  ;;      |_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|
  ;;      |______b1_______|______b2_______|______b3_______|______b4_______| 
  ;;
  ;; The last little \*(float\*)&i part taken from the q3_sqrt code.
               "uint8_t b1 = (uint8_t) i1;
                uint8_t b2 = (uint8_t) i2;
                uint8_t b3 = (uint8_t) i3;
                uint8_t b4 = (uint8_t) i4;
 
                uint32_t i = 0;
 
                i = b1;
                i = (i << 8) | b2;
                i = (i << 8) | b3;
                i = (i << 8) | b4;
 
                float f = *(float*)&i;
 
                C_return(f);")])
        (let* ([i1 (read-byte)]
               [i2 (read-byte)]
               [i3 (read-byte)]
               [i4 (read-byte)])
          (c-read-float i1 i2 i3 i4))))

  ;;
  ;; **readDouble**: See comments at **readFloat**
  ;;
  (define (readDouble)
    (let ([c-read-double
            (foreign-lambda* double
              ((int i1)
               (int i2)
               (int i3)
               (int i4)
               (int i5)
               (int i6)
               (int i7)
               (int i8))
               "uint8_t b1 = (uint8_t) i1;
                uint8_t b2 = (uint8_t) i2;
                uint8_t b3 = (uint8_t) i3;
                uint8_t b4 = (uint8_t) i4;
                uint8_t b5 = (uint8_t) i5;
                uint8_t b6 = (uint8_t) i6;
                uint8_t b7 = (uint8_t) i7;
                uint8_t b8 = (uint8_t) i8;
 
                uint64_t i = 0;
 
                i = b1;
                i = (i << 8) | b2;
                i = (i << 8) | b3;
                i = (i << 8) | b4;
                i = (i << 8) | b5;
                i = (i << 8) | b6;
                i = (i << 8) | b7;
                i = (i << 8) | b8;
 
                double d = *(double*)&i;
 
                C_return(d);")])
        (let* ([i1 (read-byte)]
               [i2 (read-byte)]
               [i3 (read-byte)]
               [i4 (read-byte)]
               [i5 (read-byte)]
               [i6 (read-byte)]
               [i7 (read-byte)]
               [i8 (read-byte)])
          (c-read-double i1 i2 i3 i4 i5 i6 i7 i8))))

  ;; **readByteArray** reads in a `TAG_Byte_Array` and returns a vector of
  ;; numbers representing that byte array.  Note that, since Chicken promotes
  ;; all read bytes into ints that the resulting vector will take up 4--8 times
  ;; as much memory as it did in the original file format.
  (define (readByteArray)
    ;; `TAG_Byte_Array` comes with an Integer length specification
    (let* ([len (readInt)]
           [bytevec (make-u8vector len)])
      (letrec ([continueByteArray
                 (lambda (i)
                   (if (= i len)
                     (void) ;; end of vector
                     (begin
                       ;; remember that readByte reads *signed* bytes, and
                       ;; read-byte reads *unsigned* bytes. Since we're using a
                       ;; u8vector (and not an s8vector), we need unsigned
                       ;; bytes
                       (u8vector-set! bytevec i (read-byte))
                       (continueByteArray (+ 1 i)))))])
        (begin
          (continueByteArray 0)
          bytevec))))

  ;;
  ;; This is an ugly hack to first declare pre-types, and then set! it to types
  ;; later because apparently, Chicken doesn't deal too well with internal
  ;; defines: http://paste.lisp.org/display/119362 and
  ;; http://lists.nongnu.org/archive/html/chicken-users/2011-02/msg00011.html
  (define pre-types #f)

  ;;
  ;; **readList** reads a list tag into a vector using recursion until it
  ;; reaches the end of the list, as specified by the `TAG_Int` length tag.
  ;;
  ;; Why are NBT lists represented as vectors here? NBT defines them to be
  ;; fixed-length, single-type structures (unlike `TAG_Compound`), so it's clear
  ;; that they're not like linked lists, but instead like arrays.
  ;;
  (define (readList)
    (let* ([type (read-byte)]
           [len (readInt)]
           [vec (make-vector len)]
           ;;
           ;; `typedef` is a row pulled out of our type table (see below), that
           ;; takes the form:
           ;;     `(4 long ,readLong)
           ;;
           [typedef (assq type pre-types)]
           [name (cadr typedef)]
           [reader (caddr typedef)])
      (letrec ([continueList
                 (lambda (i)
                   (if (= i len)
                     (void)
                     (begin
                       (vector-set! vec i `(,name ,(reader)))
                       (continueList (+ i 1)))))])
        (begin
          (continueList 0)
          vec))))

  ;;
  ;; **types**: A table of tag IDs, their names, and their corresponding read
  ;; procedures
  ;;
  (define types `((0  end   ,(lambda () (error "TAG_End")))
                  (1  byte  ,readByte)
                  (2  short ,readShort)
                  (3  int   ,readInt)
                  (4  long  ,readLong)
                  (5  float ,readFloat)
                  (6  double ,readDouble)
                  (7  byte-array ,readByteArray)
                  (8  string ,readName)
                  (9  list   ,readList)
                  (10 compound ,readCompound)))

  ;;
  ;; **readTag** reads in a tag of the given tag type. It basically looks up
  ;; thecorresponding name and procedure out of the table types (above).
  ;;
  (define (readTag type)
    ;; special case for end tag
    (if (= type 0) '()
      (let* ([typedef (assq type types)]
             [name (cadr typedef)]
             [reader (caddr typedef)])
        `(,name ,(readName) ,(reader)))))

  ;; Make sure top-level tag is compound.
  (if (= (read-byte) 10)
    ;;
    ;; **Kick off the NBT parsing!**
    ;;
    (begin
      ;; see ugly-hack note at "pre-types"
      (set! pre-types types)
      `(compound ,(readName) ,(readCompound)))
    (begin
      (error "Top-level tag is not a compound tag!"))))

;; End
;; ---
)
;; This concludes the module `nbt`.
