.PHONY: test
test:
	@nvim --headless --noplugin -u spec/setup.lua -c "PlenaryBustedDirectory spec/ {minimal_init = 'spec/setup.lua'}"
