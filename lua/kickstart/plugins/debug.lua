local function is_in_go_runtime_or_cache()
  local Path = require 'plenary.path'
  local bufname = vim.api.nvim_buf_get_name(0)
  local bufpath = Path:new(bufname):absolute()

  -- Quick substring checks for common Go internals:
  if bufpath:match '/go/pkg/mod/' or bufpath:match '/go/src/' or bufpath:match 'golang.org/toolchain' then
    return true
  end

  -- Optional: deeper segment checks, if you want
  -- (can be omitted if above works well)

  return false
end

return {
  'mfussenegger/nvim-dap',
  dependencies = {
    -- Creates a beautiful debugger UI
    'rcarriga/nvim-dap-ui',

    -- Virtual text provider
    'theHamsta/nvim-dap-virtual-text',

    -- Required dependency for nvim-dap-ui
    'nvim-neotest/nvim-nio',

    -- Installs the debug adapters for you
    'williamboman/mason.nvim',
    'jay-babu/mason-nvim-dap.nvim',

    -- Add your own debuggers here
    'leoluz/nvim-dap-go',
  },
  keys = {
    -- Basic debugging keymaps, feel free to change to your liking!
    {
      '<F5>',
      function()
        local dap = require 'dap'
        if dap.session() then
          dap.continue()
        else
          if is_in_go_runtime_or_cache() then
            vim.notify("don't do that", vim.log.levels.WARN)
            return
          end

          vim.api.nvim_command ':wall'
          local configs = dap.configurations[vim.bo.filetype]
          if configs and #configs > 0 then
            dap.run(configs[1])
          else
            vim.notify('No debug configuration found', vim.log.levels.WARN)
          end
        end
      end,
      desc = 'Debug: Start/Continue',
    },
    {
      '<F6>',
      function()
        local dap = require 'dap'
        if dap.session() then
          dap.terminate()
          vim.notify('Debug session yeeted', vim.log.levels.INFO)
        else
          vim.notify('No active session to yeet', vim.log.levels.WARN)
        end
      end,
      desc = 'Debug: murk running',
    },
    {
      '<F7>',
      function()
        require('dapui').toggle()
      end,
      desc = 'Debug: See last session result.',
    },
    {
      '<F10>',
      function()
        require('dap').step_over()
      end,
      desc = 'Debug: Step Over',
    },
    {
      '<F11>',
      function()
        require('dap').step_into()
      end,
      desc = 'Debug: Step Into',
    },
    {
      '<F12>',
      function()
        require('dap').step_out()
      end,
      desc = 'Debug: Step Out',
    },
    {
      '<leader>b',
      function()
        require('dap').toggle_breakpoint()
      end,
      desc = 'Debug: Toggle Breakpoint',
    },
    {
      '<leader>B',
      function()
        require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ')
      end,
      desc = 'Debug: Set Breakpoint',
    },
  },
  config = function()
    local dap = require 'dap'
    local dapui = require 'dapui'

    require('mason-nvim-dap').setup {
      automatic_installation = true,
      -- You can provide additional configuration to the handlers,
      -- see mason-nvim-dap README for more information
      handlers = {},
      -- You'll need to check that you have the required things installed
      -- online, please don't ask me how to install them :)
      ensure_installed = {
        'delve',
      },
    }

    -- Dap UI setup
    -- For more information, see |:help nvim-dap-ui|
    dapui.setup {
      -- Set icons to characters that are more likely to work in every terminal.
      --    Feel free to remove or use ones that you like more! :)
      --    Don't feel like these are good choices.
      icons = { expanded = '▾', collapsed = '▸', current_frame = '*' },
      controls = {
        icons = {
          pause = '⏸',
          play = '▶',
          step_into = '⏎',
          step_over = '⏭',
          step_out = '⏮',
          step_back = 'b',
          run_last = '▶▶',
          terminate = '⏹',
          disconnect = '⏏',
        },
      },
    }

    require('nvim-dap-virtual-text').setup {}

    -- Change breakpoint icons
    -- vim.api.nvim_set_hl(0, 'DapBreak', { fg = '#e51400' })
    -- vim.api.nvim_set_hl(0, 'DapStop', { fg = '#ffcc00' })
    -- local breakpoint_icons = vim.g.have_nerd_font
    --     and { Breakpoint = '', BreakpointCondition = '', BreakpointRejected = '', LogPoint = '', Stopped = '' }
    --   or { Breakpoint = '●', BreakpointCondition = '⊜', BreakpointRejected = '⊘', LogPoint = '◆', Stopped = '⭔' }
    -- for type, icon in pairs(breakpoint_icons) do
    --   local tp = 'Dap' .. type
    --   local hl = (type == 'Stopped') and 'DapStop' or 'DapBreak'
    --   vim.fn.sign_define(tp, { text = icon, texthl = hl, numhl = hl })
    -- end

    dap.listeners.after.event_initialized['dapui_config'] = dapui.open
    dap.listeners.before.event_terminated['dapui_config'] = dapui.close
    dap.listeners.before.event_exited['dapui_config'] = dapui.close

    local function find_main_go_dir_smart()
      local Path = require 'plenary.path'
      local current = Path:new(vim.api.nvim_buf_get_name(0)):parent()
      local root_limit = Path:new(vim.fn.getcwd())

      while current do
        local main_go = Path:new(current, 'main.go')
        if main_go:exists() then
          return current:absolute()
        end
        if current:absolute() == root_limit:absolute() then
          break
        end
        local parent = Path:new(current):parent()
        if parent == current then
          break
        end
        current = parent
      end
      error 'main.go not found in parents'
    end

    local function find_main_go_dir()
      local Path = require 'plenary.path'
      local current = Path:new(vim.api.nvim_buf_get_name(0)):parent()

      while current do
        local main_go = Path:new(current, 'main.go')
        if main_go:exists() then
          return current:absolute()
        end
        local parent = Path:new(current):parent()
        if parent == current then
          break
        end
        current = parent
      end
      error 'main.go not found in parents'
    end

    dap.configurations.go = {
      {
        type = 'delve',
        name = 'file',
        request = 'launch',
        program = function()
          return find_main_go_dir_smart()
        end,
        outputMode = 'remote',
      },
    }
    -- Install golang specific config
    require('dap-go').setup {
      delve = {
        detached = vim.fn.has 'win32' == 0,
      },
    }

    -- vim.api.nvim_create_autocmd('BufWinEnter', {
    --   pattern = 'DAP REPL',
    --   callback = function()
    --     vim.api.nvim_create_autocmd('TextChanged', {
    --       buffer = 0,
    --       callback = function()
    --         vim.cmd 'normal! G'
    --       end,
    --     })
    --   end,
    -- })

    -- local function resize_dap_repl()
    --   local repl_win = vim.fn.bufwinid 'DAP REPL'
    --   if repl_win ~= -1 then
    --     vim.api.nvim_win_set_height(repl_win, math.max(5, vim.api.nvim_win_get_height(repl_win)))
    --   end
    -- end
    --
    -- -- Automatically resize REPL when it opens
    -- dap.listeners.after.event_initialized['dap_repl_resize'] = function()
    --   vim.defer_fn(resize_dap_repl, 50) -- Slight delay to ensure it's applied
    -- end

    -- -- Function to scroll REPL to bottom
    -- local function scroll_repl()
    --   local repl_bufnr = vim.fn.bufnr 'DAP REPL'
    --   if repl_bufnr ~= -1 then
    --     vim.api.nvim_buf_call(repl_bufnr, function()
    --       vim.cmd 'normal! G'
    --     end)
    --   end
    -- end
    --
    -- -- Automatically scroll REPL when output is received
    -- dap.listeners.after.event_output['dap_repl_scroll'] = function()
    --   vim.defer_fn(scroll_repl, 10)
    -- end
    --
    -- -- Automatically scroll REPL when stepping through code
    -- dap.listeners.after.event_stopped['dap_repl_scroll'] = function()
    --   vim.defer_fn(scroll_repl, 10)
    -- end
  end,
}
