default: term.js

clean:
	# rm -rf elm-stuff
	rm -f term.js

term.js:
	elm make src/Main.elm --optimize --output="term.js"