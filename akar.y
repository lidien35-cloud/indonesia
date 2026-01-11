%{
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include "akar.h"

int server_fd, new_socket;
struct sockaddr_in address;
int addrlen = sizeof(address);
char request_buffer[3000];

/* Symbol Table */
struct Symbol { char *name; int type; int valInt; char *valStr; };
struct Symbol table[100];
int tableSize = 0;

int yylex(void);
void yyerror(char *s);
int ex(nodeType *p);

/* Nodes */
nodeType *con(int value);
nodeType *str(char *value);
nodeType *id(char *name);
nodeType *opr(int oper, int nops, ...);
void freeNode(nodeType *p);

/* Helper Vars */
void setValStr(char *name, char *val) {
    for(int i=0; i<tableSize; i++) {
        if(strcmp(table[i].name, name) == 0) { 
            table[i].type = 1; if(table[i].valStr) free(table[i].valStr);
            table[i].valStr = strdup(val); return; 
        }
    }
    table[tableSize].name = strdup(name); table[tableSize].type = 1; table[tableSize].valStr = strdup(val); tableSize++;
}
char* getValStr(char *name) {
    for(int i=0; i<tableSize; i++) if(strcmp(table[i].name, name)==0 && table[i].type==1) return table[i].valStr; return "";
}
void setValInt(char *name, int val) {
    for(int i=0; i<tableSize; i++) {
        if(strcmp(table[i].name, name) == 0) { table[i].type = 0; table[i].valInt = val; return; }
    }
    table[tableSize].name = strdup(name); table[tableSize].type = 0; table[tableSize].valInt = val; tableSize++;
}
int getValInt(char *name) {
    for(int i=0; i<tableSize; i++) if(strcmp(table[i].name, name)==0) return table[i].valInt; return 0;
}
%}

%union { int iValue; char *sIndex; nodeType *nPtr; };

%token <iValue> ANGKA
%token <sIndex> VARIABEL TEXT
%token TULIS BACA JIKA MAKA LAINNYA SELAMA LAKUKAN ADALAH
%token SERVER TERIMA KIRIM SAJIKAN TUTUP SISTEM ACAK

/* OPERATOR PRECEDENCE (Sangat Penting untuk Menghilangkan Conflict) */
%left SAMA BEDA LEBIH_DARI KURANG_DARI
%left '+' '-'
%left '*' '/' '%'
%nonassoc UMINUS

%type <nPtr> stmt expr stmt_list block

%%

program:
    function { exit(0); }
    ;

function:
    function stmt { ex($2); freeNode($2); }
    | /* NULL */
    ;

/* Blok kode { ... } */
block:
    '{' stmt_list '}' { $$ = $2; }
    ;

/* Daftar Statement */
stmt_list:
    stmt              { $$ = $1; }
    | stmt_list stmt  { $$ = opr(';', 2, $1, $2); }
    ;

/* Statement Tunggal */
stmt:
    ';'                            { $$ = opr(';', 2, NULL, NULL); }
    | TULIS '(' expr ')' ';'       { $$ = opr(TULIS, 1, $3); }
    | BACA '(' VARIABEL ')' ';'    { $$ = opr(BACA, 1, id($3)); }
    | SISTEM '(' expr ')' ';'      { $$ = opr(SISTEM, 1, $3); }
    | VARIABEL ADALAH expr ';'     { $$ = opr(ADALAH, 2, id($1), $3); }
    
    | SELAMA '(' expr ')' LAKUKAN block { $$ = opr(SELAMA, 2, $3, $6); }
    
    | JIKA '(' expr ')' MAKA block  { $$ = opr(JIKA, 2, $3, $6); }
    | JIKA '(' expr ')' MAKA block LAINNYA block { $$ = opr(JIKA, 3, $3, $6, $8); }
    
    | SERVER '(' expr ')' ';'      { $$ = opr(SERVER, 1, $3); }
    | TERIMA '(' ')' ';'           { $$ = opr(TERIMA, 0); }
    | KIRIM '(' expr ')' ';'       { $$ = opr(KIRIM, 1, $3); } 
    | SAJIKAN '(' expr ')' ';'     { $$ = opr(SAJIKAN, 1, $3); }
    | TUTUP '(' ')' ';'            { $$ = opr(TUTUP, 0); }
    ;

expr:
    ANGKA                 { $$ = con($1); }
    | TEXT                { $$ = str($1); }
    | VARIABEL            { $$ = id($1); }
    | ACAK '(' expr ')'   { $$ = opr(ACAK, 1, $3); }
    | '-' expr %prec UMINUS { $$ = opr(UMINUS, 1, $2); }
    | expr '+' expr       { $$ = opr('+', 2, $1, $3); }
    | expr '-' expr       { $$ = opr('-', 2, $1, $3); }
    | expr '*' expr       { $$ = opr('*', 2, $1, $3); }
    | expr '/' expr       { $$ = opr('/', 2, $1, $3); }
    | expr '%' expr       { $$ = opr('%', 2, $1, $3); }
    | expr SAMA expr      { $$ = opr(SAMA, 2, $1, $3); }
    | expr BEDA expr      { $$ = opr(BEDA, 2, $1, $3); }
    | expr LEBIH_DARI expr { $$ = opr(LEBIH_DARI, 2, $1, $3); }
    | expr KURANG_DARI expr { $$ = opr(KURANG_DARI, 2, $1, $3); }
    | '(' expr ')'        { $$ = $2; }
    ;

%%

