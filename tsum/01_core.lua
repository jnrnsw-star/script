-- TSUM core v12
TSUM = _G.TSUM or {}
local TSUM = _G.TSUM

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    LocalPlayer = Players.PlayerAdded:Wait()
end

local Rayfield = nil
local ACBridge = nil

local function showBootError(message)
    warn("[TSUM] " .. tostring(message))
    pcall(function()
        local gui = Instance.new("ScreenGui")
        gui.Name = "TSUM_BootError"
        gui.ResetOnSpawn = false
        gui.DisplayOrder = 10000
        gui.Parent = LocalPlayer:WaitForChild("PlayerGui", 10) or LocalPlayer.PlayerGui
        local label = Instance.new("TextLabel")
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundColor3 = Color3.fromRGB(20, 10, 10)
        label.BackgroundTransparency = 0.15
        label.TextColor3 = Color3.fromRGB(255, 120, 120)
        label.Font = Enum.Font.Code
        label.TextSize = 14
        label.TextWrapped = true
        label.Text = "TSUM script error:\n" .. tostring(message)
        label.Parent = gui
    end)
end

local function waitChild(parent, name, timeout)
    if not parent then
        return nil
    end
    local found = parent:FindFirstChild(name)
    if found then
        return found
    end
    return parent:WaitForChild(name, timeout or 20)
end

local function loadRayfield()
    if Rayfield then
        return true
    end
    local urls = {
        "https://sirius.menu/rayfield",
        "https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua",
    }
    for _, url in ipairs(urls) do
        local ok, lib = pcall(function()
            local src = game.HttpGetAsync and game:HttpGetAsync(url) or game:HttpGet(url)
            local compile = loadstring or load
            return compile(src)()
        end)
        if ok and lib and type(lib) == "table" and lib.CreateWindow then
            Rayfield = lib
            return true
        end
    end
    showBootError("Rayfield не загрузился — проверь HTTP в executor")
    return false
end

local TG_URL = "https://t.me/tsumfreescript"

local function openTelegram()
    local opened = false
    pcall(function()
        local guiService = game:GetService("GuiService")
        if guiService.OpenBrowserWindow then
            guiService:OpenBrowserWindow(TG_URL)
            opened = true
        end
    end)
    if not opened then
        pcall(function()
            if syn and syn.open_browser then
                syn.open_browser(TG_URL)
                opened = true
            end
        end)
    end
    if not opened then
        pcall(function()
            if fluxus and fluxus.openbrowser then
                fluxus.openbrowser(TG_URL)
                opened = true
            end
        end)
    end
    if not opened then
        pcall(function()
            if request then
                request({ Url = TG_URL, Method = "GET" })
            end
        end)
    end
    pcall(function()
        if setclipboard then
            setclipboard(TG_URL)
        end
    end)
end

-- Ранний splash (до тяжёлого кода) — виден сразу после парсинга
local BOOT_DONE = false
local function bootSplash(onContinue)
    local ok, err = pcall(function()
        local gui = Instance.new("ScreenGui")
        gui.Name = "TSUM_Splash"
        gui.ResetOnSpawn = false
        gui.DisplayOrder = 999
        gui.Parent = LocalPlayer:WaitForChild("PlayerGui", 15) or LocalPlayer.PlayerGui

        local card = Instance.new("Frame")
        card.Size = UDim2.fromOffset(320, 160)
        card.Position = UDim2.fromScale(0.5, 0.5)
        card.AnchorPoint = Vector2.new(0.5, 0.5)
        card.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
        card.BorderSizePixel = 0
        card.Parent = gui

        local cardCorner = Instance.new("UICorner")
        cardCorner.CornerRadius = UDim.new(0, 12)
        cardCorner.Parent = card

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -20, 0, 40)
        title.Position = UDim2.fromOffset(10, 16)
        title.BackgroundTransparency = 1
        title.Font = Enum.Font.GothamBold
        title.TextSize = 20
        title.Text = "TSUM | tsumfreescript"
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.Parent = card

        local sub = Instance.new("TextLabel")
        sub.Size = UDim2.new(1, -20, 0, 40)
        sub.Position = UDim2.fromOffset(10, 56)
        sub.BackgroundTransparency = 1
        sub.Font = Enum.Font.Gotham
        sub.TextSize = 13
        sub.TextWrapped = true
        sub.Text = "Загрузка..."
        sub.TextColor3 = Color3.fromRGB(170, 175, 185)
        sub.Parent = card

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -40, 0, 36)
        btn.Position = UDim2.new(0.5, 0, 1, -48)
        btn.AnchorPoint = Vector2.new(0.5, 0)
        btn.BackgroundColor3 = Color3.fromRGB(60, 130, 255)
        btn.Text = "Continue"
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 15
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Parent = card
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 8)
        btnCorner.Parent = btn

        btn.MouseButton1Click:Connect(function()
            gui:Destroy()
            BOOT_DONE = true
            task.spawn(onContinue)
        end)
    end)
    if not ok then
        showBootError("Splash: " .. tostring(err))
        task.defer(onContinue)
    end
