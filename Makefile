.PHONY: test lint clean

PLENARY_DIR ?= /tmp/plenary.nvim
NEOTEST_DIR ?= /tmp/neotest

test: deps
	nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"

deps:
	@if [ ! -d "$(PLENARY_DIR)" ]; then \
		git clone https://github.com/nvim-lua/plenary.nvim $(PLENARY_DIR); \
	fi
	@if [ ! -d "$(NEOTEST_DIR)" ]; then \
		git clone https://github.com/nvim-neotest/neotest $(NEOTEST_DIR); \
	fi

clean:
	rm -rf $(PLENARY_DIR) $(NEOTEST_DIR)
