import type { Token, tokenType } from "./token";
import { getIdentifiers, token } from "./token";

export class Lexer {
  input: string = "";
  position: number = 0;
  readPosition: number = 0;
  ch: string = "";
  constructor(input: string) {
    this.input = input;
    this.readChar();
  }
  readChar() {
    if (this.readPosition >= this.input.length) {
      this.ch = "\0";
    } else {
      this.ch = this.input[this.readPosition];
    }
    this.position = this.readPosition;
    this.readPosition += 1;
  }
  newToken(tokenType: tokenType, ch: string): Token {
    return { Type: tokenType, Literal: ch };
  }
  nextToken(): Token {
    let tok: Token = { Type: "", Literal: "" };
    this.skipWhitespace();
    switch (this.ch) {
      case "=":
        if (this.peek() == "=") {
          let ch = this.ch;
          this.readChar();
          tok = this.newToken(token.EQ, ch + this.ch);
        } else {
          tok = this.newToken(token.ASSIGN, this.ch);
        }
        break;
      case "+":
        tok = this.newToken(token.PLUS, this.ch);
        break;
      case "-":
        tok = this.newToken(token.MINUS, this.ch);
        break;
      case "!":
        if (this.peek() === "=") {
          let ch = this.ch;
          this.readChar();
          tok = this.newToken(token.NOT_EQ, ch + this.ch);
        } else {
          tok = this.newToken(token.BANG, this.ch);
        }
        break;
      case "/":
        tok = this.newToken(token.SLASH, this.ch);
        break;
      case "%":
        tok = this.newToken(token.MOD, this.ch);
        break;
      case "*":
        tok = this.newToken(token.ASTERISK, this.ch);
        break;
      case ">":
        tok = this.newToken(token.GT, this.ch);
        break;
      case "<":
        tok = this.newToken(token.LT, this.ch);
        break;
      case ";":
        tok = this.newToken(token.SEMICOLON, this.ch);
        break;
      case "(":
        tok = this.newToken(token.LPAREN, this.ch);
        break;
      case ")":
        tok = this.newToken(token.RPAREN, this.ch);
        break;
      case "{":
        tok = this.newToken(token.LBRACE, this.ch);
        break;
      case "}":
        tok = this.newToken(token.RBRACE, this.ch);
        break;
      case ",":
        tok = this.newToken(token.COMMA, this.ch);
        break;
      case "\0":
        tok = { Type: token.EOF, Literal: "\0" };
        break;
      default:
        if (this.isLetter(this.ch)) {
          tok.Literal = this.readIdentifier();
          tok.Type = getIdentifiers(tok.Literal);
          return tok;
        } else if (this.isDigit(this.ch)) {
          tok.Type = token.INT;
          tok.Literal = this.readNumber();
          return tok;
        } else {
          console.log("Invalid token");
          tok = this.newToken(token.ILLEGAL, this.ch);
        }
    }
    this.readChar();
    return tok;
  }
  isLetter(ch: string): boolean {
    const cc = ch.charCodeAt(0);
    return (cc > 64 && cc < 91) || (cc > 96 && cc < 123) || cc === 95;
  }
  isDigit(ch: string): boolean {
    const num: number = Number.parseInt(ch);
    return num >= 0 && num <= 9;
  }
  readIdentifier(): string {
    const pos = this.position;
    while (this.isLetter(this.ch)) {
      this.readChar();
    }
    return this.input.slice(pos, this.position);
  }
  readNumber(): string {
    const pos = this.position;
    while (this.isDigit(this.ch)) {
      this.readChar();
    }
    return this.input.slice(pos, this.position);
  }
  skipWhitespace() {
    while (
      this.ch === " " ||
      this.ch === "\t" ||
      this.ch === "\n" ||
      this.ch === "\r"
    ) {
      this.readChar();
    }
  }
  peek(): string {
    if (this.readPosition >= this.input.length) return "";
    else return this.input[this.readPosition];
  }
}
