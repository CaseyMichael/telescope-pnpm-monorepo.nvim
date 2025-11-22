# telescope-pnpm-monorepo.nvim

*Telescope Pnpm Monorepo* is a [Telescope](https://github.com/nvim-telescope/telescope.nvim) extension that automatically detects projects from your `pnpm-workspace.yaml` file and provides a searchable picker to quickly navigate between workspace packages.

The [telescope-pnpm-monorepo.nvim](https://github.com/CaseyMichael/telescope-pnpm-monorepo.nvim) extension makes it easy to switch between projects in a pnpm monorepo without leaving Neovim. It intelligently resolves workspace patterns (like `apps/*` or `packages/*`) and only includes directories with `package.json` files as valid projects.

## Installation

You can install this plugin using your favorite Neovim package manager.

### lazy.nvim

Using `opts` (recommended):

```lua
{
  'CaseyMichael/telescope-pnpm-monorepo.nvim',
  opts = {
    silent = false,              -- Suppress notification messages
    autoload_telescope = true,   -- Automatically load Telescope extension
  },
  dependencies = {
    'nvim-telescope/telescope.nvim',
    'nvim-lua/plenary.nvim',
  },
}
```

Or using `config` function:

```lua
{
  'CaseyMichael/telescope-pnpm-monorepo.nvim',
  config = function()
    require('pnpm_monorepo').setup({
      silent = false,
      autoload_telescope = true,
    })
  end,
  dependencies = {
    'nvim-telescope/telescope.nvim',
    'nvim-lua/plenary.nvim',
  },
}
```

### packer.nvim

```lua
use({
  'CaseyMichael/telescope-pnpm-monorepo.nvim',
  requires = {
    'nvim-telescope/telescope.nvim',
    'nvim-lua/plenary.nvim',
  },
  config = function()
    require('pnpm_monorepo').setup()
  end,
})
```

## Configuration

The plugin accepts the following configuration options:

```lua
require('pnpm_monorepo').setup({
  -- Suppress notification messages
  -- @type boolean
  silent = false,

  -- Automatically load Telescope extension when setup is called
  -- @type boolean
  autoload_telescope = true,
})
```

### Configuration Options

- **`silent`** (`boolean`, default: `false`): When `true`, suppresses notification messages from the plugin.
- **`autoload_telescope`** (`boolean`, default: `true`): When `true`, automatically loads the Telescope extension when `setup()` is called. Set to `false` if you want to manually load the extension later.

## Usage

### Telescope Extension

The plugin provides a Telescope extension that can be activated in two ways:

1. **Automatic** (default): If `autoload_telescope = true`, the extension is automatically loaded when `setup()` is called.

2. **Manual**: Load the extension manually:
```lua
require('telescope').load_extension('pnpm_monorepo')
```

### Opening the Picker

You can open the projects picker using the Telescope command:

```vim
:Telescope pnpm_monorepo
```

Or programmatically from Lua:

```lua
require('telescope').extensions.pnpm_monorepo.pnpm_monorepo()
```

### Keybinding Example

Bind the picker to a key, for example `<leader>m`:

```lua
vim.keymap.set('n', '<leader>m', function()
  require('telescope').extensions.pnpm_monorepo.pnpm_monorepo()
end)
```

Selecting a project from the picker will change Neovim's current working directory to that project root.

### Changing Monorepos

Switch to a different monorepo without restarting Neovim:

```lua
require('pnpm_monorepo').change_monorepo('/path/to/monorepo')
```

The plugin will automatically detect the new monorepo root from `pnpm-workspace.yaml` and reload all projects.

## Health Checks

The plugin provides health checks to help diagnose configuration and setup issues. Run:

```vim
:checkhealth pnpm_monorepo
```

The health check validates:
- Configuration settings
- Required dependencies (plenary.nvim)
- Optional dependencies (telescope.nvim)
- Monorepo detection
- Project loading
- Telescope extension registration

## How It Works

The plugin automatically detects projects by:

1. Walking up the directory tree from your current location to find `pnpm-workspace.yaml`
2. Parsing workspace patterns from the file (e.g., `"apps/*"`, `"packages/*"`)
3. Resolving wildcard patterns to actual directories
4. Filtering to only include directories that contain a `package.json` file

**Example `pnpm-workspace.yaml`:**

```yaml
packages:
  - "apps/*"
  - "packages/*"
  - "tools/*"
```

All directories matching these patterns that contain a `package.json` will be automatically detected as projects.

## Requirements

- **Neovim** 0.9.0 or higher
- **plenary.nvim** (required)
- **telescope.nvim** (optional, but required for picker functionality)

## Troubleshooting

If you encounter issues:

1. Run `:checkhealth pnpm_monorepo` to diagnose problems
2. Ensure you're in a directory with a `pnpm-workspace.yaml` file
3. Verify that `plenary.nvim` is installed and available
4. Check that projects have `package.json` files in their directories
