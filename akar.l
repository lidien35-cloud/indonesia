%{
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "akar.h"
#include "akar.tab.h"

#define MAX_INCLUDE_DEPTH 10
YY_BUFFER_STATE include_stack[MAX_INCLUDE_DEPTH];
int include_stack_ptr = 0;

void yyerror(char *);
%}

%option noyywrap
%option yylineno
%x STATE_IMPORT 

%%

"//".* { ; }
"/*"([^*]|\*+[^*/])*\*+"/" { ; }

"import" { BEGIN(STATE_IMPORT); }

<STATE_IMPORT>[ \t]* { ; }
<STATE_IMPORT>\"[^"]*\" { 
    char filename[100];
    memset(filename, 0, 100);
    strncpy(filename, yytext+1, strlen(yytext)-2);

    FILE *f = fopen(filename, "r");
    if (!f) {
        fprintf(stderr, "Error: Gagal import '%s'\n", filename);
        exit(1);
    }

    if (include_stack_ptr >= MAX_INCLUDE_DEPTH) {
        fprintf(stderr, "Error: Import terlalu dalam.\n");
        exit(1);
    }
    include_stack[include_stack_ptr++] = YY_CURRENT_BUFFER;
    yy_switch_to_buffer(yy_create_buffer(f, YY_BUF_SIZE));
    BEGIN(INITIAL);
}
<STATE_IMPORT>; { BEGIN(INITIAL); }

<<EOF>> {
    if (include_stack_ptr > 0) {
        --include_stack_ptr;
        yy_delete_buffer(YY_CURRENT_BUFFER);
        yy_switch_to_buffer(include_stack[include_stack_ptr]);
    } else {
        yyterminate();
    }
}

0           { yylval.iValue = atoi(yytext); return ANGKA; }
[1-9][0-9]* { yylval.iValue = atoi(yytext); return ANGKA; }

\"[^"]*\"   { 
              yytext[strlen(yytext)-1] = 0; 
              yylval.sIndex = strdup(yytext+1); 
              return TEXT; 
            }

"sistem"    { return SISTEM; }
"acak"      { return ACAK; }
"server"    { return SERVER; }
"terima"    { return TERIMA; }
"kirim"     { return KIRIM; }
"sajikan"   { return SAJIKAN; }
"tutup"     { return TUTUP; }
"tulis"     { return TULIS; }
"baca"      { return BACA; }
"jika"      { return JIKA; }
"maka"      { return MAKA; }
"lainnya"   { return LAINNYA; }
"selama"    { return SELAMA; }
"lakukan"   { return LAKUKAN; }
"adalah"    { return ADALAH; }

[a-zA-Z][a-zA-Z0-9_]* { yylval.sIndex = strdup(yytext); return VARIABEL; }

"<"         { return KURANG_DARI; }
">"         { return LEBIH_DARI; }
"=="        { return SAMA; }
"!="        { return BEDA; } 
"="         { return ADALAH; }

[ \t\n]+    ;
[-+*/%;(){}] { return *yytext; }

.           { yyerror("Karakter tidak dikenal"); }

%%
