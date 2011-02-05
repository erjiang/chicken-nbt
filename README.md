# chicken-nbt

An Named Binary Tag (Minecraft) format parser.  Chicken-NBT reads in a gzipped NBT file and returns an S-expression representation of that data.

## Example

The bigtest.nbt that Notch provides is formatted by him like this:

    TAG_Compound("Level"): 11 entries
    {
       TAG_Short("shortTest"): 32767
       TAG_Long("longTest"): 9223372036854775807
       TAG_Float("floatTest"): 0.49823147
       TAG_String("stringTest"): HELLO WORLD THIS IS A TEST STRING ÅÄÖ!
       TAG_Int("intTest"): 2147483647
       TAG_Compound("nested compound test"): 2 entries
       {
          TAG_Compound("ham"): 2 entries
          {
             TAG_String("name"): Hampus
             TAG_Float("value"): 0.75
          }
          TAG_Compound("egg"): 2 entries
          {
             TAG_String("name"): Eggbert
             TAG_Float("value"): 0.5
          }
       }
       TAG_List("listTest (long)"): 5 entries of type TAG_Long
       {
          TAG_Long: 11
          TAG_Long: 12
          TAG_Long: 13
          TAG_Long: 14
          TAG_Long: 15
       }
       TAG_Byte("byteTest"): 127
       TAG_List("listTest (compound)"): 2 entries of type TAG_Compound
       {
          TAG_Compound: 2 entries
          {
             TAG_String("name"): Compound tag #0
             TAG_Long("created-on"): 1264099775885
          }
          TAG_Compound: 2 entries
          {
             TAG_String("name"): Compound tag #1
             TAG_Long("created-on"): 1264099775885
          }
       }
       TAG_Byte_Array("byteArrayTest (the first 1000 values of (n*n*255+n*7)%100, starting with n=0 (0, 62, 34, 16, 8, ...))"): [1000 bytes]
       TAG_Double("doubleTest"): 0.4931287132182315
    }

The data structure, as parsed by chicken-nbt, looks like:

    (compound
      "Level"
      (long "longTest" 9223372036854775807)
      (short "shortTest" 32767)
      (string "stringTest" "HELLO WORLD THIS IS A TEST STRING ÅÄÖ!")
      (float "floatTest" 0.498231470584869)
      (int "intTest" 2147483647)
      (compound
        "nested compound test"
        ((compound "ham" ((string "name" "Hampus") (float "value" 0.75)))
         (compound "egg" ((string "name" "Eggbert") (float "value" 0.5)))))
      (list "listTest (long)" #((name 11) (name 12) (name 13) (name 14) (name 15)))
      (list "listTest (compound)"
            #((name ((string "name" "Compound tag #0")
                     (long "created-on" 1264099775885)))
              (name ((string "name" "Compound tag #1")
                     (long "created-on" 1264099775885)))))
      (byte "byteTest" 127)
      (byte-array
        "byteArrayTest (the first 1000 values of (n*n*255+n*7)%100, starting with n=0 (0, 62, 34, 16, 8, ...))"
        #(0 62 34 ...))
      (double "doubleTest" 0.493128713218231))

## License

GPLv3

## Author

Eric Jiang, erjiang at indiana.edu
