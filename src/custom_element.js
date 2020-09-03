/*
Copyright 2020 William Owens

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

// Defining a custom element, 'ws-term', that instantiates a websocket terminal

class WSTerm extends HTMLElement {
    constructor () {
        super();

        var shadow = this.attachShadow({mode: 'open'});

        var wrapper = document.createElement('div');
        
        // allow Elm to take over this wrapper
        var app = Elm.Main.init({
          node: wrapper
        });

        // initalize the socket-related ports, with shadow as the DOM root
        _initializeSocketPorts(app, shadow);

        shadow.appendChild(wrapper);

        // add the style
        const styleElem = document.createElement('style');
        styleElem.innerText =
        "#term-url-bar{display:flex;justify-content:space-between;align-items:baseline;background-color:#2472c8;color:#e5e5e5;padding:0 1%;font-family:monospace;font-size:smaller}#term-url-input{background-color:inherit;color:inherit;font-family:inherit;font-size:inherit;border:none;width:60%}.term{display:flex;flex-direction:column;align-items:center;justify-content:flex-end;resize:both;overflow:hidden;font-size:x-large;font-family:monospace;padding-left:.01em;min-width:82ch;width:82ch;height:60.5ch}.term-element{font-family:inherit;font-size:inherit;width:100%}#term-input,#term-output{color:#e5e5e5;background-color:#1e1e1e;white-space:pre-wrap}#term-input{resize:none;min-height:2em;max-height:2em;overflow-y:auto}#term-output{overflow:hidden scroll;overflow-wrap:break-word;flex-grow:1}.term-bold{font-weight:700}.term-italic{font-style:italic}.term-underline{text-decoration:underline}.term-blink{animation:blinking 1s steps(1,end) infinite}@keyframes blinking{50%{opacity:0}}.term-reverse{background-color:#e5e5e5;color:#1e1e1e}.term-strike{text-decoration:line-through}.term-underline-strike{text-decoration:underline line-through}.term-black{color:#1e1e1e}.term-red{color:#cd3131}.term-green{color:#0dbc79}.term-yellow{color:#e5e510}.term-blue{color:#2472c8}.term-magenta{color:#bc3fbc}.term-cyan{color:#11a8cd}.term-white{color:#e5e5e5}.term-bright-black{color:#666}.term-bright-red{color:#f14c4c}.term-bright-green{color:#23d18b}.term-bright-yellow{color:#f5f543}.term-bright-blue{color:#3b8eea}.term-bright-magenta{color:#d670d6}.term-bright-cyan{color:#29b8db}.term-bright-white{color:#e5e5e5}.term-black-bg{background-color:#1e1e1e}.term-red-bg{background-color:#cd3131}.term-green-bg{background-color:#0dbc79}.term-yellow-bg{background-color:#e5e510}.term-blue-bg{background-color:#2472c8}.term-magenta-bg{background-color:#bc3fbc}.term-cyan-bg{background-color:#11a8cd}.term-white-bg{background-color:#e5e5e5}.term-bright-black-bg{background-color:#666}.term-bright-red-bg{background-color:#f14c4c}.term-bright-green-bg{background-color:#23d18b}.term-bright-yellow-bg{background-color:#f5f543}.term-bright-blue-bg{background-color:#3b8eea}.term-bright-magenta-bg{background-color:#d670d6}.term-bright-cyan-bg{background-color:#29b8db}.term-bright-white-bg{background-color:#e5e5e5}";
        
        // Attach the created element to the shadow dom
        shadow.appendChild(styleElem);
    }
}
customElements.define('ws-term', WSTerm);
