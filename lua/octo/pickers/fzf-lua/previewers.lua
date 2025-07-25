---@diagnostic disable
local OctoBuffer = require("octo.model.octo-buffer").OctoBuffer
local notifications = require "octo.notifications"
local builtin = require "fzf-lua.previewer.builtin"
local gh = require "octo.gh"
local graphql = require "octo.gh.graphql"
local queries = require "octo.gh.queries"
local utils = require "octo.utils"
local writers = require "octo.ui.writers"
local config = require "octo.config"

local M = {}

---Inherit from the "buffer_or_file" previewer
---@class octo.fzf-lua.Previewer : fzf-lua.previewer.BufferOrFile
M.bufferPreviewer = builtin.buffer_or_file:extend()

function M.bufferPreviewer:new(o, opts, fzf_win)
  M.bufferPreviewer.super.new(self, o, opts, fzf_win)
  setmetatable(self, M.bufferPreviewer)
  -- self.title = true
  return self
end

function M.bufferPreviewer:parse_entry(entry_str)
  -- Assume an arbitrary entry in the format of 'file:line'
  local path, line = entry_str:match "([^:]+):?(.*)"
  return {
    path = path,
    line = tonumber(line) or 1,
    col = 1,
  }
end

-- Disable line numbering and word wrap
function M.bufferPreviewer:gen_winopts()
  local new_winopts = {
    wrap = false,
    number = false,
  }
  return vim.tbl_extend("force", self.winopts, new_winopts)
end

function M.bufferPreviewer:update_border(title)
  self.win:update_preview_title(title)
  self.win:update_preview_scrollbar()
end

function M.issue(formatted_issues)
  ---@type octo.fzf-lua.Previewer
  local previewer = M.bufferPreviewer:extend()

  function previewer:new(o, opts, fzf_win)
    M.bufferPreviewer.super.new(self, o, opts, fzf_win)
    self.title = "Issues"
    setmetatable(self, previewer)
    return self
  end

  function previewer:populate_preview_buf(entry_str)
    local tmpbuf = self:get_tmp_buffer()
    local entry = formatted_issues[entry_str]

    local number = entry.value
    local owner, name = utils.split_repo(entry.repo)
    local query
    if entry.kind == "issue" then
      query = graphql("issue_query", owner, name, number, _G.octo_pv2_fragment)
    elseif entry.kind == "pull_request" then
      query = graphql("pull_request_query", owner, name, number, _G.octo_pv2_fragment)
    end
    gh.run {
      args = { "api", "graphql", "-f", string.format("query=%s", query) },
      cb = function(output, stderr)
        if stderr and not utils.is_blank(stderr) then
          utils.print_err(stderr)
        elseif output and self.preview_bufnr == tmpbuf and vim.api.nvim_buf_is_valid(tmpbuf) then
          local result = vim.json.decode(output)
          local obj
          if entry.kind == "issue" then
            obj = result.data.repository.issue
          elseif entry.kind == "pull_request" then
            obj = result.data.repository.pullRequest
          end

          local state = utils.get_displayed_state(entry.kind == "issue", obj.state, obj.stateReason)

          writers.write_title(tmpbuf, obj.title, 1)
          writers.write_details(tmpbuf, obj)
          writers.write_body(tmpbuf, obj)
          writers.write_state(tmpbuf, state:upper(), number)
          local reactions_line = vim.api.nvim_buf_line_count(tmpbuf) - 1
          writers.write_block(tmpbuf, { "", "" }, reactions_line)
          writers.write_reactions(tmpbuf, obj.reactionGroups, reactions_line)
          vim.bo[tmpbuf].filetype = "octo"
        end
      end,
    }

    self:set_preview_buf(tmpbuf)
    self:update_border(entry.ordinal)
  end

  return previewer
end

