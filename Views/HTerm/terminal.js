hterm.defaultStorage = new lib.Storage.Memory();

function sendInputMessage(str) {
    const handler = window.webkit.messageHandlers.UTMSendInput;
    handler.postMessage(str);
}

function writeData(data) {
    const term = window.term;
    const str = new TextDecoder().decode(data);
    term.interpret(str);
}

function terminalSetup() {
    const term = new hterm.Terminal();
    term.onTerminalReady = function() {
        const io = this.io.push();
        io.onVTKeystroke = function (str) {
            sendInputMessage(str);
        }
        
        io.sendString = function (str) {
            sendInputMessage(str);
        }
       
        function printPrompt() {
          io.print(
            '\x1b[38:2:51:105:232mh' +
            '\x1b[38:2:213:15:37mt' +
            '\x1b[38:2:238:178:17me' +
            '\x1b[38:2:51:105:232mr' +
            '\x1b[38:2:0:153:37mm' +
            '\x1b[38:2:213:15:37m>' +
            '\x1b[0m ');
        }
        printPrompt();
        this.setCursorVisible(true);
        console.log("Whatever");
    }
    term.decorate(document.querySelector("#terminal"));
    term.installKeyboard()
    window.term = term;
    console.log(term);
};

window.onload = function() {
    lib.init(terminalSetup);
};
