-- Options and leader key first: lazy.nvim reads mapleader when it maps the
-- `keys` specs, so it has to be set before plugins are loaded.
require('vim_config')

-- Bootstraps lazy.nvim and loads every file in lua/plugins/
require('plugin')

require('keys')
