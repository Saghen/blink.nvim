build: build-fuzzy

build-fuzzy: 
	cd lua/blink/cmp/fuzzy && cargo build --release
