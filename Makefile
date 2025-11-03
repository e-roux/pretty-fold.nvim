# Makefile for testing and linting pretty-fold.nvim

NVIM ?= nvim
LUACHECK ?= luacheck
STYLUA ?= stylua
# Set to 1 to silence command echoing (like using @). Set to 0 to show commands.
SILENT ?= 1

# If SILENT is 1, enable .SILENT to suppress command echoing
ifneq ($(filter 1,$(SILENT)),)
.SILENT:
endif

.PHONY: help test lint unit fmt check

help:
	echo "Available targets:"
	echo "  test   - Run lint and unit tests (plenary)"
	echo "  lint   - Run luacheck (if installed)"
	echo "  unit   - Run unit tests using plenary + nvim (headless)"
	echo "  fmt    - Run stylua to format code (if installed)"
	echo "  check  - Alias for test"

# Run lint + unit tests (ensure deps first)
test: deps lint unit
	echo "Test targets finished."

# Dependencies directory and subpaths
DEPS_DIR ?= deps
PLENARY_DIR := $(DEPS_DIR)/plenary.nvim

.PHONY: deps plenary luacheck

# Aggregate deps target depends on individual recipe targets
deps: plenary luacheck
	echo "Deps checked."

# Ensure plenary.nvim is present in deps/
plenary:
	if [ ! -d "$(PLENARY_DIR)/.git" ] && [ ! -f "$(PLENARY_DIR)/plugin/plenary.vim" ]; then \
		echo "Cloning plenary.nvim into $(PLENARY_DIR) ..."; \
		mkdir -p $(DEPS_DIR); \
		git clone --depth 1 https://github.com/nvim-lua/plenary.nvim "$(PLENARY_DIR)" || echo "git clone failed or network unavailable"; \
	else \
		echo "plenary.nvim already present"; \
	fi

# Ensure luacheck is available (install via luarocks if possible)
luacheck:
	if command -v luacheck >/dev/null 2>&1; then \
		echo "luacheck already installed"; \
	elif command -v luarocks >/dev/null 2>&1; then \
		echo "Installing luacheck via luarocks..."; \
		luarocks install luacheck || echo "luarocks install luacheck failed or network unavailable"; \
	else \
		echo "luacheck not found and luarocks not available; please install luacheck manually"; \
	fi


# Lint with luacheck if available
lint:
	if command -v $(LUACHECK) >/dev/null 2>&1; then \
		echo "Running $(LUACHECK) ..."; \
		$(LUACHECK) .; \
	else \
		echo "$(LUACHECK) not found, skipping lint"; \
	fi

# Run unit tests using plenary's busted runner via headless Neovim
unit:
	if command -v $(NVIM) >/dev/null 2>&1; then \
		echo "Running unit tests with plenary (nvim headless)..."; \
		$(NVIM) --headless -u test/minimal_init.vim -c "lua require('plenary.test_harness').test_directory('test')" -c "qa!"; \
	else \
		echo "$(NVIM) not found, skipping unit tests"; \
	fi

# Format with stylua if available
fmt:
	if command -v $(STYLUA) >/dev/null 2>&1; then \
		echo "Running $(STYLUA) ..."; \
		$(STYLUA) .; \
	else \
		echo "$(STYLUA) not found, skipping format"; \
	fi

check: test

