# WIP

Autocompletion for [nvim-dbee](https://github.com/kndndrj/nvim-dbee/) database client.

### TODOs

- [x] schema suggestion.
- [x] model suggestion (tables, views, functions, etc).
- [x] column(s) suggestion (using treesitter, see [queries](./lua/cmp-dbee/queries.lua).
- [ ] add support for completion engines:
  - [x] [nvim-cmp](https://github.com/hrsh7th/nvim-cmp)
  - [ ] [coc.nvim](https://github.com/neoclide/coc.nvim)
  - [ ] [mini.completion](https://github.com/echasnovski/mini.completion)
- [ ] add configuration

Work is expected to be done within the upcoming weeks.

## Installation

- Using **lazy**:

```lua
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      {
        "MattiasMTS/cmp-dbee",
        ft = "sql",
      },
    },
    opts = {
      sources = {
        { "cmp-dbee" },
      },
    },
  }
```
