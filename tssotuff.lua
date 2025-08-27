-- // Libraries
local Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/discoart/FluentPlus/refs/heads/main/alpha.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()

-- // Services
-- // Services
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Camera = workspace.CurrentCamera
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
-- =========================================================
-- Global IDs / gating
-- =========================================================
local ALLOWED_GAME_ID = 115509275831248 -- webhook will only work in this universe
local PLACE_MAIN = 14067600077          -- matchmaking/main
local PLACE_CULL = 18637069183          -- culling games

-- =========================================================
-- Webhook internals (declare BEFORE UI callbacks use them)
-- =========================================================


-- // Setup Window
local Window = Fluent:CreateWindow({
    Title = "type soul | Dead Hub",
    SubTitle = "Made by Dead | Version: "..Fluent.Version,
    TabWidth = 160,
    Size = UDim2.fromOffset(540, 340),
    Acrylic = false,
    Theme = "Dark",
    Center = true,
    IsDraggable = true,
    Keybind = Enum.KeyCode.LeftControl
})





-------

local maintab = Window:AddTab({ Title = "Main", Icon = "home"})


maintab:AddParagraph({ Title = "bleh ", Content = "tbh idk what to add in the main tab gng" })

-- =========================================================
-- Auto Culling Game Tab
-- =========================================================
local CullingTab = Window:AddTab({ Title = "Auto Culling Game", Icon = "swords" })
CullingTab:AddParagraph({ Title = "⚠️ Reminder", Content = "Make sure to add this to auto load if you want to AFK farm it.\nTo add it just go to the settings tab and you will see everything." })




local chosenSlot = "A" -- default slot

-- Dropdown for selecting slot
CullingTab:AddDropdown("SlotSelect", {
    Title = "Choose Slot",
    Values = {"A", "B", "C", "D"},
    Multi = false,
    Default = 1,
    Callback = function(value)
        chosenSlot = value:upper()
        print("[Slot Selected] ->", chosenSlot)
    end
})

-- AutoTP toggle
local AutoTP = false
local AutoTPTask

CullingTab:AddToggle("AutoTP", {
    Title = "Auto TP To Matchmaking",
    Default = false,
    Callback = function(state)
        AutoTP = state

        -- Stop previous task if exists
        if AutoTPTask then
            AutoTPTask:Cancel()
            AutoTPTask = nil
        end

        if AutoTP then
            AutoTPTask = task.spawn(function()
                while AutoTP do
                    local remotes = RS:FindFirstChild("Remotes")
                    local chooseSlotRemote = remotes and remotes:FindFirstChild("ChooseSlot")

                    if chooseSlotRemote then
                        local ok, err = pcall(function()
                            print("[AutoTP] Trying to TP with slot:", chosenSlot)
                            -- ✅ Correct arguments: slot + "Matchmaking"
                            chooseSlotRemote:InvokeServer(chosenSlot, "Matchmaking")
                        end)

                        if not ok then
                            warn("[AutoTP] Failed to TP:", err)
                        else
                            print("[AutoTP] Teleport request sent successfully!")
                        end
                    else
                        warn("[AutoTP] Couldn't find ChooseSlot remote!")
                    end

                    task.wait(5)
                end
            end)
        else
            print("[AutoTP] Disabled.")
        end
    end
})

local AutoStart = false
CullingTab:AddToggle("AutoStart", {
    Title = "Auto Start Culling Game",
    Default = false,
    Callback = function(state)
        AutoStart = state
        task.spawn(function()
            while AutoStart do
                if game.PlaceId == PLACE_CULL then
                    local rem = RS:FindFirstChild("Remotes")
                    local teamR = rem and rem:FindFirstChild("Team")
                    if teamR then
                        local ok, err = pcall(function()
                            teamR:FireServer("JoinQueue", "CULLING GAMES")
                        end)
                        if not ok then warn("[AutoStart] FireServer failed:", err) end
                    end

                    -- wait 2 mins and serverhop if stuck
                    local start = tick()
                    while AutoStart and tick() - start < 120 do task.wait(1) end
                    if AutoStart and game.PlaceId == PLACE_CULL then
                        TeleportService:Teleport(game.PlaceId)
                    end
                end
                task.wait(5)
            end
        end)
    end
})

CullingTab:AddParagraph({ Title = "WARNING.!!", Content = "AUTO RESET IS DETECTED\nITS FOR PPL WHO WANT QUICK CASH\nIF U USE IT U WILL BE BANNED WITHIN 1 WEEK!!" })



