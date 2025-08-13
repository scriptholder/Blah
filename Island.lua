--// Fluent Plus UI (clean port) — All automation features wired to toggles/sliders. No settings, no saves, no watermark.

-- UI
local Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/discoart/FluentPlus/refs/heads/main/alpha.lua"))()
local Window = Fluent:CreateWindow({
    Title = "Seisen Hub - Build a Island  •  " .. Fluent.Version,
    SubTitle = "by Seisen",
    TabWidth = 140,
    Size = UDim2.fromOffset(560, 480),
    Acrylic = false,
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.LeftControl
})

-- Tabs
local Main       = Window:AddTab({ Title = "Main",       Icon = "home" })
local Essentials = Window:AddTab({ Title = "Essentials", Icon = "wrench" })
local Tools      = Window:AddTab({ Title = "Tools",      Icon = "hammer" })
local AutoEvents = Window:AddTab({ Title = "Auto Events",Icon = "calendar" })
local Upgrades   = Window:AddTab({ Title = "Upgrades",   Icon = "trending-up" })

-- Services / Globals
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

getgenv().SeisenHubRunning = true

-- Player refs
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
end)

-- Remotes (soft-resolve via WaitForChild where used)
local Communication = ReplicatedStorage:WaitForChild("Communication", 9e9)
local HitResource = Communication:FindFirstChild("HitResource") or ReplicatedStorage.Communication:WaitForChild("HitResource", 9e9)
local RewardChestClaimRequest = Communication:FindFirstChild("RewardChestClaimRequest") or ReplicatedStorage.Communication:WaitForChild("RewardChestClaimRequest", 9e9)
local Craft = Communication:FindFirstChild("Craft") or ReplicatedStorage.Communication:WaitForChild("Craft", 9e9)
local DoubleCraft = Communication:FindFirstChild("DoubleCraft") or ReplicatedStorage.Communication:WaitForChild("DoubleCraft", 9e9)
local ClaimTimedReward = Communication:FindFirstChild("ClaimTimedReward") or ReplicatedStorage.Communication:WaitForChild("ClaimTimedReward", 9e9)

-- State flags
local killAuraEnabled = false
local killAuraRange = 15
local autoRainbowEnabled = false
local autoSawmillEnabled = false
local autoWorkshopEnabled = false
local autoStonecutterEnabled = false
local autoClaimRewardEnabled = false
local worldTreeEventEnabled = false
local autoClaimDailyEnabled = false
local autoBambooPlankEnabled = false
local autoBuyEggEnabled = false
local autoBuyCrateEnabled = false
local autoHaybaleEnabled = false
local autoFurnaceEnabled = false
local autoCactusLoomEnabled = false
local autoCementEnabled = false
local autoToolsmithEnabled = false
local autoCraftingTimeEnabled = false
local autoRegrowthTimeEnabled = false
local autoSpeedBoostEnabled = false
local autoCropGrowthEnabled = false
local autoGoldenChanceEnabled = false
local autoOfflineEarningsEnabled = false
local autoBeeHiveSpeedEnabled = false
local autoCollectorTimeEnabled = false
local autoFishCrateCapacityEnabled = false
local autoHarvestEnabled = false

-- Helpers
local function safeWaitChild(parent, name)
    if not parent then return nil end
    local ok, obj = pcall(function() return parent:WaitForChild(name, 9e9) end)
    return ok and obj or nil
end

-- Functions
local function startAutoBuyCrate()
    task.spawn(function()
        while getgenv().SeisenHubRunning and autoBuyCrateEnabled do
            task.wait(5)
            pcall(function()
                local args = { [1] = "Magical Crate"; [2] = "1"; }
                safeWaitChild(Communication, "PurchaseCrateRequest"):FireServer(unpack(args))
            end)
        end
    end)
end

local function startAutoBuyEgg()
    task.spawn(function()
        while getgenv().SeisenHubRunning and autoBuyEggEnabled do
            task.wait(5)
            pcall(function()
                -- Attempt a common purchase signature; pcall keeps it safe if remote differs.
                local args = { [1] = "Egg1"; [2] = "1"; }
                local eggRemote = safeWaitChild(Communication, "PurchaseEggRequest") or safeWaitChild(Communication, "PurchaseEgg")
                if eggRemote then eggRemote:FireServer(unpack(args)) end
            end)
        end
    end)
