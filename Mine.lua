-- // Libraries
local Fluent       = loadstring(game:HttpGet("https://raw.githubusercontent.com/discoart/FluentPlus/refs/heads/main/alpha.lua"))()
local SaveManager  = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceMgr = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- // Window
local Window = Fluent:CreateWindow({
    Title        = "Mines - Dead hub " .. Fluent.Version,
    SubTitle     = "by Dead",
    TabWidth     = 160,
    Size         = UDim2.fromOffset(520, 320),
    Acrylic      = true,
    Theme        = "Darker",
    MinimizeKey  = Enum.KeyCode.LeftControl,
})

-- Tabs (Fluent icons only)
local MiningTab   = Window:AddTab({ Title = "Mining",   Icon = "hammer" })
local TeleportTab = Window:AddTab({ Title = "Teleport", Icon = "map" })
local ShopTab     = Window:AddTab({ Title = "Shop",     Icon = "shopping-cart" })
local MiscTab     = Window:AddTab({ Title = "Misc",     Icon = "wrench" })
local SettingsTab = Window:AddTab({ Title = "Settings", Icon = "settings" })

-- // Helpers
local function Notify(title, content, duration)
    Fluent:Notify({ Title = title or "Info", Content = content or "", Duration = duration or 5 })
end

-- // Services & Remotes (same as original)
local TweenService            = game:GetService("TweenService")
local ReplicatedStorage       = game:GetService("ReplicatedStorage")
local RunService              = game:GetService("RunService")
local ProximityPromptService  = game:GetService("ProximityPromptService")
local PathfindingService      = game:GetService("PathfindingService")
local Players                 = game:GetService("Players")
local Lighting                = game:GetService("Lighting")

local plr   = Players.LocalPlayer
local Mouse = plr:GetMouse()
local root  = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")

local Mine      = ReplicatedStorage["shared/network/MiningNetwork@GlobalMiningEvents"].Mine
local Drill     = ReplicatedStorage["shared/network/MiningNetwork@GlobalMiningFunctions"].Drill
local Dynamite  = ReplicatedStorage["shared/network/DynamiteNetwork@GlobalDynamiteFunctions"].UseDynamite
local BuyItem   = ReplicatedStorage.Ml.BuyItem
local itemsFold = workspace:FindFirstChild("Items")

-- // State
local AutoMine, AutoDrill, AutoDynamite, ColOres = false, false, false, false
local MiningStrength = 1
local CollectSpeed   = 0.5
local CollectMode    = "Legit"
local MiningDir      = "Camera"

local MiningThread, DrillingThread, DynamiteThread, OresThread = nil, nil, nil, nil
local PromptButtonHoldBegan = nil
local tradertomPos, ownPos = nil, nil

getgenv().desiredWalkSpeed = 16

-- // Utils
local function findtradertom()
    if tradertomPos then return end
    if not root and plr.Character then root = plr.Character:FindFirstChild("HumanoidRootPart") end
    if not root then return end

    local last = root.CFrame
    root.CFrame = CFrame.new(Vector3.new(998, 245, -71))
    local attempt = 0
    repeat
        for _, npc in pairs(workspace:GetChildren()) do
            if npc:IsA("Model") and npc:GetAttribute("Name") == "Trader Tom" and npc:FindFirstChild("HumanoidRootPart") then
                tradertomPos = npc.HumanoidRootPart.Position
                break
            end
        end
        task.wait(0.1)
        attempt += 1
    until tradertomPos or attempt > 20
    root.CFrame = last

    if not tradertomPos then
        warn("Could not find Trader Tom after", 20, "attempts")
    end
end
pcall(findtradertom)

-- keep WalkSpeed stable
if not getgenv().wshb then
    getgenv().wshb = true
    RunService.Heartbeat:Connect(function()
        pcall(function()
            if plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") then
                plr.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = getgenv().desiredWalkSpeed
            end
        end)
    end)
end

