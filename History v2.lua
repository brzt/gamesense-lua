local ui_get, ui_set = ui.get, ui.set
local draw_text = client.draw_text
local draw_rectangle = client.draw_rectangle
local width, height = client.screen_size()
local last_tick = 0

local aim_table, shot_state = { }, { }
local Elements = {
    is_active = ui.new_checkbox("MISC", "Settings", "Aim bot logging"),
    palette = ui.new_color_picker("MISC", "Settings", "Logging picker", 16, 22, 29, 160),

    table_size = ui.new_slider("MISC", "Settings", "Maximum amount", 2, 10, 5),
    size_x = ui.new_slider("MISC", "Settings", "X Axis", 1, width, 90, true, "px"),
    size_y = ui.new_slider("MISC", "Settings", "Y Axis", 1, height, 400, true, "px"),

    reset_table = ui.new_button("MISC", "Settings", "Reset table", function()
        aim_table = {}
    end)
}

local function TicksTime(tick)
    return globals.tickinterval() * tick
end

local function get_server_rate(f)
    local tickrate = 64
    local cmdrate = client.get_cvar("cl_cmdrate") or 64
    local updaterate = client.get_cvar("cl_updaterate") or 64
        
    if cmdrate <= updaterate then 
        tickrate = cmdrate
    elseif updaterate <= cmdrate then 
        tickrate = updaterate
    end

    return math.floor((f * tickrate) + 0.5)
end

local function hook_aim_event(status, m)
    if shot_state[m.id]["got"] then
        for n, _ in pairs(aim_table) do
            if aim_table[n].id == m.id then
                aim_table[n]["hit"] = status
            end
        end
    end
end

client.set_event_callback("aim_hit", function(m) hook_aim_event("aim_hit", m) end)
client.set_event_callback("aim_miss", function(m) hook_aim_event("aim_miss", m) end)

client.set_event_callback("bullet_impact", function(m)
    local g_Local = entity.get_local_player()
    local g_EntID = client.userid_to_entindex(m.userid)
    if g_Local == g_EntID and last_tick ~= globals.tickcount() then

        local m_valid = {}
        for n, _ in pairs(shot_state) do
            if not shot_state[n]["got"] and shot_state[n]["time"] > globals.curtime() then
                m_valid[#m_valid + 1] = { ["id"] = n, ["data"] = shot_state[n] }
            end
        end

        if #m_valid > 0 then
            for i = 10, 2, -1 do m_valid[i] = m_valid[i-1] end
            for i = #m_valid, 1, -1 do
                shot_state[m_valid[i].id]["got"] = true
            end
        end

        last_tick = globals.tickcount()
    end
end)

client.set_event_callback("aim_fire", function(m)
    if ui_get(Elements.is_active) then

        for i = 10, 2, -1 do
            aim_table[i] = aim_table[i-1]
        end

        local nick = entity.get_player_name(m.target)
        aim_table[1] = { 
            ["id"] = m.id, ["hit"] = 0, 
            ["player"] = string.sub(nick, 0, 14),
            ["dmg"] = m.damage, ["bt"] = get_server_rate(m.backtrack), 
            ["lc"] = (m.teleported and "Breaking" or "No"), ["pri"] = (m.high_priority and "High" or "Normal")
        }

        shot_state[m.id] = { ["hit"] = false, ["time"] = globals.curtime() + TicksTime(15) + client.latency() }
    end
end)

local function drawTable(c, count, x, y, data)
    if data then
        local y = y + 4
        local pitch = x + 10
        local yaw = y + 15 + (count * 16)
        local r, g, b = 0, 0, 0

        if data.hit == "aim_hit" then
            r, g, b = 94, 230, 75
        elseif data.hit == "aim_miss" then
            r, g, b = 255, 84, 84
        else -- Doesnt registered
            r, g, b = 118, 171, 255
        end

        draw_rectangle(c, x, yaw, 2, 15, r, g, b, 255)
        draw_text(c, pitch - 3, yaw + 1, 255, 255, 255, 255, nil, 70, data.id)
        draw_text(c, pitch + 22, yaw + 1, 255, 255, 255, 255, nil, 70, data.player)
        draw_text(c, pitch + 106, yaw + 1, 255, 255, 255, 255, nil, 70, data.dmg)
        draw_text(c, pitch + 143, yaw + 1, 255, 255, 255, 255, nil, 70, data.bt, "t")
        draw_text(c, pitch + 173, yaw + 1, 255, 255, 255, 255, nil, 70, data.lc)
        draw_text(c, pitch + 224, yaw + 1, 255, 255, 255, 255, nil, 70, data.pri)

        return (count + 1)
    end
end

client.set_event_callback("paint", function(c)
    if not ui_get(Elements.is_active) then
        return
    end

    local x, y, d = ui_get(Elements.size_x), ui_get(Elements.size_y), 0
    local r, g, b, a = ui_get(Elements.palette)

    local n = ui_get(Elements.table_size)
    local col_sz = 24 + (16 * (#aim_table > n and n or #aim_table))

    draw_rectangle(c, x, y, 280, col_sz, 22, 20, 26, 100)
    draw_rectangle(c, x, y, 280, 15, r, g, b, a)

    -- Drawing first column
    draw_text(c, x + 10, y + 8, 255, 255, 255, 255, "-c", 70, "ID")
    draw_text(c, x + 10 + 35, y + 8, 255, 255, 255, 255, "-c", 70, "PLAYER")
    draw_text(c, x + 10 + 114, y + 8, 255, 255, 255, 255, "-c", 70, "DMG")
    draw_text(c, x + 10 + 147, y + 8, 255, 255, 255, 255, "-c", 70, "BT")
    draw_text(c, x + 10 + 190, y + 8, 255, 255, 255, 255, "-c", 70, "LAG COMP")
    draw_text(c, x + 10 + 240, y + 8, 255, 255, 255, 255, "-c", 70, "PRIORITY")

    -- Drawing table
    for i = 1, ui_get(Elements.table_size), 1 do
        d = drawTable(c, d, x, y, aim_table[i])
    end
end)

local function visibility()
    local rpc = ui_get(Elements.is_active)
    ui.set_visible(Elements.table_size, rpc)
    ui.set_visible(Elements.size_x, rpc)
    ui.set_visible(Elements.size_y, rpc)
end

visibility()
ui.set_callback(Elements.is_active, visibility)