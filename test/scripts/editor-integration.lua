-- Exercise the installed LazyVim configuration, never a test-only plugin setup.
local suite = vim.env.AIRGAP_EDITOR_SUITE or "all"
local results = {}
local root = vim.fn.stdpath("cache") .. "/integration"
vim.fn.mkdir(root, "p")
vim.env.GOPROXY = "off"
vim.env.GOTOOLCHAIN = "local"
vim.env.CARGO_NET_OFFLINE = "true"
require("lazy").load({ plugins = { "nvim-lspconfig", "conform.nvim", "blink.cmp" } })

local function check(name, callback)
	local ok, err = xpcall(callback, debug.traceback)
	results[#results + 1] = { name = name, passed = ok, error = ok and nil or tostring(err) }
	print((ok and "PASS " or "FAIL ") .. name .. (ok and "" or (": " .. tostring(err))))
end

local function run(group)
	return suite == "all" or suite == group or (suite == "minimal" and (group == "formatting" or group == "plugins"))
end

local function fixture(directory, files, filename)
	local path = root .. "/" .. directory
	vim.fn.mkdir(path, "p")
	for name, lines in pairs(files) do
		vim.fn.writefile(lines, path .. "/" .. name)
	end
	vim.cmd.cd(vim.fn.fnameescape(path))
	vim.cmd("edit! " .. vim.fn.fnameescape(path .. "/" .. filename))
	return vim.api.nvim_get_current_buf()
end

local function attached(buffer, server)
	local client
	assert(
		vim.wait(30000, function()
			for _, candidate in ipairs(vim.lsp.get_clients({ bufnr = buffer, name = server })) do
				if candidate.initialized then
					client = candidate
					return true
				end
			end
			return false
		end, 100),
		server .. " did not initialize and attach; see lsp.log"
	)
	return client
end

if run("languages") then
	check("Go workspace toolchain is available offline", function()
		local result = vim.system({ "go", "env", "GOVERSION" }, { text = true }):wait(15000)
		assert(result.code == 0, "Go projects require a preinstalled Go toolchain: " .. tostring(result.stderr))
	end)
	check("Rust workspace toolchain is available offline", function()
		for _, tool in ipairs({ "cargo", "rustc" }) do
			local result = vim.system({ tool, "--version" }, { text = true }):wait(15000)
			assert(result.code == 0, "Rust projects require a preinstalled toolchain: " .. tostring(result.stderr))
		end
	end)
	local cases = {
		["lua-language-server"] = { "lua_ls", "main.lua", { ".luarc.json", "{}" }, "local answer = 42" },
		["bash-language-server"] = { "bashls", "main.sh", { ".bashrc", "" }, "#!/bin/bash\necho hello" },
		["json-lsp"] = { "jsonls", "main.json", { "package.json", "{}" }, '{"answer":42}' },
		["yaml-language-server"] = { "yamlls", "main.yaml", { ".git", "" }, "answer: 42" },
		["marksman"] = { "marksman", "main.md", { ".marksman.toml", "" }, "# Offline\n\n[Other](other.md)" },
		["pyright"] = { "pyright", "main.py", { "pyrightconfig.json", "{}" }, "answer: int = 42" },
		["rust-analyzer"] = {
			"rust_analyzer",
			"main.rs",
			{
				"Cargo.toml",
				'[package]\nname="offline-test"\nversion="0.1.0"\n[[bin]]\nname="offline-test"\npath="main.rs"',
			},
			"fn main() {}",
		},
		["typescript-language-server"] = { "ts_ls", "main.ts", { "tsconfig.json", "{}" }, "const answer: number = 42;" },
		["gopls"] = {
			"gopls",
			"main.go",
			{ "go.mod", "module offline.test/fixture\n\ngo 1.22" },
			"package main\nfunc main() {}",
		},
	}
	local manifest = dofile(vim.env.AIRGAP_PARSER_MANIFEST)
	for _, package in ipairs(manifest.mason.lsp_servers) do
		check("LSP initialization: " .. package, function()
			local case = assert(cases[package], "Add an integration fixture for " .. package)
			local files = { [case[2]] = vim.split(case[4], "\n"), [case[3][1]] = vim.split(case[3][2], "\n") }
			if package == "marksman" then
				files["other.md"] = { "# Other" }
			end
			local buffer = fixture(package, files, case[2])
			assert(vim.lsp.is_enabled(case[1]), case[1] .. " is not enabled by the installed configuration")
			attached(buffer, case[1])
		end)
	end

	local lua_buffer, lua_client
	check("Lua language features attach", function()
		lua_buffer = fixture("lua-features", {
			[".luarc.json"] = { "{}" },
			["main.lua"] = {
				"local function airgap_answer()",
				"  return 42",
				"end",
				"local result = airgap_answer()",
				"print(result)",
			},
		}, "main.lua")
		lua_client = attached(lua_buffer, "lua_ls")
	end)
	check("LSP go-to-definition returns the fixture declaration", function()
		assert(lua_client, "Lua feature client did not attach")
		local response = lua_client:request_sync("textDocument/definition", {
			textDocument = { uri = vim.uri_from_bufnr(lua_buffer) },
			position = { line = 3, character = 18 },
		}, 15000, lua_buffer)
		assert(response and not response.err, vim.inspect(response))
		local location = assert(response.result and response.result[1], "Definition returned no locations")
		assert(
			(location.uri or location.targetUri) == vim.uri_from_bufnr(lua_buffer),
			"Definition points outside the fixture"
		)
		assert((location.range or location.targetSelectionRange).start.line == 0, "Definition points at the wrong line")
	end)
	check("LSP completion returns a local symbol", function()
		assert(lua_client, "Lua feature client did not attach")
		vim.api.nvim_buf_set_lines(lua_buffer, 5, -1, false, { "airgap_" })
		local found = false
		assert(
			vim.wait(15000, function()
				local response = lua_client:request_sync("textDocument/completion", {
					textDocument = { uri = vim.uri_from_bufnr(lua_buffer) },
					position = { line = 5, character = 7 },
				}, 2000, lua_buffer)
				local result = response and response.result
				for _, item in ipairs(result and (result.items or result) or {}) do
					if item.label:find("airgap_answer", 1, true) then
						found = true
					end
				end
				return found
			end, 100),
			"Completion omitted the local airgap_answer symbol"
		)
	end)
	check("LSP publishes diagnostics and clears them after repair", function()
		assert(lua_client, "Lua feature client did not attach")
		vim.api.nvim_buf_set_lines(lua_buffer, 0, -1, false, { "local =" })
		assert(
			vim.wait(15000, function()
				return #vim.diagnostic.get(lua_buffer, { severity = vim.diagnostic.severity.ERROR }) > 0
			end, 100),
			"Invalid Lua produced no LSP error"
		)
		vim.api.nvim_buf_set_lines(lua_buffer, 0, -1, false, { "print(42)" })
		assert(
			vim.wait(15000, function()
				return #vim.diagnostic.get(lua_buffer, { severity = vim.diagnostic.severity.ERROR }) == 0
			end, 100),
			"LSP error remained after repairing the buffer"
		)
		vim.cmd.write()
	end)
end

if run("formatting") then
	check("Node tools use the relocated bundled runtime", function()
		assert(
			vim.fn.exepath("node") == vim.fn.stdpath("data") .. "/mason/node/bin/node",
			"Node resolved outside the bundled Mason runtime: " .. vim.fn.exepath("node")
		)
	end)
	local cases = {
		{ "lua", "main.lua", "stylua", "local answer=42", "local answer = 42" },
		{ "json", "main.json", "prettier", '{"answer":42}', '{ "answer": 42 }' },
		{ "yaml", "main.yaml", "prettier", "answer:    42", "answer: 42" },
		{ "javascript", "main.js", "prettier", "const answer=42", "const answer = 42;" },
		{ "typescript", "main.ts", "prettier", "const answer:number=42", "const answer: number = 42;" },
		{ "sh", "main.sh", "shfmt", "echo    hello", "echo hello" },
	}
	for _, case in ipairs(cases) do
		check("Conform formats " .. case[1] .. " with " .. case[3], function()
			local buffer = fixture("format-" .. case[1], { [case[2]] = { case[4] } }, case[2])
			local conform = require("conform")
			local available = conform.list_formatters(buffer)
			assert(
				vim.iter(available):any(function(item)
					return item.name == case[3] and item.available
				end),
				"Configured formatter is unavailable: " .. vim.inspect(available)
			)
			local done, failure = false, nil
			conform.format({ bufnr = buffer, async = false, timeout_ms = 15000, lsp_format = "never" }, function(err)
				failure, done = err, true
			end)
			assert(done and not failure, "Formatting failed: " .. tostring(failure))
			assert(
				table.concat(vim.api.nvim_buf_get_lines(buffer, 0, -1, false), "\n") == case[5],
				"Unexpected formatted buffer"
			)
			vim.cmd.write()
			assert(
				table.concat(vim.fn.readfile(vim.api.nvim_buf_get_name(buffer)), "\n") == case[5],
				"Saved file differs from formatted buffer"
			)
		end)
	end
	check("ShellCheck reports a real shell error", function()
		local result = vim.system(
			{ "shellcheck", "--format=json", "-" },
			{ text = true, stdin = '#!/bin/sh\necho "$undeclared"\n' }
		):wait(15000)
		assert(result.code == 1, "ShellCheck did not flag the invalid fixture: " .. tostring(result.stderr))
		assert(#vim.json.decode(result.stdout) > 0, "ShellCheck returned no diagnostics")
	end)
	check("eslint_d launcher uses the bundled Node runtime", function()
		local result = vim.system({ "eslint_d", "--version" }, { text = true }):wait(15000)
		assert(result.code == 0 and result.stdout:find("%d+%.%d+"), "eslint_d failed: " .. tostring(result.stderr))
	end)
end

if run("plugins") then
	local buffer = fixture(
		"navigation",
		{ ["target.lua"] = { 'print("airgap_search_needle")' }, ["other.txt"] = { "other" } },
		"target.lua"
	)
	check("File discovery finds an installed-workspace fixture", function()
		local result = vim.system({ "fd", "--type", "f", "target" }, { text = true }):wait(10000)
		assert(result.code == 0 and result.stdout:find("target.lua", 1, true), "File discovery omitted the fixture")
	end)
	check("Text search returns the fixture and line number", function()
		local result = vim.system({ "rg", "--vimgrep", "airgap_search_needle", "." }, { text = true }):wait(10000)
		assert(result.code == 0 and result.stdout:find("target.lua:1:", 1, true), "Text search omitted the fixture")
	end)
	check("Fuzzy filtering selects the expected file", function()
		local result = vim.system({ "fzf", "--filter=target" }, { text = true, stdin = "other.txt\ntarget.lua\n" })
			:wait(10000)
		assert(result.code == 0 and vim.trim(result.stdout) == "target.lua", "Fuzzy filtering selected the wrong file")
	end)
	check("Snacks file picker opens and finds the fixture", function()
		local picker = Snacks.picker.files({ cwd = root .. "/navigation" })
		local ok = vim.wait(15000, function()
			return vim.iter(picker:items()):any(function(item)
				return item.file and item.file:find("target.lua", 1, true)
			end)
		end, 100)
		picker:close()
		assert(ok, "Snacks file picker returned no fixture")
	end)
	check("Snacks grep picker returns a real match", function()
		local picker = Snacks.picker.grep({ cwd = root .. "/navigation", search = "airgap_search_needle" })
		local ok = vim.wait(15000, function()
			return vim.iter(picker:items()):any(function(item)
				return item.file and item.file:find("target.lua", 1, true)
			end)
		end, 100)
		picker:close()
		assert(ok, "Snacks grep picker returned no fixture")
	end)
	check("Snacks explorer opens the workspace", function()
		local picker = Snacks.explorer({ cwd = root .. "/navigation" })
		local ok = vim.wait(15000, function()
			return #picker:items() > 0
		end, 100)
		picker:close()
		assert(ok, "File explorer returned no entries")
	end)
	check("Completion matches symbols without downloading a native library", function()
		local fuzzy = require("blink.cmp.fuzzy")
		assert(
			require("blink.cmp.config").fuzzy.implementation == "lua",
			"Completion can attempt a native-library download"
		)
		local matches =
			fuzzy.fuzzy("airg", 4, { integration = { { label = "airgap_answer" }, { label = "unrelated" } } }, "prefix")
		assert(#matches == 1 and matches[1].label == "airgap_answer", "Completion matcher returned unexpected symbols")
	end)
	check("Normal-mode yank and paste preserve buffer text", function()
		vim.api.nvim_set_current_buf(buffer)
		vim.api.nvim_win_set_cursor(0, { 1, 0 })
		vim.cmd("normal! yyGp")
		local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
		assert(#lines == 2 and lines[1] == lines[2], "Normal-mode yank/paste changed the text")
		vim.cmd.write()
	end)
end

if run("projects") then
	dofile(vim.env.AIRGAP_PROJECT_SCRIPT)(check, fixture, attached, root)
end

vim.fn.writefile({ vim.json.encode(results) }, vim.env.AIRGAP_HEALTH_RESULTS .. "/" .. suite .. "-results.json")
local failures = vim.tbl_filter(function(result)
	return not result.passed
end, results)
assert(#results > 0, "Unknown or empty integration suite: " .. suite)
assert(#failures == 0, #failures .. " of " .. #results .. " editor integration checks failed")
print("Offline editor integration verified: " .. #results .. " checks")