function M.search()
  ---@type octo.fzf-lua.Previewer
  local previewer = M.bufferPreviewer:extend()

  function previewer:new(o, opts, fzf_win)
    M.bufferPreviewer.super.new(self, o, opts, fzf_win)
    self.title = "Issues"
    setmetatable(self, previewer)
    return self
  end

  function previewer:populate_preview_buf(entry_str)
    local tmpbuf = self:get_tmp_buffer()
    local match = string.gmatch(entry_str, "[^%s]+")
    local kind = match()
    local owner = match()
    local name = match()
    local number = tonumber(match())

    local query ---@type string
    if kind == "issue" then
      query = graphql("issue_query", owner, name, number, _G.octo_pv2_fragment)
    elseif kind == "pull_request" then
      query = graphql("pull_request_query", owner, name, number, _G.octo_pv2_fragment)
    end
    gh.run {
      args = { "api", "graphql", "-f", string.format("query=%s", query) },
      cb = function(output, stderr)
        if stderr and not utils.is_blank(stderr) then
          utils.print_err(stderr)
        elseif output and self.preview_bufnr == tmpbuf and vim.api.nvim_buf_is_valid(tmpbuf) then
          local result = vim.json.decode(output)
          local obj
          if kind == "issue" then
            obj = result.data.repository.issue
          elseif kind == "pull_request" then
            obj = result.data.repository.pullRequest
          end

          local state = utils.get_displayed_state(kind == "issue", obj.state, obj.stateReason)

          writers.write_title(tmpbuf, obj.title, 1)
          writers.write_details(tmpbuf, obj)
          writers.write_body(tmpbuf, obj)
          writers.write_state(tmpbuf, state:upper(), number)
          local reactions_line = vim.api.nvim_buf_line_count(tmpbuf) - 1
          writers.write_block(tmpbuf, { "", "" }, reactions_line)
          writers.write_reactions(tmpbuf, obj.reactionGroups, reactions_line)
          vim.bo[tmpbuf].filetype = "octo"
        end
      end,
    }

    self:set_preview_buf(tmpbuf)
    -- self:update_border(number.." "..description)
    self.win:update_preview_scrollbar()
  end

  return previewer
end

