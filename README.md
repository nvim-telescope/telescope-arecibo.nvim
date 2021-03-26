# telescope-arecibo.nvim
A Neovim Telescope extension for searching the web!


-- bad readme

Packer Installation

 ```
   use {
     "sunjon/telescope-arecibo.nvim",
     rocks = {"openssl", "lua-http-parser"}
   }
 ```


Telescope Config:  `telescope.load_extension("arecibo")`

Keybind function:  `require("telescope").extensions.arecibo.websearch()`

`<C-l>` (in finder) resets search

Highlight groups:


  index          = 'TelescopeAreciboNumber',
  url            = 'TelescopeAreciboUrl',
  prompt_default = 'TelescopePromptPrefix',
  prompt_query   = 'TelescopeAreciboPrompt',



  use {
    "conni2461/telescope.nvim",
    branch = "file_browser",
  }



extensions = {
arecibo = {
	["selected_engine"]   = 'google'
	["url_open_command"]  = 'xdg-open'
	["show_http_headers"] = false
	["show_domain_icons"] = false
},
}


previewer currently depends on `elinks` being installed and probably only works on linux.