end

local function startKillAura()
    task.spawn(function()
        while killAuraEnabled and getgenv().SeisenHubRunning do
            if not character or not humanoidRootPart then task.wait(0.1) continue end
            local playerPosition = humanoidRootPart.Position
            local hitTargets = {}

            local plots = workspace:FindFirstChild("Plots")
            local playerPlot = plots and plots:FindFirstChild(player.Name)

            if playerPlot and playerPlot:FindFirstChild("Resources") then
                for _, resource in pairs(playerPlot.Resources:GetChildren()) do
                    if resource:IsA("Model") and resource:GetAttribute("HP") and resource:GetAttribute("HP") > 0 then
                        local distance = (resource:GetPivot().Position - playerPosition).Magnitude
                        if distance <= killAuraRange then table.insert(hitTargets, resource) end
                    end
                end
            end

            for _, resource in pairs(CollectionService:GetTagged("SharedResource")) do
                if resource:GetAttribute("HP") and resource:GetAttribute("HP") > 0 then
                    local distance = (resource:GetPivot().Position - playerPosition).Magnitude
                    if distance <= killAuraRange then table.insert(hitTargets, resource) end
                end
            end

            local globalResources = workspace:FindFirstChild("GlobalResources")
            if globalResources then
                for _, resource in pairs(globalResources:GetChildren()) do
                    if resource:IsA("Model") then
                        local distance = (resource:GetPivot().Position - playerPosition).Magnitude
                        if distance <= killAuraRange then table.insert(hitTargets, resource) end
                    end
                end
            end

            if plots then
                for _, plot in pairs(plots:GetChildren()) do
                    if plot:IsA("Model") and plot ~= playerPlot and plot:FindFirstChild("Resources") then
                        for _, resource in pairs(plot.Resources:GetChildren()) do
                            if resource:IsA("Model") and resource:GetAttribute("HP") and resource:GetAttribute("HP") > 0 then
                                local distance = (resource:GetPivot().Position - playerPosition).Magnitude
                                if distance <= killAuraRange then table.insert(hitTargets, resource) end
                            end
                        end
                    end
                end
            end

            if #hitTargets > 0 and HitResource then
                for _, target in ipairs(hitTargets) do
                    pcall(function() HitResource:FireServer(target) end)
                end
            end

            task.wait(0.1)
        end
    end)
end

local function startAutoRainbow()
    task.spawn(function()
        pcall(function()
            local island = safeWaitChild(workspace, "RainbowIsland")
            local base = island and safeWaitChild(island, "FloatingIsland")
            base = base and safeWaitChild(base, "Base")
            local land = base and safeWaitChild(base, "Land")
            local pad = land and land:GetChildren()[12]
            if pad and humanoidRootPart then
                humanoidRootPart.CFrame = pad.CFrame + Vector3.new(0, 10, 0)
            end
        end)
        while autoRainbowEnabled and getgenv().SeisenHubRunning do
            pcall(function()
                if RewardChestClaimRequest then
                    RewardChestClaimRequest:FireServer("RainbowIslandShamrockChest")
                end
            end)
            task.wait(5)
        end
    end)
end

local function startAutoSawmill()
    task.spawn(function()
        while autoSawmillEnabled and getgenv().SeisenHubRunning do
            pcall(function()
                local plots = safeWaitChild(workspace, "Plots")
                local playerPlot = plots and plots:FindFirstChild(player.Name)
                local land = playerPlot and playerPlot:FindFirstChild("Land")
                if land then
                    for _, item in pairs(land:GetDescendants()) do
                        if item.Name == "Crafter" and item:FindFirstChild("Attachment")
                           and not item.Parent.Name:find("S9") and not item.Parent.Name:find("S24") then
                            if Craft then Craft:FireServer(item.Attachment) end
                            break
                        end
                    end
                end
            end)
            task.wait(3)
        end
    end)
end

