---@diagnostic disable
local config = require "octo.config"
local fragments = require "octo.gh.fragments"
local queries = require "octo.gh.queries"

config.setup {}
fragments.setup()
queries.setup()

local eq = assert.are.same

describe("stacked PRs", function()
  describe("pull_request query gating", function()
    after_each(function()
      config.values.github_hostname = ""
      queries.setup()
    end)

    it("includes stackEntry on github.com", function()
      config.values.github_hostname = ""
      queries.setup()
      assert.is_truthy(queries.pull_request:find("stackEntry {", 1, true))
      assert.is_nil(queries.pull_request:find("{stackEntry}", 1, true))
    end)

    it("omits stackEntry on GHES", function()
      config.values.github_hostname = "github.example.com"
      queries.setup()
      assert.is_nil(queries.pull_request:find("stackEntry", 1, true))
    end)
  end)
end)
