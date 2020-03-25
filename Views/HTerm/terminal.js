hterm.defaultStorage = new lib.Storage.Memory();

function sendInputMessage(str) {
    const handler = window.webkit.messageHandlers.UTMSendInput;
    handler.postMessage(str);
}

function writeData(data) {
    const term = window.term;
    const str = String.fromCharCode.apply(null, data);
    term.io.print(str);
}

function focusTerminal() {
//    const term = window.term;
//    term.scrollPort_.focus()
    var element = document.getElementById("terminal");
    element.focus();
}

// Keyboard stuff

var modifierTable = {
    altKey: false,
    ctrlKey: false,
    metaKey: false,
    shiftKey: false
};

function modifierDown(keyName) {
    modifierTable[keyName] = true;
}

function modifierUp(keyName) {
    modifierTable[keyName] = false;
}

function resetModifiers() {
    modifierTable.altKey = false;
    modifierTable.ctrlKey = false;
    modifierTable.metaKey = false;
    modifierTable.shiftKey = false;
}

function programmaticKeyDown(keyCode) {
    var eventData = {
        keyCode: keyCode,
        location: KeyboardEvent.DOM_KEY_LOCATION_STANDARD,
        altKey: modifierTable.altKey,
        ctrlKey: modifierTable.ctrlKey,
        metaKey: modifierTable.metaKey,
        shiftKey: modifierTable.shiftKey
    };
    var keyDownEvent = new KeyboardEvent("keydown", eventData);
    const term = window.term;
    term.keyboard.onKeyDown_(keyDownEvent);
}

function programmaticKeyUp(keyCode) {
    var eventData = {
        keyCode: keyCode,
        location: KeyboardEvent.DOM_KEY_LOCATION_STANDARD,
        altKey: modifierTable.altKey,
        ctrlKey: modifierTable.ctrlKey,
        metaKey: modifierTable.metaKey,
        shiftKey: modifierTable.shiftKey
    };
    var keyUpEvent = new KeyboardEvent("keyup", eventData);
    const term = window.term;
    term.keyboard.onKeyUp_(keyDownEvent);
}

function captureKeydownHandler(event) {
    var newEventData = eventDataUsingModifierTable(event);
    var newEvent = new KeyboardEvent("keydown", newEventData);
    newEvent.preventDefault = function () {
        event.preventDefault();
    }
    newEvent.stopPropagation = function() {
        event.stopPropagation();
    }
    const keyboard = window.term.keyboard;
    keyboard.onKeyDown_(newEvent);
}

function captureKeyupHandler(event) {
    var newEventData = eventDataUsingModifierTable(event);
    var newEvent = new KeyboardEvent("keyup", newEventData);
    newEvent.preventDefault = function () {
        event.preventDefault();
    }
    newEvent.stopPropagation = function() {
        event.stopPropagation();
    }
    const keyboard = window.term.keyboard;
    keyboard.onKeyUp_(newEvent);
}

function captureKeypressHandler(event) {
    var newEventData = eventDataUsingModifierTable(event);
    var newEvent = new KeyboardEvent("keypress", newEventData);
    newEvent.preventDefault = function () {
        event.preventDefault();
    }
    newEvent.stopPropagation = function() {
        event.stopPropagation();
    }
    const keyboard = window.term.keyboard;
    keyboard.onKeyPress_(newEvent);
}

function eventDataUsingModifierTable(sourceEvent) {
    return {
        keyCode: sourceEvent.keyCode,
        charCode: sourceEvent.charCode,
        location: sourceEvent.location,
        which: sourceEvent.which,
        code: sourceEvent.code,
        key: sourceEvent.key,
        repeat: sourceEvent.repeat,
        isComposing: sourceEvent.isComposing,
        altKey: modifierTable.altKey,
        ctrlKey: modifierTable.ctrlKey,
        metaKey: modifierTable.metaKey,
        shiftKey: modifierTable.shiftKey
    };
}

// Setup

function terminalSetup() {
    const term = new hterm.Terminal();
    // theme
    term.getPrefs().set('background-color', 'transparent');
    
    term.onTerminalReady = function() {
        const io = this.io.push();
        io.onVTKeystroke = function (str) {
            sendInputMessage(str);
        }
        
        io.sendString = function (str) {
            sendInputMessage(str);
        }
       
        this.setCursorVisible(true);
    }
    term.decorate(document.querySelector("#terminal"));
    // remove default event listeners
    const keyboard = term.keyboard;
    function isHandlerIncluded(tuple) {
        return !['keydown', 'keyup', 'keypress'].includes(tuple[0])
    }
    keyboard.handlers_ = keyboard.handlers_.filter(isHandlerIncluded)
    term.installKeyboard()
    // hack the keyboard events to use modifier table
    const keyboardElement = term.keyboard.keyboardElement_;
    keyboardElement.addEventListener('keydown', captureKeydownHandler);
    keyboardElement.addEventListener('keyup', captureKeyupHandler);
    keyboardElement.addEventListener('keypress', captureKeypressHandler);
    window.term = term;
};

window.onload = function() {
    lib.init(terminalSetup);
};
