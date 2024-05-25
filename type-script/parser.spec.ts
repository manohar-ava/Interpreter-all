import { expect, test } from "bun:test";
import { Lexer } from "./lexer";
import { Parser } from "./parser";
import { LetStatement, type Statement } from "./ast";
test("Test: let statements", () => {
  let input = `
let x = 5;
let y = 10;
let foobar = 838383;
`;
  let l = new Lexer(input);
  let p = new Parser(l);
  let program = p.parseProgram();
  if (program == undefined) {
    throw new Error("parseProgram() returned undefined");
  }
  if (program.Statements.length != 3) {
    throw new Error(
      `program.statements does not contain 3 statements. got ${program.Statements.length}`,
    );
  }
  const tests: string[] = ["x", "y", "foobar"];
  for (let i = 0; i < tests.length; i++) {
    const stmt = program.Statements[i];
    if (!testLetStatement(stmt, tests[i])) {
      return;
    }
  }
});

function testLetStatement(s: Statement, name: string): boolean {
  console.log(s, name);
  if (s.TokenLiteral() != "let") {
    throw new Error(`s.TokenLiteral not 'let'. got ${s.TokenLiteral()}`);
  }
  const letStmt = s;
  if (letStmt.name.value != name) {
    throw new Error(
      `letStmt.Name.Value not '${name}'. got=${letStmt.name.value}`,
    );
  }
  if (letStmt.name.TokenLiteral() != name) {
    throw new Error(`s.Name not '${name}'. got=${letStmt.name}`);
  }
  return true;
}
