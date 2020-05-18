hterm.defaultStorage = new lib.Storage.Memory();

function sendInputMessage(str) {
    const handler = window.webkit.messageHandlers.UTMSendInput;
    handler.postMessage(str);
}

function sendGesture(str) {
    const handler = window.webkit.messageHandlers.UTMSendGesture;
    handler.postMessage(str);
}

function sendTerminalSize(columns, rows) {
    const handler = window.webkit.messageHandlers.UTMSendTerminalSize;
    handler.postMessage([columns, rows]);
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
    var keyCode = sourceEvent.keyCode;
    if (sourceEvent.key.toLowerCase() == 'c' && sourceEvent.keyCode == 13) {
        keyCode = 67; // Issue #327, iOS WebKit translates Ctrl+C incorrectly
    }
    return {
        keyCode: keyCode,
        charCode: sourceEvent.charCode,
        location: sourceEvent.location,
        which: sourceEvent.which,
        code: sourceEvent.code,
        key: sourceEvent.key,
        repeat: sourceEvent.repeat,
        isComposing: sourceEvent.isComposing,
        altKey: sourceEvent.altKey || modifierTable.altKey,
        ctrlKey: sourceEvent.ctrlKey || modifierTable.ctrlKey,
        metaKey: sourceEvent.metaKey || modifierTable.metaKey,
        shiftKey: sourceEvent.shiftKey || modifierTable.shiftKey
    };
}

function detectGestures(e) {
    switch (e.type) {
        case 'touchstart':
            if (e.touches.length == 3) {
                this.startThreeTouchLocation = e.touches[0].screenY;
                e.preventDefault();
            }
            break;
        case 'touchmove':
            if (e.touches.length == 3) {
                this.lastThreeTouchLocation = e.touches[0].screenY;
                e.preventDefault();
            }
            break;
        case 'touchcancel':
        case 'touchend':
            if (this.startThreeTouchLocation) {
                if (this.lastThreeTouchLocation > this.startThreeTouchLocation) {
                    sendGesture('threeSwipeDown');
                } else {
                    sendGesture('threeSwipeUp');
                }
                e.preventDefault();
            }
            this.startThreeTouchLocation = 0;
            this.lastThreeTouchLocation = 0;
            break;
    }
}

// Setup

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
        
        io.onTerminalResize = function (columns, rows) {
            sendTerminalSize(columns, rows);
        };
       
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
    // handle touch gestures
    hterm.ScrollPort.prototype.onTouch = function(e) {
        detectGestures(e);
    }
    window.term = term;
};

function changeFont(fontFamily, fontSize) {
    const term = new hterm.Terminal();
    term.getPrefs().set('font-family', fontFamily);
    term.getPrefs().set('font-size', fontSize);
}

function setCursorBlink(blink) {
    const term = new hterm.Terminal();
    term.getPrefs().set('cursor-blink', blink);
}

window.onload = function() {
    lib.init(terminalSetup);
};
