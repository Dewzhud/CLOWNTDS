**CLOWN TDS WE SUPPORT AETHER HUB!**
our loader just teleport you to game mode that you set and find map that correct in ur config!

copy this script

``` getgenv().ADS_Config = {
    -- โหมดที่จะกดหาใน Lobby (Easy, Hard, Insane, Fallen, Hardcore, Voidcore, PizzaParty, Badlands, PollutedWasteland, DuckyEasy, DuckyHard, Trial)
    Mode = "Easy",
    
    -- แมพที่รองรับ: ชื่อแมพ = { Mode=โหมดที่ detect ได้, URL=strat }
    Maps = {
        ["Summer Castle"] = {
            Mode = "Easy",
            URL = "https://raw.githubusercontent.com/DuxiiT/auto-strat/refs/heads/main/Strategies/Easy.lua"
        },
        ["Pizza Party"] = {
            Mode = "Hard",
            URL = "https://raw.githubusercontent.com/DuxiiT/auto-strat/refs/heads/main/Strategies/PizzaParty.lua"
        },
        ["Badlands II"] = {
            Mode = "Hard",
            URL = "https://raw.githubusercontent.com/DuxiiT/auto-strat/refs/heads/main/Strategies/Badlands.lua"
        },
        ["Polluted Wasteland II"] = {
            Mode = "Hard",
            URL = "https://raw.githubusercontent.com/DuxiiT/auto-strat/refs/heads/main/Strategies/Polluted.lua"
        },
        ["Ducky Revenge"] = {
            Mode = "Easy",
            URL = "https://raw.githubusercontent.com/DuxiiT/auto-strat/refs/heads/main/Strategies/DuckyEasy.lua"
        },
        ["Fallen Mode"] = {
            Mode = "Fallen",
            URL = "https://raw.githubusercontent.com/DuxiiT/auto-strat/refs/heads/main/Strategies/Fallen.lua"
        },
        ["Hardcore Mode"] = {
            Mode = "Hardcore",
            URL = "https://raw.githubusercontent.com/DuxiiT/auto-strat/refs/heads/main/Strategies/Hardcore.lua"
        },
        ["Voidcore"] = {
            Mode = "Voidcore",
            URL = "https://raw.githubusercontent.com/DuxiiT/auto-strat/refs/heads/main/Strategies/Voidcore.lua"
        },
    }
}

-- ==================== LOADER ====================
loadstring(game:HttpGet("https://raw.githubusercontent.com/Dewzhud/CLOWNTDS/refs/heads/main/Loader"))()```
