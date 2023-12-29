-- Copyright © 2023 Clément Joly
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local M = {}

-- Table of all outputs, so that multiple calls can be made concurrently
-- {
--   [job_id] = {
--     all = {"stderr and stdout, as they happened"}
--     stdout = {"stdout only"}
--   }
-- }
local outputs = {}

-- Add the other lines
local add_lines = function(lines, data)
  for i, new_line in pairs(data) do
    if i == 1 then
      -- Complete the previous line
      lines[#lines] = lines[#lines] .. data[1]
    else
      table.insert(lines, new_line)
    end
  end
end

local record_on_output = function(job_id, data, event)
  if outputs[job_id] == nil then
    outputs[job_id] = { stdout = { "" }, all = { "" } }
  end

  -- Skip EOF
  if #data == 1 and data[1] == "" then
    return nil
  end

  add_lines(outputs[job_id]["all"], data)
  if event == "stdout" then
    add_lines(outputs[job_id]["stdout"], data)
  end
end

-- Format the given buffer, using formatprg when possible. Background limits the
-- messages emited, among other tweaks to make the command easier to run
-- automatically on write. Useful when configured to automatically format on save.
function M.format_with_formatprg(bufnr, background)
  if vim.opt_local.formatprg:get() == "" then
    -- Format and restore view
    local v = vim.fn.winsaveview()
    vim.cmd "normal! gggqG"
    vim.fn.winrestview(v)
  end
  local prg = vim.opt_local.formatprg:get()
  local job_id = vim.fn.jobstart(prg, {
    stderr_buffered = false,
    on_stderr = record_on_output,
    stdout_buffered = false,
    on_stdout = record_on_output,
    on_exit = function(job_id, exit_code)
      -- TODO Check buffer ticks as well
      if exit_code > 0 then
        if not background then
          vim.api.nvim_echo(outputs[job_id], true, {})
          vim.api.nvim_err_writeln("formatprg '" .. prg .. "' failed with code " .. exit_code)
        end
        return
      end
      local formatted_lines = outputs[job_id]["stdout"]
      -- Buffering seems to add a newline at the end, let’s remove it
      table.remove(formatted_lines)
      if #formatted_lines == 0 then
        if not background then
          vim.api.nvim_err_writeln("formatprg '" .. prg .. "' did not emit anything")
        end
        return
      end

      -- Can probably be more efficient and multi-platform friendly, but that
      -- will do for now
      local current_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
      local current_text = table.concat(current_lines, "\n")
      local new_text = table.concat(formatted_lines, "\n")

      -- Need to add line returns because when vim.diff removes a \n on the last
      -- line, it changes the line before only, like this:
      -- - }\n
      -- + }
      -- but we work with a table where "}\n" is {"}", ""}. So we need to make
      -- the indices array a little longer, to account for that
      local indices = vim.diff(current_text .. "\n", new_text .. "\n", {
        algorithm = "minimal", -- We want to minimize the number of marks lost
        result_type = "indices",
      })
      -- Go backward so that we don’t have to deal with outdated line numbers
      for i = #indices, 1, -1 do
        local hunk = indices[i]
        local start_a = hunk[1]
        local count_a = hunk[2]
        local start_b = hunk[3]
        local count_b = hunk[4]

        local source_line_start = start_a - 1
        local source_line_end = start_a + count_a - 1
        -- Handle the insert case gracefully: we want to insert below the line
        -- number given, but nvim_buf_set_lines will insert above. So shift by 1
        if count_a == 0 then
          source_line_start = source_line_start + 1
          source_line_end = source_line_end + 1
        end

        vim.api.nvim_buf_set_lines(
          bufnr,
          source_line_start, -- 0 indexed
          source_line_end, -- end excluded
          true,
          -- Different indexing, 1-based, end included
          { unpack(formatted_lines, start_b, start_b + count_b - 1) }
        )
      end

      -- TODO Remove this fallback eventually
      if
        table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, true), "\n")
        ~= table.concat(formatted_lines, "\n")
      then
        vim.api.nvim_err_writeln "Did not apply the format patch correctly, please report a bug at https://cj.rs/minimal-format-nvim-bug"
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, formatted_lines)
      end
    end,
  })
  vim.fn.chansend(job_id, vim.api.nvim_buf_get_lines(bufnr, 0, -1, true))
  vim.fn.chanclose(job_id, "stdin")

  local timeout = -1
  if background then
    -- Be quick
    timeout = 900 -- ms
  end
  local wait_res = vim.fn.jobwait({ job_id }, timeout)
  if wait_res[1] == -1 then
    vim.api.nvim_err_writeln("formatprg '" .. prg .. "' took too long")
  end
end

local autocmd_group = vim.api.nvim_create_augroup("minimal-format_on_save", { clear = false })

function M.enable_autocmd(bufnr)
  vim.api.nvim_create_autocmd("BufWritePre", {
    group = autocmd_group,
    buffer = 0,
    callback = function()
      M.format_with_formatprg(bufnr, true)
    end,
  })
end

local find_autocmds = function(bufnr)
  return vim.api.nvim_get_autocmds {
    group = autocmd_group,
    event = "BufWritePre",
    buffer = bufnr or 0,
  }
end

-- Non public interface, where the argument is not required
local disable_autocmd = function(auto_cmds, bufnr)
  local autocmds = auto_cmds or find_autocmds(bufnr)
  if #autocmds > 1 then
    vim.api.nvim_err_writeln "Too many autocmds found, aborting"
  end
  vim.api.nvim_del_autocmd(autocmds[1].id)
end

function M.disable_autocmd(bufnr)
  disable_autocmd(nil, bufnr)
end

function M.toggle_autocmd(bufnr)
  local status, autocmds = pcall(find_autocmds)
  if not status or #autocmds == 0 then
    M.enable_autocmd(bufnr)
    print "Enabled autocmd for minimal-format"
  else
    disable_autocmd(autocmds, bufnr)
    print "Disabled autocmd for minimal-format"
  end
end

return M
