local uv = vim.loop
local UV = {}

function UV.exec_async(opts, callback)
  callback = callback or function() end
  local stdout = uv.new_pipe()
  uv.spawn(
    opts.command[1],
    { args = vim.list_slice(opts.command, 2), cwd = opts.cwd, stdio = { nil, stdout, nil } },
    function(code)
      if code ~= 0 then
        -- TODO: log something?
        return callback(code, '')
      end
      local buffer = ''
      uv.read_start(stdout, function(err, data)
        assert(not err, err)
        if data then
          buffer = buffer .. data
          return
        end

        uv.read_stop(stdout)
        stdout:close()
        callback(code, buffer)
      end)
    end
  )
end

return UV
