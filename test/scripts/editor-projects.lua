-- Dependency-free workspaces exercise real language backends with empty caches.
return function(check, fixture, attached, root)
	local cache = root .. "/empty-toolchain-caches"
	vim.fn.mkdir(cache, "p")
	for name, value in pairs({
		GOENV = "off",
		GOFLAGS = "",
		GOPROXY = "off",
		GOSUMDB = "off",
		GOTOOLCHAIN = "local",
		GOWORK = "off",
		GOCACHE = cache .. "/go-build",
		GOMODCACHE = cache .. "/go-mod",
		GOPATH = cache .. "/go-path",
		CARGO_HOME = cache .. "/cargo",
		CARGO_NET_OFFLINE = "true",
		PYTHONPATH = "",
		PYTHONNOUSERSITE = "1",
	}) do
		vim.env[name] = value
	end
	local tsc = vim.fn.stdpath("data") .. "/mason/packages/typescript-language-server/node_modules/typescript/bin/tsc"
	local cases = {
		{
			name = "Lua",
			server = "lua_ls",
			file = "main.lua",
			reference = 4,
			files = {
				[".luarc.json"] = { "{}" },
				["main.lua"] = {
					"local function airgap_answer()",
					"  return 42",
					"end",
					"assert(airgap_answer() == 42)",
					"print(42)",
				},
			},
			invalid = { "local =" },
			repaired = { "print(42)" },
			commands = { { "nvim", "--headless", "-u", "NONE", "-i", "NONE", "-l", "main.lua" } },
		},
		{
			name = "Bash",
			server = "bashls",
			file = "main.sh",
			reference = 3,
			files = {
				[".bashrc"] = {},
				["main.sh"] = {
					"#!/bin/bash",
					"airgap_answer() { printf '42\\n'; }",
					"airgap_answer",
				},
			},
			invalid = { "#!/bin/bash", "if then" },
			repaired = { "#!/bin/bash", "echo 42" },
			commands = { { "bash", "main.sh" } },
		},
		{
			name = "Python",
			server = "pyright",
			file = "main.py",
			reference = 4,
			files = {
				["pyrightconfig.json"] = { '{"typeCheckingMode":"basic"}' },
				["main.py"] = {
					"def airgap_answer() -> int:",
					"    return 42",
					"",
					"answer: int = airgap_answer()",
					"assert answer == 42",
					"print(answer)",
				},
			},
			invalid = { 'answer: int = "wrong"' },
			repaired = { "answer: int = 42" },
			commands = { { "python3", "-I", "main.py" } },
		},
		{
			name = "Go",
			server = "gopls",
			file = "main.go",
			reference = 3,
			files = {
				["go.mod"] = { "module offline.test/project", "", "go 1.22" },
				["main.go"] = {
					"package main",
					"func airgap_answer() int { return 42 }",
					"func main() { _ = airgap_answer() }",
				},
				["main_test.go"] = {
					"package main",
					'import "testing"',
					'func TestAirgapAnswer(t *testing.T) { if airgap_answer() != 42 { t.Fatal("wrong answer") } }',
				},
			},
			invalid = { "package main", 'var answer int = "wrong"', "func main() {}" },
			repaired = { "package main", "func airgap_answer() int { return 42 }", "func main() {}" },
			commands = { { "go", "test", "-v", "-count=1", "./..." } },
		},
		{
			name = "Rust",
			server = "rust_analyzer",
			file = "main.rs",
			reference = 2,
			files = {
				["Cargo.toml"] = {
					"[package]",
					'name = "offline-project"',
					'version = "0.1.0"',
					'edition = "2021"',
					"[[bin]]",
					'name = "offline-project"',
					'path = "main.rs"',
				},
				["main.rs"] = {
					"fn airgap_answer() -> i32 { 42 }",
					'fn main() { println!("{}", airgap_answer()); }',
					"#[test] fn test_answer() { assert_eq!(airgap_answer(), 42); }",
				},
			},
			invalid = { 'fn main() { let _answer: i32 = "wrong"; }' },
			repaired = { "fn main() { let _answer: i32 = 42; }" },
			commands = { { "cargo", "test", "--offline" } },
		},
		{
			name = "JavaScript",
			server = "ts_ls",
			file = "main.js",
			reference = 2,
			files = {
				["jsconfig.json"] = { '{"compilerOptions":{"checkJs":true,"allowJs":true,"noEmit":true}}' },
				["main.js"] = {
					"function airgap_answer() { return 42; }",
					"const answer = airgap_answer();",
					'if (answer !== 42) throw new Error("wrong answer");',
					"console.log(answer);",
				},
			},
			invalid = { "/** @type {number} */", 'const answer = "wrong";' },
			repaired = { "const answer = 42;" },
			commands = { { "node", "main.js" }, { "node", tsc, "--project", "jsconfig.json" } },
		},
		{
			name = "TypeScript",
			server = "ts_ls",
			file = "main.ts",
			reference = 2,
			files = {
				["tsconfig.json"] = { '{"compilerOptions":{"strict":true,"outDir":"build"}}' },
				["main.ts"] = {
					"function airgap_answer(): number { return 42; }",
					"const answer = airgap_answer();",
					'if (answer !== 42) throw new Error("wrong answer");',
					"console.log(answer);",
				},
			},
			invalid = { 'const answer: number = "wrong";' },
			repaired = { "const answer: number = 42;" },
			commands = { { "node", tsc, "--project", "tsconfig.json" }, { "node", "build/main.js" } },
		},
	}

	for _, case in ipairs(cases) do
		local buffer, client
		check(case.name .. " project attaches its language server", function()
			buffer = fixture("project-" .. case.name, case.files, case.file)
			client = attached(buffer, case.server)
		end)
		check(case.name .. " project executes its assertions offline", function()
			assert(client, "Project did not attach")
			for _, command in ipairs(case.commands) do
				local result = vim.system(command, { text = true }):wait(120000)
				assert(
					result.code == 0,
					vim.inspect(command) .. " failed: " .. tostring(result.stdout) .. tostring(result.stderr)
				)
				local output = result.stdout .. result.stderr
				if command[1] == "go" then
					assert(output:find("PASS", 1, true), "Go did not execute the test assertion")
				elseif command[1] == "cargo" then
					assert(output:find("1 passed", 1, true), "Rust did not execute the test assertion")
				elseif command[2] ~= tsc then
					assert(vim.trim(output) == "42", "Project returned an unexpected answer: " .. output)
				end
			end
		end)
		check(case.name .. " definition resolves inside its project", function()
			assert(client, "Project did not attach")
			local line = case.files[case.file][case.reference]
			local column = assert(line:find("airgap_answer", 1, true))
			local declaration = (case.name == "Go" or case.name == "Bash") and 1 or 0
			local found = false
			assert(
				vim.wait(30000, function()
					local response = client:request_sync("textDocument/definition", {
						textDocument = { uri = vim.uri_from_bufnr(buffer) },
						position = { line = case.reference - 1, character = column },
					}, 3000, buffer)
					local result = response and response.result
					local locations = result and (result.uri and { result } or result) or {}
					for _, location in ipairs(locations) do
						local range = location.range or location.targetSelectionRange
						if
							(location.uri or location.targetUri) == vim.uri_from_bufnr(buffer)
							and range
							and range.start.line == declaration
						then
							found = true
						end
					end
					return found
				end, 100),
				"No definition in the project fixture"
			)
		end)
		check(case.name .. " completion returns its project symbol", function()
			assert(client, "Project did not attach")
			local completions = {
				Lua = "local answer = airgap_",
				Bash = "airgap_",
				Python = "answer = airgap_",
				Go = "func main() { _ = airgap_ }",
				Rust = "fn main() { let _ = airgap_; }",
				JavaScript = "const answer = airgap_;",
				TypeScript = "const answer = airgap_;",
			}
			local line = completions[case.name]
			local column = assert(line:find("airgap_", 1, true)) - 1 + #"airgap_"
			vim.api.nvim_buf_set_lines(buffer, case.reference - 1, case.reference, false, { line })
			assert(
				vim.wait(30000, function()
					local response = client:request_sync("textDocument/completion", {
						textDocument = { uri = vim.uri_from_bufnr(buffer) },
						position = { line = case.reference - 1, character = column },
					}, 3000, buffer)
					local result = response and response.result
					return vim.iter(result and (result.items or result) or {}):any(function(item)
						return item.label:find("airgap_answer", 1, true) ~= nil
					end)
				end, 100),
				"Completion omitted the project symbol"
			)
		end)
		check(case.name .. " diagnostics appear and clear after repair", function()
			assert(client, "Project did not attach")
			vim.api.nvim_buf_set_lines(buffer, 0, -1, false, case.invalid)
			vim.cmd.write()
			assert(
				vim.wait(30000, function()
					return #vim.diagnostic.get(buffer, { severity = vim.diagnostic.severity.ERROR }) > 0
				end, 100),
				"Invalid project code produced no LSP error"
			)
			vim.api.nvim_buf_set_lines(buffer, 0, -1, false, case.repaired)
			vim.cmd.write()
			assert(
				vim.wait(30000, function()
					return #vim.diagnostic.get(buffer, { severity = vim.diagnostic.severity.ERROR }) == 0
				end, 100),
				"LSP errors remained after repairing the project"
			)
		end)
	end

	for _, case in ipairs({
		{ name = "JSON", server = "jsonls", file = "main.json", good = '{"answer":42}', bad = '{"answer": }' },
		{ name = "YAML", server = "yamlls", file = "main.yaml", good = "answer: 42", bad = "answer: [" },
	}) do
		check(case.name .. " document symbols and syntax diagnostics work offline", function()
			local buffer = fixture("project-" .. case.name, { [case.file] = { case.good }, [".git"] = {} }, case.file)
			local client = attached(buffer, case.server)
			local response = client:request_sync(
				"textDocument/documentSymbol",
				{ textDocument = { uri = vim.uri_from_bufnr(buffer) } },
				15000,
				buffer
			)
			assert(response and not response.err and response.result and #response.result > 0, "No document symbols")
			vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { case.bad })
			assert(
				vim.wait(15000, function()
					return #vim.diagnostic.get(buffer, { severity = vim.diagnostic.severity.ERROR }) > 0
				end, 100),
				"Invalid syntax produced no diagnostics"
			)
			vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { case.good })
			assert(
				vim.wait(15000, function()
					return #vim.diagnostic.get(buffer, { severity = vim.diagnostic.severity.ERROR }) == 0
				end, 100),
				"Syntax diagnostics did not clear"
			)
		end)
	end
	check("Markdown links resolve to another project document", function()
		local buffer = fixture("project-Markdown", {
			[".marksman.toml"] = {},
			["main.md"] = { "# Main", "", "[Other](other.md)" },
			["other.md"] = { "# Other" },
		}, "main.md")
		local client = attached(buffer, "marksman")
		local found = false
		assert(
			vim.wait(15000, function()
				local response = client:request_sync("textDocument/definition", {
					textDocument = { uri = vim.uri_from_bufnr(buffer) },
					position = { line = 2, character = 10 },
				}, 3000, buffer)
				local result = response and response.result
				for _, location in ipairs(result and (result.uri and { result } or result) or {}) do
					if
						(location.uri or location.targetUri) == vim.uri_from_fname(root .. "/project-Markdown/other.md")
					then
						found = true
					end
				end
				return found
			end, 100),
			"Markdown definition did not resolve other.md"
		)
	end)
end
