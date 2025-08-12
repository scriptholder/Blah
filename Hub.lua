-- Table linking place IDs to their loader URLs
local scriptMappings = {
    -- Build a Plane (BLOOD MOON AUTOFARM)
    [137925884276740] = "https://raw.githubusercontent.com/scriptholder/Blah/refs/heads/main/plan.lua",
    -- Build a train
    [123963759682880] = "https://raw.githubusercontent.com/scriptholder/Blah/refs/heads/main/Train.lua",
    
}

-- Check the current PlaceId and fetch the matching script
local currentId = game.PlaceId
if scriptMappings[currentId] then
    local url = scriptMappings[currentId]
    local scriptContent = game:HttpGet(url)
    loadstring(scriptContent)()
else
    warn("No script found for this PlaceId:", currentId)
end
