import { Lexer } from "./lexer";
import { token } from "./token";

export const Start = async () => {
  process.stdout.write(">> ");
  for await (const chunk of Bun.stdin.stream()) {
    const chunkText = Buffer.from(chunk).toString();
    const l = new Lexer(chunkText);
    let tok = l.nextToken();
    while (tok.Type !== token.EOF) {
      console.log(tok);
      tok = l.nextToken();
    }
    process.stdout.write(">> ");
  }
};
