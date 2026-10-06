-- ============================================================================
-- opencode.nvim (sudo-tee) — in-Neovim chat + agent surface for opencode.
--
-- Scope: CHAT + AGENT workflows only. There is deliberately NO inline /
-- ghost-text / AI autocomplete anywhere in this file. Your existing
-- nvim-cmp setup (LSP / snippets / path) is untouched and gains no AI source.
--
-- Self-contained & removable:
--   * Loaded via `{ import = 'custom.plugins' }` in init.lua.
--   * To remove entirely: delete this file (init.lua needs no change).
--   * To swap to another agent UI (e.g. NickvanDyke): replace the spec below.
--
-- Requires the `opencode` CLI on PATH (already installed via mise, v1.x).
-- sudo-tee auto-detects OpenCode v1/v2 protocols, so no version pin is needed.
-- If a future plugin update breaks it, pin a working commit with `commit = ...`.
--
-- Docs: https://github.com/sudo-tee/opencode.nvim
-- ============================================================================

return {
  {
    'sudo-tee/opencode.nvim',
    config = function()
      require('opencode').setup {
        -- Reuse the picker + completion plugins this config already has.
        -- NOTE: `nvim-cmp` here only powers file/command mentions inside the
        -- opencode *input buffer* — it is not code autocompletion.
        preferred_picker = 'telescope',
        preferred_completion = 'nvim-cmp',

        -- Default mappings live under <leader>o (free in this config).
        -- Core workflow:
        --   <leader>og  toggle the opencode window
        --   <leader>oi  open input (current session)
        --   <leader>oI  open input (new session)
        --   <leader>os  select/load a previous session
        --   <leader>o/  quick chat with current context
        -- In visual mode (send a highlighted snippet, VS Code-style):
        --   <leader>oy  add selection to context
        --   <leader>oY  insert selection inline into input as a code block
        -- Diff review: <leader>od open, <leader>o] / o[ next/prev, <leader>oc close
        --   <leader>orA revert all since last prompt, <leader>orT revert this
        -- Press <leader>o and wait for which-key to discover the rest.
        keymap_prefix = '<leader>o',
        default_global_keymaps = true,

        -- Docked layout: a persistent vertical split on the right, NOT a float.
        -- (Only the quick-chat `<leader>o/` is a small floating input.)
        ui = {
          position = 'right', -- 'right'|'left'|'top'|'bottom'|'current'
          input_position = 'bottom',
          window_width = 0.40,
          persist_state = true, -- keep the pane/buffers alive across toggles
        },

        -- Esc must NOT close the chat (stray Alt/ESC sequences used to nuke it).
        -- Close deliberately with <leader>oq, or toggle with <leader>og.
        keymap = {
          input_window = { ['<esc>'] = false },
          output_window = { ['<esc>'] = false },
          editor = { ['<leader>oq'] = { 'close' } },
        },

        opencode_executable = 'opencode',
      }
    end,
    dependencies = {
      {
        'MeanderingProgrammer/render-markdown.nvim',
        -- Only render opencode's chat output. Normal Markdown editing is
        -- intentionally left untouched (your markdown lint/format stays as-is).
        opts = {
          anti_conceal = { enabled = false },
          file_types = { 'opencode_output' },
        },
        ft = { 'opencode_output' },
      },
      -- Already in this config; declared so opencode.nvim can wire them up.
      'nvim-telescope/telescope.nvim',
      'hrsh7th/nvim-cmp',
    },
  },
}