local function startAutoWorkshop()
    task.spawn(function()
        while autoWorkshopEnabled and getgenv().SeisenHubRunning do
            pcall(function()
                local plots = safeWaitChild(workspace, "Plots")
                local playerPlot = plots and plots:FindFirstChild(player.Name)
                local land = playerPlot and playerPlot:FindFirstChild("Land")
                if land then
                    for _, item in pairs(land:GetDescendants()) do
                        if item.Name == "Crafter" and item:FindFirstChild("Attachment") and item.Parent.Name:find("S9") then
                            if DoubleCraft then DoubleCraft:FireServer(item.Attachment) end
                            break
                        end
                    end
                end
            end)
            task.wait(3)
        end
    end)
end

local function startAutoStonecutter()
    task.spawn(function()
        while autoStonecutterEnabled and getgenv().SeisenHubRunning do
            pcall(function()
                local plots = safeWaitChild(workspace, "Plots")
                local playerPlot = plots and plots:FindFirstChild(player.Name)
                local land = playerPlot and playerPlot:FindFirstChild("Land")
                if land then
                    for _, item in pairs(land:GetDescendants()) do
                        if item.Name == "Crafter" and item:FindFirstChild("Attachment") and item.Parent.Name:find("S24") then
                            if Craft then Craft:FireServer(item.Attachment) end
                            break
                        end
                    end
                end
            end)
            task.wait(3)
        end
    end)
end

local function startAutoClaimReward()
    task.spawn(function()
        while autoClaimRewardEnabled and getgenv().SeisenHubRunning do
            pcall(function()
                local rewards = {
                    "rewardOne","rewardTwo","rewardThree","rewardFour","rewardFive","rewardSix",
                    "rewardSeven","rewardEight","rewardNine","rewardTen","rewardEleven","rewardTwelve"
                }
                for _, r in ipairs(rewards) do
                    if ClaimTimedReward then ClaimTimedReward:InvokeServer(r) end
                    task.wait(1)
                end
            end)
            task.wait(60)
        end
    end)
end

local function startWorldTreeEvent()
    task.spawn(function()
        pcall(function()
            local tree = safeWaitChild(safeWaitChild(safeWaitChild(workspace, "GlobalResources"), "World Tree"), "0")
            local part = tree and tree:FindFirstChild("Part67")
            if part and humanoidRootPart then
                humanoidRootPart.CFrame = part.CFrame + Vector3.new(0,5,0)
            end
        end)
        while worldTreeEventEnabled and getgenv().SeisenHubRunning do
            pcall(function()
                local ts = tick() + math.random() * 0.1
                local args = { [1] = ts }
                safeWaitChild(Communication, "RewardChestClaimRequest"):FireServer(unpack(args))
                task.wait(0.1)
                safeWaitChild(Communication, "CollectWorldTree"):FireServer(unpack(args))
            end)
            task.wait(2)
        end
    end)
end

local function startAutoClaimDaily()
    task.spawn(function()
        while autoClaimDailyEnabled and getgenv().SeisenHubRunning do
            pcall(function()
                for i = 1, 100 do
                    local args = { [1] = i }
                    safeWaitChild(Communication, "ClaimDailyReward"):FireServer(unpack(args))
                    task.wait(1)
                end
            end)
            task.wait(30)
        end
    end)
end

local function startAutoBambooPlank()
    task.spawn(function()
        while autoBambooPlankEnabled and getgenv().SeisenHubRunning do
            pcall(function()
                local plots = safeWaitChild(workspace, "Plots")
                local pl = plots and plots:FindFirstChild(player.Name)
                local att = pl and safeWaitChild(safeWaitChild(pl, "Land"), "S72")
                att = att and safeWaitChild(att, "Crafter")
                att = att and safeWaitChild(att, "Attachment")
                if att and Craft then Craft:FireServer(att) end
            end)
            task.wait(3)
        end
    end)
end

local function startAutoHaybale()
    task.spawn(function()
        while autoHaybaleEnabled and getgenv().SeisenHubRunning do
            pcall(function()
                local plots = safeWaitChild(workspace, "Plots")
                local pl = plots and plots:FindFirstChild(player.Name)
                local att = pl and safeWaitChild(safeWaitChild(pl, "Land"), "S178")
                att = att and safeWaitChild(att, "Crafter")
                att = att and safeWaitChild(att, "Attachment")
                if att and Craft then Craft:FireServer(att) end
            end)
            task.wait(3)
        end
    end)
