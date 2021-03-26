# telescope-arecibo.nvim
A Neovim Telescope extension for searching the web!

![arecibo](https://user-images.githubusercontent.com/1448118/112658122-63a32c80-8e53-11eb-9797-71eb6176493e.gif)



Arecibo is a customizable plugin that can return web search results in your editor.
It has selectable 'engines' - which are simply TreeSitter queries that are performed againt the retrived HTML document.

The following engines are currently supported:

- Google
- DuckDuckGo
- NPMjs

TODO: guide for creating new engines.

Packer Installation

Arecibo requires the [openssl](https://luarocks.org/modules/zhaozg/openssl) and [lua-http-parser](https://luarocks.org/modules/brimworks/lua-http-parser) lua rocks to be installed in order to retrieve HTTP results.

TODO: add manual rocks installation guide

```
use {
  "sunjon/telescope-arecibo.nvim",
  rocks = {"openssl", "lua-http-parser"}
}
```

### Telescope Config

Loading the extension:

```
telescope.load_extension("arecibo")
```

Extension options:

```
extensions = {
  arecibo = {
    ["selected_engine"]   = 'google',
    ["url_open_command"]  = 'xdg-open',
    ["show_http_headers"] = false,
    ["show_domain_icons"] = false,
  },
}
```

### Keymaps

```
require("telescope").extensions.arecibo.websearch()
```

`<C-l>` (in finder) resets search

### Highlight groups:

- Result Index :       `TelescopeAreciboNumber`
- Result URL   :       `TelescopeAreciboUrl`
- Result Mode Prompt : `TelescopePromptPrefix`
- Query Mode Prompt  : `TelescopeAreciboPrompt`


* Previewer currently depends on `elinks` being installed and probably only works on linux.
