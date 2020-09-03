# Examples
This folder contains various examples of `wsterm.js` in action.

- [basic.html](basic.html) Shows how to load `wsterm.js`, initialize the Elm app, and set up the ports corectly.
- [element.html](element.html) Shows how to load `wsterm-element.js` and use the custom `<wsterm>` element. (*This approach is recommended.*)
- [colorscheme.html](colorscheme.html) Shows how to create a custom colorscheme. This option is only available with `wsterm.js`, not with custom elements.
- [demo.html](demo.html) contains the HTML for the screenshot on the main README.md


To test these for yourself, you can directly download these HTML files and open them in your browser directly.
(If for some reason this doesn't work, try firing up an http server, like `python3 -m http.server.`)

From there, try connecting to `ws://echo.websocket.org`.
This is an echo server that simply repeats all of your messages back to you.
If you see your messages twice, that means it's working!
