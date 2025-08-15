local Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/discoart/FluentPlus/refs/heads/main/alpha.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Prospecting | Main",
    SubTitle = "Made by Dead | Version: "..Fluent.Version,
    TabWidth = 160,
    Size = UDim2.fromOffset(540, 340),
    Acrylic = false,
    Theme = "Dark",
    Center = true,
    IsDraggable = true,
    Keybind = Enum.KeyCode.LeftControl
})




local Main = Window:AddTab({ Title = "Main", Icon = "home" })
local Shop = Window:AddTab({ Title = "shop", Icon = "home" })
local esp = Window:AddTab({ Title = "ESP", Icon = "eye" })












-- // Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")

--// ESP Settings
local espEnabled = {
    Luck = false,
    Strength = false
}



-- // Helpers
local function getPan()
    local char = LocalPlayer.Character
    local bp = LocalPlayer:FindFirstChild("Backpack")

    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") and tool.Name:lower():find("pan") then
                return tool
            end
        end
    end
    if bp then
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") and tool.Name:lower():find("pan") then
                tool.Parent = char
                return tool
            end
        end
    end
    return nil
end

local function isPanFull()
    local ui = LocalPlayer.PlayerGui:FindFirstChild("ToolUI")
    if not ui then return false end
    local fill = ui:FindFirstChild("FillingPan")
    if not fill then return false end
    local text = fill:FindFirstChild("FillText")
    if not text then return false end

    local content = text.ContentText
    local current, max = content:match("(%d+)%/(%d+)")
    if current and max then
        return tonumber(current) >= tonumber(max)
    end
    return false
end

local function isPanEmpty()
    local ui = LocalPlayer.PlayerGui:FindFirstChild("ToolUI")
    if not ui then return true end
    local fill = ui:FindFirstChild("FillingPan")
    if not fill then return true end
    local text = fill:FindFirstChild("FillText")
    if not text then return true end

    local content = text.ContentText
    local current, max = content:match("(%d+)%/(%d+)")
    if current and max then
        return tonumber(current) <= 0
    end
    return true
end

local function moveTo(cframe)
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hrp and hum then
        hum:MoveTo(cframe.Position)
        hum.MoveToFinished:Wait()
    end
end

local function tpTo(cframe)
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = cframe
    end
end

local function getModelPivot(model)
    if typeof(model) == "Instance" and model:IsA("Model") then
        if model.GetPivot then
            return model:GetPivot()
        elseif model.PrimaryPart then
            return model.PrimaryPart.CFrame
        elseif model.GetModelCFrame then
            return model:GetModelCFrame()
        end
    end
    return nil
end


-- Item → Folder map
local shopLocations = {
    -- Shovels
    ["Iron Shovel"] = "StarterTown",
    ["Steel Shovel"] = "StarterTown",
    ["Silver Shovel"] = "StarterTown",
    ["Reinforced Shovel"] = "StarterTown",
    ["Golden Shovel"] = "RiverTown",
    ["Diamond Shovel"] = "RiverTown",
    ["Meteoric Shovel"] = "RiverTown",
    ["The Excavator"] = "RiverTown",
    ["Divine Shovel"] = "Cavern",
    ["Earthbreaker"] = "Cavern",
    ["Worldshaker"] = "Cavern",

    -- Pans
    ["Plastic Pan"] = "StarterTown",
    ["Metal Pan"] = "StarterTown",
    ["Silver Pan"] = "StarterTown",
    ["Golden Pan"] = "RiverTown",
    ["Diamond Pan"] = "RiverTown",
    ["Magnetic Pan"] = "RiverTown",
    ["Meteoric Pan"] = "RiverTown",
    ["Aurora Pan"] = "Cavern",

    -- Sluices
    ["Wood Sluice Box"] = "StarterTown",
    ["Steel Sluice Box"] = "StarterTown",
    ["Gold Sluice Box"] = "StarterTown",
    ["Obsidian Sluice Box"] = "Delta",
    ["Enchanted Sluice"] = "Delta",

    -- Potions
    ["Basic Capacity Potion"] = "RiverTown",
    ["Greater Capacity Potion"] = "RiverTown",
    ["Basic Luck Potion"] = "RiverTown",
    ["Greater Luck Potion"] = "RiverTown",
    ["Merchant's Potion"] = "RiverTown",

    -- Totems / Extras
    ["Luck Totem"] = "RiverTown",
    ["Strength Totem"] = "RiverTown",
    ["Blessed Enchant Book"] = "",
    ["Destructive Enchant Book"] = "",
    ["Meteor Fragment"] = "",
    ["Solar Token"] = ""
}

