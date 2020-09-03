default: build/wsterm.js build/wsterm-element.js

clean:
	rm -rf elm-stuff
	rm -rf build

# for quickly debugging
test:
	elm make src/Main.elm --output="wsterm-core.js"
	cat wsterm-core.js src/sockets.js > wsterm.js

# the main Elm application + socket code
build/wsterm.js:
	mkdir -p build
	elm make src/Main.elm --optimize --output="build/wsterm-core.js"
	cat build/wsterm-core.js src/sockets.js > build/wsterm.js

# the main Elm application and socket code, wrapped in a custom-element
build/wsterm-element.js: build/wsterm.js
	cat build/wsterm.js src/custom_element.js > build/wsterm-element.js

minified: build/min/wsterm.min.js build/min/wsterm-element.min.js build/min/wsterm.min.css

# minifiers for the 'minified' option
build/min/wsterm.min.js: build/wsterm.js
	mkdir -p build/min
	uglifyjs --compress --mangle -- build/wsterm.js > build/min/wsterm.min.js

build/min/wsterm-element.min.js: build/wsterm-element.js
	mkdir -p build/min
	uglifyjs --compress --mangle -- build/wsterm-element.js > build/min/wsterm-element.min.js

build/min/wsterm.min.css:
	mkdir -p build/min
	curl -X POST -s --data-urlencode 'input@src/wsterm.css' https://cssminifier.com/raw > build/min/wsterm.min.css

release: minified
	rm -f build/wsterm.tar.gz
	tar -czf build/wsterm.tar.gz -C build/min wsterm.min.js wsterm-element.min.js wsterm.min.css