local function findNearestItem()
    if not itemsFold or not plr.Character or not plr.Character:FindFirstChild("HumanoidRootPart") then
        return nil
    end
    local playerPos = plr.Character.HumanoidRootPart.Position
    local closestItem, shortestDistance = nil, math.huge

    for _, item in ipairs(itemsFold:GetChildren()) do
        local itemPos
        if item:IsA("MeshPart") then
            itemPos = item.Position
        elseif item:IsA("Tool") and item:FindFirstChild("Handle") then
            itemPos = item.Handle.Position
        end
        if itemPos then
            local distance = (playerPos - itemPos).Magnitude
            if distance < shortestDistance then
                shortestDistance = distance
                closestItem = item
            end
        end
    end
    return closestItem
end

local function MineOres()
    while AutoMine do
        local camera = workspace.CurrentCamera.CFrame.LookVector
        local minePos
        if MiningDir == "Camera" then
            minePos = Vector3.new(
                math.round(math.clamp(camera.X * 1000, -1000, 1000)),
                math.round(math.clamp(camera.Y * 1000, -1000, 1000)),
                math.round(math.clamp(camera.Z * 1000, -1000, 1000))
            )
        elseif MiningDir == "Towards Ores" then
            local closestItem = findNearestItem()
            if closestItem and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                local playerPos = plr.Character.HumanoidRootPart.Position
                local itemPos = closestItem:IsA("MeshPart") and closestItem.Position
                    or (closestItem:IsA("Tool") and closestItem:FindFirstChild("Handle") and closestItem.Handle.Position)
                local direction = itemPos and (itemPos - playerPos).Unit or camera
                minePos = Vector3.new(
                    math.round(math.clamp(direction.X * 1000, -1000, 1000)),
                    math.round(math.clamp(direction.Y * 1000, -1000, 1000)),
                    math.round(math.clamp(direction.Z * 1000, -1000, 1000))
                )
            else
                minePos = Vector3.new(
                    math.round(math.clamp(camera.X * 1000, -1000, 1000)),
                    math.round(math.clamp(camera.Y * 1000, -1000, 1000)),
                    math.round(math.clamp(camera.Z * 1000, -1000, 1000))
                )
            end
        else
            minePos = Vector3.new(math.random(-1000, 1000), math.random(-1000, 1000), math.random(-1000, 1000))
        end
        Mine:FireServer(minePos, MiningStrength)
        task.wait(0.1)
    end
end

local function MineOresDrill()
    while AutoDrill do
        local camera = workspace.CurrentCamera.CFrame.LookVector
        local minePos
        if MiningDir == "Camera" then
            minePos = Vector3.new(
                math.round(math.clamp(camera.X * 1000, -1000, 1000)),
                math.round(math.clamp(camera.Y * 1000, -1000, 1000)),
                math.round(math.clamp(camera.Z * 1000, -1000, 1000))
            )
        elseif MiningDir == "Towards Ores" then
            local closestItem = findNearestItem()
            if closestItem and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                local playerPos = plr.Character.HumanoidRootPart.Position
                local itemPos = closestItem:IsA("MeshPart") and closestItem.Position
                    or (closestItem:IsA("Tool") and closestItem:FindFirstChild("Handle") and closestItem.Handle.Position)
                local direction = itemPos and (itemPos - playerPos).Unit or camera
                minePos = Vector3.new(
                    math.round(math.clamp(direction.X * 1000, -1000, 1000)),
                    math.round(math.clamp(direction.Y * 1000, -1000, 1000)),
                    math.round(math.clamp(direction.Z * 1000, -1000, 1000))
                )
            else
                minePos = Vector3.new(
                    math.round(math.clamp(camera.X * 1000, -1000, 1000)),
                    math.round(math.clamp(camera.Y * 1000, -1000, 1000)),
                    math.round(math.clamp(camera.Z * 1000, -1000, 1000))
                )
            end
        else
            minePos = Vector3.new(math.random(-1000, 1000), math.random(-1000, 1000), math.random(-1000, 1000))
        end
        Drill:FireServer(math.random(0, 9e9), { direction = minePos, heat = 0, overheated = false })
        task.wait(0.05)
    end
end

local function UseDynamite()
    while AutoDynamite do
        local hitPosition = Mouse.Hit.Position
        Dynamite:FireServer(math.random(0, 9e9), hitPosition)
        task.wait(0.5)
    end