local autoResetEnabled = false

-- // Auto Reset Toggle
CullingTab:AddToggle("autorest",{
    Title = "Auto Reset",
    Default = false,
    Callback = function(state)
        autoResetEnabled = state
        if state then
            task.spawn(function()
                while autoResetEnabled do
                    task.wait(1) -- checks every 1 second
                    local char = LocalPlayer.Character
                    if char and char:FindFirstChild("Humanoid") then
                        local humanoid = char.Humanoid
                        if humanoid.Health > 0 then
                            humanoid.Health = 0 -- forces reset
                        end
                    end
                end
            end)
        end
    end
})


-- // Services

-- // Tabs
local EspTab = Window:AddTab({
    Title = "ESP",
    Icon = "eye"
})
local MobileTab = Window:AddTab({
    Title = "Mobile Stuff",
    Icon = "smartphone"
})


-- // Mobile Buttons
MobileTab:AddButton({
    Title = "Comma (Show NPCs)",
    Callback = function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendKeyEvent(true, Enum.KeyCode.Comma, false, game)  -- press
        task.wait(0.1)
        vim:SendKeyEvent(false, Enum.KeyCode.Comma, false, game) -- release
    end
})

-- // Mobile Buttons
MobileTab:AddButton({
    Title = "Dance ( dance wit ur buh)"",
    Callback = function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendKeyEvent(true, Enum.KeyCode.P, false, game)  -- press
        task.wait(0.1)
        vim:SendKeyEvent(false, Enum.KeyCode.P, false, game) -- release
    end
})

-- // Mobile Buttons
MobileTab:AddButton({
    Title = "Rip Mask Off (CTRL + K)",
    Callback = function()
        local vim = game:GetService("VirtualInputManager")

        -- Hold CTRL
        vim:SendKeyEvent(true, Enum.KeyCode.LeftControl, false, game)
        task.wait(0.05)

        -- Press K
        vim:SendKeyEvent(true, Enum.KeyCode.K, false, game)
        task.wait(0.1)
        vim:SendKeyEvent(false, Enum.KeyCode.K, false, game)

        -- Release CTRL
        task.wait(0.05)
        vim:SendKeyEvent(false, Enum.KeyCode.LeftControl, false, game)
    end
})


-- // Vars
local espEnabled = false
local npcEspEnabled = false
local itemEspEnabled = false -- NEW
local npcTypes = {"Fishbone", "Menos", "Adjuchas","Bawabawa","Arrancar","Shinigami"}

local selectedNPCs = {}
local espConnections = {}
local npcEspConnections = {}
local itemEspConnections = {} -- NEW

-- // Functions
local function createBillboard(parent, text)
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 200, 0, 50)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Name = "ESP_BB"
    bb.Parent = parent

    local label = Instance.new("TextLabel", bb)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.SourceSansBold
    label.TextScaled = true
    label.Text = text

    return bb, label
end

local function clearESP(tbl)
    for _, v in pairs(tbl) do
        if v and v.Parent then
            v:Destroy()
        end
    end
    table.clear(tbl)
end

