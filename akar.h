#ifndef AKAR_H
#define AKAR_H

typedef enum { 
    typeCon, typeStr, typeId, typeOpr 
} nodeEnum;

typedef struct { int value; } conNodeType;
typedef struct { char *value; } strNodeType;
typedef struct { char *name; } idNodeType;
typedef struct { 
    int oper; 
    int nops; 
    struct nodeTypeTag **op; 
} oprNodeType;

typedef struct nodeTypeTag {
    nodeEnum type;
    union {
        conNodeType con;
        strNodeType str;
        idNodeType id;
        oprNodeType opr;
    };
} nodeType;

extern int yylineno; 
#endif