nodeType *con(int value) { nodeType *p = malloc(sizeof(nodeType)); p->type = typeCon; p->con.value = value; return p; }
nodeType *str(char *value) { nodeType *p = malloc(sizeof(nodeType)); p->type = typeStr; p->str.value = strdup(value); return p; }
nodeType *id(char *name) { nodeType *p = malloc(sizeof(nodeType)); p->type = typeId; p->id.name = strdup(name); return p; }
nodeType *opr(int oper, int nops, ...) {
    va_list ap; nodeType *p = malloc(sizeof(nodeType));
    p->opr.op = malloc(nops * sizeof(nodeType *));
    p->type = typeOpr; p->opr.oper = oper; p->opr.nops = nops;
    va_start(ap, nops); for (int i = 0; i < nops; i++) p->opr.op[i] = va_arg(ap, nodeType*);
    va_end(ap); return p;
}
void freeNode(nodeType *p) { if(p) free(p); }

int ex(nodeType *p) {
    if (!p) return 0;
    switch(p->type) {
        case typeCon: return p->con.value;
        case typeStr: return 0;
        case typeId:  return getValInt(p->id.name);
        case typeOpr:
            switch(p->opr.oper) {
                case SELAMA: while(ex(p->opr.op[0])) ex(p->opr.op[1]); return 0;
                case JIKA:   if(ex(p->opr.op[0])) ex(p->opr.op[1]); else if(p->opr.nops > 2) ex(p->opr.op[2]); return 0;
                case TULIS: 
                    if(p->opr.op[0]->type == typeStr) printf("%s\n", p->opr.op[0]->str.value);
                    else if(p->opr.op[0]->type == typeId) {
                        char *s = getValStr(p->opr.op[0]->id.name);
                        if(strlen(s)>0) printf("%s\n", s); else printf("%d\n", getValInt(p->opr.op[0]->id.name));
                    } else printf("%d\n", ex(p->opr.op[0])); return 0;
                case BACA: {
                    char buf[256]; printf("Input: ");
                    if (fgets(buf, 256, stdin)) {
                        int v = atoi(buf);
                        if(v==0 && buf[0]!='0') { buf[strcspn(buf,"\n")]=0; setValStr(p->opr.op[0]->id.name, buf); }
                        else setValInt(p->opr.op[0]->id.name, v);
                    } return 0;
                }
                case SISTEM: { char *c = (p->opr.op[0]->type==typeStr)? p->opr.op[0]->str.value : getValStr(p->opr.op[0]->id.name); system(c); return 0; }
                case ACAK: return rand() % ex(p->opr.op[0]);
                case ';': ex(p->opr.op[0]); return ex(p->opr.op[1]);
                case ADALAH: if(p->opr.op[1]->type == typeStr) setValStr(p->opr.op[0]->id.name, p->opr.op[1]->str.value); else setValInt(p->opr.op[0]->id.name, ex(p->opr.op[1])); return 0;
                
                /* SERVER */
                case SERVER: {
                     int port = ex(p->opr.op[0]); printf("Server Port: %d\n", port);
                     if ((server_fd = socket(AF_INET, SOCK_STREAM, 0)) == 0) exit(1);
                     int opt = 1; setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
                     address.sin_family = AF_INET; address.sin_addr.s_addr = INADDR_ANY; address.sin_port = htons(port);
                     bind(server_fd, (struct sockaddr *)&address, sizeof(address)); listen(server_fd, 3); return 0;
                }
                case TERIMA: if ((new_socket = accept(server_fd, (struct sockaddr *)&address, (socklen_t*)&addrlen)) < 0) exit(1); read(new_socket, request_buffer, 3000); return 0;
                case SAJIKAN: {
                     char *f = (p->opr.op[0]->type==typeStr)? p->opr.op[0]->str.value : getValStr(p->opr.op[0]->id.name);
                     FILE *fp = fopen(f, "rb");
                     if(fp) { fseek(fp,0,SEEK_END); long s=ftell(fp); fseek(fp,0,SEEK_SET); char *b=malloc(s+1); fread(b,1,s,fp); fclose(fp); char h[256]; sprintf(h,"HTTP/1.1 200 OK\nContent-Length: %ld\n\n",s); write(new_socket,h,strlen(h)); write(new_socket,b,s); free(b); }
                     else { char *m="HTTP/1.1 404\n\nNot Found"; write(new_socket,m,strlen(m)); } return 0;
                }
                case KIRIM: { char h[512]; sprintf(h,"HTTP/1.1 200 OK\n\n%s", p->opr.op[0]->str.value); write(new_socket,h,strlen(h)); return 0; }
                case TUTUP: close(new_socket); return 0;

                /* MATH */
                case UMINUS: return -ex(p->opr.op[0]);
                case '+': return ex(p->opr.op[0]) + ex(p->opr.op[1]);
                case '-': return ex(p->opr.op[0]) - ex(p->opr.op[1]);
                case '*': return ex(p->opr.op[0]) * ex(p->opr.op[1]);
                case '/': return ex(p->opr.op[0]) / ex(p->opr.op[1]);
                case '%': return ex(p->opr.op[0]) % ex(p->opr.op[1]);
                case SAMA: return ex(p->opr.op[0]) == ex(p->opr.op[1]);
                case BEDA: return ex(p->opr.op[0]) != ex(p->opr.op[1]);
                case LEBIH_DARI: return ex(p->opr.op[0]) > ex(p->opr.op[1]);
                case KURANG_DARI: return ex(p->opr.op[0]) < ex(p->opr.op[1]);
            }
    }
    return 0;
}

void yyerror(char *s) { fprintf(stderr, "Error Baris %d: %s\n", yylineno, s); }
int main(int argc, char **argv) {
    srand(time(NULL));
    extern FILE* yyin;
    if (argc == 2) {
        yyin = fopen(argv[1], "r");
        if (!yyin) { perror("File Error"); return 1; }
    } else {
        printf("Gunakan: ./akar <namafile.txt>\n");
        return 1;
    }
    yyparse();
    return 0;
}
