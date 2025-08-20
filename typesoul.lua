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

-- =========================================================
-- Global IDs / gating
-- =========================================================
local ALLOWED_GAME_ID = 115509275831248 -- only run webhook in this universe
local PLACE_MAIN = 14067600077          -- matchmaking/main
local PLACE_CULL = 18637069183          -- culling games

-- =========================================================
-- Persistence helpers (webhook settings)
-- =========================================================
local CONFIG_DIR_1 = "DeadScriptHub"
local CONFIG_DIR_2 = "DeadScriptHub/TypeSoul"
local CONFIG_FILE = CONFIG_DIR_2 .. "/webhook.json"

local function safe(fn, ...)
    local ok, r = pcall(fn, ...)
    return ok, r
end

local function hasfs()
    return (typeof(writefile)=="function" and typeof(readfile)=="function" and typeof(isfile)=="function" and typeof(makefolder)=="function")
end

local function ensureDirs()
    if not hasfs() then return end
    safe(function() if not isfolder(CONFIG_DIR_1) then makefolder(CONFIG_DIR_1) end end)
    safe(function() if not isfolder(CONFIG_DIR_2) then makefolder(CONFIG_DIR_2) end end)
end

local function saveConfig(tbl)
    if not hasfs() then return end
    ensureDirs()
    local ok, body = pcall(function() return HttpService:JSONEncode(tbl) end)
    if ok then pcall(function() writefile(CONFIG_FILE, body) end) end
end

local function loadConfig()
    if not hasfs() then return {} end
    ensureDirs()
    if not isfile(CONFIG_FILE) then return {} end
    local ok, body = pcall(function() return readfile(CONFIG_FILE) end)
    if not ok or not body or body == "" then return {} end
    local ok2, data = pcall(function() return HttpService:JSONDecode(body) end)
    return ok2 and data or {}
end

-- =========================================================
-- Webhook internals (instant send; UI-controlled; rare ping)
-- =========================================================
local cfg = loadConfig()
local WEBHOOK_URL = cfg.webhook_url or ""         -- set via UI
local WebhookEnabled = cfg.webhook_enabled or false

local req = (syn and syn.request)
         or (http and http.request)
         or http_request
         or (fluxus and fluxus.request)
         or request

-- rare items that should ping everyone
local pingItems = {
    ["Yhwach's Blood"] = true,
    ["Vow of Luck"] = true,
    ["Hogyoku Ball"] = true,
    ["Creed Emblem"] = true,
    ["Vow of Sacrifice"] = true,
    ["Vow of Potential"] = true,
}

