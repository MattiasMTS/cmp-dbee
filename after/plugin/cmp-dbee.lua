local has_cmp_dbee, cmp_dbee = pcall(require, "cmp-dbee")
if not has_cmp_dbee then
  return
end
cmp_dbee.setup()
