-- Custom JavaScript snippets for LuaSnip
-- Save as ~/.config/nvim/lua/snippets/javascript.lua

local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local fmt = require("luasnip.extras.fmt").fmt

return {
  -- Console log
  s("cl", fmt([[console.log({});]], {
    i(0, "msg"),
  })),

  -- Jest test block
  s("testblock", fmt([[
    test("{}", () => {{
        {}
    }});
  ]], {
    i(1, "description"),
    i(0),
  })),

  -- Jest describe block
  s("describe", fmt([[
    describe("{}", () => {{
        {}
    }});
  ]], {
    i(1, "suite name"),
    i(0),
  })),

  -- Function
  s("fn", fmt([[
    function {}({}) {{
        {}
    }}
  ]], {
    i(1, "name"),
    i(2),
    i(0),
  })),
}



