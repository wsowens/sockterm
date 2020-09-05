default: build/sockterm.js build/sockterm-element.js

clean:
	rm -rf elm-stuff
	rm -rf build

# for quickly debugging
test:
	elm make src/Main.elm --output="build/sockterm-core.js"
	cat build/sockterm-core.js src/sockets.js > build/sockterm.js

# the main Elm application + socket code
build/sockterm.js:
	mkdir -p build
	elm make src/Main.elm --optimize --output="build/sockterm-core.js"
	cat build/sockterm-core.js src/sockets.js > build/sockterm.js

# the main Elm application and socket code, wrapped in a custom-element
build/sockterm-element.js: build/sockterm.js
	cat build/sockterm.js src/custom_element.js > build/sockterm-element.js

minified: build/min/sockterm.min.js build/min/sockterm-element.min.js build/min/sockterm.min.css

# minifiers for the 'minified' option
build/min/sockterm.min.js: build/sockterm.js
	mkdir -p build/min
	uglifyjs --compress --mangle -- build/sockterm.js > build/min/sockterm.min.js

build/min/sockterm-element.min.js: build/sockterm-element.js
	mkdir -p build/min
	uglifyjs --compress --mangle -- build/sockterm-element.js > build/min/sockterm-element.min.js

build/min/sockterm.min.css:
	mkdir -p build/min
	curl -X POST -s --data-urlencode 'input@src/sockterm.css' https://cssminifier.com/raw > build/min/sockterm.min.css

release: minified
	rm -f build/sockterm.tar.gz
	tar -czf build/sockterm.tar.gz -C build/min sockterm.min.js sockterm-element.min.js sockterm.min.css
