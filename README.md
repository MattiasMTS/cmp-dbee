# cmp-dbee

Autocompletion for [nvim-dbee](https://github.com/kndndrj/nvim-dbee/) database client.

> Still very much a WIP plugin => expect some breaking changes.

## Usage

cmp-dbee is using regex and treesitter to generate suggestions.

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

### TODOs

- [x] schema suggestion.
- [x] model suggestion (tables, views, functions, etc).
- [x] column(s) suggestion via aliases (using treesitter, see [queries](./lua/cmp-dbee/queries.lua); currently only tables supported)
- [ ] add support for completion engines:
  - [x] [nvim-cmp](https://github.com/hrsh7th/nvim-cmp)
  - [ ] [coc.nvim](https://github.com/neoclide/coc.nvim)
  - [ ] [mini.completion](https://github.com/echasnovski/mini.completion)
- [ ] add configuration
- [ ] add query highlighting

Work is expected to be done within the upcoming weeks.
