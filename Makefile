.PHONY: install test

# Bootstrap: put `dotconfigs` and the `dots` alias on PATH. The one step that
# can't self-heal (the tool can't symlink itself into existence), so it lives
# here at the conventional entry point rather than inside the tool.
install:
	./bin/dotconfigs setup

test:
	pytest tests/ -v