-- // PLAYER ESP
local function updatePlayerESP()
    clearESP(espConnections)
    if not espEnabled then return end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = Workspace.Entities:FindFirstChild(plr.Name)
            if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChildOfClass("Humanoid") then
                local hum = char:FindFirstChildOfClass("Humanoid")
                local race = plr:GetAttribute("Race") or "Unknown"
                local dist = (LocalPlayer.Character.HumanoidRootPart.Position - char.HumanoidRootPart.Position).Magnitude
                local bb, label = createBillboard(char.HumanoidRootPart, "")
                label.Text = string.format(
                    "User: %s |Race: %s \nDistance: %d |HP: %d/%d",
                    plr.DisplayName, plr.Name, race, dist, hum.Health, hum.MaxHealth
                )
                espConnections[#espConnections+1] = bb
            end
        end
    end
end

-- // NPC ESP
local function updateNpcESP()
    clearESP(npcEspConnections)
    if not npcEspEnabled then return end

    for _, npc in ipairs(Workspace.Entities:GetChildren()) do
        for _, npcName in ipairs(selectedNPCs) do
            local trueName = npcName == "Adjuchas" and "Jackal" or npcName
            if string.find(npc.Name, trueName) and npc:FindFirstChild("HumanoidRootPart") then
                local dist = (LocalPlayer.Character.HumanoidRootPart.Position - npc.HumanoidRootPart.Position).Magnitude
                local bb, label = createBillboard(npc.HumanoidRootPart, "")
                label.Text = string.format("NPC: %s | Distance: %d", npcName, dist)
                npcEspConnections[#npcEspConnections+1] = bb
            end
        end
    end
end

-- // ITEM ESP
local function updateItemESP()
    clearESP(itemEspConnections)
    if not itemEspEnabled then return end

    for _, item in ipairs(Workspace.DroppedItems:GetChildren()) do
        if item:FindFirstChild("PrimaryPart") or item:FindFirstChild("Handle") then
            local part = item.PrimaryPart or item:FindFirstChild("Handle")
            local dist = (LocalPlayer.Character.HumanoidRootPart.Position - part.Position).Magnitude
            local bb, label = createBillboard(part, "")
            label.Text = string.format("Item: %s | Distance: %d", item.Name, dist)
            itemEspConnections[#itemEspConnections+1] = bb
        end
    end
end

-- // Auto Update ESP every 5s
task.spawn(function()
    while true do
        task.wait(2)
        if espEnabled then updatePlayerESP() end
        if npcEspEnabled then updateNpcESP() end
        if itemEspEnabled then updateItemESP() end -- NEW
    end
end)

-- // Toggles
local npcsection = EspTab:AddSection("Npc esp")
npcsection:AddDropdown("NpcSelect", {
    Title = "Choose NPCs",
    Values = npcTypes,
    Multi = true,
    Default = {},
    Callback = function(values)
        selectedNPCs = {}
        for name, chosen in pairs(values) do
            if chosen then
                table.insert(selectedNPCs, name)
            end
        end
        if npcEspEnabled then updateNpcESP() end
    end
})

npcsection:AddToggle("NpcESP", {
    Title = "NPC ESP",
    Default = false,
    Callback = function(state)
        npcEspEnabled = state
        if not state then
            clearESP(npcEspConnections)
        else
            updateNpcESP()
        end
    end
})

local playsection = EspTab:AddSection("Player esp")
playsection:AddToggle("PlayerESP", {
    Title = "Player ESP",
    Default = false,
    Callback = function(state)
        espEnabled = state
        if not state then
            clearESP(espConnections)
        else
            updatePlayerESP()
        end
    end
})

local itemsection = EspTab:AddSection("Item esp") -- NEW
itemsection:AddToggle("ItemESP", {
    Title = "Dropped Items ESP",
    Default = false,
    Callback = function(state)
        itemEspEnabled = state
        if not state then
            clearESP(itemEspConnections)
        else
            updateItemESP()
        end
    end
})



-- ========================================================= --
-- Webhook Tab
-- ========================================================= --
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

-- Try requiring clientItems safely
local clientItems
local clientItemsExists = pcall(function()
    clientItems = require(RS.Modules.ClientModules.ClientItems)
end)

-- Webhook variables
local WEBHOOK_URL = ""
local WebhookEnabled = false
local collectedItems = {}
local sending = false
local AutoCrashOnSpecialItem = false -- 🆕 Auto crash toggle

-- Request function detection
local req = (syn and syn.request) or (http and http.request) or (http_request) or (fluxus and fluxus.request) or request

-- Items that should ping @everyone and trigger auto-leave if enabled
local pingItems = {
    ["Yhwach's Blood"] = true,
    ["Vow Of Luck"] = true,
    ["Hogyoku Ball"] = true,
    ["Vow Of Sacrifice"] = true,
    ["Vow Of Potential"] = true,
    ["Hogyoku Fragment"] = true,
    ["Skill Box"] = true,
    ["Skill box Chooser"] = true
}

-- Function to handle special items (leave game if toggle is on)
local function handleSpecialItem(itemName)
    if AutoCrashOnSpecialItem and pingItems[itemName] then
        warn("⚠️ Special item found: " .. itemName .. " — Leaving the game!")
        TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
    end
end

-- Send webhook data (queue items)
local function sendWebhook(itemName, count)
    if not WebhookEnabled then return end
    if WEBHOOK_URL == "" then
        warn("⚠️ Webhook URL is empty, skipping send")
        return
    end
    if not req then
        warn("❌ No request function available, webhook can't be sent")
        return
    end

    -- Check if item already exists in the queue, if so, add to its count
    local found = false
    for _, drop in ipairs(collectedItems) do
        if drop.item == itemName then
            drop.count = drop.count + count
            found = true
            break
        end
    end

    -- If item wasn't found, insert as new
    if not found then
        table.insert(collectedItems, { item = itemName, count = count })
    end

    -- If we're already waiting to send, don't start a new timer
    if sending then return end
    sending = true

    -- Wait 2 seconds, then send one webhook for all collected items if any exist
    task.delay(2, function()
        if #collectedItems == 0 then
            sending = false
            return
        end

        -- Build one embed description for all items
        local description = ""
        local shouldPing = false
        for _, drop in ipairs(collectedItems) do
            description = description .. string.format("**Item:** %s | **Count:** %s\n", drop.item, drop.count)
            if pingItems[drop.item] then
                shouldPing = true
            end
        end

        local data = {
            username = "Type Soul Logger",
            content = shouldPing and "@everyone" or nil,
            embeds = {{
                title = "🎯 Items Obtained!",
                description = description,
                color = shouldPing and 0xFF0000 or 0x00FF00,
                footer = { text = "Type Soul Culling Games Tracker" },
                timestamp = DateTime.now():ToIsoDate()
            }}
        }

        -- Double-check: only send if there are still items
        if #collectedItems > 0 then
            req({
                Url = WEBHOOK_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(data)
            })
        end

        -- Clear collected items and reset sending state
        collectedItems = {}
        sending = false
    end)
end

-- Hook clientItems.ItemObtained ONLY if it exists
if clientItemsExists and clientItems and clientItems.ItemObtained then
    local oldItemObtained
    oldItemObtained = hookfunction(clientItems.ItemObtained, function(player, itemName, count, ...)
        print("[Item Obtained] Player:", player and player.Name or "nil", " | Item:", itemName, " | Count:", count)
        handleSpecialItem(itemName) -- 🆕 Leave game if special item found
        sendWebhook(itemName, count)
        return oldItemObtained(player, itemName, count, ...)
    end)

    print("✅ Webhook logger hooked into ItemObtained. Rewards will show in Discord + console when enabled.")
else
    warn("⚠️ clientItems module not found — webhook logger disabled")
end

-- 🟢 WEBHOOK UI TAB 🟢
local WebhookTab = Window:AddTab({ Title = "Webhook", Icon = "globe" })

WebhookTab:AddParagraph({
    Title = "⚠️ Reminder",
    Content = "Make sure to add this to auto load if you want to AFK farm it.\nTo add it just go to the settings tab and you will see everything."
})

WebhookTab:AddInput("WebhookInput", {
    Title = "Webhook URL",
    Placeholder = "Enter your webhook here",
    Callback = function(value)
        WEBHOOK_URL = value or ""
    end
})

WebhookTab:AddToggle("WebhookToggle", {
    Title = "Enable Webhook Logger",
    Default = false,
    Callback = function(state)
        if not clientItemsExists then
            Fluent:Notify({
                Title = "Webhook Logger",
                Content = "❌ Can't enable webhook logging, clientItems missing!",
                Duration = 5
            })
            return
        end
        WebhookEnabled = state
        Fluent:Notify({
            Title = "Webhook Logger",
            Content = state and "✅ Enabled webhook logging!" or "❌ Disabled webhook logging!",
            Duration = 5
        })
    end
})

-- 🆕 New toggle for auto-crash/leave
WebhookTab:AddToggle("AutoCrashToggle", {
    Title = "Auto Crash if Special Item Found",
    Default = false,
    Callback = function(state)
        AutoCrashOnSpecialItem = state
        Fluent:Notify({
            Title = "Special Item Auto Crash",
            Content = state and "✅ Enabled auto crash on special item!" or "❌ Disabled auto crash on special item!",
            Duration = 5
        })
    end
})

WebhookTab:AddButton({
    Title = "Test Webhook",
    Description = "Send test drops to your webhook",
    Callback = function()
        if WEBHOOK_URL == "" then
            Fluent:Notify({ Title = "Error", Content = "Please input a webhook first!", Duration = 5 })
            return
        end
        table.insert(collectedItems, { item = "Test Drop", count = 1 })
        sendWebhook("Test Drop", 1)
        Fluent:Notify({ Title = "Webhook", Content = "✅ Test drop sent!", Duration = 5 })
    end
})

WebhookTab:AddParagraph({ Title = "Webhook Credits", Content = "96ms & gs._" })

-- 🔥 TEST trigger (only runs if clientItems exists)
if clientItemsExists and clientItems and clientItems.ItemObtained then
    task.delay(3, function()
        local lp = Players.LocalPlayer
        print("🧪 Sending test item to webhook...")
        sendWebhook("Test Sword of Doom", 2)
        clientItems.ItemObtained(lp, "Test Sword of Doom", 2)
    end)
end
    
    
    
    
    
    local extra = Window:AddTab({ Title = "extra", Icon = "cpu" })

-- Store original settings so we can restore
local originalSettings = {
    FogStart = Lighting.FogStart,
    FogEnd = Lighting.FogEnd,
    Brightness = Lighting.Brightness,
    GlobalShadows = Lighting.GlobalShadows,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    QualityLevel = settings().Rendering.QualityLevel
}
local FPSTab = extra:AddSection("Fps boost")

-- 🌫️ Remove Fog
FPSTab:AddButton({
    Title = "Remove Fog",
    Callback = function()
        Lighting.FogStart = 1e6
        Lighting.FogEnd = 1e6
    end
})

-- 🌙 Lower Brightness
FPSTab:AddButton({
    Title = "Lower Brightness",
    Callback = function()
        Lighting.Brightness = 1
        Lighting.GlobalShadows = false
        Lighting.OutdoorAmbient = Color3.fromRGB(128,128,128)
    end
})

-- 🚀 FPS Boost
FPSTab:AddButton({
    Title = "FPS Boost",
    Callback = function()
        -- Lower graphics-heavy settings
        sethiddenproperty(workspace, "InterpolationThrottling", Enum.InterpolationThrottlingMode.Disabled)
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01

        -- Destroy unnecessary effects
        for _, v in pairs(workspace:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") then
                v:Destroy()
            end
        end

        -- Shadows off
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 1e6
        Lighting.Brightness = 1
    end
})

-- 🔄 Restore Defaults
FPSTab:AddButton({
    Title = "Restore Defaults",
    Callback = function()
        Lighting.FogStart = originalSettings.FogStart
        Lighting.FogEnd = originalSettings.FogEnd
        Lighting.Brightness = originalSettings.Brightness
        Lighting.GlobalShadows = originalSettings.GlobalShadows
        Lighting.OutdoorAmbient = originalSettings.OutdoorAmbient
        settings().Rendering.QualityLevel = originalSettings.QualityLevel
    end
})


local extrastuff = extra:AddSection("some extra stuff")

extrastuff:AddButton({
    Title = "Enable Full Chat",
    Callback = function()
        local Players = game:GetService("Players")
        local StarterGui = game:GetService("StarterGui")
        local ReplicatedStorage = game:GetService("ReplicatedStorage")

        -- First try to enable default chat
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)

        -- Disable bubble-only chat if possible
        pcall(function()
            local ChatService = game:GetService("Chat")
            ChatService.BubbleChatEnabled = false
        end)

        -- If no chat UI exists, try reinjecting Roblox's DefaultChatSystem
        task.delay(1, function()
            local player = Players.LocalPlayer
            local playerGui = player:WaitForChild("PlayerGui")

            if not playerGui:FindFirstChild("Chat") then
                local chatModule = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatModules")
                if chatModule then
                    local chatClone = chatModule:Clone()
                    chatClone.Name = "Chat"
                    chatClone.Parent = playerGui
                    print("[CHAT FIX] DefaultChatSystem re-injected!")
                else
                    warn("[CHAT FIX] Could not find DefaultChatSystemChatModules in ReplicatedStorage!")
                end
            else
                print("[CHAT FIX] Chat enabled successfully!")
            end
        end)
    end
})




-- =========================================================
-- SaveManager & InterfaceManager Setup
-- =========================================================
local Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })


SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("DeadScriptHub")
SaveManager:SetFolder("DeadScriptHub/TypeSoul")
InterfaceManager:BuildInterfaceSection(Settings)
SaveManager:BuildConfigSection(Settings)

Window:SelectTab(1)

Fluent:Notify({
    Title = "Type Soul",
    Content = "Script loaded and ready.",
    Duration = 8,
})

SaveManager:LoadAutoloadConfig()


-- // Auto rejoin Type Soul after 950 seconds (~15m 50s)
task.delay(1200, function()
    local TeleportService = game:GetService("TeleportService")
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer

    -- Safety check to avoid errors
    if player and TeleportService then
        warn("⏳ 950 seconds passed! Rejoining Type Soul...")
        TeleportService:Teleport(14067600077, player)
    else
        warn("⚠️ Couldn't rejoin — TeleportService or LocalPlayer missing.")
    end
end)
