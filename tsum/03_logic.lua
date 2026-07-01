-- TSUM logic v12
TSUM = _G.TSUM or {}
local TSUM = _G.TSUM
local Players = TSUM.Players
local ReplicatedStorage = TSUM.ReplicatedStorage
local RunService = TSUM.RunService
local LocalPlayer = TSUM.LocalPlayer
local Rayfield = TSUM.Rayfield
local ACBridge = TSUM.ACBridge
local showBootError = TSUM.showBootError
local bootSplash = TSUM.bootSplash
local loadRayfield = TSUM.loadRayfield
local SHOP_CATALOG = TSUM.SHOP_CATALOG
local CatalogState = TSUM.CatalogState
local CATALOG_FALLBACK = TSUM.CATALOG_FALLBACK
local initShopCatalogIndex = TSUM.initShopCatalogIndex
local AC = TSUM.AC
local acWait = TSUM.acWait
local safeRemoteCall = TSUM.safeRemoteCall
local installAntiCheatBypass = TSUM.installAntiCheatBypass
local RARITY_COLORS = TSUM.RARITY_COLORS
local RARITY_ORDER = TSUM.RARITY_ORDER
local BARIGA_PIVOT = TSUM.BARIGA_PIVOT
local BARIGA_FALLBACK = TSUM.BARIGA_FALLBACK
local AUTOBUY_ITEMS = TSUM.AUTOBUY_ITEMS or {}

local State = {
    espEnabled = false,
    espMaxDistance = 220,
    espScanInterval = 2.5,
    shopCache = {},
    espUi = nil,
    lastEspScan = 0,
    selectedRarities = {
        Common = true,
        Uncommon = true,
        Rare = true,
        Epic = true,
        Legendary = true,
        Exclusive = true,
        TokyoExclusive = true,
    },
    connections = {},
    inventory = {},
    equipped = {},
    barigaHoldSeconds = 3,
    barigaAutoOpen = true,
    barigaTpConn = nil,
    barigaTpRunning = false,
    barigaWasAnchored = nil,
    stealthTp = true,
    autoBuyEnabled = false,
    autoBuyRunning = false,
    autoBuyOnce = true,
    autoBuyScanInterval = 2.5,
    autoBuyRarity = "Rare",
    autoBuyTarget = nil,
    autoFarmEnabled = false,
    autoFarmRunning = false,
    autoFarmRarity = "Common",
    autoFarmTarget = nil,
    autoFarmUseBest = true,
    autoFarmScanInterval = 2.5,
    autoFarmDelay = 2,
    autoFarmMaxCycles = nil,
    inventoryHooksReady = false,
    requestInventoryRemote = nil,
    barigaRemotesFolder = nil,
    catalogLoaded = false,
    remoteSpyEnabled = true,
    remoteLog = {},
    refreshRemoteSpy = nil,
}

local function notify(title, text, duration)
    if Rayfield and Rayfield.Notify then
        Rayfield:Notify({
            Title = title,
            Content = text,
            Duration = duration or 4,
            Image = 4483362458,
        })
    else
        warn("[TSUM] " .. tostring(title) .. ": " .. tostring(text))
    end
end

local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getHRP()
    local char = getCharacter()
    return char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 5)
end

