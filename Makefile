PLUGIN_DIR := lua/

.PHONY: lint
lint:
	@command -v luacheck > /dev/null || (echo "Error: 'luacheck' is not installed. Please run 'make lint-install' to install it." && exit 1)
	luacheck ${PLUGIN_DIR}

.PHONY: lint-install
lint-install:
	@if [ "$(shell uname)" = "Darwin" ]; then \
		command -v brew > /dev/null || (echo "Error: Homebrew is not installed. Please install Homebrew and try again." && exit 1); \
		brew install luacheck; \
	elif [ "$(shell uname)" = "Linux" ]; then \
		command -v apt-get > /dev/null && sudo apt-get install -y luacheck || \
		command -v yum > /dev/null && sudo yum install -y luacheck || \
		(echo "Error: Unsupported package manager. Please install 'luacheck' manually." && exit 1); \
	else \
		echo "Error: Unsupported operating system. Install 'luacheck' manually"; \
		exit 1; \
	fi
