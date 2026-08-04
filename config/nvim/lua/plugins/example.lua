-- Your own plugins and LazyVim overrides go in this directory.
-- Every .lua file under lua/plugins/ is loaded automatically, so you can
-- split things into as many files as you like.
--
-- Full reference: https://lazy.folke.io/spec

return {
  -- Add a plugin:
  -- { "folke/todo-comments.nvim" },

  -- Override a LazyVim plugin's options (merged with LazyVim's defaults):
  -- {
  --   "nvim-telescope/telescope.nvim",
  --   opts = { defaults = { layout_strategy = "horizontal" } },
  -- },

  -- Disable a plugin LazyVim enables by default:
  -- { "akinsho/bufferline.nvim", enabled = false },

  -- Enable a LazyVim "extra" (language packs, coding tools, etc.). These are
  -- normally managed with `:LazyExtras`, which writes lazyvim.json next to
  -- this config. You can also list them here explicitly:
  -- { import = "lazyvim.plugins.extras.lang.typescript" },
}