end

local function startAutoFurnace()
    task.spawn(function()
        while autoFurnaceEnabled and getgenv().SeisenHubRunning do
            pcall(function()
                local plots = safeWaitChild(workspace, "Plots")
                local pl = plots and plots:FindFirstChild(player.Name)
                local att = pl and safeWaitChild(safeWaitChild(pl, "Land"), "S23")
                att = att and safeWaitChild(att, "Crafter")
                att = att and safeWaitChild(att, "Attachment")
                if att and DoubleCraft then DoubleCraft:FireServer(att) end
            end)
            task.wait(3)
        end
    end)
end

local function startAutoCactusLoom()
    task.spawn(function()
        while autoCactusLoomEnabled and getgenv().SeisenHubRunning do
            pcall(function()
                local plots = safeWaitChild(workspace, "Plots")
                local pl = plots and plots:FindFirstChild(player.Name)
                local att = pl and safeWaitChild(safeWaitChild(pl, "Land"), "S54")
                att = att and safeWaitChild(att, "Crafter")
                att = att and safeWaitChild(att, "Attachment")
                if att and Craft then Craft:FireServer(att) end
            end)
            task.wait(3)
        end
    end)
end

local function startAutoCement()
    task.spawn(function()
        while autoCementEnabled and getgenv().SeisenHubRunning do
            pcall(function()
                local plots = safeWaitChild(workspace, "Plots")
                local pl = plots and plots:FindFirstChild(player.Name)
                local att = pl and safeWaitChild(safeWaitChild(pl, "Land"), "S281")
                att = att and safeWaitChild(att, "Crafter")
                att = att and safeWaitChild(att, "Attachment")
                if att and DoubleCraft then DoubleCraft:FireServer(att) end
            end)
            task.wait(3)
        end
    end)
end

local function startAutoToolsmith()
    task.spawn(function()
        while autoToolsmithEnabled and getgenv().SeisenHubRunning do
            pcall(function()
                local plots = safeWaitChild(workspace, "Plots")
                local pl = plots and plots:FindFirstChild(player.Name)
                local att = pl and safeWaitChild(safeWaitChild(pl, "Land"), "S38")
                att = att and safeWaitChild(att, "Crafter")
                att = att and safeWaitChild(att, "Attachment")
                if att and DoubleCraft then DoubleCraft:FireServer(att) end
            end)
            task.wait(3)
        end
    end)
end

local function startAutoCraftingTime()
    task.spawn(function()
        while autoCraftingTimeEnabled and getgenv().SeisenHubRunning do
            pcall(function()
                safeWaitChild(Communication, "DoGoldUpgrade"):FireServer("CraftingTime")
            end)
            task.wait(5)
        end
    end)
end

local function startAutoRegrowthTime()
    task.spawn(function()
        while autoRegrowthTimeEnabled and getgenv().SeisenHubRunning do
            pcall(function()
                safeWaitChild(Communication, "DoGoldUpgrade"):FireServer("RegrowthTime")
            end)
            task.wait(5)
        end
    end)
end

local function startAutoSpeedBoost()
    task.spawn(function()
        while autoSpeedBoostEnabled and getgenv().SeisenHubRunning do
            pcall(function()
                safeWaitChild(Communication, "DoGoldUpgrade"):FireServer("SpeedBoost")
            end)
            task.wait(5)
        end
    end)
end

local function startAutoCropGrowth()
    task.spawn(function()
        while autoCropGrowthEnabled and getgenv().SeisenHubRunning do
            pcall(function()
                safeWaitChild(Communication, "DoGoldUpgrade"):FireServer("CropGrowth")
            end)
            task.wait(5)
        end
    end)
end

local function startAutoGoldenChance()
    task.spawn(function()
        while autoGoldenChanceEnabled and getgenv().SeisenHubRunning do
            pcall(function()
                safeWaitChild(Communication, "DoGoldUpgrade"):FireServer("GoldenChance")
            end)
            task.wait(5)
        end
    end)
end

