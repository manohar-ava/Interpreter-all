import { Start } from "./repl";
import { userInfo } from "os";
const userName: string = userInfo().username;
const welcomeMessage = `Hello there! welcome ${userName}.\n`;
process.stdout.write(welcomeMessage);
process.stdout.write(`
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@         @@@        @@@  @@@@@  @@@       @@@@@
@@@@@@@@@@  @@@@@@@@@@@@@@   @@@  @@@  @@@@@   @@@
@@@        @@@@        @@@@   @  @@@  @@@@@@@  @@@
@@@  @@@  @@@@@@@@@@@@@@@@@@  @ @@@@@  @@@@@   @@@
@@@  @@@@   @@@        @@@@@@  @@@@@@@       @@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

`);
Start();