local function restorePlayerMovement(char)
    char = char or LocalPlayer.Character
    if not char then
        return
    end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = false
            part.AssemblyLinearVelocity = Vector3.zero
            part.AssemblyAngularVelocity = Vector3.zero
        end
    end
    if hrp then
        pcall(function()
            hrp:SetNetworkOwner(nil)
        end)
    end
    if hum then
        hum.PlatformStand = false
        hum.Sit = false
        hum.AutoRotate = true
        if hum.WalkSpeed < 1 then
            hum.WalkSpeed = 16
        end
        pcall(function()
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
        task.defer(function()
            pcall(function()
                if hum and hum.Parent then
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                end
            end)
        end)
    end
end

local function stopBarigaHold()
    if State.barigaTpConn then
        State.barigaTpConn:Disconnect()
        State.barigaTpConn = nil
    end
    State.barigaTpRunning = false
    State.barigaWasAnchored = nil
    restorePlayerMovement()
end

local function zeroCharacterVelocity(char)
    if not char then
        return
    end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.AssemblyLinearVelocity = Vector3.zero
            part.AssemblyAngularVelocity = Vector3.zero
        end
    end
end

local function streamPosition(position)
    pcall(function()
        LocalPlayer:RequestStreamAroundAsync(position, 40)
    end)
end

local function snapFeetToGround(pos, char, fallbackY)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { char }
    local origin = Vector3.new(pos.X, (fallbackY or pos.Y) + 6, pos.Z)
    local hit = workspace:Raycast(origin, Vector3.new(0, -18, 0), params)
    if hit then
        return Vector3.new(pos.X, hit.Position.Y + 3, pos.Z)
    end
    return Vector3.new(pos.X, fallbackY or pos.Y, pos.Z)
end

local function resolveBarigaTarget()
    local char = LocalPlayer.Character
    local pivotPos = BARIGA_PIVOT
    local lookFlat = Vector3.new(0, 0, 1)

    local npc = workspace:FindFirstChild("BarigaNPC", true)
    if npc and npc:IsA("Model") then
        local pivot = npc:GetPivot()
        pivotPos = pivot.Position
        lookFlat = Vector3.new(pivot.LookVector.X, 0, pivot.LookVector.Z)
        if lookFlat.Magnitude < 0.05 then
            lookFlat = Vector3.new(0, 0, 1)
        else
            lookFlat = lookFlat.Unit
        end
    end

    local standPos = pivotPos - lookFlat * 5
    standPos = snapFeetToGround(standPos, char, pivotPos.Y + 3)

    local faceTarget = pivotPos + Vector3.new(0, 2, 0)
    return CFrame.new(standPos, faceTarget), "BarigaNPC"
end

local function applyHardTeleport(targetCF, holdSeconds)
    stopBarigaHold()

    local char = getCharacter()
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return false
    end

    holdSeconds = holdSeconds or State.barigaHoldSeconds or 3
    State.barigaTpRunning = true

    local function placeOnce(cf)
        zeroCharacterVelocity(char)
        char:PivotTo(cf)
    end

    streamPosition(targetCF.Position)

    if AC.enabled and AC.stealthTp and State.stealthTp then
        local startCF = hrp.CFrame
        local steps = 10
        for i = 1, steps do
            if not hrp.Parent then
                stopBarigaHold()
                return false
            end
            local alpha = i / steps
            local pos = startCF.Position:Lerp(targetCF.Position, alpha)
            streamPosition(pos)
            placeOnce(CFrame.new(pos) * (targetCF - targetCF.Position))
            task.wait(0.05)
        end
    else
        placeOnce(targetCF)
    end

    pcall(function()
        local adminFly = ReplicatedStorage:FindFirstChild("AdminRemotes")
        local fly = adminFly and adminFly:FindFirstChild("AdminFly")
        if fly and fly:IsA("RemoteEvent") then
            fly:FireServer(false)
        end
    end)

    local endTime = tick() + holdSeconds
    State.barigaTpConn = RunService.Heartbeat:Connect(function()
        if not hrp.Parent then
            stopBarigaHold()
            return
        end
        if tick() < endTime then
            placeOnce(targetCF)
        else
            stopBarigaHold()
        end
    end)

    task.delay(holdSeconds + 0.35, function()
        stopBarigaHold()
    end)

    return true
end

local function openBarigaMenu()
    local bariga = ReplicatedStorage:FindFirstChild("BarigaRemotes")
    local trigger = bariga and bariga:FindFirstChild("TriggerBariga")
    if trigger then
        trigger:FireServer()
        return true
    end
    return false
end

local function tryFireBarigaPrompt()
    local prompt = workspace:FindFirstChild("BarigaPrompt", true)
    if not prompt or not prompt:IsA("ProximityPrompt") then
        return false
    end
    local fired = false
    pcall(function()
        if fireproximityprompt then
            fireproximityprompt(prompt, 1)
            fired = true
        end
    end)
    if not fired then
        pcall(function()
            prompt:InputHoldBegin()
            task.wait(0.08)
            prompt:InputHoldEnd()
            fired = true
        end)
    end
    return fired
end

local function teleportToBariga()
    if State.barigaTpRunning then
        notify("Барыга", "Телепорт уже идёт — подожди", 3)
        return
    end

    task.spawn(function()
        local targetCF, source = resolveBarigaTarget()
        notify("Барыга", "Загрузка зоны (" .. source .. ")…", 4)

        for _ = 1, 4 do
            streamPosition(targetCF.Position)
            task.wait(0.45)
        end

        if not applyHardTeleport(targetCF, State.barigaHoldSeconds) then
            notify("Ошибка", "Не найден персонаж для ТП", 5)
            return
        end

        task.wait(State.barigaHoldSeconds + 0.4)
        stopBarigaHold()

        local hrp = getHRP()
        local dist = hrp and (hrp.Position - targetCF.Position).Magnitude or 999

        if dist > 22 then
            notify("Барыга", "Откат — повтор 4 сек…", 3)
            streamPosition(targetCF.Position)
            task.wait(0.5)
            applyHardTeleport(targetCF, 4)
            task.wait(4.4)
            stopBarigaHold()
            hrp = getHRP()
            dist = hrp and (hrp.Position - targetCF.Position).Magnitude or 999
        end

        restorePlayerMovement()
        task.wait(0.15)
        tryFireBarigaPrompt()
        if State.barigaAutoOpen then
            task.wait(0.1)
            openBarigaMenu()
        end

        if dist <= 22 then
            notify("Барыга", "ТП успешен. Позиция удержана.", 5)
        else
            notify(
                "Барыга — откат",
                "Сервер возвращает назад (дист. " .. math.floor(dist) .. ").\nПроверь анти-ТП / NetworkOwner на сервере.",
                8
            )
        end
    end)
end

local function formatPrice(n)
    if not n or n <= 0 then
        return "—"
    end
    local s = tostring(math.floor(n))
    local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
    return "$" .. out
end

local function formatChance(pct)
    if not pct or pct <= 0 then
        return "0%"
    end
    if pct < 1 then
        return string.format("%.2f%%", pct)
    end
    if pct == math.floor(pct) then
        return tostring(math.floor(pct)) .. "%"
    end
    return string.format("%.1f%%", pct)
end

local function findCatalogEntry(name, assetId)
    if not SHOP_CATALOG then
        return nil
    end
    if assetId then
        local hit = SHOP_CATALOG.byId and SHOP_CATALOG.byId[tostring(assetId)]
        if hit then
            return hit
        end
    end
    if name and name ~= "" then
        if SHOP_CATALOG.byName and SHOP_CATALOG.byName[name] then
            local d = SHOP_CATALOG.byName[name]
            return {
                name = name,
                rarity = d.rarity,
                fairPrice = d.fairPrice,
                spawnChance = d.spawnChance,
                id = d.id,
                type = d.type,
            }
        end
        local lower = string.lower(name)
        if SHOP_CATALOG_BY_NAME_LOWER[lower] then
            return SHOP_CATALOG_BY_NAME_LOWER[lower]
        end
        if SHOP_CATALOG.byName then
            for catName, data in pairs(SHOP_CATALOG.byName) do
                local cl = string.lower(catName)
                if cl == lower or cl:find(lower, 1, true) or lower:find(cl, 1, true) then
                    return {
                        name = catName,
                        rarity = data.rarity,
                        fairPrice = data.fairPrice,
                        spawnChance = data.spawnChance,
                        id = data.id,
                        type = data.type,
                    }
                end
            end
        end
    end
    return nil
end

local function getAssetIdFromSlot(slot)
    local mannequin = slot:FindFirstChild("Mannequin")
    if mannequin then
        local shirt = mannequin:FindFirstChildOfClass("Shirt")
        if shirt and shirt.ShirtTemplate ~= "" then
            local id = shirt.ShirtTemplate:match("%d+")
            if id then
                return id
            end
        end
        local pants = mannequin:FindFirstChildOfClass("Pants")
        if pants and pants.PantsTemplate ~= "" then
            local id = pants.PantsTemplate:match("%d+")
            if id then
                return id
            end
        end
    end
    for _, desc in ipairs(slot:GetDescendants()) do
        if desc:IsA("MeshPart") or desc:IsA("SpecialMesh") then
            local tex = ""
            if desc:IsA("MeshPart") then
                tex = desc.TextureID
            elseif desc:IsA("SpecialMesh") then
                tex = desc.TextureId
            end
            local id = tostring(tex):match("%d+")
            if id and #id >= 5 then
                return id
            end
        end
        if desc:IsA("StringValue") and desc.Name:lower():find("id") then
            local id = tostring(desc.Value):match("%d+")
            if id then
                return id
            end
        end
    end
    return nil
end

local function enrichShopEntry(info, slot)
    if not info then
        return info
    end
    local assetId = info.assetId or (slot and getAssetIdFromSlot(slot))
    local cat = findCatalogEntry(info.name, assetId)
    if cat then
        info.name = cat.name or info.name
        info.rarity = cat.rarity or info.rarity
        info.price = info.price or cat.fairPrice
        info.fairPrice = cat.fairPrice or info.fairPrice
        info.spawnChance = cat.spawnChance or info.spawnChance
        info.catalogHit = true
    elseif assetId then
        info.assetId = assetId
    end
    return info
end

local function buildEspLabel(info, rarity)
    local chance = info.spawnChance
    local price = info.price or info.fairPrice
    local chanceStr = chance and formatChance(chance) or "?"
    local priceStr = price and formatPrice(price) or ""
    local itemName = info.name or "?"
    if #itemName > 28 then
        itemName = itemName:sub(1, 26) .. ".."
    end
    return string.format("[%s %s] %s  %s", rarity, chanceStr, itemName, priceStr)
end

local function isRaritySelected(rarity)
    return State.selectedRarities[rarity] == true
end

local function normalizeRarity(text)
    if not text or text == "" then
        return "Common"
    end
    for _, rarity in ipairs(RARITY_ORDER) do
        if string.lower(text) == string.lower(rarity) then
            return rarity
        end
    end
    return text
end

local function colorDistance(a, b)
    return (a.R - b.R) ^ 2 + (a.G - b.G) ^ 2 + (a.B - b.B) ^ 2
end

local function colorToRarity(color)
    local bestName = "Common"
    local bestDist = math.huge
    for _, rarity in ipairs(RARITY_ORDER) do
        local ref = RARITY_COLORS[rarity]
        local dist = colorDistance(color, ref)
        if dist < bestDist then
            bestDist = dist
            bestName = rarity
        end
    end
    return bestName
end

local function getRarityFromSlot(slot)
    local rarityValue = slot:FindFirstChild("Rarity")
    if rarityValue and rarityValue:IsA("StringValue") then
        return normalizeRarity(rarityValue.Value)
    end

    local attr = slot:GetAttribute("Rarity")
    if attr then
        return normalizeRarity(tostring(attr))
    end

    local highlight = slot:FindFirstChild("ItemHighlight")
    if highlight and highlight:IsA("Highlight") then
        return colorToRarity(highlight.OutlineColor)
    end

    for _, desc in ipairs(slot:GetDescendants()) do
        if desc.Name == "ItemInfo" and desc:IsA("TextLabel") then
            local text = desc.Text:lower()
            for _, rarity in ipairs(RARITY_ORDER) do
                if text:find(rarity:lower(), 1, true) then
                    return rarity
                end
            end
        end
    end

    return "Common"
end

local function getItemNameFromSlot(slot)
    local assetId = getAssetIdFromSlot(slot)
    if assetId then
        local cat = findCatalogEntry(nil, assetId)
        if cat and cat.name then
            return cat.name
        end
    end

    local mannequin = slot:FindFirstChild("Mannequin")
    if mannequin then
        local shirt = mannequin:FindFirstChildOfClass("Shirt")
        if shirt and shirt.ShirtTemplate ~= "" then
            return "Shirt #" .. (shirt.ShirtTemplate:match("%d+") or "?")
        end
        local pants = mannequin:FindFirstChildOfClass("Pants")
        if pants and pants.PantsTemplate ~= "" then
            return "Pants #" .. (pants.PantsTemplate:match("%d+") or "?")
        end
    end

    for _, desc in ipairs(slot:GetDescendants()) do
        if desc.Name == "ItemInfo" and desc:IsA("TextLabel") and desc.Text ~= "" then
            return desc.Text
        end
    end

    local prompt = slot:FindFirstChild("TakePrompt")
    if prompt and prompt.ObjectText ~= "" then
        return prompt.ObjectText
    end

    return slot.Name
end

local function getRarityFromShopInfo(info)
    if not info then
        return "Common"
    end
    if info.rarity then
        return normalizeRarity(info.rarity)
    end
    if typeof(info.rarityColor) == "Color3" then
        return colorToRarity(info.rarityColor)
    end
    return "Common"
end

local function getColorFromShopInfo(info, rarity)
    if info and typeof(info.rarityColor) == "Color3" then
        return info.rarityColor
    end
    return RARITY_COLORS[rarity] or RARITY_COLORS.Common
end

local PlayerGui = nil
local ShopRemotes = nil

local function ensureShopRemotes()
    if ShopRemotes then
        return ShopRemotes ~= nil
    end
    PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 15) or LocalPlayer.PlayerGui
    ShopRemotes = waitChild(ReplicatedStorage, "ShopRemotes", 20)
    if ShopRemotes then
        pcall(function()
            local reveal = ShopRemotes:WaitForChild("SlotPriceReveal", 8)
            if reveal then
                reveal.OnClientEvent:Connect(ingestShopReveal)
            end
        end)
        pcall(function()
            local clear = ShopRemotes:WaitForChild("SlotInfoClear", 8)
            if clear then
                clear.OnClientEvent:Connect(function()
                    for _k in pairs(State.shopCache) do State.shopCache[_k] = nil end
                end)
            end
        end)
        pcall(function()
            local upd = ShopRemotes:WaitForChild("SlotInfoUpdate", 8)
            if upd then
                upd.OnClientEvent:Connect(function(data)
                    if data and data.zoneId then
                        task.defer(fallbackScanShopParts)
                    end
                end)
            end
        end)
    end
    return ShopRemotes ~= nil
