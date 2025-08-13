local Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/discoart/FluentPlus/refs/heads/main/alpha.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Build a Car - Dead " .. Fluent.Version,
    SubTitle = "by Dead",
    TabWidth = 160,
    Size = UDim2.fromOffset(560, 460),
    Acrylic = true,
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.LeftControl,
})

local Main = Window:AddTab({ Title = "Main", Icon = "home" })
local Shop = Window:AddTab({ Title = "Shop", Icon = "shopping-cart" })
local Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local workspace = game:GetService("Workspace")

local remotes = workspace:WaitForChild("__THINGS"):WaitForChild("__REMOTES")

local items = {
    "Slab", "Block", "Wheel", "Regular Gas Tank", "Small Engine",
    "Good Wheel", "Big Gas Tank", "Medium Engine", "Efficient Gas Tank",
    "Big Wheel", "Super Gas Tank", "Great Engine", "V10 Engine",
    "Glass Panel", "Carbon Fiber Block", "Carbon Fiber Slab", "Heavy Block"
}

local selectedItems = {}
local buySelectedToggleEnabled = false
local buyAllToggleEnabled = false

local function buyItem(itemName)
    local args = {itemName}
    pcall(function()
        remotes:WaitForChild("merchant_purchase"):InvokeServer(unpack(args))
    end)
end

local function buySelectedOnce()
    if type(selectedItems) == "string" then
        buyItem(selectedItems)
    elseif type(selectedItems) == "table" then
        for _, item in pairs(selectedItems) do
            buyItem(item)
            task.wait(0.05)
        end
    end
end

local function buyAllOnce()
    for _, item in pairs(items) do
        buyItem(item)
        task.wait(0.05)
    end
end

task.spawn(function()
    while true do
        if buySelectedToggleEnabled and #selectedItems > 0 then
            if type(selectedItems) == "string" then
                buyItem(selectedItems)
                task.wait(0.05)
            else
                for _, item in pairs(selectedItems) do
                    buyItem(item)
                    task.wait(0.05)
                    if not buySelectedToggleEnabled then break end
                end
            end
        end
        task.wait(0.1)
    end
end)

task.spawn(function()
    while true do
        if buyAllToggleEnabled then
            for _, item in pairs(items) do
                buyItem(item)
                task.wait(0.05)
                if not buyAllToggleEnabled then break end
            end
        end
        task.wait(0.1)
    end
end)

Main:AddButton({
    Title = "Get inf money",
    Description = "Spawn and stop vehicle to get infinite money",
    Callback = function()
        pcall(function()
            remotes:WaitForChild("vehicle_spawn"):InvokeServer()
        end)
        task.wait(0.5)
        pcall(function()
            remotes:WaitForChild("vehicle_stop"):InvokeServer()
        end)
    end,
})

local dropdown = Shop:AddDropdown("dropdown", {
    Title = "Select Items",
    Description = "Select items to buy",
    Multiselect = true,
    Values = items,
    Callback = function(selected)
        selectedItems = selected or {}
    end,
})

Shop:AddButton({
    Title = "Buy Selected",
    Description = "Buy selected items once",
    Callback = function()
        if #selectedItems == 0 then return end
        buySelectedOnce()
    end,
})

Shop:AddToggle("buySelectedToggleEnabled", {
    Title = "Buy Selected Toggle",
    Description = "Keep buying selected",
    Default = false,
    Callback = function(state)
        buySelectedToggleEnabled = state
    end,
})

Shop:AddToggle("buyAllToggleEnabled", {
    Title = "Buy All Toggle",
    Description = "Keep buying all items",
    Default = false,
    Callback = function(state)
        buyAllToggleEnabled = state
    end,
})

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("FluentScriptHub")
SaveManager:SetFolder("FluentScriptHub/BuildACar")
InterfaceManager:BuildInterfaceSection(Settings)
SaveManager:BuildConfigSection(Settings)

Window:SelectTab(1)

Fluent:Notify({
    Title = "Build a Car",
    Content = "Script loaded and ready.",
    Duration = 8,
})

SaveManager:LoadAutoloadConfig()
