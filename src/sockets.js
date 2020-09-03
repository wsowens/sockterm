/* Initialize the ports for a particular app instance */

function _initializeSocketPorts(elm_app, _DOM_root) {
    // create a variable for a websocket
    elm_app.ws_term_socket = null;

    var socket = null;
    // Handlers for the four events
    function socketOpen(event) {
      console.debug(event);
      elm_app.ports.openSocket.send(null);
    }
    function socketMsg(event) {
      console.debug(event);
      elm_app.ports.msgSocket.send(event.data);
    }
    /*
    Websockets essentially have no data when an error occurs, just an error event...
    https://stackoverflow.com/questions/18803971/websocket-onerror-how-to-read-error-description
    For now, we just log the error in the console, but don't send anything to Elm.
    */
    function socketErr(event) {
      console.error(event);
    }
    // from link above, 1006 is basically the only result you will get
    function socketClose(event) {
      console.log(event);
      elm_app.ports.closeSocket.send(event.code);
    }

    // Create a new port, `connectSocket`, that connects a socket and sets it up appopriately
    elm_app.ports.connectSocket.subscribe((address) => {
      // disconnect socket, if it is open
      if (socket != null) {
        socket.close();
        socket = null;
      }
      socket = new WebSocket(address);
      // add event handlers
      socket.addEventListener("open", socketOpen);
      socket.addEventListener("message", socketMsg);
      socket.addEventListener("error", socketErr);
      socket.addEventListener("close", socketClose);
    });
    // Create a new port, `writeSocket`, that writes a message to the socket
    elm_app.ports.writeSocket.subscribe((data) => {
      if (socket != null) {
        socket.send(data);
      }
      // TODO: handle this specifically
      // maybe use the "error" port?
    });
    // Create a port for scrolling the terminal
    elm_app.ports.scrollTerm.subscribe((elementId) => {
      var elem = _DOM_root.getElementById(elementId);
      if (elem === null) {
        console.err("Could not scroll " + elementId)
        return;
      }
      // we have a slight delay to allow the DOM to update
      setTimeout(()=> {
        /* Check if the window is less than 50% of the way from the bottom. */
        if ((elem.scrollHeight - elem.scrollTop - elem.clientHeight) / elem.clientHeight < 0.5) {
          elem.scroll(0, elem.scrollHeight)
        }
      }, 50)
    });
}

function initializeSocketPorts(elm_app) {
    // call inner function with document as root
    _initializeSocketPorts(elm_app, document);
}