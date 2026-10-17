-- `rex do sessions.lua --json`: every session with the working directory of each
-- of its terminals, for rex-project-picker. Neither `rex ls` nor session.view
-- carries a cwd, so ask each terminal block for its pwd.
local TERM = "com.superlogical.terminal"

local out = {}
for _, s in ipairs((rex.call("session.list") or {}).sessions or {}) do
  local entry = { session_id = s.session_id, label = s.label, pwds = {} }
  -- list_blocks answers 409 until the script's stream is attached to that session
  rex.call("session.attach", { session_id = s.session_id })
  local list = rex.call("session.list_blocks", { session_id = s.session_id }) or {}
  for _, b in ipairs(list.blocks or {}) do
    if b.creator_name == TERM then
      local r = rex.call("block.method", { session_id = s.session_id, block_id = b.block_id, method = "pwd" })
      if r and r.pwd then
        table.insert(entry.pwds, r.pwd)
      end
    end
  end
  rex.call("session.detach", { session_id = s.session_id })
  table.insert(out, entry)
end
return out
