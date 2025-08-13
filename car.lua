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
	Title = 'Infinite Cash',
	Description = 'Gives you infinite money ( keep clicking if it didnt work it will eventually)',
	Callback = function()
		local Players = game:GetService('Players')
		local LocalPlayer = Players.LocalPlayer
		local Character = LocalPlayer.Character
			or LocalPlayer.CharacterAdded:Wait()
		local Root = Character:WaitForChild('HumanoidRootPart')
		local Remotes = workspace
			:WaitForChild('__THINGS')
			:WaitForChild('__REMOTES')

		for _, part in ipairs(Character:GetDescendants()) do
			if part:IsA('BasePart') then
				part.Anchored = false
				part.CanCollide = true
			end
		end

		local spin = Instance.new('BodyAngularVelocity')
		spin.AngularVelocity = Vector3.new(999999, 999999, 999999)
		spin.MaxTorque = Vector3.new(1, 1, 1) * math.huge
		spin.P = math.huge
		spin.Parent = Root

		local bv = Instance.new('BodyVelocity')
		bv.Velocity = Root.CFrame.LookVector * 1500
		bv.MaxForce = Vector3.new(1, 1, 1) * 1e9
		bv.P = 1e6
		bv.Parent = Root

		print('💥 You were flung like a goddamn cannonball')

		task.delay(3, function()
			spin:Destroy()
			bv:Destroy()
		end)

		task.delay(1, function()
			local spawnRemote = Remotes:WaitForChild('vehicle_spawn')
			local success = pcall(function()
				spawnRemote:InvokeServer()
			end)
			print(
				success and '🚗 Vehicle spawn fired'
					or '❌ Failed to fire vehicle_spawn'
			)
		end)

		task.delay(11, function()
			local stopRemote = Remotes:WaitForChild('vehicle_stop')
			local success = pcall(function()
				stopRemote:InvokeServer()
			end)
			print(
				success and '🛑 Vehicle stop fired'
					or '❌ Failed to fire vehicle_stop'
			)
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
