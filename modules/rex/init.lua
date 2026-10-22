-- Rex keymap, kept close to modules/ai/herdr.nix: ctrl+space prefix, plus
-- ctrl+hjkl that moves through nvim splits and Rex panes as one grid.
local TERM = "com.superlogical.terminal"
local P = "ctrl+space>"

local DIRS = { h = "left", j = "down", k = "up", l = "right" }

-- nix-wrapped programs can show up as ".nvim-wrapped"
local function base_name(s)
  local name = ((s or ""):match("[^/]*$") or ""):gsub("^%.", ""):gsub("%-wrapped_?$", "")
  return name
end

local VIM = { vim = true, nvim = true }

local function pane_is_vim(ctx)
  local p = rex.block.call(TERM, "process", { block_id = ctx.block_id })
  if p == nil then
    -- Unknown pane: hand the key over so nvim splits keep working.
    return true
  end
  local fg = p.foreground
  return fg ~= nil and (VIM[base_name(fg.name)] or VIM[base_name(fg.argv0)]) == true
end

for key, dir in pairs(DIRS) do
  -- Returning false hands the key to the terminal, so nvim (smart-splits)
  -- moves between its splits and calls `rex focus` at its edge.
  rex.bind("ctrl+" .. key, function(ctx)
    if pane_is_vim(ctx) then
      return false
    end
    rex.session.focus_direction({ direction = dir })
    return true
  end)

  rex.bind(P .. key, "pane.focus", { direction = dir })
  rex.bind("ctrl+alt+" .. key, "pane.focus", { direction = dir })
end

-- Press the prefix twice to send it to the terminal.
rex.bind(P .. "ctrl+space", "pane.send_key", { key = "ctrl+space" })

-- Panes
rex.bind(P .. "v", "pane.split", { direction = "right" })
rex.bind(P .. "shift+\\", "pane.split", { direction = "right" }) -- |
rex.bind(P .. "-", "pane.split", { direction = "down" })
rex.bind(P .. "z", "pane.zoom")
rex.bind(P .. "x", "pane.close")
rex.bind(P .. "=", "pane.balance")

-- Tabs
rex.bind(P .. "c", "client.tab.new")
rex.bind(P .. "shift+j", "client.tab.next") -- tabs sit vertically in the sidebar
rex.bind(P .. "shift+k", "client.tab.previous")
rex.bind(P .. ",", "client.tab.rename")
rex.bind(P .. "shift+t", "client.tab.rename")

-- Sessions (herdr workspaces)
rex.bind(P .. "s", "session.switch")
rex.bind(P .. "w", "session.switch")
rex.bind(P .. "shift+n", "session.new")
rex.bind(P .. "n", "session.next")
rex.bind(P .. "p", "session.previous")
rex.bind(P .. "shift+9", "session.previous") -- ( and ) as in tmux
rex.bind(P .. "shift+0", "session.next")
rex.bind(P .. "shift+4", "session.rename") -- $ as in tmux

rex.action({
  name = "goto_session",
  title = "Go to Session by Number",
  args = { index = "integer" },
  run = function(_, args)
    local list, err = rex.call("session.list")
    if err ~= nil then
      error(err, 0)
    end
    local s = list.sessions[args.index]
    if s then
      rex.client.queue("session.select", { session_id = s.session_id })
    end
  end,
})

for i = 1, 9 do
  rex.bind(P .. i, "goto_session", { index = i })
end

-- herdr's popups (prefix+y, prefix+f) run in a split below the pane, not a floating
-- layer: Rex draws a layer's unpainted cells see-through, so fzf would sit on top of
-- the pane's text. The split closes when the command exits.
local function split_below(ctx, command)
  local _, err = rex.session.new_split({
    anchor_block_id = ctx.block_id,
    direction = "vertical",
    side = "after",
    ratio = 0.6,
    focus = true,
    layout = rex.layout.block({
      flavor = "com.superlogical.terminal.shell",
      options = { command = command },
    }),
  })
  if err ~= nil then
    error(err, 0)
  end
end

-- Pick a URL, path or hash from the pane: enter copies it, tab types it into the pane
rex.action({
  name = "hints",
  title = "Copy or Type a Hint from the Pane",
  run = function(ctx)
    split_below(ctx, { "rex-hints", ctx.block_id })
  end,
})
rex.bind(P .. "y", "hints")

-- Pick a project under ~/p: switch to the session already open there, or start one
rex.action({
  name = "projects",
  title = "Open or Switch to a Project Session",
  run = function(ctx)
    split_below(ctx, { "rex-project-picker" })
  end,
})
rex.bind(P .. "f", "projects")

-- Browse the pane's host and insert a shell-escaped path (Rex's own ctrl+cmd+i)
rex.bind(P .. "i", "pane.insert_path")

-- Resize mode, like nvim's <leader>wr submode
rex.mode("resize", { exclusive = true })
rex.bind(P .. "shift+r", "client.mode.enter", { name = "resize" })
for key, dir in pairs(DIRS) do
  rex.bind("resize/" .. key, "pane.resize", { direction = dir })
  rex.bind("resize/shift+" .. key, "pane.resize", { direction = dir, amount = 15 })
end
rex.bind("resize/=", "pane.balance")
rex.bind("resize/q", "client.mode.exit")
rex.bind("resize/enter", "client.mode.exit")

-- App
rex.bind(P .. "r", "client.config.reload")
rex.bind(P .. "shift+s", "client.settings")
rex.bind(P .. "shift+;", "client.palette.toggle") -- :
