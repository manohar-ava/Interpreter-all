import { Identifier, LetStatement, Program, type Statement } from "./ast";
import { Lexer } from "./lexer";
import { token, type Token, type tokenType } from "./token";

export interface IParser {
  l: Lexer;
  curToken: Token;
  peekToken: Token;
  parseProgram(): Program;
  parseStatement(): Statement | undefined;
  parseLetStatement(): LetStatement | undefined;
}
export class Parser implements IParser {
  l: Lexer;
  curToken: Token;
  peekToken: Token;
  constructor(l: Lexer) {
    this.l = l;
    this.curToken = { Type: "", Literal: "" };
    this.peekToken = { Type: "", Literal: "" };
    this.nextToken();
    this.nextToken();
  }
  nextToken(): void {
    this.curToken = this.peekToken;
    this.peekToken = this.l.nextToken();
  }
  parseProgram(): Program {
    let program = new Program();
    program.Statements = [];
    while (this.curToken.Type != token.EOF) {
      const stmt = this.parseStatement();
      if (stmt != undefined) {
        program.Statements.push(stmt);
      }
      this.nextToken();
    }
    return program;
  }
  parseStatement(): Statement | undefined {
    switch (this.curToken.Type) {
      case token.LET:
        return this.parseLetStatement();
      default:
        return undefined;
    }
  }
  parseLetStatement(): LetStatement | undefined {
    let stmt = new LetStatement(this.curToken);
    if (!this.expectPeek(token.IDENT)) return undefined;
    stmt.name = new Identifier(this.curToken, this.curToken.Literal);
    if (!this.expectPeek(token.ASSIGN)) return undefined;
    while (!this.curTokenIs(token.SEMICOLON)) {
      this.nextToken();
    }
    return stmt;
  }
  curTokenIs(t: tokenType) {
    return this.curToken.Type === t;
  }
  peekTokenIs(t: tokenType) {
    return this.peekToken.Type === t;
  }
  expectPeek(t: tokenType) {
    if (this.peekTokenIs(t)) {
      this.nextToken();
      return true;
    } else {
      return false;
    }
  }
}