end

task.defer(openTelegram)

-- Rayfield загружается в loadMainUI (не блокируем старт)

-- Shop catalog: embedded payload, lazy decode after splash
local SHOP_CATALOG = { byName = {}, byId = {} }
local CatalogState = { started = false, done = false }

local CATALOG_FALLBACK = {
    byName = {
        ["Белая футболка"] = { rarity = "Common", fairPrice = 120, spawnChance = 55, id = "1352050969", type = "Shirt" },
        ["Drip футболка"] = { rarity = "Rare", fairPrice = 1200, spawnChance = 8, id = "6384915788", type = "Shirt" },
        ["Золотая цепь"] = { rarity = "Epic", fairPrice = 3800, spawnChance = 1.5, id = "12001043365", type = "Shirt" },
        ["BAPE Full Zip Shark"] = { rarity = "Legendary", fairPrice = 135000, spawnChance = 0.005, id = "1329266704", type = "Shirt" },
    },
    byId = {
        ["1352050969"] = { name = "Белая футболка", rarity = "Common", fairPrice = 120, spawnChance = 55 },
        ["6384915788"] = { name = "Drip футболка", rarity = "Rare", fairPrice = 1200, spawnChance = 8 },
    },
}

local function loadShopCatalogFromFile()
    if not (readfile and isfile and loadstring) then
        return nil
    end
    for _, path in ipairs({
        "shop_catalog_data.lua",
        "tsum/shop_catalog_data.lua",
        "tsum_free_script_catalog.lua",
    }) do
        if isfile(path) then
            local ok, data = pcall(function()
                return loadstring(readfile(path))()
            end)
            if ok and type(data) == "table" and data.byName then
                return data
            end
        end
    end
    return nil
end

function TSUM_loadEmbeddedCatalogAsync(callback)
    if CatalogState.done then
        if callback then callback(SHOP_CATALOG) end
        return
    end
    if CatalogState.started then
        task.spawn(function()
            while not CatalogState.done do task.wait(0.05) end
            if callback then callback(SHOP_CATALOG) end
        end)
        return
    end
    CatalogState.started = true
    task.spawn(function()
        local cat = loadShopCatalogFromFile()
        if type(EMBEDDED_CATALOG_B64) == "table" and #EMBEDDED_CATALOG_B64 > 0 and b64decode then
            local ok, result = pcall(function()
                local HttpService = game:GetService("HttpService")
                local raw = b64decode(table.concat(EMBEDDED_CATALOG_B64))
                local compact = HttpService:JSONDecode(raw)
                return expandCatalogCompact and expandCatalogCompact(compact) or compact
            end)
            if ok and type(result) == "table" and next(result.byName) then
                cat = result
            end
        end
        SHOP_CATALOG = cat or CATALOG_FALLBACK
        if TSUM.initShopCatalogIndex then
            TSUM.initShopCatalogIndex()
        end
        CatalogState.done = true
        if callback then callback(SHOP_CATALOG) end
    end)
