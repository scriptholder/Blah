local scriptMappings = {
    -- [137925884276740] = "https://raw.githubusercontent.com/scriptholder/Blah/refs/heads/main/plan.lua",
    [123963759682880] = "https://raw.githubusercontent.com/scriptholder/Blah/refs/heads/main/train.lua",
    [88728793053496] = "https://raw.githubusercontent.com/scriptholder/Blah/refs/heads/main/car.lua",
    [101949297449238] = "https://raw.githubusercontent.com/scriptholder/Blah/refs/heads/main/Island.lua",
    [112279762578792] = "https://raw.githubusercontent.com/scriptholder/Blah/refs/heads/main/mine.lua",
    [129827112113663] = "https://raw.githubusercontent.com/scriptholder/Blah/refs/heads/main/pro.lua",
    [98632918083844] = "https://raw.githubusercontent.com/scriptholder/Blah/refs/heads/main/Bro.lua",
    [131603408057162] = "https://raw.githubusercontent.com/scriptholder/Blah/refs/heads/main/cage.lua",
  --  [14067600077] = "https://raw.githubusercontent.com/scriptholder/Blah/refs/heads/main/typesoul.lua",
   -- [18637069183] = "https://raw.githubusercontent.com/scriptholder/Blah/refs/heads/main/typesoul.lua",
   -- [115509275831248] = "https://raw.githubusercontent.com/scriptholder/Blah/refs/heads/main/typesoul.lua",
    [95712269457211] = "https://raw.githubusercontent.com/scriptholder/Blah/refs/heads/main/tractor.lua",
    
    
}



local currentId = game.PlaceId
local url = scriptMappings[currentId]

if url then
    print("Loading script for PlaceId:", currentId)
    local success, scriptContent = pcall(game.HttpGet, game, url)
    if success and scriptContent and scriptContent ~= "" then
        local func, loadErr = loadstring(scriptContent)
        if func then
            local runSuccess, runErr = pcall(func)
            if not runSuccess then
                warn("Error running script:", runErr)
            end
        else
            warn("Error compiling script:", loadErr)
        end
    else
        warn("Failed to fetch script from URL:", url)
    end
else
    warn("No script found for this PlaceId:", currentId)
end
