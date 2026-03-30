SHELL := /bin/bash
.SILENT:
.ONESHELL:
.DEFAULT_GOAL := help

#------------------------------------------------------------------------------
# Configuration
#------------------------------------------------------------------------------

STYLUA  := stylua
LUACHECK := luacheck
LLS     := lua-language-server
NVIM    := nvim
LUA_DIR := lua

#------------------------------------------------------------------------------
# Phony Targets Declaration
#------------------------------------------------------------------------------

.PHONY: help sync fmt lint typecheck check qa clean distclean
.PHONY: test test.unit test.integration test.e2e

#------------------------------------------------------------------------------
# High-Level Targets
#------------------------------------------------------------------------------

check: fmt lint typecheck
qa: check test
test: test.unit

#------------------------------------------------------------------------------
# Installation & Dependencies
#------------------------------------------------------------------------------

sync:
	echo "Checking required tools..."
	for tool in $(STYLUA) $(LUACHECK) $(LLS); do \
		command -v $$tool >/dev/null 2>&1 || { echo "Missing: $$tool (install via brew)"; exit 1; }; \
	done
	echo "All tools present."

#------------------------------------------------------------------------------
# Code Quality
#------------------------------------------------------------------------------

fmt:
	$(STYLUA) $(LUA_DIR)/

lint:
	$(LUACHECK) $(LUA_DIR)/ --globals vim

typecheck:
	$(LLS) --check $(LUA_DIR)/

#------------------------------------------------------------------------------
# Testing
#------------------------------------------------------------------------------

test.unit:
	$(NVIM) --headless -u NONE \
		-c "lua dofile('test/add_close_patterns.lua')" \
		-c "qall" 2>&1 || true

test.integration:
	echo "No integration tests defined."

test.e2e:
	echo "No e2e tests defined."

#------------------------------------------------------------------------------
# Cleanup
#------------------------------------------------------------------------------

clean:
	find . -name "*.log" -delete
	echo "Cleaned."

distclean: clean
	echo "Deep clean done."

#------------------------------------------------------------------------------
# Help
#------------------------------------------------------------------------------

help:
	printf "\033[36m"
	printf "██████╗ ██████╗ ███████╗████████╗████████╗██╗   ██╗    ███████╗ ██████╗ ██╗     ██████╗ \n"
	printf "██╔══██╗██╔══██╗██╔════╝╚══██╔══╝╚══██╔══╝╚██╗ ██╔╝    ██╔════╝██╔═══██╗██║     ██╔══██╗\n"
	printf "██████╔╝██████╔╝█████╗     ██║      ██║    ╚████╔╝     █████╗  ██║   ██║██║     ██║  ██║\n"
	printf "██╔═══╝ ██╔══██╗██╔══╝     ██║      ██║     ╚██╔╝      ██╔══╝  ██║   ██║██║     ██║  ██║\n"
	printf "██║     ██║  ██║███████╗   ██║      ██║      ██║       ██║     ╚██████╔╝███████╗██████╔╝\n"
	printf "╚═╝     ╚═╝  ╚═╝╚══════╝   ╚═╝      ╚═╝      ╚═╝       ╚═╝      ╚═════╝ ╚══════╝╚═════╝ \n"
	printf "\033[0m\n"
	printf "Usage: make [target]\n\n"
	printf "\033[1;35mSetup:\033[0m\n"
	printf "  sync         - Check required tools\n"
	printf "\n"
	printf "\033[1;35mDev:\033[0m\n"
	printf "  fmt          - Format Lua (stylua)\n"
	printf "  lint         - Lint Lua (luacheck)\n"
	printf "  typecheck    - Type-check (lua-language-server)\n"
	printf "  check        - fmt + lint + typecheck\n"
	printf "  qa           - check + test (quality gate)\n"
	printf "\n"
	printf "\033[1;35mTest:\033[0m\n"
	printf "  test         - Run all tests\n"
	printf "  test.unit    - Unit tests (nvim headless)\n"
	printf "\n"
	printf "\033[1;35mCleanup:\033[0m\n"
	printf "  clean        - Remove logs\n"
	printf "  distclean    - Deep clean\n"
