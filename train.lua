
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/discoart/FluentPlus/refs/heads/main/alpha.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Build a train - Dead " .. Fluent.Version,
    SubTitle = "by Dead",
    TabWidth = 140,
    Size = UDim2.fromOffset(460, 360),
    Acrylic = false,
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Main = Window:AddTab({ Title = "Main", Icon = "home" })
local config = Window:AddTab({ Title = "configs", Icon = "cpu" })
local Shop = Window:AddTab({ Title = "Shop", Icon = "shopping-cart" })
local Extra = Window:AddTab({ Title = "Extra", Icon = "cpu" })
local Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })

-- ----------------------------
-- State / Config
-- ----------------------------
local myPlotIndex = nil
local buyRemote = nil
local claimremote = nil
local autofarm = false
local farmingThread = nil
local autoclaimenabled = false
local buyDelay = 0.05
local buySelectedRunning = false
local buyAllRunning = false

-- Shop items list (left as you provided)
local shopItems = {
    "FuelBarrel",
    "BetterExhaust",
    "BetterEngine",
    "BetterFuel",
    "Handbrake",
    "Headlight",
    "Exhaust",
    "CoalEngine",
    "Seat",
    "CoalFuel",
    "Wedge",
    "Whistle",
    "Realinger",
    "Truss",
    "Block"
}

-- ----------------------------
-- Utilities
-- ----------------------------
local function safeNotify(title, content, dur)
    dur = dur or 2
    if Fluent and Fluent.Notify then
        pcall(function() Fluent:Notify({ Title = title, Content = content, Duration = dur }) end)
    else
        warn("[Notify]", title, content)
    end
end

-- ----------------------------
-- Find Player Plot
-- ----------------------------
local function findMyPlot()
    myPlotIndex = nil
    local playerName = LocalPlayer and LocalPlayer.Name or (Players.LocalPlayer and Players.LocalPlayer.Name)
    if not playerName then
        warn("[findMyPlot] LocalPlayer not ready.")
        return
    end

    local plotsFolder = workspace:FindFirstChild("Plots")
    if not plotsFolder then
        warn("[findMyPlot] workspace.Plots folder not found!")
        return
    end

    local locationFolders = plotsFolder:GetChildren()
    for i, locationFolder in ipairs(locationFolders) do
        -- Some maps use Attributes, some use nested value; we check attribute
        if locationFolder.Name == "Location" and typeof(locationFolder.GetAttribute) == "function" then
            local owner = locationFolder:GetAttribute("Owner")
            if owner == playerName then
                myPlotIndex = i
                warn("[findMyPlot] Found your Location at index:", i, "Name:", locationFolder.Name)
                return
            end
        end
    end

    warn("[findMyPlot] Could not find your Location with matching Owner attribute.")
end
-- initial attempt
findMyPlot()

-- ----------------------------
-- Recursive Seat Finder
-- ----------------------------
local function findSeatRecursive(instance)
    for _, child in ipairs(instance:GetChildren()) do
        if child.Name == "Seat" then
            if child:IsA("BasePart") then
                return child
            elseif child:IsA("Model") and child.PrimaryPart then
                return child.PrimaryPart
            end
        end
        local found = findSeatRecursive(child)
        if found then return found end
    end
    return nil
end

-- ----------------------------
-- Auto Claim (calls stored claimremote)
-- ----------------------------

local function autoclaim_once()
    if not claimremote then
        safeNotify("Auto Claim", "No claim remote set!", 2)
        warn("[autoclaim_once] claimremote is nil")
        return false
    end

    local suc, err = pcall(function()
        -- claim remote expected to be FireServer({})
        claimremote:FireServer({})
    end)

    if not suc then
        warn("[claim] Error claiming money:", err)
        safeNotify("Auto Claim", "Claim failed!", 3)
        return false
    end

    local successDelete = false

    -- Delete "Menu" UI
    local menuUI = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("Menu")
    if menuUI then
        pcall(function() menuUI:Destroy() end)
        warn("[claim] Deleted 'Menu' UI after claim.")
        successDelete = true
    end

    -- Delete "DarkBackground" UI
    local darkBgUI = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("DarkBackground")
    if darkBgUI then
        pcall(function() darkBgUI:Destroy() end)
        warn("[claim] Deleted 'DarkBackground' UI after claim.")
        successDelete = true
    end

    warn("[claim] Claimed money successfully.")
    if successDelete then
        safeNotify("Auto Claim", "Claimed and removed UI.", 2)
    else
        safeNotify("Auto Claim", "Claimed successfully.", 2)
    end

    return true