end

local function navigateToNearestOre()
    if not (plr.Character and root) then return end
    local humanoid = plr.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    local playerPos  = root.Position
    local plrHeadPos = plr.Character:FindFirstChild("Head") and plr.Character.Head.Position
    local closest    = findNearestItem()
    local targetPos  = nil

    if closest then
        if closest:IsA("MeshPart") then
            targetPos = closest.Position
        elseif closest:IsA("Tool") and closest:FindFirstChild("Handle") then
            targetPos = closest.Handle.Position
        end
    else
        local radius = 50
        local randomAngle = math.random() * 2 * math.pi
        local randomDistance = math.random(20, radius)
        targetPos = playerPos + Vector3.new(math.cos(randomAngle) * randomDistance, 0, math.sin(randomAngle) * randomDistance)
    end

    if targetPos then
        if closest and plrHeadPos then
            local rayOrigin    = plrHeadPos
            local rayDirection = targetPos - plrHeadPos
            local rp = RaycastParams.new()
            rp.FilterDescendantsInstances = { plr.Character, itemsFold }
            rp.FilterType = Enum.RaycastFilterType.Blacklist
            local hit = workspace:Raycast(rayOrigin, rayDirection, rp)

            if not hit then
                local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
                local tween = TweenService:Create(root, tweenInfo, { CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0)) })
                tween:Play()
                tween.Completed:Wait()
            end
        else
            local path = PathfindingService:CreatePath({
                AgentRadius = 7,
                AgentHeight = 9.5,
                AgentCanJump = true,
                Costs = {}
            })

            local ok = pcall(function()
                path:ComputeAsync(root.Position, targetPos)
            end)

            if ok and path.Status == Enum.PathStatus.Success then
                for _, wp in ipairs(path:GetWaypoints()) do
                    if not (plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")) then break end
                    humanoid:MoveTo(wp.Position)
                    local _ = humanoid.MoveToFinished:Wait(2)
                    if wp.Action == Enum.PathWaypointAction.Jump then
                        humanoid.Jump = true
                    end
                end
            else
                humanoid:MoveTo(targetPos)
            end
        end
    end
    task.wait(0.1)
end

local function CollectOres()
    local miningNetwork = ReplicatedStorage:FindFirstChild("shared/network/MiningNetwork@GlobalMiningEvents")
    local collectItem   = miningNetwork and miningNetwork:FindFirstChild("CollectItem")

    while ColOres do
        if CollectMode == "Legit" then
            navigateToNearestOre()
        else
            local ch = itemsFold and itemsFold:GetChildren() or {}
            if #ch > 0 then
                for _, item in ipairs(ch) do
                    if not ColOres then break end
                    local ok, err = pcall(function()
                        if collectItem then
                            collectItem:FireServer(item.Name)
                        end
                    end)
                    if not ok then
                        warn("Error collecting item:", err)
                    end
                    task.wait(CollectSpeed)
                end
            end
        end
        task.wait()
    end
end

local function SellInventory()
    if not tradertomPos then
        Notify("Auto Sell Failed", "Could not find trader tom's position, retrying search.", 3)
        findtradertom()
        if not tradertomPos then return end
    end

    local success, err = pcall(function()
        local lastPos = root.Position
        root.CFrame = CFrame.new(tradertomPos)
        task.wait(0.5)
        ReplicatedStorage.Ml.SellInventory:FireServer()
        task.wait(0.5)
        root.CFrame = CFrame.new(lastPos)
    end)

    if not success then
        Notify("Auto Sell Failed", tostring(err), 5)
    end
end

-- // MINING TAB CONTROLS
local AutoMineToggle = MiningTab:AddToggle("AutoMine", {
    Title   = "Auto Mine",
    Default = false,
    Callback = function(bool)
        AutoMine = bool
        if AutoMine then
            if MiningStrength then
                if MiningThread then task.cancel(MiningThread) end
                MiningThread = task.spawn(MineOres)
                Notify("Auto Mining", "Auto mining is now active.", 3)
            else
                Notify("Mining Strength Missing!", "Please set the mining strength first.", 5)
                AutoMine = false
                pcall(function() AutoMineToggle:SetValue(false) end)
            end
        else
            if MiningThread then
                task.cancel(MiningThread)
                MiningThread = nil
                Notify("Auto Mining", "Auto mining has been disabled.", 3)
            end
        end
    end
})

MiningTab:AddToggle("AutoDrill", {
    Title   = "Auto Drill (REQUIRES ANY DRILL)",
    Default = false,
    Callback = function(bool)
        AutoDrill = bool
        if AutoDrill then
            if DrillingThread then task.cancel(DrillingThread) end
            DrillingThread = task.spawn(MineOresDrill)
            Notify("Auto Drill", "Auto drill is now active.", 3)
        else
            if DrillingThread then
                task.cancel(DrillingThread)
                DrillingThread = nil
                Notify("Auto Drill", "Auto drill has been disabled.", 3)
            end
        end
    end
})

MiningTab:AddToggle("AutoDynamite", {
    Title   = "Auto Dynamite (REQUIRES ANY DYNAMITE)",
    Default = false,
    Callback = function(bool)
        AutoDynamite = bool
        if AutoDynamite then
            if DynamiteThread then task.cancel(DynamiteThread) end
            DynamiteThread = task.spawn(UseDynamite)
            Notify("Auto Dynamite", "Auto dynamite is now active.", 3)
        else
            if DynamiteThread then
                task.cancel(DynamiteThread)
                DynamiteThread = nil
                Notify("Auto Dynamite", "Auto dynamite has been disabled.", 3)
            end
        end
    end
})

MiningTab:AddDropdown("MiningStrength", {
    Title   = "Mining Strength",
    Values  = { "Max", "Good", "Decent", "Bad" },
    Default = "Max",
    Multi   = false,
    Callback = function(Value)
        if Value == "Max" then
            MiningStrength = 1
        elseif Value == "Good" then
            MiningStrength = 0.8
        elseif Value == "Decent" then
            MiningStrength = 0.7
        elseif Value == "Bad" then
            MiningStrength = 0.6
        end
        if AutoMine then
            if MiningThread then task.cancel(MiningThread) end
            MiningThread = task.spawn(MineOres)
        end
    end
})

MiningTab:AddDropdown("MiningDirection", {
    Title   = "Mining Direction",
    Values  = { "Camera", "Random", "Towards Ores" },
    Default = "Camera",
    Multi   = false,
    Callback = function(Value)
        MiningDir = Value
    end
})

MiningTab:AddToggle("CollectOres", {
    Title   = "Collect Ores",
    Default = false,
    Callback = function(bool)
        ColOres = bool
        if ColOres then
            if OresThread then task.cancel(OresThread) end
            OresThread = task.spawn(CollectOres)
            Notify("Collecting Ores", "Auto Ore Collecting is now active. (Might cause lag bcuz game bad lol)", 3)
        else
            if OresThread then
                task.cancel(OresThread)
                OresThread = nil
                Notify("Collecting Ores", "Auto Ore Collecting is now disabled.", 3)
            end
        end
    end
})

MiningTab:AddDropdown("CollectSpeed", {
    Title   = "Collect Speed",
    Values  = { "Instant (LAG)", "Fast", "Slow" },
    Default = "Slow",
    Multi   = false,
    Callback = function(Value)
        if Value == "Instant (LAG)" then
            CollectSpeed = 0
        elseif Value == "Fast" then
            CollectSpeed = 0.125
        elseif Value == "Slow" then
            CollectSpeed = 0.5
        end
    end
})

MiningTab:AddDropdown("CollectMode", {
    Title   = "Collect Mode",
    Values  = { "Always", "Legit" },
    Default = "Legit",
    Multi   = false,
    Callback = function(Value)
        CollectMode = Value
    end
})

MiningTab:AddButton({
    Title = "Sell Everything",
    Callback = function()
        SellInventory()
    end
})

MiningTab:AddButton({
    Title = "Equip Best Items (USE SCRIPT'S MINING)",
    Callback = function()
        local EquipItem = ReplicatedStorage.Ml.EquipItem
        EquipItem:FireServer("Dragon Pickaxe")
        task.wait(2)
        EquipItem:FireServer("Ruby Drill")
        task.wait(2)
        EquipItem:FireServer("Toxic Dynamite")
    end
})

-- // TELEPORT TAB
TeleportTab:AddSection("Teleports")
TeleportTab:AddButton({
    Title = "Forest",
    Callback = function()
        if root then root.CFrame = CFrame.new(Vector3.new(998, 245, -71)) end
    end
})
TeleportTab:AddButton({
    Title = "Mine Passage",
    Callback = function()
        if root then root.CFrame = CFrame.new(Vector3.new(1020, 181, -1451)) end
    end
})
TeleportTab:AddButton({
    Title = "Crystal Cave",
    Callback = function()
        if root then root.CFrame = CFrame.new(Vector3.new(1011, 177, -2910)) end
    end
})
TeleportTab:AddButton({
    Title = "Merchant Mike (Ores)",
    Callback = function()
        if root then root.CFrame = CFrame.new(Vector3.new(1043, 245, -198)) end
    end
})
TeleportTab:AddButton({
    Title = "Driller Dan (Drills)",
    Callback = function()
        if root then root.CFrame = CFrame.new(Vector3.new(906, 245, -454)) end
    end
})
TeleportTab:AddButton({
    Title = "Sally (Pickaxes)",
    Callback = function()
        if root then root.CFrame = CFrame.new(Vector3.new(1054, 245, -283)) end
    end
})
TeleportTab:AddButton({
    Title = "Bob (Radars)",
    Callback = function()
        if root then root.CFrame = CFrame.new(Vector3.new(1085, 245, -468)) end
    end
})
TeleportTab:AddButton({
    Title = "Miner Mike (Offline)",
    Callback = function()
        if root then root.CFrame = CFrame.new(Vector3.new(954, 245, -222)) end
    end
})

TeleportTab:AddSection("Custom Teleports")
TeleportTab:AddButton({
    Title = "Set your own position",
    Callback = function()
        if root then
            ownPos = root.Position
            Notify("Teleport Set!", "Successfully set teleport position.", 3)
        end
    end
})
TeleportTab:AddButton({
    Title = "Teleport to your own position",
    Callback = function()
        if ownPos and root then
            root.CFrame = CFrame.new(ownPos)
        else
            Notify("Teleport Failed!", "Please set your position first.", 3)
        end
    end
})

-- // SHOP TAB (sections + dropdown + buy button per section)
local function stripPrice(label)
    -- removes the trailing " ($...)" part
    return string.gsub(label, "%s%(%$[%d,]+%)", "")
end




ShopTab:AddParagraph({
    Title = "warning!!!!",
    Content = "if u buy a pickaxe that u already have u will just waste ur money!"
})
-- Pickaxes
ShopTab:AddSection("Pickaxes")
local pickaxeSelected = "Rusty Pickaxe ($5)"
local PickaxeDD = ShopTab:AddDropdown("shop_pickaxes", {
    Title   = "Pickaxe",
    Values  = {
        "Rusty Pickaxe ($5)", "Wooden Pickaxe ($250)", "Stone Pickaxe ($1,350)", "Iron Pickaxe ($5,000)",
        "Emerald Pickaxe ($20,000)", "Sapphire Pickaxe ($40,000)", "Ruby Pickaxe ($100,000)",
        "Amethyst Pickaxe ($100,000)", "Quartz Pickaxe ($500,000)", "Citrine Pickaxe ($1,000,000)",
        "Obsidian Pickaxe ($2,500,000)", "Celestite Pickaxe ($5,000,000)", "Frostbite Pickaxe ($6,000,000)",
        "Sunfrost Pickaxe ($7,500,000)", "Rosefrost Pickaxe ($9,000,000)", "Shadowfrost Pickaxe ($12,500,000)"
    },
    Default = "Rusty Pickaxe ($5)",
    Multi   = false,
    Callback = function(Value) pickaxeSelected = Value end
})
ShopTab:AddButton( {
    Title = "Buy Pickaxe",
    Callback = function()
        BuyItem:FireServer(stripPrice(pickaxeSelected))
    end
})

-- Radars
ShopTab:AddSection("Radars")
local radarSelected = "Copper Radar ($50)"
local RadarDD = ShopTab:AddDropdown("shop_radars", {
    Title   = "Radar",
    Values  = {
        "Copper Radar ($50)", "Iron Radar ($500)", "Gold Radar ($1,500)", "Diamond Radar ($4,000)",
        "Emerald Radar ($20,000)", "Sapphire Radar ($40,000)", "Ruby Radar ($70,000)", "Amethyst Radar ($100,000)",
        "Quartz Radar ($1,500,000)", "Citrine Radar ($3,500,000)", "Obsidian Radar ($5,000,000)",
        "Celestite Radar ($7,000,000)", "Frostbite Radar ($7,000,000)", "Sunfrost Radar ($8,500,000)",
        "Rosefrost Radar ($10,000,000)", "Shadowfrost Radar ($13,000,000)"
    },
    Default = "Copper Radar ($50)",
    Multi   = false,
    Callback = function(Value) radarSelected = Value end
})
ShopTab:AddButton( {
    Title = "Buy Radar",
    Callback = function()
        BuyItem:FireServer(stripPrice(radarSelected))
    end
})

-- Drills
ShopTab:AddSection("Drills")
local drillSelected = "Weak Drill ($25,000)"
local DrillDD = ShopTab:AddDropdown("shop_drills", {
    Title   = "Drill",
    Values  = { "Weak Drill ($25,000)", "Light Drill ($50,000)", "Heavy Drill ($250,000)" },
    Default = "Weak Drill ($25,000)",
    Multi   = false,
    Callback = function(Value) drillSelected = Value end
})
ShopTab:AddButton({
    Title = "Buy Drill",
    Callback = function()
        BuyItem:FireServer(stripPrice(drillSelected))
    end
})

-- Dynamites
ShopTab:AddSection("Dynamites")
local dynamiteSelected = "Light Dynamite ($600,000)"
local DynamiteDD = ShopTab:AddDropdown("shop_dynamites", {
    Title   = "Dynamite",
    Values  = { "Light Dynamite ($600,000)", "Heavy Dynamite ($1,000,000)" },
    Default = "Light Dynamite ($600,000)",
    Multi   = false,
    Callback = function(Value) dynamiteSelected = Value end
})
ShopTab:AddButton( {
    Title = "Buy Dynamite",
    Callback = function()
        BuyItem:FireServer(stripPrice(dynamiteSelected))
    end
})

-- // MISC TAB
MiscTab:AddParagraph({
    Title = "Credits",
    Content = "Made with <3 by Dead"
})

MiscTab:AddToggle("InstantProx", {
    Title   = "Instant Proximity Prompt",
    Default = false,
    Callback = function(bool)
        if bool then
            if fireproximityprompt then
                PromptButtonHoldBegan = ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
                    fireproximityprompt(prompt)
                end)
            else
                Notify("Incompatible Exploit", "Your exploit is incompatible with fireproximityprompt.", 6)
            end
        else
            if PromptButtonHoldBegan then
                PromptButtonHoldBegan:Disconnect()
                PromptButtonHoldBegan = nil
            end
        end
    end
})

MiscTab:AddSlider("Walkspeed", {
    Title    = "Walkspeed",
    Default  = 16,
    Min      = 16,
    Max      = 200,
    Rounding = 0,
    Callback = function(Value)
        pcall(function()
            getgenv().desiredWalkSpeed = Value
        end)
    end
})

MiscTab:AddButton({
    Title = "Remove Fog",
    Callback = function()
        Lighting.FogEnd = 10000
        for _, v in pairs(Lighting:GetDescendants()) do
            if v:IsA("Atmosphere") then
                v:Destroy()
            end
        end
    end
})

-- // Save/Interface integration
SaveManager:SetLibrary(Fluent)
InterfaceMgr:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceMgr:SetFolder("DeadScriptHub")
SaveManager:SetFolder("DeadScriptHub/Mines")
InterfaceMgr:BuildInterfaceSection(SettingsTab)
SaveManager:BuildConfigSection(SettingsTab)

Window:SelectTab(1)

Notify("Mines", "Script loaded and ready.", 8)
SaveManager:LoadAutoloadConfig()
