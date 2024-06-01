import { expect, test } from "bun:test";
import { Lexer } from "./lexer";
import { Parser } from "./parser";
import { LetStatement, type Statement } from "./ast";
console.log("hello")
function checkParserErrors(p) {
  const errors = p.errors;
  if (!errors.length) return;
  for (const err of errors) {
    console.log("parser error: " + err);
  }
  throw new Error(`parser has ${errors.length} errors`);
}

test("Test: let statements", () => {
  let input = `
let x = 5;
let y = 10;
let foobar = 838383;
`;
  let l = new Lexer(input);
  let p = new Parser(l);
  let program = p.parseProgram();
  checkParserErrors(p);
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
test("Test: return statements", () => {
  let input = `
return 5;
return 10;
return 993322;
`;
  let l = new Lexer(input);
  let p = new Parser(l);
  let program = p.parseProgram();
  checkParserErrors(p);
  if (program == undefined) {
    throw new Error("parseProgram() returned undefined");
  }
  if (program.Statements.length != 3) {
    throw new Error(
      `program.statements does not contain 3 statements. got ${program.Statements.length}`,
    );
  }
  for (const stmt of program.Statements) {
    if (stmt.TokenLiteral() != "return") {
      throw new Error(
        `returnStmt.TokenLiteral not 'return', got ${stmt.TokenLiteral()}`,
      );
    }
  }
});

test("Test: let statements", () => {
  let input = `
let x = 5;
let y = 10;
let foobar = 838383;
`;
  let l = new Lexer(input);
  let p = new Parser(l);
  let program = p.parseProgram();
  checkParserErrors(p);
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

test.skip("Test: parser error statements", () => {
  let input = `
let x 5;
let = 10;
let 838383;
`;
  let l = new Lexer(input);
  let p = new Parser(l);
  let program = p.parseProgram();
  checkParserErrors(p);
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