end

-- ----------------------------
-- Autofarm (teleport + cart yeet)
-- ----------------------------
local function startAutofarm()
    if farmingThread then return end
    farmingThread = task.spawn(function()
        while autofarm do
            if not myPlotIndex then
                findMyPlot()
                task.wait(1)
                -- if still nil continue
            end

            local plotsFolder = workspace:FindFirstChild("Plots")
            if not plotsFolder then
                warn("[autofarm] Plots folder not found!")
                task.wait(2)
                continue
            end

            local yourPlot = plotsFolder:GetChildren()[myPlotIndex]
            if not yourPlot then
                warn("[autofarm] Your plot not found at index " .. tostring(myPlotIndex))
                task.wait(2)
                continue
            end

            local seat = findSeatRecursive(yourPlot)
            if not seat then
                warn("[autofarm] No seat found in your plot!")
                task.wait(2)
                continue
            end

            -- Prefer "Bounds" if present
            local targetPart = seat
            if seat.Parent then
                local block = seat.Parent:FindFirstChild("Bounds")
                if block and block:IsA("BasePart") then
                    targetPart = block
                end
            end

            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp and targetPart then
                hrp.CFrame = targetPart.CFrame + Vector3.new(0, 5, 1)
                warn("[autofarm] Teleported to seat/bounds.")
            else
                warn("[autofarm] HumanoidRootPart or target part not found!")
                task.wait(2)
                continue
            end

            -- Wait a bit and ensure sitting
            task.wait(1)
            local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if not humanoid or not humanoid.Sit then
                warn("[autofarm] You are not sitting on the train seat.")
                task.wait(2)
                continue
            end

            -- Teleport cart far away
            local myPlot = workspace.Plots:GetChildren()[myPlotIndex]
            if myPlot then
                local cart = myPlot:FindFirstChild("Cart")
                if cart then
                    if cart:IsA("BasePart") then
                        cart.Position = Vector3.new(1e9, 1e9, 1e9)
                    elseif cart.PrimaryPart then
                        cart:SetPrimaryPartCFrame(CFrame.new(1e9, 1e9, 1e9))
                    end
                    warn("[autofarm] Cart teleported far away.")
                    task.wait(2)
                else
                    warn("[autofarm] No cart found in your plot.")
                end

                -- Reset character to trigger server-side reset
                if humanoid then
                    humanoid.Health = 0
                    warn("[autofarm] Character reset.")
                end
            else
                warn("[autofarm] Plot not found at myPlotIndex: " .. tostring(myPlotIndex))
            end

            task.wait(2) -- cooldown
        end

        farmingThread = nil
    end)
end

-- ----------------------------
-- Cart Yeet loop (separate optional function kept from your script)
-- ----------------------------
local running_cartLoop = false
local function cartLoop()
    running_cartLoop = true
    while running_cartLoop do
        if not myPlotIndex then findMyPlot() end

        local plotsFolder = workspace:FindFirstChild("Plots")
        if not plotsFolder then
            warn("[cartLoop] Plots folder not found in workspace!")
            return
        end

        local myPlot = Workspace.Plots:GetChildren()[myPlotIndex]
        if myPlot then
            local seat = findSeatRecursive(myPlot)
            if not seat then
                warn("[cartLoop] No seat found inside your plot!")
                return
            end

            local targetPart = seat
            if seat.Parent then
                local block = seat.Parent:FindFirstChild("Bounds")
                if block and block:IsA("BasePart") then
                    targetPart = block
                end
            end

            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp and targetPart then
                hrp.CFrame = targetPart.CFrame + Vector3.new(0, 5, 1)
                warn("[cartLoop] Teleported to your plot's seat or Seat.Block if available.")
            else
                warn("[cartLoop] HumanoidRootPart or target part not found!")
            end

            task.wait(1)
            local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                if not humanoid.Sit then
                    safeNotify("CartLoop", "You are not sitting on the train seat.")
                    return
                end
            else
                warn("[cartLoop] No humanoid found!")
                return
            end

            task.wait(1)
            local cart = myPlot:FindFirstChild("Cart")
            if cart then
                if cart:IsA("BasePart") then
                    cart.Position = Vector3.new(1e9, 1e9, 1e9)
                elseif cart.PrimaryPart then
                    cart:SetPrimaryPartCFrame(CFrame.new(1e9, 1e9, 1e9))
                end
                warn("[cartLoop] Cart teleported far away.")
                task.wait(2)
            else
                warn("[cartLoop] No cart found in your plot.")
            end

            -- Teleport player far away
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(1e9, 1e9, 1e9)
                warn("[cartLoop] Player teleported far away.")
            end

            -- Reset character
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
                LocalPlayer.Character:FindFirstChildOfClass("Humanoid").Health = 0
                warn("[cartLoop] Character reset.")
            end
        else
            warn("[cartLoop] My plot not found during loop.")
        end

        task.wait(1.5)
    end