end

--{{AUTOBUY_CATALOG}}
local SHOP_CATALOG_BY_NAME_LOWER = {}

local function initShopCatalogIndex()
    if not SHOP_CATALOG or not SHOP_CATALOG.byName then
        return
    end
    for _k in pairs(SHOP_CATALOG_BY_NAME_LOWER) do SHOP_CATALOG_BY_NAME_LOWER[_k] = nil end
    for name, data in pairs(SHOP_CATALOG.byName) do
        SHOP_CATALOG_BY_NAME_LOWER[string.lower(name)] = {
            name = name,
            rarity = data.rarity,
            fairPrice = data.fairPrice,
            spawnChance = data.spawnChance,
            id = data.id,
            type = data.type,
        }
    end
end

task.defer(function()
    if not CatalogState.done and not next(SHOP_CATALOG.byName) then
        SHOP_CATALOG = CATALOG_FALLBACK
        initShopCatalogIndex()
    end
end)

local AC = {
    enabled = true,
    antiKick = true,
    antiSpeed = true,
    antiFling = true,
    antiAdonis = true,
    hideCoreGui = true,
    stealthTp = true,
    useRemoteQueue = true,
    stealthRemotes = true,
    remoteDelay = 0.35,
    jitterMax = 0.4,
    walkSpeed = 16,
    jumpPower = 50,
}

local RemoteQueue = {}
local RemoteQueueBusy = false
local function acWait(base)
    if not AC.enabled or not AC.stealthRemotes then
        return
    end
    local delay = base or AC.remoteDelay
    if AC.jitterMax > 0 then
        delay = delay + math.random() * AC.jitterMax
    end
    task.wait(delay)
end

local function drainRemoteQueue()
    if RemoteQueueBusy then
        return
    end
    RemoteQueueBusy = true
    while #RemoteQueue > 0 do
        local job = table.remove(RemoteQueue, 1)
        pcall(job)
        acWait(AC.remoteDelay)
    end
    RemoteQueueBusy = false
end

local function queueRemoteJob(fn)
    table.insert(RemoteQueue, fn)
    task.spawn(drainRemoteQueue)
end

local function safeRemoteCall(remote, ...)
    if not remote then
        return nil
    end
    local args = { ... }
    local ref = remote
    if cloneref then
        pcall(function()
            ref = cloneref(remote)
        end)
    end
    local function fire()
        local ok, res = pcall(function()
            if ref:IsA("RemoteEvent") then
                return ref:FireServer(table.unpack(args))
            end
            return ref:InvokeServer(table.unpack(args))
        end)
        logRemoteQA(ref.Name, ref, args, ok)
        if not ok then
            error(res)
        end
        return res
    end
    if AC.enabled and AC.useRemoteQueue then
        local result
        local done = false
        queueRemoteJob(function()
            result = fire()
            done = true
        end)
        local t0 = tick()
        while not done and tick() - t0 < 12 do
            task.wait(0.05)
        end
        return result
    end
    return fire()
end

