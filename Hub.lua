local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Hub",
    LoadingTitle = "Hub",
    LoadingSubtitle = "MM2",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

local MainTab = Window:CreateTab("Main", 4483362458)
local GunTab = Window:CreateTab("Gun", 4483362458)
local VisualTab = Window:CreateTab("Visuals", 4483362458)
local SkyTab = Window:CreateTab("SkyBox", 4483362458)
local ShaderTab = Window:CreateTab("Shaders", 4483362458)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer

local WalkSpeedValue = 16
local JumpPowerValue = 50
local InfJump = false
local SpeedGlitch = false
local SpeedGlitchValue = 50

local AutoGrab = false
local GunNotify = false
local SuccessNotify = false
local isGrabbing = false

local root, humanoid

local function notify(title, content)
    Rayfield:Notify({
        Title = title,
        Content = content,
        Duration = 3
    })
end

local function hasGun()
    local char = LocalPlayer.Character
    return LocalPlayer.Backpack:FindFirstChild("Gun") or (char and char:FindFirstChild("Gun"))
end

local function GrabGun()
    if isGrabbing or hasGun() then return end
    isGrabbing = true

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        isGrabbing = false
        return
    end

    for i = 1, 40 do
        if hasGun() then break end
        local drop = Workspace:FindFirstChild("GunDrop", true)
        if drop then
            pcall(function()
                local target = hrp.CFrame * CFrame.new(0, 1.2, 0)
                if drop:IsA("BasePart") then
                    drop.Anchored = false
                    drop.CanCollide = false
                    drop.CFrame = target
                else
                    local part = drop:FindFirstChild("Handle") or drop:FindFirstChildWhichIsA("BasePart") or drop.PrimaryPart
                    if part then
                        part.Anchored = false
                        part.CanCollide = false
                        part.CFrame = target
                    end
                end
            end)
        end
        task.wait(0.03)
    end

    if hasGun() and SuccessNotify then
        notify("GrabGun", "Пистолет взят")
    end
    isGrabbing = false
end

Workspace.DescendantAdded:Connect(function(obj)
    if obj.Name == "GunDrop" then
        task.wait(0.1)
        if GunNotify then
            notify("Gun Drop", "Пистолет выпал")
        end
        if AutoGrab then
            task.spawn(GrabGun)
        end
    end
end)

local function applyMovement(char)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = WalkSpeedValue
        hum.JumpPower = JumpPowerValue
        hum.UseJumpPower = true
    end
end

LocalPlayer.CharacterAdded:Connect(function(char)
    root = char:WaitForChild("HumanoidRootPart", 2)
    humanoid = char:WaitForChild("Humanoid", 2)
    task.wait(0.3)
    applyMovement(char)
end)

if LocalPlayer.Character then
    root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    applyMovement(LocalPlayer.Character)
end