end

-- ----------------------------
-- UI: Main Tab
-- ----------------------------
local mainsec = Main:AddSection("auto farm")

mainsec:AddToggle("cartLoop", {
    Title = "Auto Farm Money",
    Default = false,
    Callback = function(state)
        autofarm = state
        warn("[UI] Auto farm money toggle:", state)
        if state then
            if not farmingThread then
                startAutofarm()
            end
        else
            -- stop farming thread by flipping autofarm; thread will end naturally
            farmingThread = nil
        end
    end
})

mainsec:AddToggle("autoclaim", {
    Title = "Auto Claim",
    Default = false,
    Callback = function(state)
        autoclaimenabled = state
        warn("[UI] Auto Claim toggle:", state)
        if state then
            startAutoClaimLoop()
        end
    end
})

mainsec:AddButton({
    Title = "tp to the end and reset",
    Callback = function()
        local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            if not humanoid.Sit then
                safeNotify("Auto Farm", "You are not sitting on the train seat.")
                return
            end
        else
            warn("[tp/reset] No humanoid found!")
            return
        end

        if not myPlotIndex then findMyPlot() end
        local myPlot = Workspace.Plots:GetChildren()[myPlotIndex]
        if myPlot then
            local cart = myPlot:FindFirstChild("Cart")
            if cart then
                if cart:IsA("BasePart") then
                    cart.Position = Vector3.new(1e9, 1e9, 1e9)
                elseif cart.PrimaryPart then
                    cart:SetPrimaryPartCFrame(CFrame.new(1e9, 1e9, 1e9))
                end
                warn("[tp/reset] Cart teleported far away.")
                task.wait(2)
            else
                warn("[tp/reset] No cart found in your plot.")
            end

            if LocalPlayer.Character and humanoid then
                humanoid.Health = 0
                warn("[tp/reset] Character reset.")
            end
        else
            warn("[tp/reset] Plot not found at myPlotIndex: " .. tostring(myPlotIndex))
        end
    end
})

mainsec:AddButton({
    Title = "Teleport to Your seat",
    Default = false,
    Callback = function()
        if not myPlotIndex then findMyPlot() end
        local plotIndex = myPlotIndex
        local plotsFolder = workspace:FindFirstChild("Plots")
        if not plotsFolder then
            warn("[Teleport] Plots folder not found!")
            return
        end

        local yourPlot = plotsFolder:GetChildren()[plotIndex]
        if not yourPlot then
            warn("[Teleport] Your plot not found at index " .. tostring(plotIndex))
            return
        end

        local seat = findSeatRecursive(yourPlot)
        if not seat then
            warn("[Teleport] No seat found inside your plot!")
            return
        end

        local targetPart = seat
        if seat.Parent then
            local block = seat.Parent:FindFirstChild("Bounds")
            if block and block:IsA("BasePart") then
                targetPart = block
            end
        end

        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp and targetPart then
            hrp.CFrame = targetPart.CFrame + Vector3.new(0, 5, 1)
            warn("[Teleport] Teleported to your plot's seat.")
        else
            warn("[Teleport] HumanoidRootPart or target part not found!")
        end
    end
})

-- ----------------------------
-- Extra Tab: FPS tweaks
-- ----------------------------
local fpsSection = Extra:AddSection("FPS")

