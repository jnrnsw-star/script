-- TSUM UI module v1.2
TSUM = _G.TSUM or {}
local TSUM = _G.TSUM
local Players = TSUM.Players
local ReplicatedStorage = TSUM.ReplicatedStorage
local RunService = TSUM.RunService
local LocalPlayer = TSUM.LocalPlayer
local Rayfield = TSUM.Rayfield
local showBootError = TSUM.showBootError
local bootSplash = TSUM.bootSplash
local loadRayfield = TSUM.loadRayfield
local installAntiCheatBypass = TSUM.installAntiCheatBypass
local State = TSUM.State
local notify = TSUM.notify
local AC = TSUM.AC
local RARITY_ORDER = TSUM.RARITY_ORDER
local AUTOBUY_ITEMS = TSUM.AUTOBUY_ITEMS or {}
local runAutoBuyLoop = TSUM.runAutoBuyLoop
local stopAutoBuy = TSUM.stopAutoBuy
local runAutoFarmLoop = TSUM.runAutoFarmLoop
local stopAutoFarm = TSUM.stopAutoFarm
local setESP = TSUM.setESP
local refreshESP = TSUM.refreshESP
local startESPLoop = TSUM.startESPLoop
local scanShopForTarget = TSUM.scanShopForTarget
local getAutobuyItemsForRarity = TSUM.getAutobuyItemsForRarity
local buildAutobuyItemNames = TSUM.buildAutobuyItemNames or function() return {} end
local resolveAutobuyTargetByName = TSUM.resolveAutobuyTargetByName
local pickBestFarmItem = TSUM.pickBestFarmItem
local stopBarigaHold = TSUM.stopBarigaHold
local teleportToBariga = TSUM.teleportToBariga
local openBarigaMenu = TSUM.openBarigaMenu
local tryFireBarigaPrompt = TSUM.tryFireBarigaPrompt
local ACBridge = TSUM.ACBridge

local function destroyRemoteSpyGui()
    if State.remoteSpyGui and State.remoteSpyGui.screen then
        State.remoteSpyGui.screen:Destroy()
    end
    State.remoteSpyGui = nil
    State.refreshRemoteSpy = nil
end

