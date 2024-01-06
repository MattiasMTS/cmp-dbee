local ok, cmp = pcall(require, "cmp")
if not ok then
	return
end

cmp.register_source("cmp-dbee", require("cmp-dbee"):new())