end

local function resolveSlotPart(container)
    if not container then
        return nil
    end
    if container:IsA("BasePart") then
        return container
    end
    local interact = container:FindFirstChild("Interact")
    if interact and interact:IsA("BasePart") then
        return interact
    end
    for _, desc in ipairs(container:GetDescendants()) do
        if desc:IsA("ProximityPrompt") and (desc.Name == "TakePrompt" or desc.Name == "Take") then
            local parent = desc.Parent
            if parent and parent:IsA("BasePart") then
                return parent
            end
        end
    end
    if container:IsA("Model") then
        if container.PrimaryPart then
            return container.PrimaryPart
        end
        return container:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

local function scanSlotContainer(container)
    local part = resolveSlotPart(container)
    if not part or not part.Parent then
        return
    end
    local highlight = container:FindFirstChild("ItemHighlight", true)
    local rarity = getRarityFromSlot(container)
    local color = RARITY_COLORS[rarity] or RARITY_COLORS.Common
    if highlight and highlight:IsA("Highlight") then
        color = highlight.OutlineColor
        rarity = colorToRarity(color)
        pcall(function()
            highlight.Enabled = true
        end)
    end
    local key = "slot_" .. container:GetFullName()
    local entry = {
        slotId = key,
        slotRef = part,
        name = getItemNameFromSlot(container),
        rarity = rarity,
        rarityColor = color,
        assetId = getAssetIdFromSlot(container),
    }
    State.shopCache[key] = enrichShopEntry(entry, container)
