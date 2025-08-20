-- // Libraries
local Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/discoart/FluentPlus/refs/heads/main/alpha.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()

-- // Services
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer

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

-- =========================================================
-- Auto Culling Game Tab
-- =========================================================
local CullingTab = Window:AddTab({ Title = "Auto Culling Game", Icon = "swords" })
CullingTab:AddParagraph({ Title = "⚠️ Reminder", Content = "Make sure to add this to auto load if you want to AFK farm it.\nTo add it just go to the settings tab and you will see everything." })

local chosenSlot = "A"
CullingTab:AddDropdown("SlotSelect", {
    Title = "Choose Slot",
    Values = {"A", "B", "C", "D"},
    Multi = false,
    Default = 1,
    Callback = function(value)
        chosenSlot = value:upper()
    end
})

local AutoTP = false
CullingTab:AddToggle("AutoTP", {
    Title = "Auto TP To Matchmaking",
    Default = false,
    Callback = function(state)
        AutoTP = state
        task.spawn(function()
            while AutoTP do
                if game.PlaceId == 14067600077 then
                    local args = {chosenSlot, "Matchmaking"}
                    local ok, err = pcall(function()
                        RS.Remotes.ChooseSlot:InvokeServer(unpack(args))
                    end)
                    if not ok then warn("[AutoTP] Invoke failed:", err) end
                end
                task.wait(5)
            end
        end)
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
                if game.PlaceId == 18637069183 then
                    local ok, err = pcall(function()
                        RS.Remotes.Team:FireServer("JoinQueue", "CULLING GAMES")
                    end)
                    if not ok then warn("[AutoStart] FireServer failed:", err) end

                    -- wait 2 mins and serverhop if stuck
                    local start = tick()
                    while AutoStart and tick() - start < 120 do
                        task.wait(1)
                    end
                    if AutoStart and game.PlaceId == 18637069183 then
                        TeleportService:Teleport(game.PlaceId)
                    end
                end
                task.wait(5)
            end
        end)
    end
})

-- =========================================================
-- Webhook Tab
-- =========================================================
local WebhookTab = Window:AddTab({ Title = "Webhook", Icon = "globe" })
WebhookTab:AddParagraph({ Title = "⚠️ Reminder", Content = "Make sure to add this to auto load if you want to AFK farm it.\nTo add it just go to the settings tab and you will see everything." })

local WEBHOOK_URL = ""
WebhookTab:AddInput("WebhookInput", {
    Title = "Webhook URL",
    Placeholder = "Enter your webhook here",
    Callback = function(value)
        WEBHOOK_URL = value or ""
    end
})

local WebhookEnabled = false
WebhookTab:AddToggle("WebhookToggle", {
    Title = "Enable Webhook Logger",
    Default = false,
    Callback = function(state)
        WebhookEnabled = state
    end
})

WebhookTab:AddButton({
    Title = "Test Webhook",
    Description = "Send test drops to your webhook",
    Callback = function()
        if WEBHOOK_URL == "" then
            Fluent:Notify({Title = "Error", Content = "Please input a webhook first!", Duration = 5})
            return
        end
        table.insert(collectedItems, {item = "Test Drop", count = 1})
        sendWebhookBatch(true) -- force send now
    end
})

WebhookTab:AddParagraph({ Title = "Webhook Credits", Content = "96ms & gs._" })

-- ===== webhook internals =====
local collectedItems = {}
local req = (syn and syn.request) or (http and http.request) or (http_request) or (fluxus and fluxus.request) or request

-- rare items that should trigger @everyone
local pingItems = {
    ["Yhwach's Blood"] = true,
    ["Vow of Luck"] = true,
    ["Hogyoku Ball"] = true,
    ["Creed Emblem"] = true,
    ["Vow of Sacrifice"] = true,
    ["Vow of Potential"] = true,
}

local function sendWebhookBatch(force)
    if not WebhookEnabled or WEBHOOK_URL == "" then return end
    if not req then return warn("[Webhook] No request function available") end
    if not force and #collectedItems == 0 then return end

    local desc, pingEveryone = "", false
    for _, v in ipairs(collectedItems) do
        desc = desc .. string.format("• **%s** × %s\n", v.item, v.count)
        if pingItems[v.item] then pingEveryone = true end
    end

    local data = {
        username = "Type Soul Logger",
        content = pingEveryone and "@everyone" or "",
        embeds = {{
            title = "🎯 Items Obtained!",
            description = desc ~= "" and desc or "No items this batch.",
            color = 0x00FF00,
            footer = { text = "Type Soul Culling Games Tracker" },
            timestamp = DateTime.now():ToIsoDate()
        }}
    }

    pcall(function()
        req({
            Url = WEBHOOK_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(data)
        })
    end)

    table.clear(collectedItems)
end

-- batching loop (every 5s)
task.spawn(function()
    while true do
        task.wait(5)
        sendWebhookBatch(false)
    end
end)

-- ===== safe, non-blocking hook for ClientItems =====
local hooked = false
local function tryHookClientItems()
    if hooked then return end
    if game.PlaceId ~= 18637069183 then return end -- only hook inside Culling Games

    -- First try the expected path quickly with FindFirstChild (no yield)
    local module
    local modules = RS:FindFirstChild("Modules")
    if modules then
        local cm = modules:FindFirstChild("ClientModules")
        if cm then module = cm:FindFirstChild("ClientItems") end
    end

    -- Fallback: scan descendants for a ModuleScript named "ClientItems"
    if not module then
        for _, d in ipairs(RS:GetDescendants()) do
            if d:IsA("ModuleScript") and d.Name == "ClientItems" then
                module = d
                break
            end
        end
    end

    if not module then return end

    local ok, clientItems = pcall(require, module)
    if not ok or type(clientItems) ~= "table" or type(clientItems.ItemObtained) ~= "function" then
        return
    end
    if not hookfunction then
        warn("[Webhook] hookfunction not available in this executor")
        return
    end

    local old
    old = hookfunction(clientItems.ItemObtained, function(player, itemName, count, ...)
        -- Only collect when enabled; never crash if types are weird
        if WebhookEnabled and typeof(itemName) == "string" and (typeof(count) == "number" or typeof(count) == "string") then
            table.insert(collectedItems, { item = itemName, count = count })
        end
        return old(player, itemName, count, ...)
    end)

    hooked = true
    Fluent:Notify({ Title = "Webhook", Content = "Hooked ClientItems.ItemObtained", Duration = 5 })
end

-- keep trying to hook without blocking anything
task.spawn(function()
    while not hooked do
        pcall(tryHookClientItems)
        task.wait(3)
    end
end)

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
