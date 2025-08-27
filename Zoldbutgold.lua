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

-- =========================================================
-- Auto Culling Game Tab
-- =========================================================
local CullingTab = Window:AddTab({ Title = "Auto Culling Game", Icon = "swords" })
CullingTab:AddParagraph({ Title = "âš ï¸ Reminder", Content = "Make sure to add this to auto load if you want to AFK farm it.\nTo add it just go to the settings tab and you will see everything." })

local chosenSlot = ""
local main1 = 14067600077 -- Replace this with the main game place ID

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

local AutoTP = false
CullingTab:AddToggle("AutoTP", {
    Title = "Auto TP To Matchmaking",
    Default = false,
    Callback = function(state)
        AutoTP = state
        task.spawn(function()
            while AutoTP do
                -- Check if we're not already in the culling/matchmaking place
                if game.PlaceId ~= main1 then
                    local rem = RS:FindFirstChild("Remotes")
                    local chooseSlot = rem and rem:FindFirstChild("ChooseSlot")

                    if chooseSlot then
                        local ok, err = pcall(function()
                            -- Call the remote with slot + matchmaking
                            print("[AutoTP] Trying to TP with slot:", chosenSlot)
                            chooseSlot:InvokeServer(chosenSlot, "Matchmaking")
                        end)

                        if not ok then
                            warn("[AutoTP] Failed to TP:", err)
                        else
                            print("[AutoTP] Teleport request sent successfully!")
                        end
                    else
                        warn("[AutoTP] Couldn't find ChooseSlot remote!")
                    end
                else
                    print("[AutoTP] Already inside Culling place, skipping...")
                end

                task.wait(5) -- Wait before trying again
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
local AutoCrashOnSpecialItem = false -- ðŸ†• Auto crash toggle

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
        warn("âš ï¸ Special item found: " .. itemName .. " â€” Leaving the game!")
        TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
    end
end

-- Send webhook data (queue items)
local function sendWebhook(itemName, count)
    if not WebhookEnabled then return end
    if WEBHOOK_URL == "" then
        warn("âš ï¸ Webhook URL is empty, skipping send")
        return
    end
    if not req then
        warn("âŒ No request function available, webhook can't be sent")
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
                title = "ðŸŽ¯ Items Obtained!",
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
        handleSpecialItem(itemName) -- ðŸ†• Leave game if special item found
        sendWebhook(itemName, count)
        return oldItemObtained(player, itemName, count, ...)
    end)

    print("âœ… Webhook logger hooked into ItemObtained. Rewards will show in Discord + console when enabled.")
else
    warn("âš ï¸ clientItems module not found â€” webhook logger disabled")
end

-- ðŸŸ¢ WEBHOOK UI TAB ðŸŸ¢
local WebhookTab = Window:AddTab({ Title = "Webhook", Icon = "globe" })

WebhookTab:AddParagraph({
    Title = "âš ï¸ Reminder",
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
                Content = "âŒ Can't enable webhook logging, clientItems missing!",
                Duration = 5
            })
            return
        end
        WebhookEnabled = state
        Fluent:Notify({
            Title = "Webhook Logger",
            Content = state and "âœ… Enabled webhook logging!" or "âŒ Disabled webhook logging!",
            Duration = 5
        })
    end
})

-- ðŸ†• New toggle for auto-crash/leave
WebhookTab:AddToggle("AutoCrashToggle", {
    Title = "Auto Crash if Special Item Found",
    Default = false,
    Callback = function(state)
        AutoCrashOnSpecialItem = state
        Fluent:Notify({
            Title = "Special Item Auto Crash",
            Content = state and "âœ… Enabled auto crash on special item!" or "âŒ Disabled auto crash on special item!",
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
        Fluent:Notify({ Title = "Webhook", Content = "âœ… Test drop sent!", Duration = 5 })
    end
})

WebhookTab:AddParagraph({ Title = "Webhook Credits", Content = "96ms & gs._" })

-- ðŸ”¥ TEST trigger (only runs if clientItems exists)
if clientItemsExists and clientItems and clientItems.ItemObtained then
    task.delay(3, function()
        local lp = Players.LocalPlayer
        print("ðŸ§ª Sending test item to webhook...")
        sendWebhook("Test Sword of Doom", 2)
        clientItems.ItemObtained(lp, "Test Sword of Doom", 2)
    end)
end
    
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
        warn("â³ 950 seconds passed! Rejoining Type Soul...")
        TeleportService:Teleport(14067600077, player)
    else
        warn("âš ï¸ Couldn't rejoin â€” TeleportService or LocalPlayer missing.")
    end
end)
