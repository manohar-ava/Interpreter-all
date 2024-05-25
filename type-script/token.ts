export type tokenType = string;

export type Token = {
  Type: tokenType;
  Literal: string;
};

export const token = {
  ILLEGAL: "ILLEGAL",
  EOF: "EOF",

  //identifiers + literals

  IDENT: "IDENT",
  INT: "INT",

  //Operators

  ASSIGN: "=",
  PLUS: "+",
  MINUS: "-",
  BANG: "!",
  ASTERISK: "*",
  SLASH: "/",
  LT: "<",
  GT: ">",
  MOD: "%",
  EQ: "==",
  NOT_EQ: "!=",

  // Delimiters

  COMMA: ",",
  SEMICOLON: ";",

  LPAREN: "(",
  RPAREN: ")",
  LBRACE: "{",
  RBRACE: "}",

  // keywords

  FUNCTION: "FUNCTION",
  LET: "LET",
  RETURN: "RETURN",
  TRUE: "TRUE",
  FALSE: "FALSE",
  IF: "IF",
  ELSE: "ELSE",
};

const keywords: Map<string, string> = new Map([
  ["fn", token.FUNCTION],
  ["let", token.LET],
  ["return", token.RETURN],
  ["true", token.TRUE],
  ["false", token.FALSE],
  ["if", token.IF],
  ["else", token.ELSE],
]);

export function getIdentifiers(ident: string): string {
  return keywords.get(ident) || token.IDENT;
}
