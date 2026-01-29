-- Custom C++ snippets for LuaSnip
-- Save as ~/.config/nvim/lua/snippets/cpp.lua

local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local fmt = require("luasnip.extras.fmt").fmt

return {
  -- Google Test boilerplate
  s("gtest", fmt([[
    #include <gtest/gtest.h>

    TEST({}, {}) {{
        {}
    }}
  ]], {
    i(1, "TestSuite"),
    i(2, "TestName"),
    i(0),
  })),

  -- Google Test fixture
  s("gfixture", fmt([[
    class {} : public ::testing::Test {{
    protected:
        void SetUp() override {{
            {}
        }}

        void TearDown() override {{
            {}
        }}
    }};

    TEST_F({}, {}) {{
        {}
    }}
  ]], {
    i(1, "FixtureName"),
    i(2, "// setup"),
    i(3, "// teardown"),
    rep(1), -- reuse FixtureName
    i(4, "TestName"),
    i(0),
  })),

  -- Main function
  s("main", fmt([[
    int main(int argc, char **argv) {{
        {}
        return 0;
    }}
  ]], {
    i(0),
  })),
}
