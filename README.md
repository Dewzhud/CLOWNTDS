# CLOWN TDS 

our loader just teleport you to game mode that you set and find map that correct !

copy this script

playback strat By **Aether Hub**
```
getgenv().ADS_Config = {
    Repo = "Dewzhud/CLOWNTDS",
    Branch = "main",
    BuyConfigURL     = "https://raw.githubusercontent.com/Dewzhud/CLOWNTDS/refs/heads/main/Buycfg.lua",
    FarmPollInterval = 30,  -- เช็คเงินทุก 30 วินาที (optional, default 30)

    Mode = "Easy"
}

loadstring(game:HttpGet("https://raw.githubusercontent.com/Dewzhud/CLOWNTDS/main/Loader"))()

```
# you can add same map name but different mode too!