function M.commit(formatted_commits, repo)
  ---@type octo.fzf-lua.Previewer
  local previewer = M.bufferPreviewer:extend()

  function previewer:new(o, opts, fzf_win)
    M.bufferPreviewer.super.new(self, o, opts, fzf_win)
    setmetatable(self, previewer)
    return self
  end

  function previewer:populate_preview_buf(entry_str)
    local tmpbuf = self:get_tmp_buffer()
    local entry = formatted_commits[entry_str]

    local lines = {}
    vim.list_extend(lines, { string.format("Commit: %s", entry.value) })
    vim.list_extend(lines, { string.format("Author: %s", entry.author) })
    vim.list_extend(lines, { string.format("Date: %s", entry.date) })
    vim.list_extend(lines, { "" })
    vim.list_extend(lines, vim.split(entry.msg, "\n"))
    vim.list_extend(lines, { "" })

    vim.api.nvim_buf_set_lines(tmpbuf, 0, -1, false, lines)
    vim.bo[tmpbuf].filetype = "git"
    vim.api.nvim_buf_add_highlight(tmpbuf, -1, "OctoDetailsLabel", 0, 0, string.len "Commit:")
    vim.api.nvim_buf_add_highlight(tmpbuf, -1, "OctoDetailsLabel", 1, 0, string.len "Author:")
    vim.api.nvim_buf_add_highlight(tmpbuf, -1, "OctoDetailsLabel", 2, 0, string.len "Date:")

    local url = string.format("/repos/%s/commits/%s", repo, entry.value)
    local cmd = table.concat({ "gh", "api", "--paginate", url, "-H", "'Accept: application/vnd.github.v3.diff'" }, " ")
    local proc = io.popen(cmd, "r")
    local output ---@type string
    if proc ~= nil then
      output = proc:read "*a"
      proc:close()
    else
      output = "Failed to read from " .. url
    end

    vim.api.nvim_buf_set_lines(tmpbuf, #lines, -1, false, vim.split(output, "\n"))

    self:set_preview_buf(tmpbuf)
    self:update_border(entry.ordinal)
  end

  return previewer
end

function M.changed_files(formatted_files)
  ---@type octo.fzf-lua.Previewer
  local previewer = M.bufferPreviewer:extend()

  function previewer:new(o, opts, fzf_win)
    M.bufferPreviewer.super.new(self, o, opts, fzf_win)
    setmetatable(self, previewer)
    return self
  end

  function previewer:populate_preview_buf(entry_str)
    local tmpbuf = self:get_tmp_buffer()
    local entry = formatted_files[entry_str]

    local diff = entry.change.patch
    if diff then
      vim.api.nvim_buf_set_lines(tmpbuf, 0, -1, false, vim.split(diff, "\n"))
      vim.bo[tmpbuf].filetype = "git"
    end

    self:set_preview_buf(tmpbuf)
    self:update_border(entry.ordinal)
  end

  return previewer
end

function M.review_thread(formatted_threads)
  ---@type octo.fzf-lua.Previewer
  local previewer = M.bufferPreviewer:extend()

  function previewer:new(o, opts, fzf_win)
    M.bufferPreviewer.super.new(self, o, opts, fzf_win)
    setmetatable(self, previewer)
    return self
  end

  function previewer:populate_preview_buf(entry_str)
    local tmpbuf = self:get_tmp_buffer()
    local entry = formatted_threads[entry_str]

    local buffer = OctoBuffer:new {
      bufnr = tmpbuf,
    }
    buffer:configure()
    buffer:render_threads { entry.thread }
    vim.api.nvim_buf_call(tmpbuf, function()
      vim.cmd [[setlocal foldmethod=manual]]
      vim.cmd [[normal! zR]]
    end)

    self:set_preview_buf(tmpbuf)
    self:update_border(entry.ordinal)
  end

  return previewer
end

function M.gist(formatted_gists)
  ---@type octo.fzf-lua.Previewer
  local previewer = M.bufferPreviewer:extend()

  function previewer:new(o, opts, fzf_win)
    M.bufferPreviewer.super.new(self, o, opts, fzf_win)
    setmetatable(self, previewer)
    return self
  end

  function previewer:populate_preview_buf(entry_str)
    local tmpbuf = self:get_tmp_buffer()

    local entry = formatted_gists[entry_str]

    local file = entry.gist.files[1]
    if file.text then
      vim.api.nvim_buf_set_lines(tmpbuf, 0, -1, false, vim.split(file.text, "\n"))
    else
      vim.api.nvim_buf_set_lines(tmpbuf, 0, -1, false, entry.gist.description)
    end
    vim.api.nvim_buf_call(tmpbuf, function()
      pcall(vim.cmd, "set filetype=" .. string.gsub(file.extension, "\\.", ""))
    end)

    self:set_preview_buf(tmpbuf)
    self:update_border(entry.gist.description)
  end

  return previewer
end

function M.repo(formatted_repos)
  ---@type octo.fzf-lua.Previewer
  local previewer = M.bufferPreviewer:extend()

  function previewer:new(o, opts, fzf_win)
    M.bufferPreviewer.super.new(self, o, opts, fzf_win)
    setmetatable(self, previewer)
    return self
  end

  function previewer:populate_preview_buf(entry_str)
    local tmpbuf = self:get_tmp_buffer()
    local entry = formatted_repos[entry_str]

    local buffer = OctoBuffer:new {
      bufnr = tmpbuf,
    }
    buffer:configure()
    local repo_name_owner = vim.split(entry_str, " ")[1]
    local owner, name = utils.split_repo(repo_name_owner)

    local function cb(output, _)
      -- when the entry changes `preview_bufnr` will also change (due to `set_preview_buf`)
      -- and `tmpbuf` within this context is already cleared and invalidated
      if self.preview_bufnr == tmpbuf and vim.api.nvim_buf_is_valid(tmpbuf) then
        local resp = vim.json.decode(output)
        buffer.node = resp.data.repository
        buffer:render_repo()
      end
    end
    gh.api.graphql {
      query = queries.repository,
      f = { owner = owner, name = name },
      paginate = true,
      jq = ".",
      opts = { cb = cb },
    }
    self:set_preview_buf(tmpbuf)

    ---@type string, string
    local stargazer, fork
    if config.values.picker_config.use_emojis then
      stargazer = string.format("💫: %s", entry.repo.stargazerCount)
      fork = string.format("🔱: %s", entry.repo.forkCount)
    else
      stargazer = string.format("s: %s", entry.repo.stargazerCount)
      fork = string.format("f: %s", entry.repo.forkCount)
    end
    self:update_border(string.format("%s (%s, %s)", repo_name_owner, stargazer, fork))
  end

  return previewer
end

function M.issue_template(formatted_templates)
  ---@type octo.fzf-lua.Previewer
  local previewer = M.bufferPreviewer:extend()

  function previewer:new(o, opts, fzf_win)
    M.bufferPreviewer.super.new(self, o, opts, fzf_win)
    setmetatable(self, previewer)
    return self
  end

  function previewer:populate_preview_buf(entry_str)
    local tmpbuf = self:get_tmp_buffer()
    local entry = formatted_templates[entry_str]
    local template = entry.template.body

    if template then
      vim.api.nvim_buf_set_lines(tmpbuf, 0, -1, false, vim.split(template, "\n"))
      vim.bo[tmpbuf].filetype = "markdown"
    end

    self:set_preview_buf(tmpbuf)
    self:update_border(entry.value)
    self.win:update_preview_scrollbar()
  end

  return previewer
end

---@param formatted_notifications table<string, octo.NotificationEntry>
---@return fzf-lua.previewer.BufferOrFile
function M.notifications(formatted_notifications)
  local previewer = M.bufferPreviewer:extend() ---@type fzf-lua.previewer.BufferOrFile

  function previewer:new(o, opts, fzf_win)
    M.bufferPreviewer.super.new(self, o, opts, fzf_win)
    setmetatable(self, previewer)
    return self
  end

  function previewer:populate_preview_buf(entry_str)
    local tmpbuf = self:get_tmp_buffer() ---@type integer
    local entry = formatted_notifications[entry_str]
    local number = entry.value ---@type string
    local owner, name = utils.split_repo(entry.repo)

    notifications.populate_preview_buf(tmpbuf, owner, name, number, entry.kind)
    self:set_preview_buf(tmpbuf)
    self:update_border(entry.value)
    self.win:update_preview_scrollbar()
  end

  return previewer
end

return M
