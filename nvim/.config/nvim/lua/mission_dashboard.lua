local M = {}

function M.setup()
  if vim.g.mission_dashboard_loaded then
    return
  end
  vim.g.mission_dashboard_loaded = true

  local uv = vim.uv or vim.loop
  local state_root = vim.fn.stdpath("state") .. "/mission-dashboard"
  local registry_path = state_root .. "/registry.json"
  local results_path = state_root .. "/checks.json"
  local dashboard_buf
  local poll_timer
  local snapshots = {}
  local origin_by_tab = {}
  local previous_agent_signature
  local sidekick_checked = false
  local augroup = vim.api.nvim_create_augroup("MissionDashboard", { clear = true })

  local function read_json(path)
    local fd = uv.fs_open(path, "r", 438)
    if not fd then
      return nil, "fichier absent"
    end
    local stat = uv.fs_fstat(fd)
    local data = uv.fs_read(fd, stat and stat.size or 0, 0)
    uv.fs_close(fd)
    if not data then
      return nil, "lecture impossible"
    end
    local ok, decoded = pcall(vim.json.decode, data)
    if not ok then
      return nil, "JSON invalide"
    end
    return decoded
  end

  local function write_json(path, value)
    vim.fn.mkdir(state_root, "p", 448)
    local tmp = path .. ".tmp-" .. tostring(uv.hrtime())
    local fd, err = uv.fs_open(tmp, "w", 384)
    if not fd then
      return nil, err
    end
    local ok, write_err = uv.fs_write(fd, vim.json.encode(value) .. "\n", 0)
    if ok then
      uv.fs_fsync(fd)
    end
    uv.fs_close(fd)
    if not ok then
      uv.fs_unlink(tmp)
      return nil, write_err
    end
    local renamed, rename_err = uv.fs_rename(tmp, path)
    if not renamed then
      uv.fs_unlink(tmp)
      return nil, rename_err
    end
    return true
  end

  local function normalize(path)
    return vim.fn.fnamemodify(vim.fn.resolve(path), ":p"):gsub("/$", "")
  end

  local function mission_root(start)
    local path = normalize(start)
    while path ~= "" do
      if vim.fn.filereadable(path .. "/.team/board.json") == 1 then
        return path
      end
      local parent = vim.fs.dirname(path)
      if parent == path then
        break
      end
      path = parent
    end
  end

  local function registry()
    local value, err = read_json(registry_path)
    if not value then
      if vim.fn.filereadable(registry_path) == 0 then
        return { schema = 1, projects = {} }
      end
      return nil, err
    end
    if type(value) ~= "table" or value.schema ~= 1 or type(value.projects) ~= "table" then
      return nil, "format d’index non pris en charge"
    end
    for _, project in ipairs(value.projects) do
      if type(project) ~= "table" or type(project.root) ~= "string" then
        return nil, "entrée invalide dans l’index"
      end
    end
    return value
  end

  local function valid_board(root)
    local board, err = read_json(root .. "/.team/board.json")
    if not board then
      return nil, err
    end
    if type(board) ~= "table" or board.schema ~= 1 or type(board.tickets) ~= "table" then
      return nil, "schéma de board non pris en charge"
    end
    return board
  end

  local function read_mission_title(root)
    local lines = vim.fn.readfile(root .. "/.team/mission.md", "", 1)
    return lines[1] and lines[1]:match("^#%s+(.+)$") or vim.fn.fnamemodify(root, ":t")
  end

  local function register_root(root)
    root = normalize(root)
    if not valid_board(root) then
      return false
    end
    local index = registry()
    if not index then
      return false
    end
    for _, project in ipairs(index.projects) do
      if normalize(project.root) == root then
        return false
      end
    end
    index.projects[#index.projects + 1] = { root = root, label = read_mission_title(root) }
    table.sort(index.projects, function(a, b) return a.root < b.root end)
    write_json(registry_path, index)
    return true
  end

  local function current_mission()
    local root = mission_root(vim.fn.getcwd())
    if not root then
      return nil, "aucun .team/board.json trouvé depuis le répertoire courant"
    end
    local board, err = valid_board(root)
    if not board then
      return nil, "board illisible : " .. err
    end
    return { root = root, board = board }
  end

  local function current_project_root()
    local buf = vim.api.nvim_get_current_buf()
    if vim.bo[buf].buftype == "" then
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= "" and vim.fn.fnamemodify(name, ":p") == name then
        local root = mission_root(vim.fs.dirname(name))
        if root then return root end
      end
    end
    return mission_root(vim.fn.getcwd())
  end

  local function dashboard_buffer()
    if dashboard_buf and vim.api.nvim_buf_is_valid(dashboard_buf) then
      return dashboard_buf
    end
    local existing = vim.fn.bufnr("MissionDashboard")
    dashboard_buf = existing > 0 and existing or vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(dashboard_buf, "MissionDashboard")
    vim.bo[dashboard_buf].buftype = "nofile"
    vim.bo[dashboard_buf].bufhidden = "hide"
    vim.bo[dashboard_buf].swapfile = false
    vim.bo[dashboard_buf].buflisted = false
    vim.bo[dashboard_buf].filetype = "missiondashboard"
    return dashboard_buf
  end

  local function agent_sessions()
    local available = {}
    local ok, lazy = pcall(require, "lazy")
    if ok and not sidekick_checked then
      pcall(lazy.load, { plugins = { "sidekick.nvim" } })
      sidekick_checked = true
    end
    local loaded, state = pcall(require, "sidekick.cli.state")
    if loaded then
      local got, sessions = pcall(state.get)
      if got then
        for _, session in ipairs(sessions) do
          if session.session and session.session.cwd then
            local root = normalize(session.session.cwd)
            available[root] = available[root] or {}
            local label = session.tool.name
            available[root][label] = session.attached and "attachée" or (session.started and "démarrée" or "présente")
          end
        end
      end
    end
    return available
  end

  local dashboard_ns = vim.api.nvim_create_namespace("MissionDashboard")
  local row_actions = {}
  local dashboard_width = 48

  local function fit(text, width)
    text = tostring(text or "")
    if vim.fn.strdisplaywidth(text) <= width then return text end
    local out = ""
    for i = 0, vim.fn.strchars(text) - 1 do
      local char = vim.fn.strcharpart(text, i, 1)
      if vim.fn.strdisplaywidth(out .. char .. "…") > width then break end
      out = out .. char
    end
    return out .. "…"
  end

  local function add_line(lines, spans, actions, text, group, action, accent)
    text = fit(text, dashboard_width)
    local row = #lines + 1
    lines[row] = text
    if group then spans[#spans + 1] = { row = row - 1, start = 0, finish = #text, group = group } end
    if accent then spans[#spans + 1] = { row = row - 1, start = accent[1], finish = accent[2], group = accent[3] } end
    if action then actions[row] = action end
  end

  local function add_highlights()
    vim.api.nvim_set_hl(0, "MissionDashboardTitle", { link = "Title", default = true })
    vim.api.nvim_set_hl(0, "MissionDashboardProject", { link = "DiagnosticInfo", default = true })
    vim.api.nvim_set_hl(0, "MissionDashboardMuted", { link = "Comment", default = true })
    vim.api.nvim_set_hl(0, "MissionDashboardActive", { link = "DiagnosticWarn", default = true })
    vim.api.nvim_set_hl(0, "MissionDashboardDone", { link = "DiagnosticOk", default = true })
    vim.api.nvim_set_hl(0, "MissionDashboardBlocked", { link = "DiagnosticError", default = true })
    vim.api.nvim_set_hl(0, "MissionDashboardReady", { link = "Special", default = true })
  end

  local function state_style(state)
    local styles = {
      developing = { "●", "MissionDashboardActive" },
      verifying = { "◌", "MissionDashboardReady" },
      integrating = { "↻", "MissionDashboardReady" },
      correcting = { "!", "MissionDashboardBlocked" },
      blocked = { "×", "MissionDashboardBlocked" },
      ready = { "○", "MissionDashboardReady" },
      draft = { "·", "MissionDashboardMuted" },
      done = { "✓", "MissionDashboardDone" },
    }
    return unpack(styles[state] or { "?", "MissionDashboardMuted" })
  end

  local function short_path(path)
    return path:gsub("/$", ""):match("([^/]+/[^/]+)$") or path
  end

  local function make_lines()
    local index, err = registry()
    local lines, spans, actions = {}, {}, {}
    if not index then
      add_line(lines, spans, actions, "  MISSION CONTROL", "MissionDashboardTitle")
      add_line(lines, spans, actions, "  Index local illisible · " .. tostring(err), "MissionDashboardBlocked")
      return lines, spans, actions
    end
    local checks = read_json(results_path)
    if type(checks) ~= "table" or checks.schema ~= 1 or type(checks.results) ~= "table" then
      checks = { schema = 1, results = {} }
    end
    local sessions = agent_sessions()
    add_line(lines, spans, actions, "  MISSION CONTROL", "MissionDashboardTitle")
    add_line(lines, spans, actions, string.format("  %d worktree(s) suivis", #index.projects), "MissionDashboardMuted")
    add_line(lines, spans, actions, "  Entrée détails · c contrôles · q fermer", "MissionDashboardMuted")
    add_line(lines, spans, actions, "  a suivre · d retirer · r actualiser", "MissionDashboardMuted")
    add_line(lines, spans, actions, string.rep("─", dashboard_width), "MissionDashboardMuted")
    if #index.projects == 0 then
      add_line(lines, spans, actions, "  Aucun worktree avec .team/ détecté.", "MissionDashboardMuted")
      add_line(lines, spans, actions, "  Ouvre le projet : il sera suivi automatiquement.", "MissionDashboardMuted")
    end
    for _, entry in ipairs(index.projects) do
      local root = normalize(entry.root)
      local board, board_err = valid_board(root)
      add_line(lines, spans, actions, "  ◆ " .. (entry.label or root), "MissionDashboardProject", { type = "project", root = root })
      add_line(lines, spans, actions, "    " .. short_path(root), "MissionDashboardMuted")
      if not board then
        add_line(lines, spans, actions, "    Board inaccessible · " .. tostring(board_err), "MissionDashboardBlocked")
      else
        local active = 0
        for _, ticket in pairs(board.tickets) do
          if type(ticket) == "table" then
            if ticket.state == "developing" then active = active + 1 end
          end
        end
        local agent = sessions[root] or {}
        local function agent_mark(name)
          local value = agent[name]
          if value == "attachée" then return "●" end
          if value then return "◉" end
          return "–"
        end
        add_line(lines, spans, actions,
          string.format("    CLI  C%s  Cl%s  O%s  Cp%s", agent_mark("codex"), agent_mark("claude"), agent_mark("opencode"), agent_mark("copilot")),
          "MissionDashboardMuted")
        add_line(lines, spans, actions,
          string.format("    %d actif(s) · %d ticket(s)", active, vim.tbl_count(board.tickets)),
          active > 0 and "MissionDashboardActive" or "MissionDashboardMuted")
        local ids = vim.tbl_keys(board.tickets)
        local rank = { developing = 1, blocked = 2, correcting = 3, verifying = 4, integrating = 5, ready = 6, draft = 7, done = 8 }
        table.sort(ids, function(a, b)
          local ta, tb = board.tickets[a], board.tickets[b]
          local ra = type(ta) == "table" and (rank[ta.state] or 9) or 10
          local rb = type(tb) == "table" and (rank[tb.state] or 9) or 10
          return ra == rb and a < b or ra < rb
        end)
        for _, id in ipairs(ids) do
          local ticket = board.tickets[id]
          if type(ticket) == "table" then
            local evidence = type(ticket.evidence) == "table" and ticket.evidence or {}
            local glyph, group = state_style(ticket.state)
            local prefix = string.format("      %s %-3s ", glyph, id)
            local suffix = string.format("  %d p.", #evidence)
            local title_width = math.max(6, dashboard_width - vim.fn.strdisplaywidth(prefix) - vim.fn.strdisplaywidth(suffix))
            local row = prefix .. fit(ticket.title or id, title_width) .. suffix
            add_line(lines, spans, actions, row, "MissionDashboardMuted", { type = "ticket", root = root, id = id, title = ticket.title or id, state = ticket.state })
            local line = #lines - 1
            spans[#spans + 1] = { row = line, start = #"      ", finish = #prefix, group = group }
          else
            add_line(lines, spans, actions, "      × Ticket " .. tostring(id) .. " invalide", "MissionDashboardBlocked")
          end
        end
        if #ids == 0 then add_line(lines, spans, actions, "      Aucun ticket pour cette mission.", "MissionDashboardMuted") end
        local results = checks.results[root]
        if type(results) == "table" and type(results[1]) == "table" then
          local result = results[1]
          add_line(lines, spans, actions,
            string.format("    %s %s · %ss", result.ok and "✓" or "×", tostring(result.id), tostring(result.seconds)),
            result.ok and "MissionDashboardDone" or "MissionDashboardBlocked")
        end
      end
      add_line(lines, spans, actions, "", nil)
    end
    return lines, spans, actions
  end

  local function render()
    local buf = dashboard_buffer()
    local visible = vim.fn.win_findbuf(buf)
    if #visible > 0 then
      dashboard_width = math.max(20, vim.api.nvim_win_get_width(visible[1]) - 2)
    elseif vim.o.columns >= 110 then
      dashboard_width = math.min(46, vim.o.columns - 8)
    else
      dashboard_width = math.min(72, vim.o.columns - 8)
    end
    add_highlights()
    local cursor_by_win = {}
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      cursor_by_win[win] = vim.api.nvim_win_get_cursor(win)
    end
    vim.bo[buf].modifiable = true
    local lines, spans, actions = make_lines()
    row_actions = actions
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_clear_namespace(buf, dashboard_ns, 0, -1)
    for _, span in ipairs(spans) do
      vim.api.nvim_buf_add_highlight(buf, dashboard_ns, span.group, span.row, span.start, span.finish)
    end
    vim.bo[buf].modifiable = false
    for win, cursor in pairs(cursor_by_win) do
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
        local last = math.max(1, vim.api.nvim_buf_line_count(buf))
        pcall(vim.api.nvim_win_set_cursor, win, { math.min(cursor[1], last), cursor[2] })
      end
    end
    return buf
  end

  local function panel_win(tab)
    if not dashboard_buf or not vim.api.nvim_buf_is_valid(dashboard_buf) then return nil end
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab or vim.api.nvim_get_current_tabpage())) do
      if vim.api.nvim_win_get_buf(win) == dashboard_buf then return win end
    end
  end

  local function anchor_win(tab)
    local current = vim.api.nvim_get_current_win()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      if vim.api.nvim_win_get_buf(win) ~= dashboard_buf
        and vim.bo[vim.api.nvim_win_get_buf(win)].buftype ~= "terminal"
        and vim.api.nvim_win_get_config(win).relative == "" then
        return win
      end
    end
    return current
  end

  local function layout_for(anchor)
    local width = math.min(48, math.max(38, math.floor(vim.o.columns * 0.32)))
    local height = math.min(14, math.max(9, math.floor(vim.o.lines * 0.28)))
    local source_width = vim.api.nvim_win_get_width(anchor)
    local source_height = vim.api.nvim_win_get_height(anchor)
    if source_width >= width + 64 then
      return "vertical", width, height
    end
    if source_height >= height + 8 then
      return "horizontal", width, height
    end
    return "float", math.max(20, math.min(64, vim.o.columns - 8)), math.max(5, math.min(16, vim.o.lines - 8))
  end

  local function set_panel_options(win, mode)
    local wo = vim.wo[win]
    wo.number = false
    wo.relativenumber = false
    wo.signcolumn = "no"
    wo.foldcolumn = "0"
    wo.wrap = false
    wo.cursorline = true
    wo.winfixwidth = mode == "vertical"
    wo.winfixheight = mode == "horizontal"
  end

  local function close_panel()
    local tab = vim.api.nvim_get_current_tabpage()
    local win = panel_win(tab)
    if win then
      vim.api.nvim_win_close(win, true)
    end
  end

  local function open_panel(focus)
    local tab = vim.api.nvim_get_current_tabpage()
    local buf = render()
    local win = panel_win(tab)
    if win then
      if focus then vim.api.nvim_set_current_win(win) end
      return win
    end
    local previous = vim.api.nvim_get_current_win()
    local anchor = anchor_win(tab)
    origin_by_tab[tab] = anchor
    vim.api.nvim_set_current_win(anchor)
    local mode, width, height = layout_for(anchor)
    if mode == "vertical" then
      vim.cmd("botright vsplit")
    elseif mode == "horizontal" then
      vim.cmd("botright new")
    else
      local float_width, float_height = width, height
      win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        style = "minimal",
        border = "rounded",
        width = float_width,
        height = float_height,
        row = math.max(0, math.floor((vim.o.lines - float_height) / 2) - 1),
        col = math.max(0, math.floor((vim.o.columns - float_width) / 2)),
        title = " Missions agentiques ",
        title_pos = "center",
      })
    end
    if mode ~= "float" then
      win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(win, buf)
      if mode == "vertical" then
        vim.api.nvim_win_set_width(win, width)
      else
        vim.api.nvim_win_set_height(win, height)
      end
    end
    set_panel_options(win, mode)
    render()
    if not focus and vim.api.nvim_win_is_valid(previous) and previous ~= win then
      vim.api.nvim_set_current_win(previous)
    elseif focus then
      vim.api.nvim_set_current_win(win)
    end
    return win
  end

  local function toggle_panel()
    if panel_win() then close_panel() else open_panel(true) end
  end

  local function show_output(title, output)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, "MissionCheck:" .. title .. ":" .. tostring(uv.hrtime()))
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(output ~= "" and output or "(aucune sortie)", "\n", { plain = true }))
    local width = math.max(20, math.min(100, vim.o.columns - 6))
    local height = math.max(5, math.min(24, vim.o.lines - 6))
    local win = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      style = "minimal",
      border = "rounded",
      width = width,
      height = height,
      row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
      col = math.max(0, math.floor((vim.o.columns - width) / 2)),
      title = " " .. title .. " ",
      title_pos = "center",
    })
    vim.wo[win].wrap = true
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "no"
    vim.keymap.set("n", "q", function() if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end end, { buffer = buf, nowait = true, silent = true })
  end

  local function show_ticket_details(action)
    local board, err = valid_board(action.root)
    local lines = { "  " .. action.id .. " · " .. action.title, "" }
    if not board then
      lines[#lines + 1] = "  Board indisponible · " .. tostring(err)
      show_output("Ticket " .. action.id, table.concat(lines, "\n"))
      return
    end
    local ticket = board.tickets[action.id]
    if type(ticket) ~= "table" then
      lines[#lines + 1] = "  Ticket introuvable dans le board."
      show_output("Ticket " .. action.id, table.concat(lines, "\n"))
      return
    end
    lines[#lines + 1] = "  État · " .. tostring(ticket.state or "?") .. "    Rôle · " .. tostring(ticket.role or "non attribué")
    lines[#lines + 1] = "  Projet · " .. action.root
    if type(ticket.depends) == "table" and #ticket.depends > 0 then
      lines[#lines + 1] = "  Dépendances · " .. table.concat(ticket.depends, ", ")
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "  CRITÈRES"
    local evidence = type(ticket.evidence) == "table" and ticket.evidence or {}
    for _, criterion in ipairs(type(ticket.criteria) == "table" and ticket.criteria or {}) do
      local latest
      for _, item in ipairs(evidence) do
        if type(item) == "table" and item.check == criterion then latest = item end
      end
      local state = latest and tostring(latest.result) or "preuve absente"
      lines[#lines + 1] = "  " .. state .. " · " .. tostring(criterion)
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "  Entrée depuis la liste · q fermer"
    show_output("Ticket " .. action.id, table.concat(lines, "\n"))
  end

  local function remove_project(root)
    local index, err = registry()
    if not index then vim.notify(err, vim.log.levels.ERROR); return end
    root = normalize(root)
    local kept, removed = {}, false
    for _, entry in ipairs(index.projects) do
      if normalize(entry.root) == root then removed = true else kept[#kept + 1] = entry end
    end
    if not removed then vim.notify("Worktree non suivi.", vim.log.levels.INFO); return end
    index.projects = kept
    snapshots[root] = nil
    local ok, write_err = write_json(registry_path, index)
    if not ok then vim.notify("Écriture de l’index impossible : " .. tostring(write_err), vim.log.levels.ERROR); return end
    vim.notify("Worktree retiré du suivi.", vim.log.levels.INFO)
    render()
  end

  local function run_check(root)
    local mission, err
    if root then
      local board, board_err = valid_board(root)
      if board then mission = { root = normalize(root), board = board } else err = board_err end
    else
      mission, err = current_mission()
    end
    if not mission then vim.notify(err, vim.log.levels.ERROR); return end
    local config, config_err = read_json(mission.root .. "/.team/checks.json")
    if type(config) ~= "table" or config.schema ~= 1 or type(config.checks) ~= "table" then
      vim.notify("Contrôles indisponibles : " .. tostring(config_err or "format de .team/checks.json invalide"), vim.log.levels.ERROR)
      return
    end
    local choices = {}
    for _, check in ipairs(config.checks) do
      if type(check) == "table" and type(check.id) == "string" and check.id:match("^[%w_-]+$")
        and type(check.label) == "string" and type(check.argv) == "table" and #check.argv > 0 then
        local valid = true
        for _, arg in ipairs(check.argv) do
          if type(arg) ~= "string" or arg == "" or arg:find("%z") then valid = false end
        end
        if valid then choices[#choices + 1] = check end
      end
    end
    if #choices == 0 then vim.notify("Aucun contrôle valide déclaré.", vim.log.levels.WARN); return end
    vim.ui.select(choices, {
      prompt = "Choisir un contrôle à exécuter",
      format_item = function(check) return check.label .. " — " .. table.concat(check.argv, " ") end,
    }, function(selected)
      if not selected then return end
      vim.ui.select({ "Exécuter", "Annuler" }, { prompt = "Confirmer : " .. table.concat(selected.argv, " ") }, function(answer)
        if answer ~= "Exécuter" then return end
        local started = uv.hrtime()
        vim.system(selected.argv, { cwd = mission.root, text = true }, function(result)
          local seconds = math.floor((uv.hrtime() - started) / 10000000) / 100
          vim.schedule(function()
            local history = read_json(results_path)
            if type(history) ~= "table" or history.schema ~= 1 or type(history.results) ~= "table" then
              history = { schema = 1, results = {} }
            end
            history.results[mission.root] = history.results[mission.root] or {}
            table.insert(history.results[mission.root], 1, { id = selected.id, ok = result.code == 0, code = result.code, seconds = seconds, at = os.date("%Y-%m-%dT%H:%M:%S%z") })
            while #history.results[mission.root] > 20 do table.remove(history.results[mission.root]) end
            local saved, save_err = write_json(results_path, history)
            local output = (result.stdout or "") .. (result.stderr and result.stderr ~= "" and ("\n--- stderr ---\n" .. result.stderr) or "")
            show_output(selected.label, output)
            vim.notify(string.format("%s (code %d, %.2fs)%s", result.code == 0 and "Contrôle réussi" or "Contrôle en échec", result.code, seconds, saved and "" or ("; historique non enregistré : " .. tostring(save_err))), result.code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR)
            render()
          end)
        end)
      end)
    end)
  end

  local function setup_keymaps(buf)
    vim.keymap.set("n", "r", render, { buffer = buf, silent = true, nowait = true, desc = "Actualiser les missions" })
    vim.keymap.set("n", "a", function() vim.cmd("TeamMissionAdd") end, { buffer = buf, silent = true, nowait = true })
    vim.keymap.set("n", "d", function()
      local action = row_actions[vim.api.nvim_win_get_cursor(0)[1]]
      if action and action.root then
        vim.ui.select({ "Retirer", "Annuler" }, { prompt = "Ne plus suivre " .. action.root .. " ?" }, function(choice)
          if choice == "Retirer" then remove_project(action.root) end
        end)
      else
        vim.notify("Place le curseur sur une mission ou un ticket.", vim.log.levels.INFO)
      end
    end, { buffer = buf, silent = true, nowait = true })
    vim.keymap.set("n", "c", function()
      local action = row_actions[vim.api.nvim_win_get_cursor(0)[1]]
      run_check(action and action.root or nil)
    end, { buffer = buf, silent = true, nowait = true })
    vim.keymap.set("n", "q", close_panel, { buffer = buf, silent = true, nowait = true })
    vim.keymap.set("n", "<CR>", function()
      local action = row_actions[vim.api.nvim_win_get_cursor(0)[1]]
      if not action then return end
      if action.type == "ticket" then
        show_ticket_details(action)
        return
      end
      local root = action.root
      if vim.fn.isdirectory(root) ~= 1 then vim.notify("Worktree inaccessible.", vim.log.levels.ERROR); return end
      local tab = vim.api.nvim_get_current_tabpage()
      local target = origin_by_tab[tab]
      if not target or not vim.api.nvim_win_is_valid(target) then target = anchor_win(tab) end
      if target and vim.api.nvim_win_is_valid(target) then
        vim.api.nvim_set_current_win(target)
        vim.cmd("lcd " .. vim.fn.fnameescape(root))
      end
    end, { buffer = buf, silent = true, nowait = true })
  end

  local function board_snapshot(board)
    local states, signature = {}, {}
    for _, id in ipairs(vim.tbl_keys(board.tickets)) do
      local ticket = board.tickets[id]
      local state = type(ticket) == "table" and tostring(ticket.state or "?") or "invalid"
      states[id] = state
      signature[#signature + 1] = id .. "=" .. state
      if type(ticket) == "table" then
        signature[#signature + 1] = tostring(type(ticket.evidence) == "table" and #ticket.evidence or 0)
      end
    end
    signature[#signature + 1] = "events=" .. tostring(type(board.events) == "table" and #board.events or 0)
    return table.concat(signature, "|"), states
  end

  local function has_active(states)
    for _, state in pairs(states) do if state == "developing" then return true end end
    return false
  end

  local function session_signature()
    local sessions = agent_sessions()
    local keys = vim.tbl_keys(sessions)
    table.sort(keys)
    local out = {}
    for _, root in ipairs(keys) do
      local names = vim.tbl_keys(sessions[root])
      table.sort(names)
      for _, name in ipairs(names) do out[#out + 1] = root .. ":" .. name .. ":" .. sessions[root][name] end
    end
    return table.concat(out, "|")
  end

  local function panel_visible()
    return dashboard_buf and vim.api.nvim_buf_is_valid(dashboard_buf) and #vim.fn.win_findbuf(dashboard_buf) > 0
  end

  local function poll(initial)
    local cwd = current_project_root()
    if cwd then register_root(cwd) end
    local index = registry()
    if not index then return end
    local changed, started = false, false
    for _, entry in ipairs(index.projects) do
      local root = normalize(entry.root)
      local board = valid_board(root)
      if board then
        local signature, states = board_snapshot(board)
        local previous = snapshots[root]
        if previous then
          if previous.signature ~= signature then changed = true end
          for id, state in pairs(states) do
            if state == "developing" and previous.states[id] ~= "developing" then started = true end
          end
        elseif has_active(states) and not initial then
          started = true
        elseif has_active(states) and initial then
          started = true
        end
        snapshots[root] = { signature = signature, states = states }
      end
    end
    if started then
      open_panel(false)
      if not initial then vim.notify("Mission démarrée : panneau de suivi ouvert sans déplacer le focus.", vim.log.levels.INFO) end
    elseif changed and panel_visible() then
      render()
    end
    if panel_visible() then
      local current = session_signature()
      if current ~= previous_agent_signature then
        previous_agent_signature = current
        render()
      end
    end
  end

  local function start_monitor(initial)
    if poll_timer then return end
    poll(initial)
    poll_timer = uv.new_timer()
    poll_timer:start(1800, 1800, vim.schedule_wrap(function() poll(false) end))
  end

  local function resize_panel()
    local tab = vim.api.nvim_get_current_tabpage()
    local win = panel_win(tab)
    if not win then return end
    local anchor = origin_by_tab[tab]
    if not anchor or not vim.api.nvim_win_is_valid(anchor) then anchor = anchor_win(tab) end
    local wanted = layout_for(anchor)
    local config = vim.api.nvim_win_get_config(win)
    local current = config.relative ~= "" and "float" or (vim.wo[win].winfixwidth and "vertical" or "horizontal")
    if current ~= wanted then
      local focus = vim.api.nvim_get_current_win()
      vim.api.nvim_win_close(win, true)
      if anchor and vim.api.nvim_win_is_valid(anchor) then vim.api.nvim_set_current_win(anchor) end
      open_panel(false)
      if focus ~= win and vim.api.nvim_win_is_valid(focus) then vim.api.nvim_set_current_win(focus) end
    else
      local _, width, height = layout_for(anchor)
      if current == "vertical" then
        vim.api.nvim_win_set_width(win, width)
      elseif current == "horizontal" then
        vim.api.nvim_win_set_height(win, height)
      else
        vim.api.nvim_win_set_config(win, {
          relative = "editor",
          style = "minimal",
          border = "rounded",
          width = width,
          height = height,
          row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
          col = math.max(0, math.floor((vim.o.columns - width) / 2)),
          title = " Missions agentiques ",
          title_pos = "center",
        })
      end
    end
  end

  vim.api.nvim_create_user_command("TeamMissions", function() open_panel(true) end, { desc = "Afficher le panneau des missions" })
  vim.api.nvim_create_user_command("TeamMissionsToggle", toggle_panel, { desc = "Afficher ou fermer le panneau des missions" })
  vim.api.nvim_create_user_command("TeamMissionsClose", close_panel, { desc = "Fermer le panneau des missions" })
  vim.api.nvim_create_user_command("TeamMissionAdd", function()
    local mission, err = current_mission()
    if not mission then vim.notify(err, vim.log.levels.ERROR); return end
    if not register_root(mission.root) then
      local index = registry()
      for _, project in ipairs(index and index.projects or {}) do
        if normalize(project.root) == mission.root then vim.notify("Ce worktree est déjà suivi.", vim.log.levels.INFO); return end
      end
      vim.notify("Impossible d’ajouter ce worktree à l’index.", vim.log.levels.ERROR)
      return
    end
    vim.notify("Worktree ajouté au suivi.", vim.log.levels.INFO)
    render()
  end, { desc = "Suivre le worktree courant" })
  vim.api.nvim_create_user_command("TeamMissionRemove", function()
    local root = mission_root(vim.fn.getcwd())
    if not root then vim.notify("Aucun worktree .team dans le répertoire courant.", vim.log.levels.ERROR); return end
    remove_project(root)
  end, { desc = "Ne plus suivre le worktree courant" })
  vim.api.nvim_create_user_command("TeamMissionCheck", function() run_check() end, { desc = "Lancer un contrôle déclaré pour le worktree courant" })

  vim.api.nvim_create_autocmd("VimEnter", { group = augroup, once = true, callback = function() start_monitor(true) end })
  vim.api.nvim_create_autocmd("DirChanged", { group = augroup, callback = function() poll(true) end })
  vim.api.nvim_create_autocmd("BufEnter", { group = augroup, callback = function() poll(true) end })
  vim.api.nvim_create_autocmd("VimResized", { group = augroup, callback = resize_panel })
  vim.api.nvim_create_autocmd("TabEnter", { group = augroup, callback = resize_panel })
  vim.api.nvim_create_autocmd("VimLeavePre", { group = augroup, once = true, callback = function()
    if poll_timer then poll_timer:stop(); poll_timer:close(); poll_timer = nil end
  end })

  local buf = dashboard_buffer()
  setup_keymaps(buf)
end

return M