fpsSection:AddButton({
    Title = "Delete Particles (All Plots)",
    Callback = function()
        local count = 0
        if not Workspace:FindFirstChild("Plots") then
            safeNotify("FPS", "Plots not found", 2)
            return
        end
        for _, plot in ipairs(Workspace.Plots:GetChildren()) do
            for _, obj in ipairs(plot:GetDescendants()) do
                if obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or (obj.Name:lower():find("fire")) then
                    pcall(function() obj:Destroy() end)
                    count = count + 1
                end
            end
        end
        warn(string.format("[FPS] Deleted %d particle/fire objects from all plots.", count))
        safeNotify("FPS", ("Deleted %d objects"):format(count), 2)
    end
})

fpsSection:AddButton({
    Title = "Delete Other Plots",
    Callback = function()
        if not myPlotIndex then findMyPlot() end
        local deleted = 0
        if not Workspace:FindFirstChild("Plots") then
            safeNotify("FPS", "Plots folder not found", 2)
            return
        end
        for i, plot in ipairs(Workspace.Plots:GetChildren()) do
            if i ~= myPlotIndex then
                pcall(function() plot:Destroy() end)
                deleted = deleted + 1
            end
        end
        warn(string.format("[FPS] Deleted %d plots (not yours).", deleted))
        safeNotify("FPS", ("Deleted %d plots"):format(deleted), 2)
    end
})

fpsSection:AddButton({
    Title = "Re-find My Plot",
    Callback = function()
        findMyPlot()
        safeNotify("Config", "Re-found your plot (check logs).", 2)
    end
})

-- ----------------------------
-- Shop Tab (Shop / buy)
-- ----------------------------
local shopSection = Shop:AddSection("Shop")

-- Dropdown (selectedItem)
local selectedItem = shopItems[1]
shopSection:AddDropdown("ShopItemDropdown", {
    Title = "Select Item",
    Values = shopItems,
    Default = selectedItem,
    Callback = function(val)
        selectedItem = val
        warn("[Shop] Dropdown selected:", val)
    end
})

-- Buy delay input
local function setBuyDelay(val)
    local n = tonumber(val)
    if n and n >= 0 then
        buyDelay = n
        warn("[Shop] Buy delay set to:", buyDelay)
        safeNotify("Shop", ("Delay: %0.3f"):format(buyDelay), 2)
    else
        safeNotify("Shop", "Invalid delay; using previous value.", 2)
    end
end

-- show initial buyDelay in UI input; ensure buyDelay exists
shopSection:AddInput("setBuyDelay", {
    Title = "Buy Delay (s)",
    Text = tostring(buyDelay),
    Placeholder = "0.05",
    Callback = function(val)
        setBuyDelay(val)
    end
})

-- Buy function (uses stored buyRemote)
local function doBuy(itemName)
    if not buyRemote then
        safeNotify("Shop", "Must set buy remote first!", 2)
        warn("[Shop] Attempted buy but buyRemote is nil.")
        return false
    end

    local args = {
        {
            ItemName = itemName,
            Amount = 1
        }
    }

    local suc, err = pcall(function()
        -- prefer :InvokeServer if remote supports it
        if buyRemote.InvokeServer then
            buyRemote:InvokeServer(unpack(args))
        else
            buyRemote:FireServer(unpack(args))
        end
    end)

    if not suc then
        warn("[Shop] Error buying item:", itemName, err)
        safeNotify("Shop", "Buy failed: " .. tostring(err), 3)
        return false
    end

    warn("[Shop] Bought item:", itemName)
    return true
end

-- Buy Selected toggle
shopSection:AddToggle("BuySelectedToggle", {
    Title = "Buy Selected",
    Default = false,
    Callback = function(state)
        buySelectedRunning = state
        if state then
            warn("[Shop] Starting Buy Selected for:", selectedItem)
            task.spawn(function()
                while buySelectedRunning do
                    if buyRemote then
                        doBuy(selectedItem)
                    else
                        safeNotify("Shop", "No buy remote set. Stopping Buy Selected.", 3)
                        buySelectedRunning = false
                        break
                    end
                    task.wait(buyDelay)
                end
                warn("[Shop] Buy Selected loop ended.")
            end)
        else
            warn("[Shop] Buy Selected toggled off.")
        end
    end
})