UserInputService.JumpRequest:Connect(function()
    if not InfJump then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

RunService.Heartbeat:Connect(function()
    if SpeedGlitch and root and humanoid and humanoid.FloorMaterial == Enum.Material.Air then
        local dir = humanoid.MoveDirection
        if dir.Magnitude > 0.05 then
            local vel = root.AssemblyLinearVelocity
            root.AssemblyLinearVelocity = Vector3.new(dir.X * SpeedGlitchValue, vel.Y, dir.Z * SpeedGlitchValue)
        end
    end
end)

local PARTICLE_AURA_DATA = {
    { "starlight", "rbxassetid://134645216613107" },
    { "heavenly", "rbxassetid://139300897520961" },
    { "ribbon", "rbxassetid://132069507632161" },
    { "sakura", "rbxassetid://81755778619404" },
    { "angel", "rbxassetid://97658130917593" },
    { "wind", "rbxassetid://80694081850877" },
    { "flow", "rbxassetid://119913533725648" },
    { "star", "rbxassetid://73754563740680" },
    { "neon", "rbxassetid://18498709246" },
}

local PARTICLE_AURA_NAMES = {}
local particleAuraIdByName = {}

for _, row in ipairs(PARTICLE_AURA_DATA) do
    table.insert(PARTICLE_AURA_NAMES, row[1])
    particleAuraIdByName[row[1]] = row[2]
end

local loadedParticleAuras = {}
local selfAuraParticles = {}
local SelfAuraEnabled = false
local SelfAuraType = "starlight"
local SelfAuraColor = Color3.fromRGB(133, 220, 255)

local function mapCharacterParts(character)
    local parts = {}
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("BasePart") then
            parts[child.Name] = child
        end
    end
    return parts
end

local function getParticleAuraTemplate(name)
    local cached = loadedParticleAuras[name]
    if cached then return cached end
    local id = particleAuraIdByName[name]
    if not id then return nil end
    local ok, result = pcall(function()
        return game:GetObjects(id)[1]
    end)
    if ok and result then
        loadedParticleAuras[name] = result
        return result
    end
    return nil
end

local function clearSelfAura()
    for _, p in ipairs(selfAuraParticles) do
        if p then p:Destroy() end
    end
    table.clear(selfAuraParticles)
end

local function tintParticleSubtree(rootObj, color)
    if not color or not rootObj then return end
    local seq = ColorSequence.new(color)
    local function tintOne(obj)
        if obj:IsA("ParticleEmitter") or obj:IsA("Beam") or obj:IsA("Trail") then
            obj.Color = seq
        elseif obj:IsA("PointLight") then
            obj.Color = color
        end
    end
    tintOne(rootObj)
    for _, d in ipairs(rootObj:GetDescendants()) do
        tintOne(d)
    end
end

local function setParticleEmittersEnabledInSubtree(rootObj, enabled)
    if not rootObj then return end
    if rootObj:IsA("ParticleEmitter") then
        rootObj.Enabled = enabled
    end
    for _, d in ipairs(rootObj:GetDescendants()) do
        if d:IsA("ParticleEmitter") then
            d.Enabled = enabled
        end
    end
end

local function applyParticleAuraToCharacter(character, auraName, color, isPersistent)
    local auraObj = getParticleAuraTemplate(auraName)
    if not auraObj then return {} end

    local localParts = mapCharacterParts(character)
    local cloned = auraObj:Clone()
    local created = {}

    for _, part in ipairs(cloned:GetChildren()) do
        local targetPart = localParts[part.Name]
        if targetPart then
            for _, child in ipairs(part:GetChildren()) do
                local inst = child:Clone()
                inst.Name = "LarpticAuraParticle"
                inst.Parent = targetPart
                if color then
                    tintParticleSubtree(inst, color)
                end
                table.insert(created, inst)
            end
        end
    end
    cloned:Destroy()

    for _, p in ipairs(created) do
        setParticleEmittersEnabledInSubtree(p, true)
    end

    return created
end

local function refreshSelfAura()
    clearSelfAura()
    if not SelfAuraEnabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    if not particleAuraIdByName[SelfAuraType] then return end
    selfAuraParticles = applyParticleAuraToCharacter(char, SelfAuraType, SelfAuraColor, true)
end

LocalPlayer.CharacterAdded:Connect(function()
    if SelfAuraEnabled then
        task.delay(0.75, refreshSelfAura)
    end
end)

local SkyboxAssets = {
    ["Black Storm"] = {
        Bk = "rbxassetid://15502511288", Dn = "rbxassetid://15502508460", Ft = "rbxassetid://15502510289",
        Lf = "rbxassetid://15502507918", Rt = "rbxassetid://15502509398", Up = "rbxassetid://15502511911",
    },
    HD = {
        Bk = "http://www.roblox.com/asset/?id=16553658937", Dn = "http://www.roblox.com/asset/?id=16553660713",
        Ft = "http://www.roblox.com/asset/?id=16553662144", Lf = "http://www.roblox.com/asset/?id=16553664042",
        Rt = "http://www.roblox.com/asset/?id=16553665766", Up = "http://www.roblox.com/asset/?id=16553667750",
    },
    Snow = {
        Bk = "http://www.roblox.com/asset/?id=155657655", Dn = "http://www.roblox.com/asset/?id=155674246",
        Ft = "http://www.roblox.com/asset/?id=155657609", Lf = "http://www.roblox.com/asset/?id=155657671",
        Rt = "http://www.roblox.com/asset/?id=155657619", Up = "http://www.roblox.com/asset/?id=155674931",
    },
    ["Blue Space"] = {
        Bk = "rbxassetid://15536110634", Dn = "rbxassetid://15536112543", Ft = "rbxassetid://15536116141",
        Lf = "rbxassetid://15536114370", Rt = "rbxassetid://15536118762", Up = "rbxassetid://15536117282",
    },
    Realistic = {
        Bk = "rbxassetid://653719502", Dn = "rbxassetid://653718790", Ft = "rbxassetid://653719067",
        Lf = "rbxassetid://653719190", Rt = "rbxassetid://653718931", Up = "rbxassetid://653719321",
    },
    Stormy = {
        Bk = "http://www.roblox.com/asset/?id=18703245834", Dn = "http://www.roblox.com/asset/?id=18703243349",
        Ft = "http://www.roblox.com/asset/?id=18703240532", Lf = "http://www.roblox.com/asset/?id=18703237556",
        Rt = "http://www.roblox.com/asset/?id=18703235430", Up = "http://www.roblox.com/asset/?id=18703232671",
    },
    Pink = {
        Bk = "rbxassetid://12216109205", Dn = "rbxassetid://12216109875", Ft = "rbxassetid://12216109489",
        Lf = "rbxassetid://12216110170", Rt = "rbxassetid://12216110471", Up = "rbxassetid://12216108877",
    },
    Sunset = {
        Bk = "rbxassetid://600830446", Dn = "rbxassetid://600831635", Ft = "rbxassetid://600832720",
        Lf = "rbxassetid://600886090", Rt = "rbxassetid://600833862", Up = "rbxassetid://600835177",
    },
    Arctic = {
        Bk = "http://www.roblox.com/asset/?id=225469390", Dn = "http://www.roblox.com/asset/?id=225469395",
        Ft = "http://www.roblox.com/asset/?id=225469403", Lf = "http://www.roblox.com/asset/?id=225469450",
        Rt = "http://www.roblox.com/asset/?id=225469471", Up = "http://www.roblox.com/asset/?id=225469481",
    },
    Space = {
        Bk = "http://www.roblox.com/asset/?id=166509999", Dn = "http://www.roblox.com/asset/?id=166510057",
        Ft = "http://www.roblox.com/asset/?id=166510116", Lf = "http://www.roblox.com/asset/?id=166510092",
        Rt = "http://www.roblox.com/asset/?id=166510131", Up = "http://www.roblox.com/asset/?id=166510114",
    },
    ["Roblox Default"] = {
        Bk = "rbxasset://textures/sky/sky512_bk.tex", Dn = "rbxasset://textures/sky/sky512_dn.tex",
        Ft = "rbxasset://textures/sky/sky512_ft.tex", Lf = "rbxasset://textures/sky/sky512_lf.tex",
        Rt = "rbxasset://textures/sky/sky512_rt.tex", Up = "rbxasset://textures/sky/sky512_up.tex",
    },
    ["Red Night"] = {
        Bk = "http://www.roblox.com/asset/?id=401664839", Dn = "http://www.roblox.com/asset/?id=401664862",
        Ft = "http://www.roblox.com/asset/?id=401664960", Lf = "http://www.roblox.com/asset/?id=401664881",
        Rt = "http://www.roblox.com/asset/?id=401664901", Up = "http://www.roblox.com/asset/?id=401664936",
    },
    ["Deep Space 1"] = {
        Bk = "http://www.roblox.com/asset/?id=149397692", Dn = "http://www.roblox.com/asset/?id=149397686",
        Ft = "http://www.roblox.com/asset/?id=149397697", Lf = "http://www.roblox.com/asset/?id=149397684",
        Rt = "http://www.roblox.com/asset/?id=149397688", Up = "http://www.roblox.com/asset/?id=149397702",
    },
    ["Pink Skies"] = {
        Bk = "http://www.roblox.com/asset/?id=151165214", Dn = "http://www.roblox.com/asset/?id=151165197",
        Ft = "http://www.roblox.com/asset/?id=151165224", Lf = "http://www.roblox.com/asset/?id=151165191",
        Rt = "http://www.roblox.com/asset/?id=151165206", Up = "http://www.roblox.com/asset/?id=151165227",
    },
    ["Purple Sunset"] = {
        Bk = "rbxassetid://264908339", Dn = "rbxassetid://264907909", Ft = "rbxassetid://264909420",
        Lf = "rbxassetid://264909758", Rt = "rbxassetid://264908886", Up = "rbxassetid://264907379",
    },
    ["Blue Night"] = {
        Bk = "http://www.roblox.com/asset/?id=12064107", Dn = "http://www.roblox.com/asset/?id=12064152",
        Ft = "http://www.roblox.com/asset/?id=12064121", Lf = "http://www.roblox.com/asset/?id=12063984",
        Rt = "http://www.roblox.com/asset/?id=12064115", Up = "http://www.roblox.com/asset/?id=12064131",
    },
    ["Blossom Daylight"] = {
        Bk = "http://www.roblox.com/asset/?id=271042516", Dn = "http://www.roblox.com/asset/?id=271077243",
        Ft = "http://www.roblox.com/asset/?id=271042556", Lf = "http://www.roblox.com/asset/?id=271042310",
        Rt = "http://www.roblox.com/asset/?id=271042467", Up = "http://www.roblox.com/asset/?id=271077958",
    },
    ["Blue Nebula"] = {
        Bk = "http://www.roblox.com/asset?id=135207744", Dn = "http://www.roblox.com/asset?id=135207662",
        Ft = "http://www.roblox.com/asset?id=135207770", Lf = "http://www.roblox.com/asset?id=135207615",
        Rt = "http://www.roblox.com/asset?id=135207695", Up = "http://www.roblox.com/asset?id=135207794",
    },
    ["Blue Planet"] = {
        Bk = "rbxassetid://218955819", Dn = "rbxassetid://218953419", Ft = "rbxassetid://218954524",
        Lf = "rbxassetid://218958493", Rt = "rbxassetid://218957134", Up = "rbxassetid://218950090",
    },
    ["Deep Space 2"] = {
        Bk = "http://www.roblox.com/asset/?id=159248188", Dn = "http://www.roblox.com/asset/?id=159248183",
        Ft = "http://www.roblox.com/asset/?id=159248187", Lf = "http://www.roblox.com/asset/?id=159248173",
        Rt = "http://www.roblox.com/asset/?id=159248192", Up = "http://www.roblox.com/asset/?id=159248176",
    },
    Summer = {
        Bk = "rbxassetid://16648590964", Dn = "rbxassetid://16648617436", Ft = "rbxassetid://16648595424",
        Lf = "rbxassetid://16648566370", Rt = "rbxassetid://16648577071", Up = "rbxassetid://16648598180",
    },
    Galaxy = {
        Bk = "rbxassetid://15983968922", Dn = "rbxassetid://15983966825", Ft = "rbxassetid://15983965025",
        Lf = "rbxassetid://15983967420", Rt = "rbxassetid://15983966246", Up = "rbxassetid://15983964246",
    },
    Stylized = {
        Bk = "rbxassetid://18351376859", Dn = "rbxassetid://18351374919", Ft = "rbxassetid://18351376800",
        Lf = "rbxassetid://18351376469", Rt = "rbxassetid://18351376457", Up = "rbxassetid://18351377189",
    },
    Minecraft = {
        Bk = "rbxassetid://8735166756", Dn = "http://www.roblox.com/asset/?id=8735166707",
        Ft = "http://www.roblox.com/asset/?id=8735231668", Lf = "http://www.roblox.com/asset/?id=8735166755",
        Rt = "http://www.roblox.com/asset/?id=8735166751", Up = "http://www.roblox.com/asset/?id=8735166729",
    },
    ["Cloudy Rain"] = {
        Bk = "http://www.roblox.com/asset/?id=4498828382", Dn = "http://www.roblox.com/asset/?id=4498828812",
        Ft = "http://www.roblox.com/asset/?id=4498829917", Lf = "http://www.roblox.com/asset/?id=4498830911",
        Rt = "http://www.roblox.com/asset/?id=4498830417", Up = "http://www.roblox.com/asset/?id=4498831746",
    },
    ["Black Cloudy Rain"] = {
        Bk = "http://www.roblox.com/asset/?id=149679669", Dn = "http://www.roblox.com/asset/?id=149681979",
        Ft = "http://www.roblox.com/asset/?id=149679690", Lf = "http://www.roblox.com/asset/?id=149679709",
        Rt = "http://www.roblox.com/asset/?id=149679722", Up = "http://www.roblox.com/asset/?id=149680199",
    },
}

local DefaultSky = Lighting:FindFirstChildOfClass("Sky")
local DefaultSkySettings = {}
if DefaultSky then
    DefaultSkySettings.SkyboxBk = DefaultSky.SkyboxBk
    DefaultSkySettings.SkyboxDn = DefaultSky.SkyboxDn
    DefaultSkySettings.SkyboxFt = DefaultSky.SkyboxFt
    DefaultSkySettings.SkyboxLf = DefaultSky.SkyboxLf
    DefaultSkySettings.SkyboxRt = DefaultSky.SkyboxRt
    DefaultSkySettings.SkyboxUp = DefaultSky.SkyboxUp
end

local SkyboxEnabled = false
local CurrentSkybox = "HD"
local skyboxList = {}
for name in pairs(SkyboxAssets) do
    table.insert(skyboxList, name)
end
table.sort(skyboxList)

local function Skybox_Apply(name)
    local data = SkyboxAssets[name]
    if not data then return end
    local sky = Lighting:FindFirstChildOfClass("Sky")
    if not sky then
        sky = Instance.new("Sky")
        sky.Parent = Lighting
    end
    sky.SkyboxBk = data.Bk
    sky.SkyboxDn = data.Dn
    sky.SkyboxFt = data.Ft
    sky.SkyboxLf = data.Lf
    sky.SkyboxRt = data.Rt
    sky.SkyboxUp = data.Up
end

local function Skybox_RestoreDefault()
    local sky = Lighting:FindFirstChildOfClass("Sky")
    if sky and DefaultSkySettings.SkyboxBk then
        sky.SkyboxBk = DefaultSkySettings.SkyboxBk
        sky.SkyboxDn = DefaultSkySettings.SkyboxDn
        sky.SkyboxFt = DefaultSkySettings.SkyboxFt
        sky.SkyboxLf = DefaultSkySettings.SkyboxLf
        sky.SkyboxRt = DefaultSkySettings.SkyboxRt
        sky.SkyboxUp = DefaultSkySettings.SkyboxUp
    elseif sky then
        sky:Destroy()
    end
end

local defaultLighting = {
    ClockTime = Lighting.ClockTime,
    Brightness = Lighting.Brightness,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    ColorShift_Top = Lighting.ColorShift_Top,
    ColorShift_Bottom = Lighting.ColorShift_Bottom,
    EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
    EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
    GlobalShadows = Lighting.GlobalShadows,
    ExposureCompensation = Lighting.ExposureCompensation,
    FogStart = Lighting.FogStart,
    FogEnd = Lighting.FogEnd,
    FogColor = Lighting.FogColor,
    GeographicLatitude = Lighting.GeographicLatitude,
}

local function getOrCreate(className, name)
    local obj = Lighting:FindFirstChild(name)
    if obj and obj:IsA(className) then return obj end
    obj = Instance.new(className)
    obj.Name = name
    obj.Parent = Lighting
    return obj
end

local function applyShaderPreset(preset)
    Lighting.ClockTime = preset.ClockTime or 12
    Lighting.Brightness = preset.Brightness or 2
    Lighting.Ambient = preset.Ambient or Color3.fromRGB(100, 100, 100)
    Lighting.OutdoorAmbient = preset.OutdoorAmbient or Color3.fromRGB(128, 128, 128)
    Lighting.ColorShift_Top = preset.ColorShift_Top or Color3.new(0, 0, 0)
    Lighting.ColorShift_Bottom = preset.ColorShift_Bottom or Color3.new(0, 0, 0)
    Lighting.EnvironmentDiffuseScale = preset.EnvironmentDiffuseScale or 1
    Lighting.EnvironmentSpecularScale = preset.EnvironmentSpecularScale or 1
    Lighting.GlobalShadows = preset.GlobalShadows ~= false
    Lighting.ExposureCompensation = preset.ExposureCompensation or 0
    Lighting.FogStart = preset.FogStart or 0
    Lighting.FogEnd = preset.FogEnd or 100000
    Lighting.FogColor = preset.FogColor or Color3.fromRGB(192, 192, 192)
    Lighting.GeographicLatitude = preset.GeographicLatitude or 41.7

    local cc = getOrCreate("ColorCorrectionEffect", "HubCC")
    cc.Enabled = true
    cc.Brightness = preset.CC_Brightness or 0
    cc.Contrast = preset.CC_Contrast or 0
    cc.Saturation = preset.CC_Saturation or 0
    cc.TintColor = preset.CC_Tint or Color3.new(1, 1, 1)

    local bloom = getOrCreate("BloomEffect", "HubBloom")
    bloom.Enabled = true
    bloom.Intensity = preset.BloomIntensity or 0.4
    bloom.Size = preset.BloomSize or 24
    bloom.Threshold = preset.BloomThreshold or 0.95

    local blur = getOrCreate("BlurEffect", "HubBlur")
    blur.Enabled = preset.BlurSize and preset.BlurSize > 0
    blur.Size = preset.BlurSize or 0

    local atm = getOrCreate("Atmosphere", "HubAtm")
    atm.Density = preset.AtmDensity or 0.3
    atm.Offset = preset.AtmOffset or 0
    atm.Color = preset.AtmColor or Color3.fromRGB(199, 212, 255)
    atm.Decay = preset.AtmDecay or Color3.fromRGB(106, 112, 125)
    atm.Glare = preset.AtmGlare or 0
    atm.Haze = preset.AtmHaze or 0

    local sun = getOrCreate("SunRaysEffect", "HubSunRays")
    sun.Enabled = preset.SunRays ~= false
    sun.Intensity = preset.SunIntensity or 0.1
    sun.Spread = preset.SunSpread or 0.5
end

local function resetShader()
    Lighting.ClockTime = defaultLighting.ClockTime
    Lighting.Brightness = defaultLighting.Brightness
    Lighting.Ambient = defaultLighting.Ambient
    Lighting.OutdoorAmbient = defaultLighting.OutdoorAmbient
    Lighting.ColorShift_Top = defaultLighting.ColorShift_Top
    Lighting.ColorShift_Bottom = defaultLighting.ColorShift_Bottom
    Lighting.EnvironmentDiffuseScale = defaultLighting.EnvironmentDiffuseScale
    Lighting.EnvironmentSpecularScale = defaultLighting.EnvironmentSpecularScale
    Lighting.GlobalShadows = defaultLighting.GlobalShadows
    Lighting.ExposureCompensation = defaultLighting.ExposureCompensation
    Lighting.FogStart = defaultLighting.FogStart
    Lighting.FogEnd = defaultLighting.FogEnd
    Lighting.FogColor = defaultLighting.FogColor
    Lighting.GeographicLatitude = defaultLighting.GeographicLatitude

    for _, name in ipairs({"HubCC", "HubBloom", "HubBlur", "HubAtm", "HubSunRays"}) do
        local obj = Lighting:FindFirstChild(name)
        if obj then obj:Destroy() end
    end
end

local ShaderPresets = {
    Morning = {
        ClockTime = 7.5, Brightness = 2.2, Ambient = Color3.fromRGB(160, 140, 120),
        OutdoorAmbient = Color3.fromRGB(180, 160, 140), ColorShift_Top = Color3.fromRGB(255, 200, 150),
        ExposureCompensation = 0.1, FogStart = 50, FogEnd = 2000, FogColor = Color3.fromRGB(255, 220, 180),
        CC_Brightness = 0.05, CC_Contrast = 0.05, CC_Saturation = 0.1, CC_Tint = Color3.fromRGB(255, 245, 230),
        BloomIntensity = 0.5, BloomSize = 28, BloomThreshold = 0.9,
        AtmDensity = 0.25, AtmColor = Color3.fromRGB(255, 220, 180), AtmDecay = Color3.fromRGB(200, 160, 120),
        AtmGlare = 0.3, AtmHaze = 1, SunRays = true, SunIntensity = 0.15,
    },
    Midday = {
        ClockTime = 12, Brightness = 3, Ambient = Color3.fromRGB(140, 140, 150),
        OutdoorAmbient = Color3.fromRGB(180, 180, 190), ColorShift_Top = Color3.fromRGB(255, 255, 240),
        ExposureCompensation = 0, FogStart = 0, FogEnd = 100000, FogColor = Color3.fromRGB(192, 192, 192),
        CC_Brightness = 0, CC_Contrast = 0.1, CC_Saturation = 0.05, CC_Tint = Color3.new(1, 1, 1),
        BloomIntensity = 0.6, BloomSize = 24, BloomThreshold = 0.95,
        AtmDensity = 0.2, AtmColor = Color3.fromRGB(200, 220, 255), AtmDecay = Color3.fromRGB(120, 140, 180),
        AtmGlare = 0.5, AtmHaze = 0.5, SunRays = true, SunIntensity = 0.25,
    },
    Afternoon = {
        ClockTime = 16, Brightness = 2.5, Ambient = Color3.fromRGB(150, 130, 110),
        OutdoorAmbient = Color3.fromRGB(170, 150, 130), ColorShift_Top = Color3.fromRGB(255, 180, 120),
        ExposureCompensation = 0.05, FogStart = 80, FogEnd = 2500, FogColor = Color3.fromRGB(255, 200, 150),
        CC_Brightness = 0.02, CC_Contrast = 0.08, CC_Saturation = 0.12, CC_Tint = Color3.fromRGB(255, 240, 220),
        BloomIntensity = 0.55, BloomSize = 26, BloomThreshold = 0.92,
        AtmDensity = 0.28, AtmColor = Color3.fromRGB(255, 200, 150), AtmDecay = Color3.fromRGB(180, 140, 100),
        AtmGlare = 0.4, AtmHaze = 1.2, SunRays = true, SunIntensity = 0.2,
    },
    Evening = {
        ClockTime = 18.5, Brightness = 1.5, Ambient = Color3.fromRGB(100, 70, 60),
        OutdoorAmbient = Color3.fromRGB(120, 80, 70), ColorShift_Top = Color3.fromRGB(255, 120, 60),
        ExposureCompensation = -0.1, FogStart = 30, FogEnd = 1500, FogColor = Color3.fromRGB(200, 100, 60),
        CC_Brightness = -0.05, CC_Contrast = 0.15, CC_Saturation = 0.2, CC_Tint = Color3.fromRGB(255, 200, 170),
        BloomIntensity = 0.7, BloomSize = 32, BloomThreshold = 0.85,
        AtmDensity = 0.4, AtmColor = Color3.fromRGB(255, 150, 80), AtmDecay = Color3.fromRGB(150, 80, 50),
        AtmGlare = 0.8, AtmHaze = 2, SunRays = true, SunIntensity = 0.3,
    },
    Night = {
        ClockTime = 21, Brightness = 0.8, Ambient = Color3.fromRGB(40, 50, 80),
        OutdoorAmbient = Color3.fromRGB(30, 40, 70), ColorShift_Top = Color3.fromRGB(60, 80, 150),
        ExposureCompensation = -0.3, FogStart = 20, FogEnd = 800, FogColor = Color3.fromRGB(30, 40, 70),
        CC_Brightness = -0.1, CC_Contrast = 0.1, CC_Saturation = -0.1, CC_Tint = Color3.fromRGB(180, 200, 255),
        BloomIntensity = 0.3, BloomSize = 20, BloomThreshold = 1,
        AtmDensity = 0.35, AtmColor = Color3.fromRGB(40, 60, 120), AtmDecay = Color3.fromRGB(20, 30, 60),
        AtmGlare = 0.1, AtmHaze = 1.5, SunRays = false,
    },
    Midnight = {
        ClockTime = 0, Brightness = 0.4, Ambient = Color3.fromRGB(20, 25, 40),
        OutdoorAmbient = Color3.fromRGB(15, 20, 35), ColorShift_Top = Color3.fromRGB(30, 40, 80),
        ExposureCompensation = -0.5, FogStart = 10, FogEnd = 500, FogColor = Color3.fromRGB(15, 20, 40),
        CC_Brightness = -0.15, CC_Contrast = 0.05, CC_Saturation = -0.2, CC_Tint = Color3.fromRGB(150, 170, 220),
        BloomIntensity = 0.2, BloomSize = 16, BloomThreshold = 1.1,
        AtmDensity = 0.45, AtmColor = Color3.fromRGB(20, 30, 60), AtmDecay = Color3.fromRGB(10, 15, 30),
        AtmGlare = 0, AtmHaze = 2, SunRays = false,
    },
    Rain = {
        ClockTime = 14, Brightness = 1.2, Ambient = Color3.fromRGB(90, 100, 110),
        OutdoorAmbient = Color3.fromRGB(80, 90, 100), ExposureCompensation = -0.2,
        FogStart = 10, FogEnd = 400, FogColor = Color3.fromRGB(100, 110, 120),
        CC_Brightness = -0.05, CC_Contrast = 0.05, CC_Saturation = -0.15, CC_Tint = Color3.fromRGB(200, 210, 220),
        BloomIntensity = 0.25, AtmDensity = 0.55, AtmColor = Color3.fromRGB(120, 130, 140),
        AtmDecay = Color3.fromRGB(80, 90, 100), AtmHaze = 3, BlurSize = 2, SunRays = false,
    },
    Snow = {
        ClockTime = 12, Brightness = 2.5, Ambient = Color3.fromRGB(200, 210, 220),
        OutdoorAmbient = Color3.fromRGB(220, 230, 240), ExposureCompensation = 0.2,
        FogStart = 30, FogEnd = 600, FogColor = Color3.fromRGB(220, 230, 240),
        CC_Brightness = 0.1, CC_Contrast = 0.05, CC_Saturation = -0.05, CC_Tint = Color3.fromRGB(240, 245, 255),
        BloomIntensity = 0.4, AtmDensity = 0.4, AtmColor = Color3.fromRGB(230, 240, 255),
        AtmDecay = Color3.fromRGB(180, 190, 210), AtmHaze = 2, SunRays = true, SunIntensity = 0.1,
    },
    Fog = {
        ClockTime = 10, Brightness = 1, Ambient = Color3.fromRGB(120, 120, 130),
        OutdoorAmbient = Color3.fromRGB(110, 110, 120), ExposureCompensation = -0.15,
        FogStart = 5, FogEnd = 150, FogColor = Color3.fromRGB(160, 165, 170),
        CC_Brightness = 0, CC_Contrast = -0.05, CC_Saturation = -0.2, CC_Tint = Color3.fromRGB(210, 215, 220),
        BloomIntensity = 0.2, AtmDensity = 0.7, AtmColor = Color3.fromRGB(180, 185, 190),
        AtmDecay = Color3.fromRGB(140, 145, 150), AtmHaze = 5, BlurSize = 3, SunRays = false,
    },
    Storm = {
        ClockTime = 15, Brightness = 0.7, Ambient = Color3.fromRGB(50, 55, 70),
        OutdoorAmbient = Color3.fromRGB(40, 45, 60), ExposureCompensation = -0.4,
        FogStart = 5, FogEnd = 300, FogColor = Color3.fromRGB(40, 45, 55),
        CC_Brightness = -0.1, CC_Contrast = 0.2, CC_Saturation = -0.25, CC_Tint = Color3.fromRGB(160, 170, 200),
        BloomIntensity = 0.15, AtmDensity = 0.6, AtmColor = Color3.fromRGB(50, 60, 80),
        AtmDecay = Color3.fromRGB(30, 35, 50), AtmHaze = 4, BlurSize = 2, SunRays = false,
    },
    Sunny = {
        ClockTime = 13, Brightness = 3.5, Ambient = Color3.fromRGB(160, 160, 150),
        OutdoorAmbient = Color3.fromRGB(200, 200, 190), ColorShift_Top = Color3.fromRGB(255, 255, 220),
        ExposureCompensation = 0.15, FogStart = 0, FogEnd = 100000,
        CC_Brightness = 0.05, CC_Contrast = 0.15, CC_Saturation = 0.15, CC_Tint = Color3.fromRGB(255, 255, 240),
        BloomIntensity = 0.8, BloomSize = 30, BloomThreshold = 0.9,
        AtmDensity = 0.15, AtmColor = Color3.fromRGB(220, 230, 255), AtmGlare = 1, AtmHaze = 0.3,
        SunRays = true, SunIntensity = 0.35,
    },
    Red = {
        ClockTime = 12, Brightness = 2, Ambient = Color3.fromRGB(80, 30, 30),
        OutdoorAmbient = Color3.fromRGB(100, 40, 40), CC_Tint = Color3.fromRGB(255, 120, 120),
        CC_Saturation = 0.3, CC_Contrast = 0.1, BloomIntensity = 0.5,
        AtmColor = Color3.fromRGB(200, 50, 50), AtmDecay = Color3.fromRGB(100, 20, 20), AtmDensity = 0.35,
    },
    Blue = {
        ClockTime = 12, Brightness = 2, Ambient = Color3.fromRGB(30, 40, 80),
        OutdoorAmbient = Color3.fromRGB(40, 50, 100), CC_Tint = Color3.fromRGB(150, 180, 255),
        CC_Saturation = 0.2, BloomIntensity = 0.5,
        AtmColor = Color3.fromRGB(80, 120, 220), AtmDecay = Color3.fromRGB(30, 50, 120), AtmDensity = 0.35,
    },
    Green = {
        ClockTime = 12, Brightness = 2, Ambient = Color3.fromRGB(30, 70, 40),
        OutdoorAmbient = Color3.fromRGB(40, 90, 50), CC_Tint = Color3.fromRGB(150, 255, 170),
        CC_Saturation = 0.25, BloomIntensity = 0.5,
        AtmColor = Color3.fromRGB(80, 200, 100), AtmDecay = Color3.fromRGB(30, 100, 50), AtmDensity = 0.35,
    },
    Purple = {
        ClockTime = 12, Brightness = 2, Ambient = Color3.fromRGB(50, 30, 80),
        OutdoorAmbient = Color3.fromRGB(70, 40, 100), CC_Tint = Color3.fromRGB(200, 150, 255),
        CC_Saturation = 0.25, BloomIntensity = 0.5,
        AtmColor = Color3.fromRGB(150, 80, 220), AtmDecay = Color3.fromRGB(70, 30, 120), AtmDensity = 0.35,
    },
    Pink = {
        ClockTime = 12, Brightness = 2, Ambient = Color3.fromRGB(80, 40, 60),
        OutdoorAmbient = Color3.fromRGB(100, 50, 80), CC_Tint = Color3.fromRGB(255, 180, 220),
        CC_Saturation = 0.3, BloomIntensity = 0.5,
        AtmColor = Color3.fromRGB(255, 150, 200), AtmDecay = Color3.fromRGB(150, 70, 110), AtmDensity = 0.35,
    },
}

MainTab:CreateSlider({
    Name = "WalkSpeed",
    Range = {16, 100},
    Increment = 1,
    CurrentValue = 16,
    Flag = "WalkSpeed",
    Callback = function(v)
        WalkSpeedValue = v
        if humanoid then humanoid.WalkSpeed = v end
    end
})

MainTab:CreateSlider({
    Name = "JumpPower",
    Range = {50, 200},
    Increment = 1,
    CurrentValue = 50,
    Flag = "JumpPower",
    Callback = function(v)
        JumpPowerValue = v
        if humanoid then
            humanoid.JumpPower = v
            humanoid.UseJumpPower = true
        end
    end
})

MainTab:CreateToggle({
    Name = "Infinite Jump",
    CurrentValue = false,
    Flag = "InfJump",
    Callback = function(v) InfJump = v end
})

MainTab:CreateToggle({
    Name = "Speed Glitch",
    CurrentValue = false,
    Flag = "SpeedGlitch",
    Callback = function(v) SpeedGlitch = v end
})

MainTab:CreateSlider({
    Name = "Speed Glitch Value",
    Range = {20, 120},
    Increment = 1,
    CurrentValue = 50,
    Flag = "SpeedGlitchValue",
    Callback = function(v) SpeedGlitchValue = v end
})

GunTab:CreateToggle({
    Name = "Auto Grab Gun",
    CurrentValue = false,
    Flag = "AutoGrab",
    Callback = function(v)
        AutoGrab = v
        if v and Workspace:FindFirstChild("GunDrop", true) and not hasGun() then
            task.spawn(GrabGun)
        end
    end
})

GunTab:CreateToggle({
    Name = "Gun Notify",
    CurrentValue = false,
    Flag = "GunNotify",
    Callback = function(v) GunNotify = v end
})

GunTab:CreateToggle({
    Name = "Success Notify",
    CurrentValue = false,
    Flag = "SuccessNotify",
    Callback = function(v) SuccessNotify = v end
})

GunTab:CreateButton({
    Name = "Grab Gun",
    Callback = function()
        task.spawn(GrabGun)
    end
})

GunTab:CreateButton({
    Name = "Status",
    Callback = function()
        local has = hasGun()
        local drop = Workspace:FindFirstChild("GunDrop", true)
        notify("Status", has and "Gun в инвентаре" or (drop and "GunDrop на карте" or "Нет пистолета"))
    end
})

VisualTab:CreateToggle({
    Name = "Self Aura",
    CurrentValue = false,
    Flag = "SelfAura",
    Callback = function(v)
        SelfAuraEnabled = v
        if v then refreshSelfAura() else clearSelfAura() end
    end
})

VisualTab:CreateDropdown({
    Name = "Aura Type",
    Options = PARTICLE_AURA_NAMES,
    CurrentOption = {"starlight"},
    Flag = "AuraType",
    Callback = function(opt)
        SelfAuraType = type(opt) == "table" and opt[1] or opt
        if SelfAuraEnabled then refreshSelfAura() end
    end
})

VisualTab:CreateColorPicker({
    Name = "Aura Color",
    Color = Color3.fromRGB(133, 220, 255),
    Flag = "AuraColor",
    Callback = function(c)
        SelfAuraColor = c
        if SelfAuraEnabled then refreshSelfAura() end
    end
})

SkyTab:CreateToggle({
    Name = "Enable Skybox",
    CurrentValue = false,
    Flag = "SkyboxEnabled",
    Callback = function(v)
        SkyboxEnabled = v
        if v then Skybox_Apply(CurrentSkybox) else Skybox_RestoreDefault() end
    end
})

SkyTab:CreateDropdown({
    Name = "Select Skybox",
    Options = skyboxList,
    CurrentOption = {"HD"},
    Flag = "SkyboxSelect",
    Callback = function(opt)
        CurrentSkybox = type(opt) == "table" and opt[1] or opt
        if SkyboxEnabled then Skybox_Apply(CurrentSkybox) end
    end
})

SkyTab:CreateButton({
    Name = "Restore Default Sky",
    Callback = function()
        SkyboxEnabled = false
        Skybox_RestoreDefault()
        notify("SkyBox", "Небо сброшено")
    end
})

ShaderTab:CreateDropdown({
    Name = "Time Shader",
    Options = {"Morning", "Midday", "Afternoon", "Evening", "Night", "Midnight"},
    CurrentOption = {"Midday"},
    Flag = "TimeShader",
    Callback = function(opt)
        local name = type(opt) == "table" and opt[1] or opt
        if ShaderPresets[name] then
            applyShaderPreset(ShaderPresets[name])
            notify("Shader", name)
        end
    end
})

ShaderTab:CreateDropdown({
    Name = "Weather Shader",
    Options = {"Sunny", "Rain", "Snow", "Fog", "Storm"},
    CurrentOption = {"Sunny"},
    Flag = "WeatherShader",
    Callback = function(opt)
        local name = type(opt) == "table" and opt[1] or opt
        if ShaderPresets[name] then
            applyShaderPreset(ShaderPresets[name])
            notify("Shader", name)
        end
    end
})

ShaderTab:CreateDropdown({
    Name = "Color Shader",
    Options = {"Red", "Blue", "Green", "Purple", "Pink"},
    CurrentOption = {"Blue"},
    Flag = "ColorShader",
    Callback = function(opt)
        local name = type(opt) == "table" and opt[1] or opt
        if ShaderPresets[name] then
            applyShaderPreset(ShaderPresets[name])
            notify("Shader", name)
        end
    end
})

ShaderTab:CreateButton({
    Name = "Reset Shader",
    Callback = function()
        resetShader()
        notify("Shader", "Сброшено")
    end
})
