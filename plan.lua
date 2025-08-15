local Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/discoart/FluentPlus/refs/heads/main/alpha.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Build a Plane - Dead" .. Fluent.Version,
    SubTitle = "by Dead",
    TabWidth = 160,
    Size = UDim2.fromOffset(560, 460),
    Acrylic = true, -- The blur may be detectable, setting this to false disables blur entirely
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.LeftControl -- Used when theres no MinimizeKeybind
})

local Main = Window:AddTab({ Title = "Main", Icon = "home" })
local Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
local autofarmEnabled = false


local currentIndex = 1
local cachedCoins = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local function getCharacter()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    repeat task.wait() until char:FindFirstChild("Humanoid") and char:FindFirstChild("HumanoidRootPart")
    return char
end

local function waitForRespawn()
    while true do
        local char = getCharacter()
        local hum = char:FindFirstChild("Humanoid")
        if hum and hum.Health > 0 then break end
        task.wait()
    end
end

local function getVehicle()
    local seat = getCharacter():FindFirstChildOfClass("Humanoid") and getCharacter():FindFirstChildOfClass("Humanoid").SeatPart
    if not seat then return end
    local model = seat:FindFirstAncestorOfClass("Model")
    if not model then return end

    if not model.PrimaryPart then
        for _, part in ipairs(model:GetDescendants()) do
            if part:IsA("BasePart") then
                model.PrimaryPart = part
                break
            end
        end
    end
    return model
end


local function tpVehicleTo(vehicle, position)
    if not vehicle or not vehicle.PrimaryPart then return end
    vehicle:SetPrimaryPartCFrame(CFrame.new(position + Vector3.new(0, 7, 0)))
end

local function getCoinsSorted()
    if #cachedCoins > 0 then return cachedCoins end

    local char = getCharacter()
    local pos = char:WaitForChild("HumanoidRootPart").Position
    local allCoins = {}

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Folder") and obj.Name == "Coins" then
            for _, coin in ipairs(obj:GetChildren()) do
                if coin:IsA("BasePart") then
                    table.insert(allCoins, coin)
                end
            end
        end
    end

    table.sort(allCoins, function(a, b)
        return (a.Position - pos).Magnitude < (b.Position - pos).Magnitude
    end)

    cachedCoins = allCoins
    return cachedCoins
end



local godmode = false


local function getplot()
    local plots = workspace.Islands
    for i, plot in plots:GetChildren() do
        if plot.Important.OwnerID.Value == game.Players.LocalPlayer.UserId then
            return plot
        end
    end
end
local plot = getplot()


spawn(function()
while true do
task.wait(0.1)
if autofarmEnabled then
waitForRespawn()
fireLaunchAndPortal()
task.wait(0.1)

local vehicle = getVehicle()  
        if not vehicle then warn("No vehicle") task.wait(1) continue end  

        local coins = getCoinsSorted()  
        if currentIndex > #coins then  
            currentIndex = 1 -- restart when finished  
        end  

        local coin = coins[currentIndex]  
        if coin and coin:IsA("BasePart") then  
            tpVehicleTo(vehicle, coin.Position)  
            collectCoin(coin)  
            currentIndex += 1  
            task.wait(0.1)  
        end  
    end  
end

end)

-- Godmode
spawn(function()
    while true do 
        if godmode then
            for _, item in plot:FindFirstChild("PlacedBlocks"):GetDescendants() do
                if (item:IsA("Part") or item:IsA("MeshPart")) 
                    and (item.Parent.Name ~= "driver_seat_1" and item.Name ~= "Part") then
                    if item.CanTouch then
                        item.CanTouch = false
                    end
                end
            end
        else
            for _, item in plot:FindFirstChild("PlacedBlocks"):GetDescendants() do
                if (item:IsA("Part") or item:IsA("MeshPart")) 
                    and (item.Parent.Name ~= "driver_seat_1" and item.Name ~= "Part") then
                    item.CanTouch = true
                end
            end
        end
        task.wait(0.2)
    end
end)




local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BuyBlock = ReplicatedStorage.Remotes.ShopEvents:WaitForChild("BuyBlock")

-- Variables
local autobuyEnabled = false
local autobuySelectedEnabled = false
local selectedItems = {}

-- Buy ALL items
local function autoBuyAll()
    local itemsToBuy = {
        "block_1",
        "wing_1", "wing_2",
        "fuel_1", "fuel_2", "fuel_3",
        "propeller_1", "propeller_2",
        "seat_1",
        "balloon",
        "missile",
        "rocket",
        "energy"
    }

    while autobuyEnabled do
        for _, item in ipairs(itemsToBuy) do
            pcall(function()
                BuyBlock:FireServer(item)
            end)
            task.wait(0.1)
        end
        task.wait(1)
    end
end

-- Buy SELECTED items
local function autoBuySelected()
    while autobuySelectedEnabled do
        for _, item in ipairs(selectedItems) do
            pcall(function()
                BuyBlock:FireServer(item)
            end)
            task.wait(0.1)
        end
        task.wait(1)
    end
