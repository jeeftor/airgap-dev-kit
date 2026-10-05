-- Verify observable editing features in the installed, offline kit.
require("lazy").load({ plugins = { "nvim-treesitter", "mason.nvim" } })
local manifest = dofile(vim.env.AIRGAP_PARSER_MANIFEST)
assert(vim.fn.executable("tree-sitter") == 1, "Bundled Tree-sitter CLI not on editor PATH")
local cli = vim.system({ "tree-sitter", "--version" }, { text = true }):wait()
assert(cli.code == 0, cli.stderr)
assert(require("lazy.core.config").options.rocks.enabled == false, "Unused LuaRocks enabled")
local plugin = require("lazy.core.config").plugins["nvim-treesitter"]
local opts = require("lazy.core.plugin").values(plugin, "opts", false)
assert(#opts.ensure_installed == 0, "Offline startup tries to install parsers")

for _, language in ipairs(manifest.treesitter) do
	assert(vim.treesitter.language.add(language), "Cannot load parser: " .. language)
	local parser = vim.treesitter.get_string_parser("", language)
	assert(#parser:parse() > 0, "Cannot parse: " .. language)
	assert(vim.treesitter.query.get(language, "highlights"), "Cannot load queries: " .. language)
end

local buffer = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(buffer)
vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "local answer = 42" })
vim.bo[buffer].filetype = "lua"
vim.treesitter.start(buffer, "lua")
assert(vim.treesitter.highlighter.active[buffer], "Lua highlighting did not start")
local tree = vim.treesitter.get_parser(buffer, "lua"):parse()[1]
assert(not tree:root():has_error(), "Valid Lua failed to parse")
vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "local =" })
tree = vim.treesitter.get_parser(buffer, "lua"):parse()[1]
assert(tree:root():has_error(), "Invalid Lua did not produce a syntax error")
vim.fn.setreg('"', "internal clipboard")
assert(vim.fn.getreg('"') == "internal clipboard", "Internal yank register broken")
print("Offline editor parsers, queries, highlighting, CLI, and yank verified")