local function createRemoteSpyGui()
    destroyRemoteSpyGui()

    local gui = Instance.new("ScreenGui")
    gui.Name = "TSUM_RemoteSpy"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 997
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local root = Instance.new("Frame")
    root.Size = UDim2.fromOffset(480, 300)
    root.Position = UDim2.new(0, 12, 1, -312)
    root.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
    root.BorderSizePixel = 0
    root.Parent = gui
    local rootCorner = Instance.new("UICorner")
    rootCorner.CornerRadius = UDim.new(0, 10)
    rootCorner.Parent = root
    local stroke = Instance.new("UIStroke")
    stroke.Parent = root
    stroke.Color = Color3.fromRGB(80, 180, 255)
    stroke.Thickness = 1.2

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -40, 0, 28)
    title.Position = UDim2.fromOffset(10, 6)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(120, 200, 255)
    title.Text = "Remote Spy (Dex-style) — AutoBuy"
    title.Parent = root

    local close = Instance.new("TextButton")
    close.Size = UDim2.fromOffset(24, 24)
    close.Position = UDim2.new(1, -30, 0, 8)
    close.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    close.Text = "X"
    close.Font = Enum.Font.GothamBold
    close.TextSize = 12
    close.Parent = root
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = close

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -20, 1, -44)
    scroll.Position = UDim2.fromOffset(10, 36)
    scroll.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.CanvasSize = UDim2.fromOffset(0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = root
    local scrollCorner = Instance.new("UICorner")
    scrollCorner.CornerRadius = UDim.new(0, 6)
    scrollCorner.Parent = scroll
    local layout = Instance.new("UIListLayout")
    layout.Parent = scroll
    layout.Padding = UDim.new(0, 2)
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    local function paint()
        for _, child in ipairs(scroll:GetChildren()) do
            if child:IsA("TextLabel") then
                child:Destroy()
            end
        end
        if #State.remoteLog == 0 then
            local empty = Instance.new("TextLabel")
            empty.Size = UDim2.new(1, -8, 0, 24)
            empty.BackgroundTransparency = 1
            empty.Font = Enum.Font.Code
            empty.TextSize = 11
            empty.TextXAlignment = Enum.TextXAlignment.Left
            empty.TextColor3 = Color3.fromRGB(140, 145, 155)
            empty.Text = "Ожидание remote-вызовов..."
            empty.Parent = scroll
            return
        end
        for i, entry in ipairs(State.remoteLog) do
            local row = Instance.new("TextLabel")
            row.Size = UDim2.new(1, -8, 0, 18)
            row.BackgroundTransparency = 1
            row.Font = Enum.Font.Code
            row.TextSize = 10
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.TextTruncate = Enum.TextTruncate.AtEnd
            row.TextColor3 = entry.ok and Color3.fromRGB(120, 220, 140) or Color3.fromRGB(255, 130, 130)
            row.Text = string.format("[%s] %s", entry.time, entry.text)
            row.LayoutOrder = i
            row.Parent = scroll
        end
    end

    State.refreshRemoteSpy = paint
    State.remoteSpyGui = { screen = gui }
    paint()

    close.MouseButton1Click:Connect(function()
        destroyRemoteSpyGui()
    end)
end


local function createSplash(onContinue)
    local gui = Instance.new("ScreenGui")
    gui.Name = "TSUM_Splash"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 999
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local dim = Instance.new("Frame")
    dim.Size = UDim2.fromScale(1, 1)
    dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    dim.BackgroundTransparency = 0.35
    dim.BorderSizePixel = 0
    dim.Parent = gui

    local card = Instance.new("Frame")
    card.Size = UDim2.fromOffset(360, 220)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    card.BorderSizePixel = 0
    card.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(70, 130, 255)
    stroke.Thickness = 1.5
    stroke.Parent = card

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -24, 0, 48)
    title.Position = UDim2.fromOffset(12, 20)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 22
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Text = "made by tsumfreescript"
    title.Parent = card

    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -24, 0, 60)
    subtitle.Position = UDim2.fromOffset(12, 72)
    subtitle.BackgroundTransparency = 1
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 14
    subtitle.TextWrapped = true
    subtitle.TextColor3 = Color3.fromRGB(180, 185, 195)
    subtitle.Text = "TSUM Free Script\nAutoFarm + AutoBuy + ESP\nНажми Continue"
    subtitle.Parent = card

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -48, 0, 42)
    button.Position = UDim2.new(0.5, 0, 1, -58)
    button.AnchorPoint = Vector2.new(0.5, 0)
    button.BackgroundColor3 = Color3.fromRGB(60, 130, 255)
    button.Text = "Continue"
    button.Font = Enum.Font.GothamBold
    button.TextSize = 16
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.AutoButtonColor = true
    button.BorderSizePixel = 0
    button.Parent = card

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = button

    button.MouseButton1Click:Connect(function()
        gui:Destroy()
        onContinue()
    end)
end