end

-- UI Setup
local buymain = Main:AddSection("auto buy")

-- Toggle: Auto Buy All
buymain:AddToggle("AutobuyToggle", {
    Title = "Auto Buy All Items",
    Default = false,
    Callback = function(state)
        autobuyEnabled = state
        if state then
            task.spawn(autoBuyAll)
        end
        print("Autobuy All toggled:", state)
    end
})

-- Dropdown: Select Items to Auto Buy
local selectedItemsDropdown = buymain:AddDropdown("SelectItemsToBuy", {
    Title = "Select Items to Auto Buy",
    Values = {
        "block_1", "wing_1", "wing_2",
        "fuel_1", "fuel_2", "fuel_3",
        "propeller_1", "propeller_2",
        "seat_1", "balloon", "missile",
        "rocket", "energy"
    },
    Multi = true,
    Default = {}
})

-- ✅ FIX: Properly convert dictionary to array
selectedItemsDropdown:OnChanged(function(values)
    local cleaned = {}
    for item, isSelected in pairs(values) do
        if isSelected then
            table.insert(cleaned, item)
        end
    end
    selectedItems = cleaned

    print("Selected items to buy:", #selectedItems > 0 and table.concat(selectedItems, ", ") or "None")
end)

-- Toggle: Auto Buy Selected
buymain:AddToggle("AutobuySelectedToggle", {
    Title = "Auto Buy Selected Items",
    Default = false,
    Callback = function(state)
        autobuySelectedEnabled = state
        if state then
            task.spawn(autoBuySelected)
        end
        print("Autobuy Selected toggled:", state)
    end
})



local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer

-- Variables
local stepDistance = 10
local stepInterval = 0.3
local flyHeight = 300
local straightFarmEnabled = false
local selectedFarmMode = "Teleport"

-- Character + Seat
local function getCharacter()
    return player.Character or player.CharacterAdded:Wait()
end

local function getVehicleSeat()
    local char = getCharacter()
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and hum.SeatPart and hum.SeatPart:IsA("VehicleSeat") then
        return hum.SeatPart
    end
    return nil
end

-- Autofarm logic
local function straightAutoFarm()
    while straightFarmEnabled do
        local seat = getVehicleSeat()
        if not seat then
            warn("Not seated in a VehicleSeat.")
            task.wait(1)
            continue
        end

        local forward = seat.CFrame.LookVector * stepDistance
        local targetPos = Vector3.new(
            seat.Position.X + forward.X,
            flyHeight,
            seat.Position.Z + forward.Z
        )

        if selectedFarmMode == "Teleport" then
            seat.CFrame = CFrame.new(targetPos, targetPos + seat.CFrame.LookVector)
            task.wait(stepInterval)

        elseif selectedFarmMode == "Tween" then
            local tween = TweenService:Create(seat, TweenInfo.new(stepInterval, Enum.EasingStyle.Linear), {
                CFrame = CFrame.new(targetPos, targetPos + seat.CFrame.LookVector)
            })
            tween:Play()
            tween.Completed:Wait()
        end
    end
end


local mainsection = Main:AddSection("Main Farm")

mainsection:AddToggle("StraightFarmToggle", {
    Title = "Straight AutoFarm (Fly Forward)",
    Default = false,
    Callback = function(state)
        straightFarmEnabled = state
        print("Straight Autofarm toggled:", state)
        if state then
            task.spawn(straightAutoFarm)
        end
    end
})

mainsection:AddToggle("godmode",{
    Title = "God mode ( hide ur seat)",
    Default = false,
    Callback = function(state)
    godmode = state
    print("god mode toggle:", state)
    end
})

local farmModeDropdown = mainsection:AddDropdown("FarmMethod", {
    Title = "AutoFarm Method",
    Description = "Choose how the vehicle moves",
    Values = {"Teleport", "Tween"},
    Multi = false,
    Default = 1,
})

farmModeDropdown:OnChanged(function(Value)
    selectedFarmMode = Value
    print("Farm method set to:", Value)
end)

mainsection:AddSlider("StepDistance", {
    Title = "Step Distance",
    Description = "Distance moved forward per step",
    Default = stepDistance,
    Min = 5,
    Max = 100,
    Rounding = 1,
    Callback = function(val)
        stepDistance = val
    end
})

mainsection:AddSlider("StepInterval", {
    Title = "Step Interval",
    Description = "Time between each movement",
    Default = stepInterval,
    Min = 0.01,
    Max = 1,
    Rounding = 2,
    Callback = function(val)
        stepInterval = val
    end
})

mainsection:AddSlider("FlyHeight", {
    Title = "Fly Height",
    Description = "Fixed Y position while flying",
    Default = flyHeight,
    Min = 50,
    Max = 500,
    Rounding = 0,
    Callback = function(val)
        flyHeight = val
    end
})

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
    Title = "Build a Plane",
    Content = "Script loaded and ready.",
    Duration = 8,
})

SaveManager:LoadAutoloadConfig()