local function sendWebhook(itemName, count)
    if game.GameId ~= ALLOWED_GAME_ID then return end
    if not WebhookEnabled or WEBHOOK_URL == "" then return end
    if not req then return warn("❌ No request function available, webhook can't be sent") end

    local contentPing = (pingItems[tostring(itemName)] and "@everyone") or ""

    local data = {
        username = "Type Soul Logger",
        content = contentPing,
        embeds = {{
            title = "🎯 Item Obtained!",
            description = string.format("**Item:** %s\n**Count:** %s", tostring(itemName), tostring(count or 1)),
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
end

-- =========================================================
-- Hook ClientItems.ItemObtained (instant send)
-- =========================================================
local function hookClientItems()
    local okReq, clientItems = pcall(function()
        local modules = RS:FindFirstChild("Modules")
        local cm = modules and modules:FindFirstChild("ClientModules")
        local mod = cm and cm:FindFirstChild("ClientItems")
        if not mod then
            -- fallback deep search
            for _, d in ipairs(RS:GetDescendants()) do
                if d:IsA("ModuleScript") and d.Name == "ClientItems" then
                    mod = d
                    break
                end
            end
        end
        return mod and require(mod) or nil
    end)
    if not okReq or not clientItems or type(clientItems.ItemObtained) ~= "function" then
        return false
    end
    if not hookfunction then
        warn("[Webhook] hookfunction not available in this executor")
        return false
    end

    local old
    old = hookfunction(clientItems.ItemObtained, function(player, itemName, count, ...)
        if typeof(itemName) == "string" then
            print("[Item Obtained] Player:", player and player.Name or "nil", "| Item:", itemName, "| Count:", count)
            sendWebhook(itemName, count)
        end
        return old(player, itemName, count, ...)
    end)

    print("✅ Webhook logger hooked into ItemObtained. Rewards will show in Discord + console.")
    return true
end

-- keep retrying until hooked
task.spawn(function()
    while true do
        if hookClientItems() then break end
        task.wait(3)
    end
end)

-- =========================================================
-- Fluent UI Setup
-- =========================================================
local Window = Fluent:CreateWindow({
    Title = "type soul | Dead Hub",
    SubTitle = "Made by Dead | Version: "..Fluent.Version,
    TabWidth = 160,
    Size = UDim2.fromOffset(540, 360),
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
CullingTab:AddParagraph({
    Title = "⚠️ Reminder",
    Content = "Make sure to add this to auto load if you want to AFK farm it.\nTo add it just go to the settings tab and you will see everything."
})

local chosenSlot = "A"
CullingTab:AddDropdown("SlotSelect", {
    Title = "Choose Slot",
    Values = {"A", "B", "C", "D"},
    Multi = false,
    Default = 1,
    Callback = function(value)
        chosenSlot = tostring(value or "A"):upper()
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
                if game.PlaceId ~= PLACE_CULL then
                    local rem = RS:FindFirstChild("Remotes")
                    local chooseSlot = rem and rem:FindFirstChild("ChooseSlot")
                    if chooseSlot then
                        pcall(function()
                            chooseSlot:InvokeServer(chosenSlot, "Matchmaking")
                        end)
                    end
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
                if game.PlaceId == PLACE_CULL then
                    local rem = RS:FindFirstChild("Remotes")
                    local teamR = rem and rem:FindFirstChild("Team")
                    if teamR then
                        pcall(function()
                            teamR:FireServer("JoinQueue", "CULLING GAMES")
                        end)
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

-- =========================================================
-- Webhook Tab
-- =========================================================
local WebhookTab = Window:AddTab({ Title = "Webhook", Icon = "globe" })
WebhookTab:AddParagraph({
    Title = "⚡ Webhook Logger",
    Content = "Logs your item drops instantly to your Discord webhook. Rare drops will ping @everyone."
})

local function persist()
    saveConfig({
        webhook_url = WEBHOOK_URL,
        webhook_enabled = WebhookEnabled
    })
end

WebhookTab:AddInput("WebhookInput", {
    Title = "Webhook URL",
    Placeholder = "Enter your webhook here",
    Default = WEBHOOK_URL,
    Callback = function(value)
        WEBHOOK_URL = value or ""
        persist()
        Fluent:Notify({ Title = "Webhook Updated", Content = (WEBHOOK_URL ~= "" and "New webhook URL saved.") or "Cleared webhook URL.", Duration = 4 })
    end
})

WebhookTab:AddToggle("WebhookToggle", {
    Title = "Enable Webhook Logger",
    Default = WebhookEnabled,
    Callback = function(state)
        WebhookEnabled = state and true or false
        persist()
        Fluent:Notify({
            Title = WebhookEnabled and "Webhook Enabled" or "Webhook Disabled",
            Content = WebhookEnabled and "Drops will now be logged." or "Drops will not be logged.",
            Duration = 4
        })
    end
})

WebhookTab:AddButton({
    Title = "Test Webhook",
    Description = "Send a test drop to your webhook",
    Callback = function()
        if WEBHOOK_URL == "" then
            Fluent:Notify({ Title = "Error", Content = "Please input a webhook first!", Duration = 5 })
            return
        end
        local prev = WebhookEnabled
        WebhookEnabled = true -- force send for test
        sendWebhook("Test Sword of Doom", 2)
        WebhookEnabled = prev
        Fluent:Notify({ Title = "Webhook Test Sent", Content = "Check your Discord channel.", Duration = 5 })
    end
})

WebhookTab:AddParagraph({ Title = "Webhook Credits", Content = "96ms & gs._" })

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
