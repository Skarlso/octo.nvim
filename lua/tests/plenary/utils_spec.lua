---@diagnostic disable
local this = require "octo.utils"
local eq = assert.are.same

describe("Utils module:", function()
  describe("setup", function() --------------------------------------------------
    it("parse_remote_url supports all schemes and aliases.", function()
      local remote_urls = {
        "https://github.com/pwntester/octo.nvim.git",
        "ssh://git@github.com/pwntester/octo.nvim.git",
        "git@github.com:pwntester/octo.nvim.git",
        "git@github.com:pwntester/octo.nvim.git",
        "hub.com:pwntester/octo.nvim.git",
        "hub.com-alias:pwntester/octo.nvim.git",
      }
      local aliases = {
        ["hub.com"] = "github.com",
        ["hub.com-.*"] = "github.com",
      }
      eq(this.parse_remote_url(remote_urls[1], aliases).host, "github.com")
      eq(this.parse_remote_url(remote_urls[1], aliases).repo, "pwntester/octo.nvim")
      eq(this.parse_remote_url(remote_urls[2], aliases).host, "github.com")
      eq(this.parse_remote_url(remote_urls[2], aliases).repo, "pwntester/octo.nvim")
      eq(this.parse_remote_url(remote_urls[3], aliases).host, "github.com")
      eq(this.parse_remote_url(remote_urls[3], aliases).repo, "pwntester/octo.nvim")
      eq(this.parse_remote_url(remote_urls[4], aliases).host, "github.com")
      eq(this.parse_remote_url(remote_urls[4], aliases).repo, "pwntester/octo.nvim")
      eq(this.parse_remote_url(remote_urls[5], aliases).host, "github.com")
      eq(this.parse_remote_url(remote_urls[5], aliases).repo, "pwntester/octo.nvim")
      eq(this.parse_remote_url(remote_urls[6], aliases).host, "github.com")
      eq(this.parse_remote_url(remote_urls[6], aliases).repo, "pwntester/octo.nvim")
    end)

    it("convert_vim_mapping_to_fzf changes vim mappings to fzf mappings", function()
      local utils = require "octo.utils"
      local mappings = {
        ["<C-j>"] = "ctrl-j",
        ["<c-k>"] = "ctrl-k",
        ["<A-J>"] = "alt-j",
        ["<a-k>"] = "alt-k",
        ["<M-Tab>"] = "alt-tab",
        ["<m-UP>"] = "alt-up",
      }

      for vim_mapping, fzf_mapping in pairs(mappings) do
        eq(utils.convert_vim_mapping_to_fzf(vim_mapping), fzf_mapping)
      end
    end)
  end)
end)

describe("Utils escape_char(): ", function()
  it("escapes backslash characters in a string", function()
    local input = [[hello \\ world]]
    local expected = [[hello \\\\ world]]
    eq(expected, this.escape_char(input))
  end)

  it("returns the same string if no escape characters", function()
    local input = [['hello/ ~^'*$"world%]]
    local expected = [['hello/ ~^'*$"world%]]
    eq(expected, this.escape_char(input))
  end)

  it("handles an empty string", function()
    local input = ""
    local expected = ""
    eq(expected, this.escape_char(input))
  end)
end)

describe("Utils parse_remote_url(): ", function()
  it("Should replace remote url with alias", function()
    local ssh_aliases = {
      ["github.com-work"] = "github.com",
    }
    local url = "git@github.com-work:pwntester/octo.nvim.git"

    local expected = {
      host = "github.com",
      repo = "pwntester/octo.nvim",
    }

    eq(expected, this.parse_remote_url(url, ssh_aliases))
  end)

  it("Should replace multiple hyphens in remote url with alias", function()
    local ssh_aliases = {
      ["github.com-octo-work"] = "github.com",
    }
    local url = "git@github.com-octo-work:pwntester/octo.nvim.git"

    local expected = {
      host = "github.com",
      repo = "pwntester/octo.nvim",
    }

    eq(expected, this.parse_remote_url(url, ssh_aliases))
  end)

  it("Should not replace remote url with alias", function()
    local url = "git@github.com-work:pwntester/octo.nvim.git"
    local expected = {
      host = "github.com-work",
      repo = "pwntester/octo.nvim",
    }

    eq(expected, this.parse_remote_url(url, {}))
  end)

  it("Should keep the original url", function()
    local ssh_aliases = {
      ["github.com-work"] = "github.com",
    }
    local url = "git@github.com:pwntester/octo.nvim.git"
    local expected = {
      host = "github.com",
      repo = "pwntester/octo.nvim",
    }
    eq(expected, this.parse_remote_url(url, ssh_aliases))
  end)
end)
describe("get_pages", function()
  it("handles empty single page", function()
    local text = "[]"
    local actual = this.get_pages(text)

    eq(actual, { {} })
  end)
  it("handles multiple pages", function()
    local text = vim.trim [[
      [1,2,3]
      [4,5,6]
      [7,8,9]
    ]]

    local actual = this.get_pages(text)
    eq(actual, { { 1, 2, 3 }, { 4, 5, 6 }, { 7, 8, 9 } })
  end)
end)
describe("get_flatten_pages", function()
  it("handles empty single page", function()
    local text = "[]"
    local actual = this.get_flatten_pages(text)

    eq(actual, {})
  end)
  it("handles multiple list pages", function()
    local text = vim.trim [[
      [1,2,3]
      [4,5,6]
      [7,8,9]
    ]]
    local actual = this.get_flatten_pages(text)

    eq(actual, { 1, 2, 3, 4, 5, 6, 7, 8, 9 })
  end)
  it("handles multiple json pages", function()
    local text = vim.trim [[
      [{"a": 1},{"b": 2, "name": "foo"}]
      [{"c": 3}]
      [{"d": 4}]
    ]]
    local actual = this.get_flatten_pages(text)
    eq(actual, { { a = 1 }, { b = 2, name = "foo" }, { c = 3 }, { d = 4 } })
  end)
end)
describe("parse_url", function()
  it("issues", function()
    local url = "https://github.com/pwntester/octo.nvim/issues/1"
    local repo, number, kind = this.parse_url(url)

    eq(repo, "pwntester/octo.nvim")
    eq(number, "1")
    eq(kind, "issue")
  end)
  it("pull", function()
    local url = "https://github.com/pwntester/octo.nvim/pull/1"
    local repo, number, kind = this.parse_url(url)

    eq(repo, "pwntester/octo.nvim")
    eq(number, "1")
    eq(kind, "pull")
  end)
  it("discussion", function()
    local url = "https://github.com/pwntester/octo.nvim/discussions/1"
    local repo, number, kind = this.parse_url(url)

    eq(repo, "pwntester/octo.nvim")
    eq(number, "1")
    eq(kind, "discussion")
  end)
end)