local function startAutoOfflineEarnings()
    task.spawn(function()
        while autoOfflineEarningsEnabled and getgenv().SeisenHubRunning do
            pcall(function()
                safeWaitChild(Communication, "DoGoldUpgrade"):FireServer("OfflineEarnings")
            end)
            task.wait(5)
        end
    end)
end

local function startAutoBeeHiveSpeed()
    task.spawn(function()
        while autoBeeHiveSpeedEnabled and getgenv().SeisenHubRunning do
            pcall(function()
                safeWaitChild(Communication, "DoGoldUpgrade"):FireServer("BeeHiveSpeed")
            end)
            task.wait(5)
        end
    end)
end

local function startAutoCollectorTime()
    task.spawn(function()
        while autoCollectorTimeEnabled and getgenv().SeisenHubRunning do
            pcall(function()
                safeWaitChild(Communication, "DoGoldUpgrade"):FireServer("CollectorTime")
            end)
            task.wait(5)
        end
    end)
end

local function startAutoFishCrateCapacity()
    task.spawn(function()
        while autoFishCrateCapacityEnabled and getgenv().SeisenHubRunning do
            pcall(function()
                safeWaitChild(Communication, "DoGoldUpgrade"):FireServer("FishCrateCapacity")
            end)
            task.wait(5)
        end
    end)
end

local function startAutoHarvest()
    task.spawn(function()
        while autoHarvestEnabled and getgenv().SeisenHubRunning do
            pcall(function()
                for i = 1, 25 do
                    local args = { [1] = tostring(i) }
                    safeWaitChild(Communication, "Harvest"):FireServer(unpack(args))
                    task.wait(0.5)
                end
            end)
            task.wait(10)
        end
    end)
end

-- UI Controls

-- Main
Main:AddToggle("autoBuyEggEnabled",{
    Title = "Auto Buy Egg",
    Default = false,
    Callback = function(v)
        autoBuyEggEnabled = v
        if v then startAutoBuyEgg() end
    end
})

Main:AddToggle("autoBuyCrateEnabled",{
    Title = "Auto Buy Crate",
    Default = false,
    Callback = function(v)
        autoBuyCrateEnabled = v
        if v then startAutoBuyCrate() end
    end
})

Main:AddToggle("killAuraEnabled",{
    Title = "Auto Chop/Mine",
    Default = false,
    Callback = function(v)
        killAuraEnabled = v
        if v then startKillAura() end
    end
})

Main:AddSlider("killAuraRange",{
    Title = "Chop/Mine Range",
    Description = "Studs",
    Default = 15, Min = 15, Max = 30, Rounding = 0,
    Callback = function(v) killAuraRange = v end
})

Main:AddToggle("autoClaimRewardEnabled",{
    Title = "Auto Claim Reward (1-12)",
    Default = false,
    Callback = function(v)
        autoClaimRewardEnabled = v
        if v then startAutoClaimReward() end
    end
})

Main:AddToggle("autoClaimRewardEnabled",{
    Title = "Auto Claim Daily (1-100)",
    Default = false,
    Callback = function(v)
        autoClaimDailyEnabled = v
        if v then startAutoClaimDaily() end
    end
})

Main:AddToggle("autoHarvestEnabled",{
    Title = "Auto Harvest (1-25)",
    Default = false,
    Callback = function(v)
        autoHarvestEnabled = v
        if v then startAutoHarvest() end
    end
})

-- Essentials
Essentials:AddToggle("autoSawmillEnabled",{
    Title = "Auto Sawmill",
    Default = false,
    Callback = function(v)
        autoSawmillEnabled = v
        if v then startAutoSawmill() end
    end
})

Essentials:AddToggle("autoStonecutterEnabled",{
    Title = "Auto Stonecutter",
    Default = false,
    Callback = function(v)
        autoStonecutterEnabled = v
        if v then startAutoStonecutter() end
    end
})

Essentials:AddToggle("autoBambooPlankEnabled",{
    Title = "Auto Bamboo Plank (S72)",
    Default = false,
    Callback = function(v)
        autoBambooPlankEnabled = v
        if v then startAutoBambooPlank() end
    end
})

Essentials:AddToggle("autoHaybaleEnabled",{
    Title = "Auto Haybale (S178)",
    Default = false,
    Callback = function(v)
        autoHaybaleEnabled = v
        if v then startAutoHaybale() end
    end
})