end

local function harvestGameBillboards()
    ensureShopRemotes()
    if not PlayerGui then
        return
    end
    for _, gui in ipairs(PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Name:sub(1, 5) == "__SB_" then
            for _, bg in ipairs(gui:GetChildren()) do
                if bg:IsA("BillboardGui") and bg.Adornee and bg.Adornee:IsA("BasePart") then
                    local labels = {}
                    for _, ch in ipairs(bg:GetChildren()) do
                        if ch:IsA("TextLabel") and ch.Text ~= "" then
                            table.insert(labels, ch)
                        end
                    end
                    if #labels > 0 then
                        local nameLabel = labels[1]
                        local priceLabel = labels[2]
                        local color = nameLabel.TextColor3
                        local rarity = colorToRarity(color)
                        local price = nil
                        if priceLabel then
                            price = tonumber(priceLabel.Text:match("%d+"))
                        end
                        local part = bg.Adornee
                        local key = "bb_" .. part:GetFullName()
                        local entry = {
                            slotId = key,
                            slotRef = part,
                            name = nameLabel.Text,
                            rarity = rarity,
                            rarityColor = color,
                            price = price,
                        }
                        State.shopCache[key] = enrichShopEntry(entry, part.Parent)
                    end
                end
            end
        end
    end
end

local function ingestShopReveal(payload)
    if type(payload) ~= "table" then
        return
    end
    local list = payload
    if not payload[1] and payload.slotId then
        list = { payload }
    end
    for _, info in ipairs(list) do
        if info and info.slotId then
            local part = info.slotRef
            if part and not part:IsA("BasePart") then
                part = resolveSlotPart(part)
            end
            if part and part.Parent then
                info.slotRef = part
                enrichShopEntry(info, part.Parent)
                State.shopCache[tostring(info.slotId)] = info
            end
        end
    end
end

local function collectShopRoots()
    local roots = {}
    local seen = {}
    local function add(root)
        if root and not seen[root] then
            seen[root] = true
            table.insert(roots, root)
        end
    end
    add(workspace:FindFirstChild("NPCSpawn"))
    add(workspace:FindFirstChild("ShopZones"))
    for _, child in ipairs(workspace:GetChildren()) do
        if child.Name:match("^Shop_ShopZone") or child.Name:match("^ShopZone") then
            add(child)
        end
    end
    return roots
end

local function fallbackScanShopParts()
    harvestGameBillboards()
    for _, root in ipairs(collectShopRoots()) do
        for _, desc in ipairs(root:GetDescendants()) do
            if desc.Name:match("^Slot_%d+$") and (desc:IsA("Model") or desc:IsA("Folder")) then
                scanSlotContainer(desc)
            elseif desc:IsA("Highlight") and desc.Name == "ItemHighlight" and desc.Parent then
                local slot = desc.Parent
                while slot and slot ~= root and not slot.Name:match("^Slot_%d+$") do
                    slot = slot.Parent
                end
                if slot and slot.Name:match("^Slot_%d+$") then
                    scanSlotContainer(slot)
                end
            end
        end
    end
end


-- ========== AutoBuy ==========
local function resolveShopZonePivot()
    local roots = collectShopRoots()
    for _, root in ipairs(roots) do
        if root and root:IsA("Model") then
            local ok, cf = pcall(function()
                return root:GetPivot()
            end)
            if ok and cf then
                return cf + Vector3.new(0, 0, 8)
            end
        end
        if root then
            local part = root:FindFirstChildWhichIsA("BasePart", true)
            if part then
                return part.CFrame + Vector3.new(0, 0, 6)
            end
        end
    end
    for _, root in ipairs(roots) do
        for _, desc in ipairs(root:GetDescendants()) do
            if desc:IsA("BasePart") and desc.Name:match("^Slot_") then
                return desc.CFrame + Vector3.new(0, 0, 5)
            end
        end
    end
    return nil
end

local function stealthTeleportToPart(part, holdSeconds)
    if not part or not part.Parent then
        return false
    end
    local targetCF = part.CFrame * CFrame.new(0, 0, 4)
    return applyHardTeleport(targetCF, holdSeconds or 1.8)
end

local function slotMatchesAutobuyTarget(entry, target)
    if not entry or not target then
        return false
    end
    if target.i and entry.assetId and tostring(entry.assetId) == tostring(target.i) then
        return true
    end
    if target.i and entry.id and tostring(entry.id) == tostring(target.i) then
        return true
    end
    if target.n and entry.name then
        local a = string.lower(entry.name)
        local b = string.lower(target.n)
        if a == b or a:find(b, 1, true) or b:find(a, 1, true) then
            return true
        end
    end
    return false
end

local function scanShopForTarget(target)
    ensureShopRemotes()
    harvestGameBillboards()
    fallbackScanShopParts()
    local hrp = getHRP()
    local best, bestDist = nil, math.huge
    for _, info in pairs(State.shopCache) do
        if slotMatchesAutobuyTarget(info, target) then
            local part = info.slotRef
            if part and part.Parent then
                local dist = (hrp.Position - part.Position).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    best = info
                end
            end
        end
    end
    return best
end

local function fireSlotPrompts(part)
    if not part then
        return
    end
    local function tryPrompt(prompt)
        if not prompt or not prompt:IsA("ProximityPrompt") then
            return
        end
        pcall(function()
            if fireproximityprompt then
                fireproximityprompt(prompt, 1)
            else
                prompt:InputHoldBegin()
                task.wait(0.1)
                prompt:InputHoldEnd()
            end
        end)
    end
    for _, desc in ipairs(part:GetDescendants()) do
        if desc:IsA("ProximityPrompt") then
            tryPrompt(desc)
        end
    end
    local parent = part.Parent
    if parent then
        for _, desc in ipairs(parent:GetDescendants()) do
            if desc:IsA("ProximityPrompt") then
                tryPrompt(desc)
            end
        end
    end
end

local function addItemToCart(part)
    if not ensureShopRemotes() or not part then
        return false
    end
    local takeMobile = ShopRemotes:FindFirstChild("TakeItemMobile")
    local take = ShopRemotes:FindFirstChild("TakeItem")
    local reqTake = ShopRemotes:FindFirstChild("RequestTakeItem")
    if takeMobile then
        safeRemoteCall(takeMobile, part)
    end
    if take then
        safeRemoteCall(take, part)
    end
    if reqTake then
        safeRemoteCall(reqTake, part)
    end
    fireSlotPrompts(part)
    return true
end

local function payShopCart()
    if not ensureShopRemotes() then
        return false
    end
    local confirm = ShopRemotes:FindFirstChild("ConfirmPurchase")
    if not confirm then
        return false
    end
    acWait(0.4)
    safeRemoteCall(confirm)
    return true
end

local function stopAutoBuy()
    State.autoBuyEnabled = false
end

local function runAutoBuyLoop()
    if State.autoBuyRunning then
        return
    end
    if not State.autoBuyTarget then
        notify("AutoBuy", "Выбери редкость и вещь", 4)
        return
    end
    State.autoBuyRunning = true
    State.autoBuyEnabled = true
    notify("AutoBuy", "Старт: " .. State.autoBuyTarget.n, 5)

    task.spawn(function()
        local target = State.autoBuyTarget
        local scans = 0
        while State.autoBuyEnabled do
            local hit = scanShopForTarget(target)
            if hit and hit.slotRef then
                notify("AutoBuy", "Найдено → " .. (hit.name or target.n), 4)
                stealthTeleportToPart(hit.slotRef, 2)
                task.wait(0.6)
                addItemToCart(hit.slotRef)
                task.wait(0.9)
                payShopCart()
                notify("AutoBuy", "Оплата отправлена", 4)
                if State.autoBuyOnce then
                    State.autoBuyEnabled = false
                    break
                end
                task.wait(2)
            else
                scans = scans + 1
                if scans % 3 == 1 then
                    notify("AutoBuy", "Скан ЦУМ (#" .. scans .. ")…", 3)
                end
                local zoneCF = resolveShopZonePivot()
                if zoneCF then
                    applyHardTeleport(zoneCF, 1.2)
                end
                task.wait(State.autoBuyScanInterval or 2.5)
            end
        end
        State.autoBuyRunning = false
        notify("AutoBuy", "Остановлен", 3)
    end)
end


-- ========== AutoFarm (ЦУМ -> Барыга) ==========
local function ensureInventoryHooks()
    if State.inventoryHooksReady then
        return true
    end
    local folder = ReplicatedStorage:FindFirstChild("InventoryRemotes")
    if not folder then
        return false
    end
    local updated = folder:FindFirstChild("InventoryUpdated")
    State.requestInventoryRemote = folder:FindFirstChild("RequestInventory")
    if updated and updated:IsA("RemoteEvent") then
        table.insert(
            State.connections,
            updated.OnClientEvent:Connect(function(payload)
                if type(payload) == "table" then
                    if payload.inventory then
                        State.inventory = payload.inventory
                    elseif payload[1] and type(payload[1]) == "table" and payload[1].uid then
                        State.inventory = payload
                    end
                end
            end)
        )
    end
    State.inventoryHooksReady = true
    return true
end

local function pullInventory()
    ensureInventoryHooks()
    if State.requestInventoryRemote then
        safeRemoteCall(State.requestInventoryRemote)
    end
    task.wait(0.65)
end

local function inventoryItemMatches(target, item)
    if not target or not item then
        return false
    end
    if target.i then
        local aid = item.id or item.assetId or item.templateId
        if aid and tonumber(aid) == tonumber(target.i) then
            return true
        end
    end
    if target.n and item.name then
        local a = string.lower(item.name)
        local b = string.lower(target.n)
        if a == b or a:find(b, 1, true) or b:find(a, 1, true) then
            return true
        end
    end
    return false
end

local function findItemUid(target)
    for _, item in ipairs(State.inventory or {}) do
        if inventoryItemMatches(target, item) and item.uid then
            return item.uid, item
        end
    end
    return nil
end

local function pickBestFarmItem(rarity)
    local items = getAutobuyItemsForRarity(rarity)
    local best, bestScore = nil, -1
    for _, it in ipairs(items) do
        local spawnChance = it.s or 0
        local fairPrice = it.p or 0
        if spawnChance > 0 and fairPrice > 0 then
            if spawnChance > bestScore then
                bestScore = spawnChance
                best = it
            end
        end
    end
    return best or items[1]
end

local function ensureBarigaRemotes()
    if State.barigaRemotesFolder then
        return true
    end
    local folder = ReplicatedStorage:FindFirstChild("BarigaRemotes")
    if not folder then
        return false
    end
    State.barigaRemotesFolder = folder
    return true
end

local function visitBarigaSync()
    local targetCF = resolveBarigaTarget()
    if not targetCF then
        return false, "BarigaNPC не найден"
    end
    for _ = 1, 3 do
        streamPosition(targetCF.Position)
        task.wait(0.4)
    end
    if not applyHardTeleport(targetCF, State.barigaHoldSeconds or 2) then
        return false, "ТП к барыге не удался"
    end
    task.wait((State.barigaHoldSeconds or 2) + 0.45)
    stopBarigaHold()
    restorePlayerMovement()
    tryFireBarigaPrompt()
    task.wait(0.15)
    openBarigaMenu()
    task.wait(0.9)
    return true
end

local function sellItemToBariga(target)
    if not ensureBarigaRemotes() then
        return false, "BarigaRemotes"
    end
    local folder = State.barigaRemotesFolder
    local getOffer = folder:FindFirstChild("GetBarigaOffer")
    local getInv = folder:FindFirstChild("GetBarigaInventory")
    local confirm = folder:FindFirstChild("ConfirmBarigaSale")
    local closeRemote = folder:FindFirstChild("CloseBariga")

    pullInventory()
    local uid = findItemUid(target)
    if not uid and getInv then
        local ok, inv = pcall(function()
            return getInv:InvokeServer()
        end)
        if ok and type(inv) == "table" then
            for _, item in ipairs(inv) do
                if inventoryItemMatches(target, item) and item.uid then
                    uid = item.uid
                    break
                end
            end
        end
    end
    if not uid then
        return false, "Вещь не найдена в инвентаре"
    end

    if getOffer then
        pcall(function()
            getOffer:InvokeServer({ uid })
        end)
        acWait(0.35)
    end
    if confirm then
        safeRemoteCall(confirm, true)
        acWait(0.45)
    else
        return false, "ConfirmBarigaSale"
    end
    if closeRemote then
        safeRemoteCall(closeRemote)
    end
    pullInventory()
    return true, uid
end

local function stopAutoFarm()
    State.autoFarmEnabled = false
end

local function runAutoFarmLoop()
    if State.autoFarmRunning then
        return
    end
    ensureInventoryHooks()
    local target = State.autoFarmTarget
    if not target and State.autoFarmUseBest then
        target = pickBestFarmItem(State.autoFarmRarity or State.autoBuyRarity or "Common")
        State.autoFarmTarget = target
    end
    if not target then
        notify("AutoFarm", "Выбери вещь или включи «Лучший шанс»", 4)
        return
    end

    State.autoFarmRunning = true
    State.autoFarmEnabled = true
    State.autoBuyEnabled = false
    notify("AutoFarm", "Старт: " .. target.n, 5)

    task.spawn(function()
        local cycles = 0
        while State.autoFarmEnabled do
            cycles = cycles + 1
            local activeTarget = State.autoFarmTarget or target
            local bought = false
            local scans = 0

            while State.autoFarmEnabled and not bought do
                local hit = scanShopForTarget(activeTarget)
                if hit and hit.slotRef then
                    notify("AutoFarm", "Покупка: " .. (hit.name or activeTarget.n), 3)
                    stealthTeleportToPart(hit.slotRef, 2)
                    task.wait(0.6)
                    addItemToCart(hit.slotRef)
                    task.wait(0.9)
                    payShopCart()
                    task.wait(1.1)
                    pullInventory()
                    bought = findItemUid(activeTarget) ~= nil
                else
                    scans = scans + 1
                    if scans % 3 == 1 then
                        notify("AutoFarm", "Скан ЦУМ (#" .. scans .. ")", 2)
                    end
                    local zoneCF = resolveShopZonePivot()
                    if zoneCF then
                        applyHardTeleport(zoneCF, 1.2)
                    end
                    task.wait(State.autoFarmScanInterval or 2.5)
                end
            end

            if not bought or not State.autoFarmEnabled then
                break
            end

            notify("AutoFarm", "Продажа барыге...", 3)
            local okVisit = visitBarigaSync()
            if not okVisit then
                notify("AutoFarm", "Не удалось дойти до барыги", 5)
                task.wait(2)
            else
                local okSell, info = sellItemToBariga(activeTarget)
                if okSell then
                    notify("AutoFarm", "Цикл #" .. cycles .. " OK", 4)
                else
                    notify("AutoFarm", "Продажа: " .. tostring(info), 5)
                end
            end

            if State.autoFarmUseBest then
                State.autoFarmTarget = pickBestFarmItem(State.autoFarmRarity or "Common")
                activeTarget = State.autoFarmTarget
            end

            if State.autoFarmMaxCycles and cycles >= State.autoFarmMaxCycles then
                State.autoFarmEnabled = false
                State.autoFarmMaxCycles = nil
            end

            task.wait(State.autoFarmDelay or 2)
        end
        State.autoFarmRunning = false
        notify("AutoFarm", "Остановлен", 3)
    end)
end


local function getAutobuyItemsForRarity(rarity)
    if not AUTOBUY_ITEMS then
        return {}
    end
    return AUTOBUY_ITEMS[rarity] or {}
end

local function buildAutobuyItemNames(rarity)
    local names = {}
    for _, it in ipairs(getAutobuyItemsForRarity(rarity)) do
        table.insert(names, it.n)
    end
    table.sort(names)
    return names
end

local function resolveAutobuyTargetByName(name, rarity)
    for _, it in ipairs(getAutobuyItemsForRarity(rarity)) do
        if it.n == name then
            return it
        end
    end
    return nil
end

local function ensureEspScreen()
    if State.espUi and State.espUi.screen and State.espUi.screen.Parent then
        State.espUi.pool = State.espUi.pool or {}
        State.espUi.live = State.espUi.live or {}
        return State.espUi
    end
    local gui = Instance.new("ScreenGui")
    gui.Name = "TSUM_ESP_Overlay"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 500
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = PlayerGui
    State.espUi = { screen = gui, pool = {}, live = {} }
    return State.espUi
end

local function releaseEspWidget(ui, holder)
    local w = ui.live[holder]
    if w then
        holder.Visible = false
        ui.live[holder] = nil
        table.insert(ui.pool, w)
    end
end

local function acquireEspWidgets(ui)
    local w = table.remove(ui.pool)
    if w then
        return w
    end
    local holder = Instance.new("Frame")
    holder.BackgroundTransparency = 1
    holder.Size = UDim2.fromOffset(0, 0)
    holder.Visible = false
    holder.Parent = ui.screen

    local tracer = Instance.new("Frame")
    tracer.BorderSizePixel = 0
    tracer.AnchorPoint = Vector2.new(0.5, 0.5)
    tracer.ZIndex = 2
    tracer.Parent = holder

    local box = Instance.new("Frame")
    box.BackgroundTransparency = 1
    box.ZIndex = 3
    box.Parent = holder
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Parent = box

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromOffset(300, 36)
    label.TextWrapped = true
    label.AnchorPoint = Vector2.new(0.5, 1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.TextStrokeTransparency = 0.3
    label.ZIndex = 4
    label.Parent = holder

    return { holder = holder, tracer = tracer, box = box, stroke = stroke, label = label }
end

local function drawLine(frame, fromPos, toPos, thickness, color)
    local dx = toPos.X - fromPos.X
    local dy = toPos.Y - fromPos.Y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 2 then
        frame.Visible = false
        return
    end
    frame.Visible = true
    frame.BackgroundColor3 = color
    frame.Size = UDim2.fromOffset(dist, thickness)
    frame.Position = UDim2.fromOffset((fromPos.X + toPos.X) * 0.5, (fromPos.Y + toPos.Y) * 0.5)
    frame.Rotation = math.deg(math.atan2(dy, dx))
end

local function clearAllESP()
    if State.espUi and State.espUi.screen then
        State.espUi.screen:Destroy()
    end
    State.espUi = nil
end

local function renderEspFrame()
    if not State.espEnabled then
        return
    end
    ensureShopRemotes()
    local camera = workspace.CurrentCamera
    local hrp = getHRP()
    if not camera or not hrp then
        return
    end
    if tick() - State.lastEspScan >= State.espScanInterval then
        fallbackScanShopParts()
        State.lastEspScan = tick()
    end
    local ui = ensureEspScreen()
    local active = {}
    local tracerFrom = Vector2.new(camera.ViewportSize.X * 0.5, camera.ViewportSize.Y - 6)
    local drawn = 0

    for slotId, info in pairs(State.shopCache) do
        if drawn >= 48 then
            break
        end
        local part = info.slotRef
        if part and part.Parent then
            local rarity = getRarityFromShopInfo(info)
            if isRaritySelected(rarity) then
                local worldPos = part.Position + Vector3.new(0, 2.2, 0)
                if (worldPos - hrp.Position).Magnitude <= State.espMaxDistance then
                    local screenPos, onScreen = camera:WorldToViewportPoint(worldPos)
                    if onScreen and screenPos.Z > 0 then
                        drawn = drawn + 1
                        local color = getColorFromShopInfo(info, rarity)
                        local w = acquireEspWidgets(ui)
                        ui.live[w.holder] = w
                        active[w.holder] = true
                        local center = Vector2.new(screenPos.X, screenPos.Y)
                        local boxSize = math.clamp(3200 / math.max(screenPos.Z, 1), 24, 140)
                        drawLine(w.tracer, tracerFrom, center, 2, color)
                        w.box.Visible = true
                        w.box.Size = UDim2.fromOffset(boxSize, boxSize)
                        w.box.Position = UDim2.fromOffset(center.X - boxSize * 0.5, center.Y - boxSize * 0.5)
                        w.stroke.Color = color
                        w.label.Visible = true
                        w.label.Position = UDim2.fromOffset(center.X, center.Y - boxSize * 0.5 - 4)
                        w.label.TextColor3 = color
                        w.label.Text = buildEspLabel(info, rarity)
                        w.holder.Visible = true
                    end
                end
            end
        else
            State.shopCache[slotId] = nil
        end
    end

    for holder in pairs(ui.live) do
        if not active[holder] then
            releaseEspWidget(ui, holder)
        end
    end
end

local function refreshESP()
    if State.espEnabled then
        fallbackScanShopParts()
    end
end

local function setESP(enabled)
    ensureShopRemotes()
    State.espEnabled = enabled
    if not enabled then
        clearAllESP()
        notify("ESP", "Подсветка выключена", 3)
        return
    end
    fallbackScanShopParts()
    local n = 0
    for _ in pairs(State.shopCache) do
        n = n + 1
    end
    notify("ESP", "ЦУМ ESP: " .. n .. " слотов. Каталог: " .. (SHOP_CATALOG and "OK" or "нет") .. ".", 6)
end

local function disconnectLoop()
    for _, conn in ipairs(State.connections) do
        conn:Disconnect()
    end
    for _k in pairs(State.connections) do State.connections[_k] = nil end
end

local function startESPLoop()
    disconnectLoop()
    table.insert(State.connections, RunService.RenderStepped:Connect(function()
        if State.espEnabled then
            renderEspFrame()
        end
    end))
end

TSUM.State = State
TSUM.notify = notify
TSUM.getHRP = getHRP
TSUM.teleportToBariga = teleportToBariga
TSUM.runAutoBuyLoop = runAutoBuyLoop
TSUM.stopAutoBuy = stopAutoBuy
TSUM.runAutoFarmLoop = runAutoFarmLoop
TSUM.stopAutoFarm = stopAutoFarm
TSUM.setESP = setESP
TSUM.refreshESP = refreshESP
TSUM.startESPLoop = startESPLoop
TSUM.scanShopForTarget = scanShopForTarget
TSUM.getAutobuyItemsForRarity = getAutobuyItemsForRarity
TSUM.buildAutobuyItemNames = buildAutobuyItemNames
TSUM.resolveAutobuyTargetByName = resolveAutobuyTargetByName
TSUM.pickBestFarmItem = pickBestFarmItem
TSUM.stopBarigaHold = stopBarigaHold
TSUM.openBarigaMenu = openBarigaMenu
TSUM.tryFireBarigaPrompt = tryFireBarigaPrompt
TSUM.ShopRemotes = ShopRemotes