local function logRemoteQA(label, remote, args, ok)
    if not (TSUM.State and TSUM.State.remoteSpyEnabled) then
        return
    end
    local summary = label
    if type(args) == "table" and #args > 0 then
        local parts = {}
        for i = 1, math.min(#args, 4) do
            local v = args[i]
            if type(v) == "table" and v.uid then
                table.insert(parts, "uid=" .. tostring(v.uid))
            elseif type(v) == "userdata" and typeof and typeof(v) == "Instance" then
                table.insert(parts, v.Name)
            else
                table.insert(parts, tostring(v):sub(1, 40))
            end
        end
        summary = summary .. " | " .. table.concat(parts, ", ")
    end
    TSUM.State = TSUM.State or { remoteLog = {}, remoteSpyEnabled = true }
    table.insert(TSUM.State.remoteLog, 1, {
        time = string.format("%d", math.floor(tick()) % 100000),
        text = summary,
        ok = ok,
        remote = remote and remote:GetFullName() or "?",
    })
    while #TSUM.State.remoteLog > 100 do
        table.remove(TSUM.State.remoteLog)
    end
    if TSUM.State and TSUM.State.refreshRemoteSpy then
        pcall(TSUM.State.refreshRemoteSpy)
    end
end

local function installAntiCheatBypass()
    local function loadAcModule()
        if not (readfile and isfile and loadstring) then
            return nil
        end
        for _, path in ipairs({ "ac_bypass.lua", "tsum/ac_bypass.lua" }) do
            if isfile(path) then
                local ok, mod = pcall(function()
                    return loadstring(readfile(path))()
                end)
                if ok and type(mod) == "function" then
                    return mod({
                        AC = AC,
                        LocalPlayer = LocalPlayer,
                        RunService = RunService,
                        debug = false,
                    })
                end
            end
        end
        return nil
    end

    if TSUM_installEmbeddedAC then
        pcall(TSUM_installEmbeddedAC)
    end
    if ACBridge and ACBridge.install then
        ACBridge.install()
        return
    end

    ACBridge = loadAcModule()
    if ACBridge and ACBridge.install then
        ACBridge.install()
        return
    end

    if hookmetamethod and getnamecallmethod then
        pcall(function()
            local oldNc
            local ncFn = function(self, ...)
                local method = getnamecallmethod()
                if AC.enabled and AC.antiKick and method == "Kick" and self == LocalPlayer then
                    return nil
                end
                return oldNc(self, ...)
            end
            if newcclosure then
                ncFn = newcclosure(ncFn)
            end
            oldNc = hookmetamethod(game, "__namecall", ncFn)
        end)
    end
end


local RARITY_COLORS = {
    Common = Color3.fromRGB(140, 140, 145),
    Uncommon = Color3.fromRGB(80, 200, 80),
    Rare = Color3.fromRGB(60, 140, 255),
    Epic = Color3.fromRGB(180, 70, 255),
    Legendary = Color3.fromRGB(255, 180, 30),
    Exclusive = Color3.fromRGB(138, 43, 226),
    TokyoExclusive = Color3.fromRGB(255, 100, 200),
}

local RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Exclusive", "TokyoExclusive" }

local BARIGA_PIVOT = Vector3.new(-3616.045, 324.111, -234.452)
local BARIGA_FALLBACK = CFrame.new(BARIGA_PIVOT)

-- export core
TSUM.Players = Players
TSUM.ReplicatedStorage = ReplicatedStorage
TSUM.RunService = RunService
TSUM.LocalPlayer = LocalPlayer
TSUM.PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
TSUM.Rayfield = Rayfield
TSUM.ACBridge = ACBridge
TSUM.showBootError = showBootError
TSUM.waitChild = waitChild
TSUM.loadRayfield = loadRayfield
TSUM.bootSplash = bootSplash
TSUM.BOOT_DONE = BOOT_DONE
TSUM.SHOP_CATALOG = SHOP_CATALOG
TSUM.CatalogState = CatalogState
TSUM.CATALOG_FALLBACK = CATALOG_FALLBACK
TSUM.initShopCatalogIndex = initShopCatalogIndex
TSUM.TSUM_loadEmbeddedCatalogAsync = TSUM_loadEmbeddedCatalogAsync
TSUM.AC = AC
TSUM.acWait = acWait
TSUM.safeRemoteCall = safeRemoteCall
TSUM.installAntiCheatBypass = installAntiCheatBypass
TSUM.RARITY_COLORS = RARITY_COLORS
TSUM.RARITY_ORDER = RARITY_ORDER
TSUM.BARIGA_PIVOT = BARIGA_PIVOT
TSUM.BARIGA_FALLBACK = BARIGA_FALLBACK
TSUM.openTelegram = openTelegram
