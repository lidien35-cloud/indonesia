# indonesia
bahasa pemrograman bahasa indonesia.  

masih minim fitur. tapi sudah bisa membuat web di termux.
arm64.

$bison -d akar.y

$flex akar.l

gcc lex.yy.c akar.tab.c -o idn

$chmod +x idn

$./idn web.txt

