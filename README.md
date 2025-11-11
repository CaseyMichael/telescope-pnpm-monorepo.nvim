# telescope-pnpm-monorepo.nvim

*Telescope Pnpm Monorepo* is a [Telescope](https://github.com/nvim-telescope/telescope.nvim) extension that automatically detects projects from your `pnpm-workspace.yaml` file and provides a searchable picker to quickly navigate between workspace packages.

The [telescope-pnpm-monorepo.nvim](https://github.com/CaseyMichael/telescope-pnpm-monorepo.nvim) extension makes it easy to switch between projects in a pnpm monorepo without leaving Neovim. It intelligently resolves workspace patterns (like `apps/*` or `packages/*`) and only includes directories with `package.json` files as valid projects.

## Installation

You can install this plugin using your favorite Neovim package manager, e.g. [lazy.nvim](https://github.com/folke/lazy.nvim) and [packer.nvim](https://github.com/wbthomason/packer.nvim).

**lazy.nvim**:
```lua
{
  'CaseyMichael/telescope-pnpm-monorepo.nvim',
  dependencies = {
    'nvim-telescope/telescope.nvim',
    'nvim-lua/plenary.nvim',
  },
  config = function()
    require('pnpm_monorepo').setup({
      silent = false,              -- Suppress notification messages
      autoload_telescope = true,   -- Automatically load Telescope extension
    })
  end,
}
```

**packer.nvim**:
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

## Usage

Activate the custom Telescope commands and `pnpm_monorepo` extension by adding

```lua
require('telescope').load_extension('pnpm_monorepo')
```

somewhere after your `require('telescope').setup()` call. This is typically done automatically if `autoload_telescope = true` (the default).

The following `Telescope` extension command is provided:

```VimL
:Telescope pnpm_monorepo
```

This command can also be used from your `init.lua`.

For example, to bind the picker to `<leader>m` use:

```lua
-- Open pnpm monorepo projects picker
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