-- Buy All toggle
shopSection:AddToggle("BuyAllToggle", {
    Title = "Buy All",
    Default = false,
    Callback = function(state)
        buyAllRunning = state
        if state then
            warn("[Shop] Starting Buy All.")
            task.spawn(function()
                while buyAllRunning do
                    if buyRemote then
                        for _, item in ipairs(shopItems) do
                            if not buyAllRunning then break end
                            doBuy(item)
                            task.wait(buyDelay)
                        end
                    else
                        safeNotify("Shop", "No buy remote set. Stopping Buy All.", 3)
                        buyAllRunning = false
                        break
                    end
                    task.wait(0.1)
                end
                warn("[Shop] Buy All loop ended.")
            end)
        else
            warn("[Shop] Buy All toggled off.")
        end
    end
})

-- ----------------------------
-- Config Tab: Set Remotes
-- ----------------------------
local buyConfigSection = config:AddSection("auto Buy Config (must do to work)")

-- Set Buy Remote button: listens for InvokeServer with ItemName table (your original)
buyConfigSection:AddButton({
    Title = "Set Buy Remote",
    Description = "Click this, then perform an in-game buy action to capture the remote.",
    Callback = function()
        warn("[Shop] Waiting for your next purchase to detect buy remote...")
        -- Keep original hook approach: watch for InvokeServer where args[1] is table with ItemName
        local oldNameCall
        oldNameCall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            local args = {...}
            -- detect InvokeServer within REM and arg is table with ItemName
            if method == "InvokeServer" and self:IsDescendantOf(ReplicatedStorage:WaitForChild("REM")) and typeof(args[1]) == "table" then
                local tbl = args[1]
                if tbl.ItemName then
                    buyRemote = self
                    warn("[Shop] Buy remote set to:", tostring(self) )
                    safeNotify("Shop", "Buy remote set: " .. (self.Name or "Unknown"), 3)
                    -- unhook
                    pcall(function() hookmetamethod(game, "__namecall", oldNameCall) end)
                end
            end
            return oldNameCall(self, ...)
        end)
    end
})

buyConfigSection:AddButton({
    Title = "Buy Block ( click this after clicking buy from the shop)",
    Callback = function()
        if not buyRemote then
            safeNotify("Shop", "Must set buy remote first", 3)
            return
        end
        local args = {
            {
                ItemName = "Block",
                Amount = 1
            }
        }
        warn("[Shop] Buying Block...")
        -- prefer InvokeServer if available
        pcall(function()
            if buyRemote.InvokeServer then
                buyRemote:InvokeServer(unpack(args))
            else
                buyRemote:FireServer(unpack(args))
            end
        end)
    end
})

-- ----------------------------
-- Farm Config: Claim remote
-- ----------------------------
local farmsec = config:AddSection("auto farm config")

-- Set Claim Remote: listen for FireServer with {} (empty table)
farmsec:AddButton({
    Title = "Set Claim Remote",
    Description = "Click this, then click your in-game claim button.",
    Callback = function()
        warn("[claim] Waiting for your next claim to detect claim remote...")
        local oldNameCall
        oldNameCall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            local args = {...}
            -- We expect FireServer within ReplicatedStorage.REM with an empty table argument {}
            if method == "FireServer" and self:IsDescendantOf(ReplicatedStorage:WaitForChild("REM")) then
                if typeof(args[1]) == "table" and next(args[1]) == nil then
                    claimremote = self
                    warn("[claim] Claim remote set to:", tostring(self))
                    safeNotify("Auto Claim", "Claim remote set: " .. (self.Name or "Unknown"), 3)
                    -- unhook
                    pcall(function() hookmetamethod(game, "__namecall", oldNameCall) end)
                end
            end
            return oldNameCall(self, ...)
        end)
    end
})

farmsec:AddButton({
    Title = "Claim Money (manual)",
    Description = " click after clicking claim ",
    Callback = function()
        autoclaim_once()
    end
})

-- ----------------------------
-- Final: SaveManager / Settings placeholders (kept)
-- ----------------------------
-- End of script
warn("[SCRIPT] Full script loaded. Keep your exploit hooked to hookmetamethod for remote detection to work.")

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("DeadScriptHub")
SaveManager:SetFolder("DeadScriptHub/BuildAPpane")
InterfaceManager:BuildInterfaceSection(Settings)
SaveManager:BuildConfigSection(Settings)

Window:SelectTab(1)

Fluent:Notify({
    Title = "Build a Car",
    Content = "Script loaded and ready.",
    Duration = 8,
})

SaveManager:LoadAutoloadConfig()
