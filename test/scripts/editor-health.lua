-- Verify observable editing features in the installed, offline kit.
require("lazy").load({ plugins = { "nvim-treesitter", "nvim-lspconfig" } })
local manifest = dofile(vim.env.AIRGAP_PARSER_MANIFEST)
local plugins = require("lazy.core.config").plugins
local plugin_values = require("lazy.core.plugin").values
for _, name in ipairs({ "mason.nvim", "mason-lspconfig.nvim" }) do
	local mason_opts = plugin_values(plugins[name], "opts", false)
	assert(#mason_opts.ensure_installed == 0, "Offline configuration requests automatic installs: " .. name)
end
local registry = require("mason-registry")
local bundled_packages = {}
for _, packages in pairs(manifest.mason) do
	for _, package in ipairs(packages) do
		bundled_packages[package] = true
		assert(registry.get_package(package):is_installed(), "Missing bundled Mason package: " .. package)
	end
end
-- LazyVim adds its configured LSP servers to the bridge's final install list.
local mappings = require("mason-lspconfig.mappings").get_mason_map().lspconfig_to_package
local bridge_settings = require("mason-lspconfig.settings").current
for _, server in ipairs(bridge_settings.ensure_installed) do
	local package = mappings[server]
	assert(bundled_packages[package], "Automatic install requests an unbundled server: " .. server)
	assert(registry.get_package(package):is_installed(), "Automatic install requests a missing server: " .. server)
end
assert(bridge_settings.automatic_enable ~= false, "Installed LSP activation disabled")
assert(vim.lsp.is_enabled("lua_ls"), "Bundled Lua language server is not enabled")
assert(vim.fn.executable("tree-sitter") == 1, "Bundled Tree-sitter CLI not on editor PATH")
for _, tool in ipairs({ "fd", "fzf", "rg", "lazygit" }) do
	assert(vim.fn.executable(tool) == 1, "Missing LazyVim runtime tool: " .. tool)
	local result = vim.system({ tool, "--version" }, { text = true }):wait()
	assert(result.code == 0, "Cannot run " .. tool .. ": " .. tostring(result.stderr))
end
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
local filename = vim.fn.stdpath("cache") .. "/airgap-health.lua"
vim.fn.mkdir(vim.fs.dirname(filename), "p")
vim.fn.writefile({ "local answer = 42" }, filename)
vim.api.nvim_buf_set_name(buffer, filename)
vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "local answer = 42" })
vim.bo[buffer].filetype = "lua"
assert(
	vim.wait(15000, function()
		for _, client in ipairs(vim.lsp.get_clients({ bufnr = buffer, name = "lua_ls" })) do
			if client.initialized then
				return true
			end
		end
		return false
	end, 100),
	"Bundled Lua language server did not initialize; see the Neovim LSP log"
)
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
