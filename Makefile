PLUGIN_DIR := lua/

.PHONY: lint
lint:
	luacheck ${PLUGIN_DIR}
