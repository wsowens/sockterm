default: term.js

clean:
	# rm -rf elm-stuff
	rm -f term.js

test: clean
	elm make src/Main.elm --output="term.js"

term.js:
	elm make src/Main.elm --optimize --output="term.js"