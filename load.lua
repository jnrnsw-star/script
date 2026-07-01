--[[ TSUM Loader — одна строка для executor:
loadstring(game:HttpGet("https://github.com/jnrnsw-star/script/raw/refs/heads/main/load.lua"))()
]]
_G.TSUM = _G.TSUM or {}

local VERSION = "v12"
local BASE = "https://raw.githubusercontent.com/jnrnsw-star/script/main/tsum/"
local BASE_ALT = "https://github.com/jnrnsw-star/script/raw/refs/heads/main/tsum/"

local MODULES = {
    "01_core.lua",
    "02_catalog.lua",
    "03_logic.lua",
    "04_ui.lua",
}

local Players = game:GetService("Players")
local LP = Players.LocalPlayer or Players.PlayerAdded:Wait()

local function show(msg, err)
    warn("[TSUM] " .. msg)
    pcall(function()
        local g = LP.PlayerGui:FindFirstChild("TSUM_Loader")
        if g then g:Destroy() end
        g = Instance.new("ScreenGui")
        g.Name = "TSUM_Loader"
        g.ResetOnSpawn = false
        g.DisplayOrder = 10002
        g.Parent = LP.PlayerGui
        local t = Instance.new("TextLabel")
        t.Size = UDim2.fromScale(1, 1)
        t.BackgroundColor3 = err and Color3.fromRGB(28, 10, 10) or Color3.fromRGB(10, 12, 20)
        t.BackgroundTransparency = 0.05
        t.TextColor3 = err and Color3.fromRGB(255, 110, 110) or Color3.fromRGB(210, 220, 240)
        t.Font = Enum.Font.Code
        t.TextSize = 15
        t.TextWrapped = true
        t.Text = "TSUM Loader\n\n" .. msg
        t.Parent = g
    end)
end

local function httpGet(url)
    if request then
        local r = request({ Url = url, Method = "GET" })
        if r and r.Body and #r.Body > 0 then return r.Body end
    end
    if syn and syn.request then
        local r = syn.request({ Url = url, Method = "GET" })
        if r and r.Body and #r.Body > 0 then return r.Body end
    end
    if http and http.request then
        local r = http.request({ Url = url, Method = "GET" })
        if r and r.Body and #r.Body > 0 then return r.Body end
    end
    if game.HttpGetAsync then return game:HttpGetAsync(url) end
    return game:HttpGet(url)
end

local compile = loadstring or load
if not compile then
    show("Executor без loadstring", true)
    return
end

show("TSUM — загрузка модулей...\nПодожди 10–30 сек")

for i, name in ipairs(MODULES) do
    show(("Модуль %d/%d: %s (%s)"):format(i, #MODULES, name, VERSION))
    local src, used
    for _, base in ipairs({ BASE, BASE_ALT }) do
        local url = base .. name .. "?t=" .. VERSION
        local ok, body = pcall(httpGet, url)
        if ok and type(body) == "string" and #body > 200 and not body:find("<!DOCTYPE", 1, true) then
            src, used = body, url
            break
        end
    end
    if not src then
        show("Не скачался: " .. name .. " (" .. VERSION .. ")\n\nПроверь GitHub tsum/\nHttpGet включён?", true)
        return
    end
    local fn, err = compile(src)
    if not fn then
        show("Parse " .. name .. ":\n" .. tostring(err), true)
        return
    end
    local ok, runErr = pcall(fn)
    if not ok then
        show("Runtime " .. name .. ":\n" .. tostring(runErr), true)
        return
    end
end

pcall(function()
    local g = LP.PlayerGui:FindFirstChild("TSUM_Loader")
    if g then g:Destroy() end
end)
