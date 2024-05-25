import type { Token } from "./token";

interface Node {
  TokenLiteral(): string;
}
export interface Statement extends Node {
  statementNode(): void;
}
export interface Expression extends Node {
  expressionNode(): void;
}

export interface IProgram {
  Statements: Statement[];
  TokenLiteral(): string;
}

export class Program implements IProgram {
  Statements: Statement[];
  constructor() {
    this.Statements = [];
  }
  TokenLiteral(): string {
    if (this.Statements.length) {
      return this.Statements[0].TokenLiteral();
    } else {
      return "";
    }
  }
}

export class LetStatement implements Statement {
  token: Token;
  name: Identifier;
  value: Expression;

  constructor(token: Token, name: Identifier, value: Expression) {
    this.token = token;
    this.name = name;
    this.value = value;
  }

  statementNode(): void {}

  TokenLiteral(): string {
    return this.token.Literal;
  }
}

export class Identifier implements Expression {
  token: Token;
  value: string;

  constructor(token: Token, value: string) {
    this.token = token;
    this.value = value;
  }

  expressionNode(): void {}

  TokenLiteral(): string {
    return this.token.Literal;
  }
}