Essentials:AddToggle("autoFurnaceEnabled",{
    Title = "Auto Furnace (S23)",
    Default = false,
    Callback = function(v)
        autoFurnaceEnabled = v
        if v then startAutoFurnace() end
    end
})

Essentials:AddToggle("autoCactusLoomEnabled",{
    Title = "Auto Cactus Loom (S54)",
    Default = false,
    Callback = function(v)
        autoCactusLoomEnabled = v
        if v then startAutoCactusLoom() end
    end
})

Essentials:AddToggle("autoCementEnabled",{
    Title = "Auto Cement (S281)",
    Default = false,
    Callback = function(v)
        autoCementEnabled = v
        if v then startAutoCement() end
    end
})

-- Tools
Tools:AddToggle("autoWorkshopEnabled",{
    Title = "Auto Workshop (S9)",
    Default = false,
    Callback = function(v)
        autoWorkshopEnabled = v
        if v then startAutoWorkshop() end
    end
})

Tools:AddToggle("autoToolsmithEnabled",{
    Title = "Auto Toolsmith (S38)",
    Default = false,
    Callback = function(v)
        autoToolsmithEnabled = v
        if v then startAutoToolsmith() end
    end
})

-- Auto Events
AutoEvents:AddToggle("autoRainbowEnabled",{
    Title = "Rainbow Event (Teleport + Chest)",
    Default = false,
    Callback = function(v)
        autoRainbowEnabled = v
        if v then startAutoRainbow() end
    end
})

AutoEvents:AddToggle("worldTreeEventEnabled",{
    Title = "World Tree Event",
    Default = false,
    Callback = function(v)
        worldTreeEventEnabled = v
        if v then startWorldTreeEvent() end
    end
})

-- Upgrades
Upgrades:AddToggle("autoCraftingTimeEnabled",{
    Title = "Auto Crafting Time",
    Default = false,
    Callback = function(v)
        autoCraftingTimeEnabled = v
        if v then startAutoCraftingTime() end
    end
})

Upgrades:AddToggle("autoRegrowthTimeEnabled",{
    Title = "Auto Regrowth Time",
    Default = false,
    Callback = function(v)
        autoRegrowthTimeEnabled = v
        if v then startAutoRegrowthTime() end
    end
})

Upgrades:AddToggle("autoSpeedBoostEnabled",{
    Title = "Auto Speed Boost",
    Default = false,
    Callback = function(v)
        autoSpeedBoostEnabled = v
        if v then startAutoSpeedBoost() end
    end
})

Upgrades:AddToggle("autoCropGrowthEnabled",{
    Title = "Auto Crop Growth",
    Default = false,
    Callback = function(v)
        autoCropGrowthEnabled = v
        if v then startAutoCropGrowth() end
    end
})

Upgrades:AddToggle("autoGoldenChanceEnabled",{
    Title = "Auto Golden Chance",
    Default = false,
    Callback = function(v)
        autoGoldenChanceEnabled = v
        if v then startAutoGoldenChance() end
    end
})

Upgrades:AddToggle("autoOfflineEarningsEnabled",{
    Title = "Auto Offline Earnings",
    Default = false,
    Callback = function(v)
        autoOfflineEarningsEnabled = v
        if v then startAutoOfflineEarnings() end
    end
})

Upgrades:AddToggle("autoBeeHiveSpeedEnabled",{
    Title = "Auto Honeybee (Bee Hive Speed)",
    Default = false,
    Callback = function(v)
        autoBeeHiveSpeedEnabled = v
        if v then startAutoBeeHiveSpeed() end
    end
})

Upgrades:AddToggle("autoCollectorTimeEnabled",{
    Title = "Auto Collector Time",
    Default = false,
    Callback = function(v)
        autoCollectorTimeEnabled = v
        if v then startAutoCollectorTime() end
    end
})

Upgrades:AddToggle("autoFishCrateCapacityEnabled",{
    Title = "Auto Fish Crate Capacity",
    Default = false,
    Callback = function(v)
        autoFishCrateCapacityEnabled = v
        if v then startAutoFishCrateCapacity() end
    end
})