local function loadMainUI()
    if not loadRayfield() then
        return
    end
    task.spawn(function()
        pcall(installAntiCheatBypass)
    end)
    if State.remoteSpyEnabled then
        task.defer(createRemoteSpyGui)
    end
    if State.espEnabled then
        task.defer(refreshESP)
    end

    local Window = Rayfield:CreateWindow({
        Name = "TSUM | tsumfreescript",
        LoadingTitle = "TSUM Free Script",
        LoadingSubtitle = "made by tsumfreescript",
        ConfigurationSaving = {
            Enabled = true,
            FolderName = "TSUMFreeScript",
            FileName = "settings",
        },
        KeySystem = false,
    })

    local Main = Window:CreateTab("Main", 4483362458)
    Main:CreateSection("ESP — магазин ЦУМ")

    Main:CreateParagraph({
        Title = "Каталог",
        Content = "584 вещи из SHOP_ITEMS.\nФормат: [Редкость %] Название $Цена",
    })

    Main:CreateToggle({
        Name = "ESP ЦУМ (tracer + box)",
        CurrentValue = false,
        Flag = "TSUM_ESP",
        Callback = setESP,
    })

    Main:CreateButton({
        Name = "Обновить ESP (скан ЦУМ)",
        Callback = function()
            refreshESP()
            local n = 0
            for _ in pairs(State.shopCache) do
                n = n + 1
            end
            notify("ESP", "Скан: " .. n .. " слотов в кэше", 4)
        end,
    })

    Main:CreateSection("Редкость для подсветки")

    for _, rarity in ipairs(RARITY_ORDER) do
        Main:CreateToggle({
            Name = rarity,
            CurrentValue = State.selectedRarities[rarity] == true,
            Flag = "TSUM_Rarity_" .. rarity,
            Callback = function(value)
                State.selectedRarities[rarity] = value
                if State.espEnabled then
                    refreshESP()
                end
            end,
        })
    end

    Main:CreateSection("Барыга — телепорт")

    Main:CreateButton({
        Name = "ТП к Барыге (усиленный)",
        Callback = teleportToBariga,
    })

    Main:CreateButton({
        Name = "Открыть меню Барыги",
        Callback = function()
            if openBarigaMenu() or tryFireBarigaPrompt() then
                notify("Барыга", "TriggerBariga отправлен", 3)
            else
                notify("Барыга", "BarigaRemotes / BarigaPrompt не найден", 4)
            end
        end,
    })

    Main:CreateButton({
        Name = "Снять блокировку движения",
        Callback = function()
            stopBarigaHold()
            restorePlayerMovement()
            notify("Барыга", "Движение восстановлено", 3)
        end,
    })

    Main:CreateToggle({
        Name = "Авто-открыть UI после ТП",
        CurrentValue = State.barigaAutoOpen,
        Flag = "TSUM_BarigaAutoOpen",
        Callback = function(v)
            State.barigaAutoOpen = v
        end,
    })

    Main:CreateSlider({
        Name = "Удержание позиции (сек)",
        Range = { 1, 8 },
        Increment = 1,
        Suffix = "s",
        CurrentValue = State.barigaHoldSeconds,
        Flag = "TSUM_BarigaHold",
        Callback = function(v)
            State.barigaHoldSeconds = v
        end,
    })

    Main:CreateParagraph({
        Title = "Барыга",
        Content = "Pivot Y=324 у BarigaNPC.\nСтрим зоны 2 сек → ТП к ногам NPC.\nFallback: -3616, 324, -234",
    })
    Main:CreateLabel("made by tsumfreescript")
    Main:CreateParagraph({
        Title = "ESP",
        Content = "Каталог: название, цена, % спавна.\nСкан Slot_* + billboard + SlotPriceReveal.",
    })

    Main:CreateSection("Обход античита")

    Main:CreateToggle({
        Name = "Очередь remotes (anti-spam)",
        CurrentValue = AC.useRemoteQueue,
        Flag = "TSUM_RemoteQueue",
        Callback = function(v)
            AC.useRemoteQueue = v
            AC.stealthRemotes = v
        end,
    })

    Main:CreateToggle({
        Name = "Anti-Kick (hook Kick)",
        CurrentValue = AC.antiKick,
        Flag = "TSUM_AntiKick",
        Callback = function(v)
            AC.antiKick = v
        end,
    })

    Main:CreateToggle({
        Name = "Anti-Speed reset",
        CurrentValue = AC.antiSpeed,
        Flag = "TSUM_AntiSpeed",
        Callback = function(v)
            AC.antiSpeed = v
        end,
    })

    Main:CreateToggle({
        Name = "Anti-Fling",
        CurrentValue = AC.antiFling,
        Flag = "TSUM_AntiFling",
        Callback = function(v)
            AC.antiFling = v
        end,
    })

    Main:CreateToggle({
        Name = "Stealth TP (микро-шаги)",
        CurrentValue = State.stealthTp,
        Flag = "TSUM_StealthTp",
        Callback = function(v)
            State.stealthTp = v
            AC.stealthTp = v
        end,
    })

    Main:CreateToggle({
        Name = "Anti-Adonis (Detected/Kill)",
        CurrentValue = AC.antiAdonis,
        Flag = "TSUM_AntiAdonis",
        Callback = function(v)
            AC.antiAdonis = v
            if v and ACBridge and ACBridge.refreshAdonis then
                pcall(ACBridge.refreshAdonis)
            end
        end,
    })

    Main:CreateButton({
        Name = "Перескан Adonis / AC",
        Callback = function()
            pcall(installAntiCheatBypass)
            if ACBridge and ACBridge.refreshAdonis then
                pcall(ACBridge.refreshAdonis)
            end
            notify("AC", "Перескан выполнен", 4)
        end,
    })

    Main:CreateSection("AutoBuy")

    Main:CreateButton({
        Name = "Старт AutoBuy",
        Callback = function()
            runAutoBuyLoop()
        end,
    })

    Main:CreateButton({
        Name = "Стоп AutoBuy",
        Callback = stopAutoBuy,
    })

    Main:CreateToggle({
        Name = "Remote Spy (Dex-style лог)",
        CurrentValue = State.remoteSpyEnabled,
        Flag = "TSUM_RemoteSpy",
        Callback = function(v)
            State.remoteSpyEnabled = v
            if v then
                createRemoteSpyGui()
            else
                destroyRemoteSpyGui()
            end
        end,
    })

    Main:CreateButton({
        Name = "Открыть Remote Spy",
        Callback = function()
            State.remoteSpyEnabled = true
            createRemoteSpyGui()
        end,
    })


    local AutoTab = Window:CreateTab("AutoBuy", 6031255555)
    AutoTab:CreateSection("Автопокупка в ЦУМ")
    AutoTab:CreateParagraph({
        Title = "Как работает",
        Content = "Выбери редкость → вещь → Старт.\nСканирует магазин, ТП к слоту, в корзину, оплата.\nStealth TP как у Барыги.",
    })

    local rarityOpts = {}
    for _, r in ipairs(RARITY_ORDER) do
        if AUTOBUY_ITEMS and AUTOBUY_ITEMS[r] and #AUTOBUY_ITEMS[r] > 0 then
            table.insert(rarityOpts, r)
        end
    end
    if #rarityOpts == 0 then
        rarityOpts = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
    end

    if not State.autoBuyRarity then
        State.autoBuyRarity = rarityOpts[1] or "Rare"
    end

    local itemDropdown

    local function applyAutobuyItemSelection(name)
        State.autoBuyTarget = resolveAutobuyTargetByName(name, State.autoBuyRarity)
    end

    local function refreshAutobuyItemDropdown(pickFirst)
        local itemNames = buildAutobuyItemNames(State.autoBuyRarity)
        if #itemNames == 0 then
            itemNames = { "— нет в каталоге —" }
        end
        if itemDropdown and itemDropdown.Refresh then
            itemDropdown:Refresh(itemNames)
        end
        if pickFirst and itemNames[1] and itemNames[1] ~= "— нет в каталоге —" then
            applyAutobuyItemSelection(itemNames[1])
        end
    end

    AutoTab:CreateDropdown({
        Name = "Редкость",
        Options = rarityOpts,
        CurrentOption = State.autoBuyRarity,
        Flag = "TSUM_AutoBuyRarity",
        Callback = function(v)
            State.autoBuyRarity = type(v) == "table" and v[1] or v
            State.autoBuyTarget = nil
            refreshAutobuyItemDropdown(true)
        end,
    })

    local initialItems = buildAutobuyItemNames(State.autoBuyRarity)
    if #initialItems == 0 then
        initialItems = { "— нет в каталоге —" }
    end

    itemDropdown = AutoTab:CreateDropdown({
        Name = "Вещь",
        Options = initialItems,
        CurrentOption = initialItems[1] or "—",
        Flag = "TSUM_AutoBuyItem",
        Callback = function(v)
            local name = type(v) == "table" and v[1] or v
            applyAutobuyItemSelection(name)
        end,
    })

    if initialItems[1] and initialItems[1] ~= "— нет в каталоге —" then
        applyAutobuyItemSelection(initialItems[1])
    end

    AutoTab:CreateInput({
        Name = "Поиск вещи (имя)",
        PlaceholderText = "часть названия…",
        RemoveTextAfterFocusLost = false,
        Callback = function(text)
            State.autoBuySearch = text
        end,
    })

    AutoTab:CreateButton({
        Name = "Найти в каталоге",
        Callback = function()
            local query = string.lower(tostring(State.autoBuySearch or ""))
            if query == "" then
                notify("AutoBuy", "Введи часть названия", 3)
                return
            end
            local matches = {}
            for _, it in ipairs(getAutobuyItemsForRarity(State.autoBuyRarity)) do
                if string.find(string.lower(it.n), query, 1, true) then
                    table.insert(matches, it.n)
                end
            end
            table.sort(matches)
            if #matches == 0 then
                notify("AutoBuy", "Не найдено в " .. State.autoBuyRarity, 4)
                return
            end
            if itemDropdown and itemDropdown.Refresh then
                itemDropdown:Refresh(matches)
            end
            applyAutobuyItemSelection(matches[1])
            notify("AutoBuy", "Выбрано: " .. matches[1], 5)
        end,
    })

    AutoTab:CreateToggle({
        Name = "Купить один раз",
        CurrentValue = State.autoBuyOnce,
        Flag = "TSUM_AutoBuyOnce",
        Callback = function(v)
            State.autoBuyOnce = v
        end,
    })

    AutoTab:CreateToggle({
        Name = "Stealth TP",
        CurrentValue = State.stealthTp,
        Flag = "TSUM_AutoStealthTp",
        Callback = function(v)
            State.stealthTp = v
            AC.stealthTp = v
        end,
    })

    AutoTab:CreateButton({
        Name = "Старт AutoBuy",
        Callback = function()
            local items = getAutobuyItemsForRarity(State.autoBuyRarity)
            if not State.autoBuyTarget and items[1] then
                State.autoBuyTarget = items[1]
            end
            runAutoBuyLoop()
        end,
    })

    AutoTab:CreateButton({
        Name = "Стоп AutoBuy",
        Callback = stopAutoBuy,
    })

    AutoTab:CreateButton({
        Name = "Скан + найти сейчас",
        Callback = function()
            if not State.autoBuyTarget then
                notify("AutoBuy", "Выбери вещь", 3)
                return
            end
            local hit = scanShopForTarget(State.autoBuyTarget)
            if hit then
                notify("AutoBuy", "В магазине: " .. (hit.name or "?"), 6)
            else
                notify("AutoBuy", "Не найдено — продолай скан", 4)
            end
        end,
    })
    AutoTab:CreateLabel("made by tsumfreescript")



    local FarmTab = Window:CreateTab("AutoFarm", 6031266666)
    FarmTab:CreateSection("Ферма ЦУМ → Барыга")
    FarmTab:CreateParagraph({
        Title = "Как работает",
        Content = "Скан ЦУМ → покупка → в корзину → ТП к барыге → ConfirmBarigaSale.\nКаталог из message.txt (spawnChance + fairPrice).\nStealth TP как у Барыги.",
    })

    if not State.autoFarmRarity then
        State.autoFarmRarity = State.autoBuyRarity or "Common"
    end

    local farmItemDropdown
    local farmRarityOpts = {}
    for _, r in ipairs(RARITY_ORDER) do
        if AUTOBUY_ITEMS and AUTOBUY_ITEMS[r] and #AUTOBUY_ITEMS[r] > 0 then
            table.insert(farmRarityOpts, r)
        end
    end

    local function applyFarmItemSelection(name)
        State.autoFarmTarget = resolveAutobuyTargetByName(name, State.autoFarmRarity)
    end

    local function refreshFarmItemDropdown(pickBest)
        local names = buildAutobuyItemNames(State.autoFarmRarity)
        if #names == 0 then
            names = { "— нет —" }
        end
        if farmItemDropdown and farmItemDropdown.Refresh then
            farmItemDropdown:Refresh(names)
        end
        if pickBest then
            if State.autoFarmUseBest then
                State.autoFarmTarget = pickBestFarmItem(State.autoFarmRarity)
            elseif names[1] and names[1] ~= "— нет —" then
                applyFarmItemSelection(names[1])
            end
        end
    end

    FarmTab:CreateToggle({
        Name = "Лучший шанс (spawnChance)",
        CurrentValue = State.autoFarmUseBest ~= false,
        Flag = "TSUM_AutoFarmBest",
        Callback = function(v)
            State.autoFarmUseBest = v
            if v then
                State.autoFarmTarget = pickBestFarmItem(State.autoFarmRarity)
            end
        end,
    })

    FarmTab:CreateDropdown({
        Name = "Редкость",
        Options = farmRarityOpts,
        CurrentOption = State.autoFarmRarity,
        Flag = "TSUM_AutoFarmRarity",
        Callback = function(v)
            State.autoFarmRarity = type(v) == "table" and v[1] or v
            refreshFarmItemDropdown(true)
        end,
    })

    local farmInitial = buildAutobuyItemNames(State.autoFarmRarity)
    farmItemDropdown = FarmTab:CreateDropdown({
        Name = "Вещь",
        Options = #farmInitial > 0 and farmInitial or { "— нет —" },
        CurrentOption = farmInitial[1] or "—",
        Flag = "TSUM_AutoFarmItem",
        Callback = function(v)
            local name = type(v) == "table" and v[1] or v
            applyFarmItemSelection(name)
            State.autoFarmUseBest = false
        end,
    })
    refreshFarmItemDropdown(true)

    FarmTab:CreateToggle({
        Name = "Stealth TP",
        CurrentValue = State.stealthTp,
        Flag = "TSUM_AutoFarmStealth",
        Callback = function(v)
            State.stealthTp = v
            AC.stealthTp = v
        end,
    })

    FarmTab:CreateButton({
        Name = "Старт AutoFarm",
        Callback = function()
            if State.autoFarmUseBest then
                State.autoFarmTarget = pickBestFarmItem(State.autoFarmRarity)
            elseif not State.autoFarmTarget then
                State.autoFarmTarget = pickBestFarmItem(State.autoFarmRarity)
            end
            runAutoFarmLoop()
        end,
    })

    FarmTab:CreateButton({
        Name = "Стоп AutoFarm",
        Callback = stopAutoFarm,
    })

    FarmTab:CreateButton({
        Name = "1 цикл (купить + продать)",
        Callback = function()
            State.autoFarmMaxCycles = 1
            State.autoFarmDelay = 0
            if State.autoFarmUseBest or not State.autoFarmTarget then
                State.autoFarmTarget = pickBestFarmItem(State.autoFarmRarity)
            end
            runAutoFarmLoop()
        end,
    })
    FarmTab:CreateLabel("made by tsumfreescript")


    startESPLoop()

    LocalPlayer.CharacterAdded:Connect(function()
        stopBarigaHold()
    end)

    notify("TSUM", "Скрипт загружен — t.me/tsumfreescript", 5)
end

pcall(function()
    local ok, err = pcall(function()
        bootSplash(loadMainUI)
    end)
    if not ok then
        warn("[TSUM] Startup failed: " .. tostring(err))
        showBootError(tostring(err))
    end
end)
