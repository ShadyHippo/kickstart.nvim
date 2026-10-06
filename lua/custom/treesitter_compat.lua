-- ============================================================================
-- Neovim 0.12 compatibility shim for nvim-treesitter (master branch).
--
-- Why this exists:
--   Neovim 0.12 changed treesitter query matches to lists of nodes
--   (`table<integer, TSNode[]>`). nvim-treesitter's `master` branch custom
--   directives (`set-lang-from-info-string!`, `set-lang-from-mimetype!`,
--   `downcase!`) still treat the match value as a single node, so any query
--   that uses them fails with:
--       attempt to call method 'range' (a nil value)
--   This breaks markdown code-fence injections (very common) and also the
--   injections of bash, html_tags, ruby, php, hcl and hurl.
--
-- What this does:
--   Re-registers corrected versions of those directives that unwrap the node
--   list. It only runs on Neovim >= 0.12 (where the behavior changed) and is a
--   no-op otherwise.
--
-- To remove:
--   Delete this file and the `require 'custom.treesitter_compat'` line at the
--   bottom of init.lua. The proper long-term fix is migrating nvim-treesitter
--   to its `main` branch, which supports Neovim 0.12 natively.
-- ============================================================================

if vim.fn.has 'nvim-0.12' ~= 1 then
  return
end

local query = vim.treesitter.query

-- Aliases nvim-treesitter maps to a real filetype/parser.
local alias = {
  ex = 'elixir',
  pl = 'perl',
  sh = 'bash',
  uxn = 'uxntal',
  ts = 'typescript',
}

local function resolve_lang(name)
  return vim.filetype.match { filename = 'a.' .. name } or alias[name] or name
end

-- Returns the single captured node from a match entry, or nil.
local function first_node(match, id)
  local nodes = match[id]
  if type(nodes) ~= 'table' or #nodes == 0 then
    return nil
  end
  return nodes[1]
end

-- (#set-lang-from-info-string! @capture) -- markdown fenced code blocks
query.add_directive('set-lang-from-info-string!', function(match, _, bufnr, pred, metadata)
  local node = first_node(match, pred[2])
  if not node then
    return
  end
  metadata['injection.language'] = resolve_lang(vim.treesitter.get_node_text(node, bufnr):lower())
end, { force = true })

-- (#set-lang-from-mimetype! @capture) -- html <script type="...">
query.add_directive('set-lang-from-mimetype!', function(match, _, bufnr, pred, metadata)
  local node = first_node(match, pred[2])
  if not node then
    return
  end
  local mimetype_lang = {
    importmap = 'json',
    module = 'javascript',
    ['application/ecmascript'] = 'javascript',
    ['text/ecmascript'] = 'javascript',
  }
  local value = vim.treesitter.get_node_text(node, bufnr)
  metadata['injection.language'] = mimetype_lang[value] or select(-1, value:gsub('.*/', ''))
end, { force = true })

-- (#downcase! @capture) -- lowercase a captured node's text/metadata
query.add_directive('downcase!', function(match, _, bufnr, pred, metadata)
  local id = pred[2]
  local node = first_node(match, id)
  if not node then
    return
  end
  local text = vim.treesitter.get_node_text(node, bufnr, { metadata = metadata[id] }) or ''
  metadata[id] = metadata[id] or {}
  metadata[id].text = text:lower()
end, { force = true })