-- Core function to buy safely
local function buyItem(itemName)
    local folderName = shopLocations[itemName]
    if not folderName then
        warn("Unknown item: " .. tostring(itemName))
        return
    end

    local shopItem
    if folderName == "" then
        shopItem = workspace.Purchasable:FindFirstChild(itemName)
    else
        local folder = workspace.Purchasable:FindFirstChild(folderName)
        if not folder then
            warn("Folder not found: " .. folderName)
            return
        end
        shopItem = folder:FindFirstChild(itemName)
    end

    if not shopItem then
        warn("ShopItem not found for " .. itemName)
        return
    end

    local args = { shopItem:WaitForChild("ShopItem") }
    game.ReplicatedStorage.Remotes.Shop.BuyItem:InvokeServer(unpack(args))
end


--// Services


--// Storage for ESP objects
local activeESP = {}

-- Function to create BillboardGui ESP
local function createESP(totem)
    if activeESP[totem] then return end

    -- pick color based on type
    local totemName = totem.MainPart.TotemUI.Title.Text
    local mainColor = Color3.fromRGB(255, 255, 255)
    if totemName:find("Luck") then
        mainColor = Color3.fromRGB(0, 255, 0) -- green for Luck
    elseif totemName:find("Strength") then
        mainColor = Color3.fromRGB(255, 165, 0) -- orange for Strength
    end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "TotemESP"
    billboard.Adornee = totem:WaitForChild("MainPart")
    billboard.Size = UDim2.new(0, 220, 0, 90)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 999999

    -- background frame (slight dark transparent bg)
    local bgFrame = Instance.new("Frame", billboard)
    bgFrame.Size = UDim2.new(1, 0, 1, 0)
    bgFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    bgFrame.BackgroundTransparency = 0.4
    bgFrame.BorderSizePixel = 0

    -- Title (Totem Name)
    local nameLabel = Instance.new("TextLabel", bgFrame)
    nameLabel.Size = UDim2.new(1, 0, 0.33, 0)
    nameLabel.Position = UDim2.new(0, 0, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = mainColor
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 18
    nameLabel.Text = totemName

    -- Distance
    local distLabel = Instance.new("TextLabel", bgFrame)
    distLabel.Size = UDim2.new(1, 0, 0.33, 0)
    distLabel.Position = UDim2.new(0, 0, 0.33, 0)
    distLabel.BackgroundTransparency = 1
    distLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    distLabel.Font = Enum.Font.Gotham
    distLabel.TextSize = 15
    distLabel.Text = "Distance: 0"

    -- Time left
    local timeLabel = Instance.new("TextLabel", bgFrame)
    timeLabel.Size = UDim2.new(1, 0, 0.33, 0)
    timeLabel.Position = UDim2.new(0, 0, 0.66, 0)
    timeLabel.BackgroundTransparency = 1
    timeLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
    timeLabel.Font = Enum.Font.Gotham
    timeLabel.TextSize = 15
    timeLabel.Text = "Time: 0"

    billboard.Parent = totem.MainPart

    activeESP[totem] = {
        Billboard = billboard,
        Name = nameLabel,
        Dist = distLabel,
        Time = timeLabel
    }
end
-- Function to remove ESP
local function removeESP(totem)
    if activeESP[totem] then
        activeESP[totem].Billboard:Destroy()
        activeESP[totem] = nil
    end
end

-- Update Loop
RunService.Heartbeat:Connect(function()
    local folder = workspace:FindFirstChild("ActiveTotems")
    if not folder then return end

    for _, totem in ipairs(folder:GetChildren()) do
        if totem:FindFirstChild("MainPart") and totem.MainPart:FindFirstChild("TotemUI") then
            local name = totem.MainPart.TotemUI.Title.Text

            -- Check if it should have ESP
            if (name == "Luck Totem" and espEnabled.Luck) or (name == "Strength Totem" and espEnabled.Strength) then
                if not activeESP[totem] then
                    createESP(totem)
                end

                -- Update values
                local esp = activeESP[totem]
                local char = LocalPlayer.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    local dist = (char.HumanoidRootPart.Position - totem.MainPart.Position).Magnitude
                    esp.Dist.Text = ("Distance: %d"):format(math.floor(dist))
                end
                esp.Time.Text = "Time: " .. totem.MainPart.TotemUI.Time.Text
            else
                removeESP(totem)
            end
        end
    end

    -- Clean up removed totems
    for totem, _ in pairs(activeESP) do
        if not totem.Parent then
            removeESP(totem)
        end
    end
end)







-- // Main Tab

local autoSection = Main:AddSection("Auto")

-- Dig perfection dropdown
local digMode = "Always perfect dig"
autoSection:AddDropdown("digPerfDropdown", {
    Title = "Choose dig perfection",
    Values = {"Always perfect dig","Mid dig","Low dig"},
    Multi = false,
    Default = 1,
    Callback = function(v)
        digMode = v
    end
})

-- Auto Dig toggle (wrap each dig with ToggleShovelActive true/false)
local autoDigEnabled = false
autoSection:AddToggle("autoDig",{
Title = "Auto Dig",
Default = false,
Callback = function(v)
autoDigEnabled = v
task.spawn(function()
while autoDigEnabled do
local pan = getPan()
if pan and not isPanFull() then
local val = 1
if digMode == "Mid dig" then val = 0.5 end
if digMode == "Low dig" then val = 0.3 end
pan.Scripts.Collect:InvokeServer(val)
end
task.wait(0.5)
end
end)
end
})

-- Auto Pan toggle (Pan before Shake, cd 0.1)
local autoPanEnabled = false
autoSection:AddToggle("autoPan",{
    Title = "Auto Pan",
    Default = false,
    Callback = function(v)
        autoPanEnabled = v
        task.spawn(function()
            while autoPanEnabled do
                local pan = getPan()
                if pan and not isPanEmpty() then
                    pan.Scripts.Pan:InvokeServer()
                    pan.Scripts.Shake:FireServer()
                end
                task.wait(0.1) -- pan cd
            end
        end)
    end
})

-- Auto Sell Section (TP to Merchant model pivot, then sell)
local sellSection = Main:AddSection("Auto Sell")

local sellCooldown = 5
sellSection:AddInput("cdforsell",{
    Title = "Cooldown (seconds)",
    Default = "5",
    Callback = function(text)
        local num = tonumber(text)
        if num then sellCooldown = num end
    end
})

local autoSellEnabled = false
sellSection:AddToggle("autoSell",{
    Title = "Auto Sell",
    Default = false,
    Callback = function(v)
        autoSellEnabled = v
        task.spawn(function()
            while autoSellEnabled do
                local merchant = workspace:WaitForChild("NPCs"):WaitForChild("RiverTown"):WaitForChild("Merchant")
                local pivot = getModelPivot(merchant)
                if pivot then
                    tpTo(pivot)
                end
                ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shop"):WaitForChild("SellAll"):InvokeServer()
                task.wait(sellCooldown)
            end
        end)
    end
})

sellSection:AddButton({
    Title = "Sell All Now",
    Callback = function()
        local merchant = workspace:WaitForChild("NPCs"):WaitForChild("RiverTown"):WaitForChild("Merchant")
        local pivot = getModelPivot(merchant)
        if pivot then
            tpTo(pivot)
        end
        ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shop"):WaitForChild("SellAll"):InvokeServer()
    end
})

-- Auto Farm Section (MoveTo for sand/water; dig cycle uses toggle true/collect/false)
local farmSection = Main:AddSection("Auto Farm")
local sandCFrame, waterCFrame

farmSection:AddButton({
    Title = "Set Sand Place",
    Callback = function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            sandCFrame = hrp.CFrame
            Fluent:Notify({ Title="Saved", Content="Sand place saved!", Duration=3 })
        end
    end
})

farmSection:AddButton({
    Title = "Set Water Place",
    Callback = function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            waterCFrame = hrp.CFrame
            Fluent:Notify({ Title="Saved", Content="Water place saved!", Duration=3 })
        end
    end
})

local autoFarmEnabled = false
farmSection:AddToggle("autoFarm",{
Title = "Auto Farm",
Default = false,
Callback = function(v)
autoFarmEnabled = v
task.spawn(function()
while autoFarmEnabled do
if sandCFrame and waterCFrame then
-- Go to Sand -> Dig
moveTo(sandCFrame)
while not isPanFull() and autoFarmEnabled do
local pan = getPan()
if pan then
local val = 1
if digMode == "Mid dig" then val = 0.5 end
if digMode == "Low dig" then val = 0.3 end
pan.Scripts.ToggleShovelActive:FireServer(true)

pan.Scripts.Collect:InvokeServer(val)

pan.Scripts.ToggleShovelActive:FireServer(false)
end
task.wait(0.5)
end

-- Go to Water -> Pan  
                moveTo(waterCFrame)  
                while not isPanEmpty() and autoFarmEnabled do  
                    local pan = getPan()  
                    if pan then  
                        pan.Scripts.Pan:InvokeServer()  
                        pan.Scripts.Shake:FireServer()  
                    end  
                    task.wait(0.5)  
                end  
            end  
            task.wait(0.5)  
        end  
    end)  
end

})


-- Dropdowns

-- Track selected items
local selectedShovel, selectedPan, selectedPotion, selectedSluice, selectedExtra = nil, nil, nil, nil, nil

-- Shovels
local shov = Shop:AddSection("Shovels Section")
shov:AddDropdown("shov", {
    Title = "Shovels",
    Values = {
        "Iron Shovel","Reinforced Shovel","Silver Shovel","Steel Shovel","Golden Shovel",
        "Diamond Shovel","Meteoric Shovel","Divine Shovel","Earthbreaker","Worldshaker","The Excavator"
    },
    Multi = false,
    Default = 1,
    Callback = function(Value) selectedShovel = Value end
})
shov:AddButton({
    Title = "Buy Selected Shovel",
    Callback = function() if selectedShovel then buyItem(selectedShovel) end end
})

-- Pans
local pansec = Shop:AddSection("Pans Section")
pansec:AddDropdown("pan", {
    Title = "Pans",
    Values = {
        "Plastic Pan","Metal Pan","Silver Pan","Golden Pan","Diamond Pan",
        "Magnetic Pan","Meteoric Pan","Aurora Pan"
    },
    Multi = false,
    Default = 1,
    Callback = function(Value) selectedPan = Value end
})
pansec:AddButton({
    Title = "Buy Selected Pan",
    Callback = function() if selectedPan then buyItem(selectedPan) end end
})

-- Potions
local potsec = Shop:AddSection("Potions Section")
potsec:AddDropdown("pot", {
    Title = "Potions",
    Values = {
        "Basic Capacity Potion","Greater Capacity Potion","Basic Luck Potion",
        "Greater Luck Potion","Merchant's Potion"
    },
    Multi = false,
    Default = 1,
    Callback = function(Value) selectedPotion = Value end
})
potsec:AddButton({
    Title = "Buy Selected Potion",
    Callback = function() if selectedPotion then buyItem(selectedPotion) end end
})

-- Sluices
local sluSec = Shop:AddSection("Sluices Section")
sluSec:AddDropdown("slu", {
    Title = "Sluices",
    Values = {
        "Wood Sluice Box","Steel Sluice Box","Gold Sluice Box","Enchanted Sluice","Obsidian Sluice Box"
    },
    Multi = false,
    Default = 1,
    Callback = function(Value) selectedSluice = Value end
})
sluSec:AddButton({
    Title = "Buy Selected Sluice",
    Callback = function() if selectedSluice then buyItem(selectedSluice) end end
})

-- Extras
local extraSec = Shop:AddSection("Extras Section")
extraSec:AddDropdown("extrase", {
    Title = "Extras",
    Values = {
        "Blessed Enchant Book","Destructive Enchant Book","Meteor Fragment","Solar Token",
        "Luck Totem","Strength Totem"
    },
    Multi = false,
    Default = 1,
    Callback = function(Value) selectedExtra = Value end
})
extraSec:AddButton({
    Title = "Buy Selected Extra",
    Callback = function() if selectedExtra then buyItem(selectedExtra) end end
})



local esptab = esp:AddSection("Totem esp")

esptab:AddToggle("LuckESP", {Title = "ESP Luck Totems", Default = false, Callback = function(val)
    espEnabled.Luck = val
end})

-- Strength ESP toggle
esptab:AddToggle("StrengthESP", {Title = "ESP Strength Totems", Default = false, Callback = function(val)
    espEnabled.Strength = val
end})
