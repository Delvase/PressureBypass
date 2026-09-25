local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

pcall(function()
    WindUI:AddTheme({
        Name = "SkyBlack",
        Accent = Color3.fromRGB(125, 200, 255),
        Dialog = Color3.fromRGB(12, 14, 20),
        Outline = Color3.fromRGB(40, 55, 75),
        Text = Color3.fromRGB(230, 240, 255),
        Placeholder = Color3.fromRGB(140, 160, 180),
        Background = Color3.fromRGB(8, 10, 16),
        Button = Color3.fromRGB(18, 24, 36),
        Icon = Color3.fromRGB(125, 200, 255),
    })
end)

local Window = WindUI:CreateWindow({
    Title = "Hub",
    Author = "MM2",
    Icon = "cloud",
    Theme = "SkyBlack",
    Folder = "MM2Hub",
})

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

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
    pcall(function()
        WindUI:Notify({
            Title = title,
            Content = content,
            Duration = 3,
        })
    end)
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

-- ==================== ESP (полный порт из toolbox) ====================
local CoreGui = game:GetService("CoreGui")
local espGuiParent = (gethui and gethui()) or CoreGui

local espSettings = {
    MurdererColor = Color3.fromRGB(255, 80, 80),
    SheriffColor = Color3.fromRGB(80, 140, 255),
    HeroColor = Color3.fromRGB(255, 215, 0),
    InnocentColor = Color3.fromRGB(170, 255, 170),
    UnknownColor = Color3.fromRGB(190, 190, 190),
    GunColor = Color3.fromRGB(70, 130, 255),
    NameColor = Color3.fromRGB(255, 255, 255),
    ESP = { Enabled = false, Everyone = false, Murderer = true, Sheriff = true, Innocent = true, Gun = true },
    Outline = { Enabled = false, Everyone = false, Murderer = false, Sheriff = false, Innocent = false, Gun = false },
    Chams = { Enabled = false, Everyone = false, Murderer = true, Sheriff = true, Innocent = true, Gun = true },
    Tracers = { Enabled = false, Everyone = false, Murderer = true, Sheriff = true, Innocent = true, Gun = true },
    Box = { Enabled = false, Everyone = false, Murderer = false, Sheriff = false, Innocent = false, Gun = false },
}

local roleTable = {}
local currentMurderer, currentSheriff, currentHero = nil, nil, nil
local espObjects = {}
local highlightObjects = {}
local gunEspObjects = {}
local gunHighlightObjects = {}
local allPlayersCache = {}
local GetPlayerData = nil
local ESPMaster = false

local function hasDrawing()
    return type(Drawing) == "table" and type(Drawing.new) == "function"
end

local function getRole(plr)
    if not plr then return "Unknown" end
    local entry = roleTable[plr.Name]
    return (entry and entry.Role) and tostring(entry.Role) or "Unknown"
end

local function isDead(plr)
    if not plr then return true end
    local entry = roleTable[plr.Name]
    if entry and entry.Dead == true then return true end
    local char = plr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health <= 0
end

local function getDisplayColor(role)
    if role == "Murderer" then return espSettings.MurdererColor end
    if role == "Sheriff" then return espSettings.SheriffColor end
    if role == "Hero" then return espSettings.HeroColor end
    if role == "Innocent" then return espSettings.InnocentColor end
    return espSettings.UnknownColor
end

local function shouldShow(category, role)
    local s = espSettings[category]
    if not s or not s.Enabled then return false end
    if s.Everyone then return true end
    if role == "Murderer" and s.Murderer then return true end
    if (role == "Sheriff" or role == "Hero") and s.Sheriff then return true end
    if role == "Innocent" and s.Innocent then return true end
    return false
end

local function shouldShowGun(category)
    local s = espSettings[category]
    return s and s.Enabled and s.Gun
end

local function updateCachedRoles()
    currentMurderer, currentSheriff, currentHero = nil, nil, nil
    allPlayersCache = Players:GetPlayers()
    for _, plr in ipairs(allPlayersCache) do
        local role = getRole(plr)
        if not isDead(plr) then
            if role == "Murderer" then currentMurderer = plr
            elseif role == "Sheriff" then currentSheriff = plr
            elseif role == "Hero" then currentHero = plr end
        end
    end
end

local function refreshRoles()
    if not GetPlayerData or not GetPlayerData.Parent then
        GetPlayerData = ReplicatedStorage:FindFirstChild("GetPlayerData", true)
    end
    if GetPlayerData then
        local ok, result = pcall(function()
            return GetPlayerData:InvokeServer()
        end)
        if ok and typeof(result) == "table" then
            roleTable = result
        end
    end
    updateCachedRoles()
end

local function createESP(plr)
    if espObjects[plr] then return end
    local box = {}
    if hasDrawing() then
        for i = 1, 4 do
            local line = Drawing.new("Line")
            line.Visible = false
            line.Color = Color3.fromRGB(255, 255, 255)
            line.Thickness = 1
            line.Transparency = 1
            box[i] = line
        end
    end

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 220, 0, 60)
    billboard.StudsOffset = Vector3.new(0, 2.2, 0)
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.Enabled = false
    billboard.Parent = espGuiParent

    local nameLabel = Instance.new("TextLabel")
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    nameLabel.Font = Enum.Font.Code
    nameLabel.TextSize = 14
    nameLabel.TextColor3 = espSettings.NameColor
    nameLabel.Size = UDim2.new(1, 0, 0.4, 0)
    nameLabel.Parent = billboard

    local roleLabel = Instance.new("TextLabel")
    roleLabel.BackgroundTransparency = 1
    roleLabel.TextStrokeTransparency = 0
    roleLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    roleLabel.Font = Enum.Font.Code
    roleLabel.TextSize = 13
    roleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    roleLabel.Size = UDim2.new(1, 0, 0.3, 0)
    roleLabel.Position = UDim2.new(0, 0, 0.4, 0)
    roleLabel.Parent = billboard

    local distLabel = Instance.new("TextLabel")
    distLabel.BackgroundTransparency = 1
    distLabel.TextStrokeTransparency = 0
    distLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    distLabel.Font = Enum.Font.Ubuntu
    distLabel.TextSize = 12
    distLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    distLabel.Size = UDim2.new(1, 0, 0.3, 0)
    distLabel.Position = UDim2.new(0, 0, 0.7, 0)
    distLabel.Parent = billboard

    local tracer = nil
    if hasDrawing() then
        tracer = Drawing.new("Line")
        tracer.Visible = false
        tracer.Color = Color3.fromRGB(255, 255, 255)
        tracer.Thickness = 1
        tracer.Transparency = 1
    end

    espObjects[plr] = {
        box = box,
        billboard = billboard,
        nameLabel = nameLabel,
        roleLabel = roleLabel,
        distLabel = distLabel,
        tracer = tracer,
    }
end

local function removeESP(plr)
    local obj = espObjects[plr]
    if not obj then return end
    for _, line in pairs(obj.box) do
        pcall(function() line:Remove() end)
    end
    if obj.tracer then pcall(function() obj.tracer:Remove() end) end
    if obj.billboard then pcall(function() obj.billboard:Destroy() end) end
    espObjects[plr] = nil
end

local function applyHighlight(plr, color, chams, outline)
    local char = plr.Character
    if not char then return end
    local hl = highlightObjects[plr]
    if not hl then
        hl = Instance.new("Highlight")
        hl.Adornee = char
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = espGuiParent
        highlightObjects[plr] = hl
    end
    hl.Adornee = char
    if chams and outline then
        hl.FillColor = color
        hl.FillTransparency = 0.4
        hl.OutlineColor = color
        hl.OutlineTransparency = 0
    elseif chams then
        hl.FillColor = color
        hl.FillTransparency = 0.4
        hl.OutlineTransparency = 1
    elseif outline then
        hl.FillTransparency = 1
        hl.OutlineColor = color
        hl.OutlineTransparency = 0
    end
    hl.Enabled = true
end

local function removeHighlight(plr)
    local hl = highlightObjects[plr]
    if not hl then return end
    pcall(function() hl.Adornee = nil end)
    pcall(function() hl.Enabled = false end)
    pcall(function() hl:Destroy() end)
    highlightObjects[plr] = nil
end

local function hideDrawings(obj)
    for _, line in pairs(obj.box) do
        line.Visible = false
    end
    if obj.tracer then obj.tracer.Visible = false end
    if obj.billboard then obj.billboard.Enabled = false end
end

local function createGunESP(drop)
    if gunEspObjects[drop] then return end
    local box = {}
    if hasDrawing() then
        for i = 1, 4 do
            local line = Drawing.new("Line")
            line.Visible = false
            line.Color = espSettings.GunColor
            line.Thickness = 1
            line.Transparency = 1
            box[i] = line
        end
    end

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 160, 0, 45)
    billboard.StudsOffset = Vector3.new(0, 2.8, 0)
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.Enabled = false
    billboard.Parent = espGuiParent

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.Font = Enum.Font.Code
    label.TextSize = 14
    label.TextColor3 = Color3.fromRGB(255, 220, 0)
    label.Text = "Gun"
    label.Size = UDim2.new(1, 0, 0.5, 0)
    label.Parent = billboard

    local distLabel = Instance.new("TextLabel")
    distLabel.BackgroundTransparency = 1
    distLabel.TextStrokeTransparency = 0
    distLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    distLabel.Font = Enum.Font.Code
    distLabel.TextSize = 12
    distLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    distLabel.Size = UDim2.new(1, 0, 0.5, 0)
    distLabel.Position = UDim2.new(0, 0, 0.5, 0)
    distLabel.Parent = billboard

    local tracer = nil
    if hasDrawing() then
        tracer = Drawing.new("Line")
        tracer.Visible = false
        tracer.Color = espSettings.GunColor
        tracer.Thickness = 1
        tracer.Transparency = 1
    end

    gunEspObjects[drop] = {
        box = box,
        billboard = billboard,
        label = label,
        distLabel = distLabel,
        tracer = tracer,
    }
end

local function removeGunESP(drop)
    local obj = gunEspObjects[drop]
    if not obj then return end
    for _, line in pairs(obj.box) do
        pcall(function() line:Remove() end)
    end
    if obj.tracer then pcall(function() obj.tracer:Remove() end) end
    if obj.billboard then pcall(function() obj.billboard:Destroy() end) end
    gunEspObjects[drop] = nil
end

local function applyGunHighlight(drop, chams, outline)
    local part = drop:IsA("BasePart") and drop or drop:FindFirstChildWhichIsA("BasePart") or drop.PrimaryPart
    if not part then return end
    local hl = gunHighlightObjects[drop]
    if not hl then
        hl = Instance.new("Highlight")
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = espGuiParent
        gunHighlightObjects[drop] = hl
    end
    hl.Adornee = drop:IsA("Model") and drop or part
    local color = espSettings.GunColor
    if chams and outline then
        hl.FillColor = color
        hl.FillTransparency = 0.4
        hl.OutlineColor = color
        hl.OutlineTransparency = 0
    elseif chams then
        hl.FillColor = color
        hl.FillTransparency = 0.4
        hl.OutlineTransparency = 1
    elseif outline then
        hl.FillTransparency = 1
        hl.OutlineColor = color
        hl.OutlineTransparency = 0
    end
    hl.Enabled = true
end

local function removeGunHighlight(drop)
    local hl = gunHighlightObjects[drop]
    if not hl then return end
    pcall(function() hl:Destroy() end)
    gunHighlightObjects[drop] = nil
end

local function isValidGunDrop(obj)
    if not obj or not obj.Parent then return false end
    if obj.Name ~= "GunDrop" then return false end
    return obj:IsA("BasePart") or obj:IsA("Model")
end

local function registerGunDrop(obj)
    if not isValidGunDrop(obj) then return end
    createGunESP(obj)
    obj.AncestryChanged:Connect(function(_, parent)
        if not parent then
            removeGunESP(obj)
            removeGunHighlight(obj)
        end
    end)
end

local function clearAllESP()
    for plr in pairs(espObjects) do
        removeESP(plr)
        removeHighlight(plr)
    end
    for drop in pairs(gunEspObjects) do
        removeGunESP(drop)
        removeGunHighlight(drop)
    end
end

local function updateESP()
    if not ESPMaster then return end

    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local viewport = Camera.ViewportSize

    for _, plr in ipairs(allPlayersCache) do
        if plr ~= LocalPlayer then
            if not espObjects[plr] then
                createESP(plr)
            end
            local obj = espObjects[plr]
            local char = plr.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")

            if not char or not hrp or not hum then
                hideDrawings(obj)
                removeHighlight(plr)
            else
                local role = getRole(plr)
                local dead = isDead(plr)
                local color = dead and espSettings.UnknownColor or getDisplayColor(role)
                local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                local dist = myHRP and (myHRP.Position - hrp.Position).Magnitude or 0
                if dist < 0.001 then dist = 0.001 end

                local showBox = onScreen and shouldShow("Box", role)
                local showName = onScreen and shouldShow("ESP", role)
                local showTracer = onScreen and shouldShow("Tracers", role)
                local showChams = shouldShow("Chams", role)
                local showOutline = shouldShow("Outline", role)

                if not (showBox or showName or showTracer or showChams or showOutline) then
                    hideDrawings(obj)
                    removeHighlight(plr)
                else
                    if showBox and #obj.box >= 4 then
                        local head = char:FindFirstChild("Head")
                        local topPos = head and Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0)) or screenPos
                        local botPos = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                        local w = 2000 / dist
                        local tl = Vector2.new(screenPos.X - w / 2, topPos.Y)
                        local tr = Vector2.new(screenPos.X + w / 2, topPos.Y)
                        local bl = Vector2.new(screenPos.X - w / 2, botPos.Y)
                        local br = Vector2.new(screenPos.X + w / 2, botPos.Y)
                        obj.box[1].From, obj.box[1].To, obj.box[1].Color, obj.box[1].Visible = tl, tr, color, true
                        obj.box[2].From, obj.box[2].To, obj.box[2].Color, obj.box[2].Visible = bl, br, color, true
                        obj.box[3].From, obj.box[3].To, obj.box[3].Color, obj.box[3].Visible = tl, bl, color, true
                        obj.box[4].From, obj.box[4].To, obj.box[4].Color, obj.box[4].Visible = tr, br, color, true
                    else
                        for _, line in pairs(obj.box) do line.Visible = false end
                    end

                    if showName and obj.billboard then
                        local head = char:FindFirstChild("Head")
                        obj.billboard.Adornee = head or char
                        obj.billboard.Enabled = true
                        obj.nameLabel.Text = plr.Name
                        obj.roleLabel.Text = dead and "[DEAD]" or ("[" .. role:upper() .. "]")
                        obj.roleLabel.TextColor3 = color
                        obj.distLabel.Text = string.format("[%d studs]", math.floor(dist))
                    elseif obj.billboard then
                        obj.billboard.Enabled = false
                    end

                    if showTracer and obj.tracer then
                        obj.tracer.From = Vector2.new(viewport.X / 2, viewport.Y)
                        obj.tracer.To = Vector2.new(screenPos.X, screenPos.Y)
                        obj.tracer.Color = color
                        obj.tracer.Visible = true
                    elseif obj.tracer then
                        obj.tracer.Visible = false
                    end

                    if showChams or showOutline then
                        applyHighlight(plr, color, showChams, showOutline)
                    else
                        removeHighlight(plr)
                    end
                end
            end
        end
    end

    -- Gun ESP
    for drop, obj in pairs(gunEspObjects) do
        if not drop or not drop.Parent then
            removeGunESP(drop)
            removeGunHighlight(drop)
        else
            local part = drop:IsA("BasePart") and drop or drop:FindFirstChildWhichIsA("BasePart") or drop.PrimaryPart
            if not part then
                hideDrawings(obj)
                removeGunHighlight(drop)
            else
                local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                local dist = myHRP and (myHRP.Position - part.Position).Magnitude or 0
                if dist < 0.001 then dist = 0.001 end

                local showBox = onScreen and shouldShowGun("Box")
                local showName = onScreen and shouldShowGun("ESP")
                local showTracer = onScreen and shouldShowGun("Tracers")
                local showChams = shouldShowGun("Chams")
                local showOutline = shouldShowGun("Outline")

                if not (showBox or showName or showTracer or showChams or showOutline) then
                    hideDrawings(obj)
                    removeGunHighlight(drop)
                else
                    if showBox and #obj.box >= 4 then
                        local top = Camera:WorldToViewportPoint(part.Position + Vector3.new(0, 2, 0))
                        local bot = Camera:WorldToViewportPoint(part.Position - Vector3.new(0, 2, 0))
                        local w = 1200 / dist
                        local tl = Vector2.new(screenPos.X - w / 2, top.Y)
                        local tr = Vector2.new(screenPos.X + w / 2, top.Y)
                        local bl = Vector2.new(screenPos.X - w / 2, bot.Y)
                        local br = Vector2.new(screenPos.X + w / 2, bot.Y)
                        local gc = espSettings.GunColor
                        obj.box[1].From, obj.box[1].To, obj.box[1].Color, obj.box[1].Visible = tl, tr, gc, true
                        obj.box[2].From, obj.box[2].To, obj.box[2].Color, obj.box[2].Visible = bl, br, gc, true
                        obj.box[3].From, obj.box[3].To, obj.box[3].Color, obj.box[3].Visible = tl, bl, gc, true
                        obj.box[4].From, obj.box[4].To, obj.box[4].Color, obj.box[4].Visible = tr, br, gc, true
                    else
                        for _, line in pairs(obj.box) do line.Visible = false end
                    end

                    if showName and obj.billboard then
                        obj.billboard.Adornee = part
                        obj.billboard.Enabled = true
                        obj.label.Text = "Gun"
                        obj.label.TextColor3 = Color3.fromRGB(255, 220, 0)
                        obj.distLabel.Text = string.format("[%d studs]", math.floor(dist))
                    elseif obj.billboard then
                        obj.billboard.Enabled = false
                    end

                    if showTracer and obj.tracer then
                        obj.tracer.From = Vector2.new(viewport.X / 2, viewport.Y)
                        obj.tracer.To = Vector2.new(screenPos.X, screenPos.Y)
                        obj.tracer.Color = espSettings.GunColor
                        obj.tracer.Visible = true
                    elseif obj.tracer then
                        obj.tracer.Visible = false
                    end

                    if showChams or showOutline then
                        applyGunHighlight(drop, showChams, showOutline)
                    else
                        removeGunHighlight(drop)
                    end
                end
            end
        end
    end
end

task.spawn(function()
    repeat
        GetPlayerData = ReplicatedStorage:FindFirstChild("GetPlayerData", true)
        task.wait(1)
    until GetPlayerData
    refreshRoles()
end)

task.spawn(function()
    while task.wait(2) do
        if ESPMaster or (Farm and Farm.autofarm) then
            refreshRoles()
        end
    end
end)

pcall(function()
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v.Name == "PlayerDataChanged" and v:IsA("RemoteEvent") then
            v.OnClientEvent:Connect(function(data)
                if typeof(data) == "table" then
                    roleTable = data
                    updateCachedRoles()
                else
                    refreshRoles()
                end
            end)
            break
        end
    end
end)

for _, desc in ipairs(Workspace:GetDescendants()) do
    if desc.Name == "GunDrop" then
        registerGunDrop(desc)
    end
end

Workspace.DescendantAdded:Connect(function(desc)
    if desc.Name == "GunDrop" then
        task.defer(registerGunDrop, desc)
    end
end)

RunService.RenderStepped:Connect(updateESP)

Players.PlayerRemoving:Connect(function(plr)
    removeESP(plr)
    removeHighlight(plr)
end)

Players.PlayerAdded:Connect(function(plr)
    task.delay(1, function()
        if ESPMaster then
            refreshRoles()
            createESP(plr)
        end
    end)
end)

allPlayersCache = Players:GetPlayers()
for _, plr in ipairs(allPlayersCache) do
    if plr ~= LocalPlayer then
        createESP(plr)
    end
end

-- Self Aura
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

-- SkyBox
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

-- Shaders
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



-- ==================== AUTO FARM (движок из autofarm.lua skobliko) ====================
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")

local BAG_LIMIT_DEFAULT = 40
local BAG_LIMIT_ELITE = 50
local ELITE_GAMEPASS_ID = 429957
local MAX_FARM_DISTANCE = 180

local fireTouch = (typeof(firetouchinterest) == "function" and firetouchinterest)
    or (typeof(firetouchtransmitter) == "function" and firetouchtransmitter)
    or nil
local FLY_BELOW_OFFSET = fireTouch and 2.8 or 0.75
local originalOcclusionMode = LocalPlayer.DevCameraOcclusionMode

local Farm = {
    alive = true,
    autofarm = false,
    farmSpeed = 23,
    farmed = 0,
    dieOnFullBag = true,
    protection = false,
    farmPaused = false,
    pauseReason = "",
    bagCount = 0,
    bagLimit = BAG_LIMIT_DEFAULT,
    bagFound = false,
}

local collisionCache = {}
local coinBlacklist = {}
local coinTouchFails = setmetatable({}, { __mode = "k" })
local deadCoins = setmetatable({}, { __mode = "k" })
local coinHadVisual = setmetatable({}, { __mode = "k" })
local coinSet = {}
local trackedContainers = {}
local lastRadarSweep = 0
local lenientContainers = {}
local detectedPickupNames = {}
local currentTarget = nil
local retargetAccumulator = 0
local farmIdle = false
local CLUSTER_RADIUS = 24
local CLUSTER_BONUS = 7
local lastPickTime = -math.huge
local lastPickCoin = nil
local lastPickScore = math.huge
local lastPickHadResult = false
local lastAutoDetect = 0

local PICKUP_NAME_HINTS = {
    "coin", "candy", "token", "egg", "snow", "gift", "present",
    "pickup", "collect", "drop", "orb", "shell", "star", "gem",
}
local PARENT_NAME_HINTS = {
    "container", "coin", "drop", "pickup", "spawn", "collect",
}

local function restoreCharacter()
    pcall(function()
        LocalPlayer.DevCameraOcclusionMode = originalOcclusionMode
    end)
    local character = LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.PlatformStand = false
        humanoid.AutoRotate = true
    end
    for part, oldCanCollide in pairs(collisionCache) do
        if part and part.Parent then
            part.CanCollide = oldCanCollide
        end
    end
    table.clear(collisionCache)
end

local function isCoinPart(coin)
    if not coin:IsA("BasePart") then return false end
    if string.find(coin.Name, "Server", 1, true) then return true end
    if detectedPickupNames[coin.Name] then return true end
    return lenientContainers[coin.Parent] == true
end

local function registerCoin(coin)
    if isCoinPart(coin) then
        coinSet[coin] = true
    end
end

local function unregisterCoin(coin)
    coinSet[coin] = nil
    coinBlacklist[coin] = nil
    coinTouchFails[coin] = nil
    deadCoins[coin] = nil
    coinHadVisual[coin] = nil
end

local function watchContainer(container)
    if trackedContainers[container] then return end
    trackedContainers[container] = true
    container.ChildAdded:Connect(registerCoin)
    container.ChildRemoved:Connect(unregisterCoin)
    for _, coin in ipairs(container:GetChildren()) do
        registerCoin(coin)
    end
end

local function radarSweep(force)
    if not force and os.clock() - lastRadarSweep < 3 then return end
    lastRadarSweep = os.clock()

    for container in pairs(trackedContainers) do
        if not container.Parent then
            trackedContainers[container] = nil
        end
    end
    for coin in pairs(coinSet) do
        if not coin.Parent then
            unregisterCoin(coin)
        end
    end
    for _, containerParent in ipairs(workspace:GetChildren()) do
        local container = containerParent:FindFirstChild("CoinContainer")
        if container then
            watchContainer(container)
        end
        for _, child in ipairs(containerParent:GetChildren()) do
            if child ~= container
                and not trackedContainers[child]
                and string.find(child.Name, "Container", 1, true) then
                local part = child:FindFirstChildWhichIsA("BasePart")
                if part and string.find(part.Name, "Server", 1, true) then
                    watchContainer(child)
                end
            end
        end
    end

    for container in pairs(trackedContainers) do
        if container.Parent and not lenientContainers[container] then
            local hasKnown = false
            local hasParts = false
            for _, child in ipairs(container:GetChildren()) do
                if child:IsA("BasePart") then
                    hasParts = true
                    if string.find(child.Name, "Server", 1, true) then
                        hasKnown = true
                        break
                    end
                end
            end
            if hasParts and not hasKnown then
                lenientContainers[container] = true
                for _, child in ipairs(container:GetChildren()) do
                    registerCoin(child)
                end
            end
        end
    end
end

workspace.ChildAdded:Connect(function()
    task.defer(radarSweep, true)
end)
radarSweep(true)

local function nameHasHint(name, hints)
    local lower = string.lower(name)
    for _, hint in ipairs(hints) do
        if string.find(lower, hint, 1, true) then
            return true
        end
    end
    return false
end

local function autoDetectPickups()
    if os.clock() - lastAutoDetect < 5 then return end
    lastAutoDetect = os.clock()

    local groups = {}
    for _, mapCandidate in ipairs(workspace:GetChildren()) do
        if mapCandidate:IsA("Model") or mapCandidate:IsA("Folder") then
            for _, part in ipairs(mapCandidate:GetDescendants()) do
                if part:IsA("BasePart")
                    and part.Anchored
                    and not part.CanCollide
                    and part.Size.Magnitude <= 8 then
                    local byName = groups[part.Parent]
                    if not byName then
                        byName = {}
                        groups[part.Parent] = byName
                    end
                    local info = byName[part.Name]
                    if info then
                        info.count += 1
                    else
                        byName[part.Name] = { count = 1, sample = part }
                    end
                end
            end
        end
    end

    local bestParent, bestName, bestScore, bestCount = nil, nil, 0, 0
    for parent, byName in pairs(groups) do
        for name, info in pairs(byName) do
            if info.count >= 5 then
                local sample = info.sample
                local score = 0
                if sample:FindFirstChildOfClass("TouchTransmitter") then
                    score += 4
                end
                if nameHasHint(name, PICKUP_NAME_HINTS) then score += 2 end
                if nameHasHint(parent.Name, PARENT_NAME_HINTS) then score += 2 end
                if sample:IsA("MeshPart") or sample:FindFirstChildOfClass("SpecialMesh") then
                    score += 1
                end
                if info.count <= 80 then score += 1 end
                if score >= 4 and (score > bestScore or (score == bestScore and info.count > bestCount)) then
                    bestParent, bestName, bestScore, bestCount = parent, name, score, info.count
                end
            end
        end
    end

    if bestParent then
        detectedPickupNames[bestName] = true
        watchContainer(bestParent)
        for _, part in ipairs(bestParent:GetChildren()) do
            registerCoin(part)
        end
    end
end

local function findClosestItem(rootPart)
    local now = os.clock()
    if now - lastPickTime < 0.15 then
        if not lastPickHadResult then
            return nil, math.huge, math.huge
        end
        local cached = lastPickCoin
        if cached and cached.Parent and not coinBlacklist[cached] and not deadCoins[cached] then
            return cached, (cached.Position - rootPart.Position).Magnitude, lastPickScore
        end
    end
    lastPickTime = now

    for coin, timestamp in pairs(coinBlacklist) do
        if not coin.Parent or now - timestamp > 1.5 then
            coinBlacklist[coin] = nil
        end
    end

    radarSweep(false)

    local candidates = {}
    for coin in pairs(coinSet) do
        if coin.Parent and not coinBlacklist[coin] and not deadCoins[coin] then
            local childCount = #coin:GetChildren()
            if childCount > 0 then
                coinHadVisual[coin] = true
                table.insert(candidates, coin)
            elseif not coinHadVisual[coin] then
                table.insert(candidates, coin)
            end
        end
    end

    local count = #candidates
    local rootPosition = rootPart.Position
    local positions = table.create(count)
    local distances = table.create(count)
    local order = table.create(count)
    for index = 1, count do
        local position = candidates[index].Position
        positions[index] = position
        distances[index] = (position - rootPosition).Magnitude
        order[index] = index
    end
    table.sort(order, function(a, b)
        return distances[a] < distances[b]
    end)

    local best, bestDistance, bestScore = nil, math.huge, math.huge
    local maxBonus = 6 * CLUSTER_BONUS
    for _, index in ipairs(order) do
        local distance = distances[index]
        if distance - maxBonus >= bestScore then
            break
        end
        local position = positions[index]
        local neighbors = 0
        for otherIndex = 1, count do
            if otherIndex ~= index and (positions[otherIndex] - position).Magnitude <= CLUSTER_RADIUS then
                neighbors += 1
                if neighbors >= 6 then break end
            end
        end
        local score = distance - neighbors * CLUSTER_BONUS
        if score < bestScore then
            best = candidates[index]
            bestDistance = distance
            bestScore = score
        end
    end

    lastPickCoin = best
    lastPickScore = bestScore
    lastPickHadResult = best ~= nil
    return best, bestDistance, bestScore
end

local function isRoundOver()
    local guiParent = LocalPlayer:FindFirstChild("PlayerGui")
    if not guiParent then return false end
    for _, guiName in ipairs({ "Scoreboard", "Scoreboard_Phone" }) do
        local scoreboard = guiParent:FindFirstChild(guiName)
        if scoreboard and scoreboard:IsA("ScreenGui") and scoreboard.Enabled then
            for _, modeFrame in ipairs(scoreboard:GetChildren()) do
                if modeFrame:IsA("GuiObject") and modeFrame.Visible then
                    return true
                end
            end
        end
    end
    return false
end

-- Bag counter (из autofarm.lua)
local trackedBagContainer = nil
local trackedBagLabel = nil
local lastDeepContainerScan = 0
local lastBagScan = 0
local bagKillTriggered = false
local bagFullConfirmations = 0
local bagStartFarmed = 0
local bagCheckEnabledAt = 0

local function parseBagText(object)
    if not (object:IsA("TextLabel") or object:IsA("TextButton")) then
        return nil
    end
    local text = object.Text or ""
    text = string.gsub(text, "<[^<>]->", "")
    text = string.gsub(text, ",", "")
    local currentText, capacityText = string.match(text, "^%s*(%d+)%s*/%s*(%d+)%s*$")
    if currentText then
        return tonumber(currentText), tonumber(capacityText)
    end
    local plain = string.match(text, "^%s*(%d+)%s*$")
    if plain then
        return tonumber(plain), nil
    end
    return nil
end

local function findCoinBagContainer(playerGui)
    if trackedBagContainer and trackedBagContainer.Parent then
        return trackedBagContainer
    end
    trackedBagContainer = nil
    local mainGui = playerGui:FindFirstChild("MainGUI")
    local gameFrame = mainGui and mainGui:FindFirstChild("Game")
    local coinBags = gameFrame and gameFrame:FindFirstChild("CoinBags")
    local container = coinBags and coinBags:FindFirstChild("Container")
    if container then
        trackedBagContainer = container
        return container
    end
    if os.clock() - lastDeepContainerScan < 1.5 then
        return nil
    end
    lastDeepContainerScan = os.clock()
    for _, object in ipairs(playerGui:GetDescendants()) do
        if object.Name == "CoinBags" then
            local found = object:FindFirstChild("Container") or object
            trackedBagContainer = found
            return found
        end
    end
    return nil
end

local function findCoinBagLabel(playerGui)
    local container = findCoinBagContainer(playerGui)
    if not container then return nil end
    for _, bag in ipairs(container:GetChildren()) do
        if bag:IsA("GuiObject") then
            local currencyFrame = bag:FindFirstChild("CurrencyFrame")
            local icon = currencyFrame and currencyFrame:FindFirstChild("Icon")
            local label = icon and icon:FindFirstChild("Coins")
            if label then
                local current = parseBagText(label)
                if current then
                    return label
                end
            end
        end
    end
    return nil
end

local function labelContext(object)
    local parts = {}
    local node = object
    for _ = 1, 6 do
        if not node then break end
        table.insert(parts, string.lower(node.Name or ""))
        node = node.Parent
    end
    return table.concat(parts, ".")
end

local function scanBagFromInterface()
    if trackedBagLabel and trackedBagLabel.Parent then
        local current, capacity = parseBagText(trackedBagLabel)
        if current then
            return current, capacity
        end
    end
    trackedBagLabel = nil
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return nil end
    local exactLabel = findCoinBagLabel(playerGui)
    if exactLabel then
        local current, capacity = parseBagText(exactLabel)
        if current then
            trackedBagLabel = exactLabel
            return current, capacity
        end
    end
    if os.clock() - lastBagScan < 1.5 then
        return nil
    end
    lastBagScan = os.clock()
    local bestLabel, bestCurrent, bestCapacity, bestScore = nil, nil, nil, 0
    for _, object in ipairs(playerGui:GetDescendants()) do
        local current, capacity = parseBagText(object)
        if current and object.Visible then
            local context = labelContext(object)
            local score = 0
            if string.find(context, "coin", 1, true) then score += 4 end
            if string.find(context, "bag", 1, true) then score += 3 end
            if string.find(context, "candy", 1, true) then score += 2 end
            if string.find(context, "currency", 1, true) then score += 1 end
            if object.Name == "Coins" then score += 4 end
            if capacity == BAG_LIMIT_DEFAULT or capacity == BAG_LIMIT_ELITE or capacity == 60 then
                score += 5
            end
            if (capacity or score >= 3) and score > bestScore then
                bestLabel, bestCurrent, bestCapacity, bestScore = object, current, capacity, score
            end
        end
    end
    if bestLabel then
        trackedBagLabel = bestLabel
        return bestCurrent, bestCapacity
    end
    return nil
end

local function updateBagFromInterface()
    local current, capacity = scanBagFromInterface()
    if current then
        Farm.bagCount = current
        Farm.bagFound = true
        if capacity and capacity > 0 then
            -- UI limit from dropdown wins unless elite detected
            if capacity == BAG_LIMIT_ELITE and Farm.bagLimit < capacity then
                Farm.bagLimit = capacity
            end
        end
    end
end

local function killCharacterWhenBagIsFull()
    if bagKillTriggered or not Farm.dieOnFullBag then
        return
    end
    if Farm.bagCount < Farm.bagLimit then
        return
    end
    bagKillTriggered = true
    currentTarget = nil
    Farm.farmPaused = Farm.autofarm
    Farm.pauseReason = Farm.autofarm and "RESET" or ""
    restoreCharacter()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health > 0 then
        humanoid.Health = 0
        humanoid:ChangeState(Enum.HumanoidStateType.Dead)
        task.delay(0.05, function()
            if character and character.Parent then
                character:BreakJoints()
            end
        end)
    end
end

local function stopAutofarmOnDeath(character)
    bagKillTriggered = false
    bagStartFarmed = Farm.farmed
    if Farm.autofarm then
        Farm.farmPaused = true
        Farm.pauseReason = "RESPAWN"
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 8)
    if not humanoid then return end
    humanoid.Died:Connect(function()
        currentTarget = nil
        Farm.farmPaused = Farm.autofarm
        Farm.pauseReason = Farm.autofarm and "RESPAWN" or ""
        restoreCharacter()
    end)
end

if LocalPlayer.Character then
    task.defer(stopAutofarmOnDeath, LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(stopAutofarmOnDeath)

-- Elite gamepass optional
task.spawn(function()
    local ok, ownsElite = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(LocalPlayer.UserId, ELITE_GAMEPASS_ID)
    end)
    if ok and ownsElite and Farm.bagLimit < BAG_LIMIT_ELITE then
        Farm.bagLimit = BAG_LIMIT_ELITE
    end
end)

-- Main farm loop
RunService.Heartbeat:Connect(function(deltaTime)
    if not Farm.alive then return end

    if not Farm.autofarm then
        Farm.farmPaused = false
        Farm.pauseReason = ""
        return
    end

    local character = LocalPlayer.Character
    if not character then
        Farm.farmPaused = true
        Farm.pauseReason = "RESPAWN"
        return
    end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not rootPart or not humanoid or humanoid.Health <= 0 then
        Farm.farmPaused = true
        Farm.pauseReason = "RESPAWN"
        return
    end

    if isRoundOver() then
        currentTarget = nil
        Farm.farmPaused = true
        Farm.pauseReason = "ROUND END"
        restoreCharacter()
        rootPart.AssemblyLinearVelocity = Vector3.zero
        rootPart.AssemblyAngularVelocity = Vector3.zero
        return
    end

    if not currentTarget or not currentTarget.Parent or coinBlacklist[currentTarget] then
        local candidate, candidateDistance = findClosestItem(rootPart)
        if candidate and candidateDistance <= MAX_FARM_DISTANCE then
            currentTarget = candidate
            Farm.farmPaused = false
            Farm.pauseReason = ""
        else
            currentTarget = nil
            Farm.farmPaused = true
            Farm.pauseReason = candidate and "TOO FAR" or "WAITING"
            if not candidate then
                autoDetectPickups()
            end
        end
    end

    retargetAccumulator += deltaTime
    if currentTarget and retargetAccumulator >= 0.5 then
        retargetAccumulator = 0
        local candidate, candidateDistance, candidateScore = findClosestItem(rootPart)
        if candidate and candidate ~= currentTarget and candidateDistance <= MAX_FARM_DISTANCE then
            local currentDistance = (currentTarget.Position - rootPart.Position).Magnitude
            if currentDistance > 15 and candidateScore + 12 < currentDistance then
                currentTarget = candidate
            end
        end
    end

    local target = currentTarget
    if not target or not target.Parent then
        if not farmIdle then
            farmIdle = true
            restoreCharacter()
            rootPart.AssemblyLinearVelocity = Vector3.zero
            rootPart.AssemblyAngularVelocity = Vector3.zero
        end
        return
    end
    farmIdle = false

    local targetPosition = target.Position - Vector3.new(0, FLY_BELOW_OFFSET, 0)
    local offset = targetPosition - rootPart.Position
    local distance = offset.Magnitude

    if distance > MAX_FARM_DISTANCE then
        currentTarget = nil
        Farm.farmPaused = true
        Farm.pauseReason = "TOO FAR"
        restoreCharacter()
        rootPart.AssemblyLinearVelocity = Vector3.zero
        rootPart.AssemblyAngularVelocity = Vector3.zero
        return
    end

    Farm.farmPaused = false
    Farm.pauseReason = ""

    if LocalPlayer.DevCameraOcclusionMode ~= Enum.DevCameraOcclusionMode.Invisicam then
        pcall(function()
            LocalPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
        end)
    end

    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            if collisionCache[part] == nil then
                collisionCache[part] = part.CanCollide
            end
            part.CanCollide = false
        end
    end

    humanoid.PlatformStand = true
    rootPart.AssemblyLinearVelocity = Vector3.zero
    rootPart.AssemblyAngularVelocity = Vector3.zero

    if distance <= 0.45 then
        if fireTouch then
            pcall(fireTouch, rootPart, target, 0)
            pcall(fireTouch, rootPart, target, 1)
        end
        coinBlacklist[target] = os.clock()
        local bagFull = Farm.bagFound and Farm.bagLimit > 0 and Farm.bagCount >= Farm.bagLimit
        if not bagFull then
            coinTouchFails[target] = (coinTouchFails[target] or 0) + 1
            if coinTouchFails[target] >= 3 then
                deadCoins[target] = true
            end
        end
        currentTarget = nil
        return
    end

    if distance <= 0.001 then return end

    local safeDelta = math.min(deltaTime, 1 / 30)
    local step = math.min(Farm.farmSpeed * safeDelta, math.max(distance - 0.1, 0))
    local nextPosition = rootPart.Position + offset.Unit * step

    local flatOffset = Vector3.new(offset.X, 0, offset.Z)
    if flatOffset.Magnitude > 0.05 then
        rootPart.CFrame = CFrame.lookAt(nextPosition, nextPosition + flatOffset.Unit) * CFrame.Angles(-math.pi / 2, 0, 0)
    else
        rootPart.CFrame = rootPart.CFrame.Rotation + nextPosition
    end
end)

-- Anti fling / void
local lastSafePosition = nil
local lastFramePosition = nil
local safePosAccumulator = 0
local voidThreshold = -440
do
    local ok, destroyHeight = pcall(function()
        return workspace.FallenPartsDestroyHeight
    end)
    if ok and typeof(destroyHeight) == "number" then
        voidThreshold = destroyHeight + 80
    end
end

RunService.Heartbeat:Connect(function(deltaTime)
    if not Farm.alive or not Farm.protection then return end
    local character = LocalPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not rootPart or not humanoid or humanoid.Health <= 0 then return end

    local farmingActively = Farm.autofarm and not Farm.farmPaused
    local pos = rootPart.Position
    local vel = rootPart.AssemblyLinearVelocity

    if not farmingActively then
        if vel.Magnitude < 90 and pos.Y > voidThreshold then
            safePosAccumulator += deltaTime
            if safePosAccumulator >= 0.15 then
                lastSafePosition = pos
                safePosAccumulator = 0
            end
        else
            safePosAccumulator = 0
        end
    end

    if vel.Magnitude > 250 or pos.Y < voidThreshold then
        rootPart.AssemblyLinearVelocity = Vector3.zero
        rootPart.AssemblyAngularVelocity = Vector3.zero
        if lastSafePosition then
            rootPart.CFrame = CFrame.new(lastSafePosition) * (rootPart.CFrame - rootPart.CFrame.Position)
        elseif lastFramePosition then
            rootPart.CFrame = CFrame.new(lastFramePosition) * (rootPart.CFrame - rootPart.CFrame.Position)
        end
    end
    lastFramePosition = rootPart.Position
end)

-- Bag update + auto reset tick
RunService.Heartbeat:Connect(function()
    if not Farm.alive then return end
    updateBagFromInterface()
    killCharacterWhenBagIsFull()
end)

function startFarming()
    Farm.autofarm = true
    bagKillTriggered = false
    bagStartFarmed = Farm.farmed
    bagCheckEnabledAt = os.clock()
    radarSweep(true)
end

function stopFarming()
    Farm.autofarm = false
    currentTarget = nil
    Farm.farmPaused = false
    Farm.pauseReason = ""
    restoreCharacter()
end

-- ==================== UI (WindUI) ====================
local MainTab = Window:Tab({ Title = "Main", Icon = "zap" })
local GunTab = Window:Tab({ Title = "Gun", Icon = "target" })
local FarmTab = Window:Tab({ Title = "Farm", Icon = "coins" })
local EspTab = Window:Tab({ Title = "ESP", Icon = "eye" })
local VisualTab = Window:Tab({ Title = "Visuals", Icon = "sparkles" })
local SkyTab = Window:Tab({ Title = "SkyBox", Icon = "cloud-sun" })
local ShaderTab = Window:Tab({ Title = "Shaders", Icon = "palette" })

MainTab:Slider({
    Title = "WalkSpeed",
    Step = 1,
    Value = { Min = 16, Max = 100, Default = 16 },
    Callback = function(v)
        WalkSpeedValue = v
        if humanoid then humanoid.WalkSpeed = v end
    end,
})

MainTab:Slider({
    Title = "JumpPower",
    Step = 1,
    Value = { Min = 50, Max = 200, Default = 50 },
    Callback = function(v)
        JumpPowerValue = v
        if humanoid then
            humanoid.JumpPower = v
            humanoid.UseJumpPower = true
        end
    end,
})

MainTab:Toggle({
    Title = "Infinite Jump",
    Value = false,
    Callback = function(v) InfJump = v end,
})

MainTab:Toggle({
    Title = "Speed Glitch",
    Value = false,
    Callback = function(v) SpeedGlitch = v end,
})

MainTab:Slider({
    Title = "Speed Glitch Value",
    Step = 1,
    Value = { Min = 20, Max = 120, Default = 50 },
    Callback = function(v) SpeedGlitchValue = v end,
})

GunTab:Toggle({
    Title = "Auto Grab Gun",
    Value = false,
    Callback = function(v)
        AutoGrab = v
        if v and Workspace:FindFirstChild("GunDrop", true) and not hasGun() then
            task.spawn(GrabGun)
        end
    end,
})

GunTab:Toggle({
    Title = "Gun Notify",
    Value = false,
    Callback = function(v) GunNotify = v end,
})

GunTab:Toggle({
    Title = "Success Notify",
    Value = false,
    Callback = function(v) SuccessNotify = v end,
})

GunTab:Button({
    Title = "Grab Gun",
    Callback = function()
        task.spawn(GrabGun)
    end,
})

GunTab:Button({
    Title = "Status",
    Callback = function()
        local has = hasGun()
        local drop = Workspace:FindFirstChild("GunDrop", true)
        notify("Status", has and "Gun в инвентаре" or (drop and "GunDrop на карте" or "Нет пистолета"))
    end,
})


FarmTab:Toggle({
    Title = "Auto Farm",
    Value = false,
    Callback = function(v)
        if v then
            startFarming()
        else
            stopFarming()
        end
    end,
})

FarmTab:Slider({
    Title = "Farm Speed",
    Step = 1,
    Value = { Min = 22, Max = 30, Default = 23 },
    Callback = function(v)
        Farm.farmSpeed = v
    end,
})

FarmTab:Dropdown({
    Title = "Coin Limit (Reset)",
    Values = {"40", "60"},
    Value = "40",
    Callback = function(opt)
        local name = type(opt) == "table" and (opt.Title or opt[1] or opt) or opt
        Farm.bagLimit = tonumber(name) or 40
        bagKillTriggered = false
    end,
})

FarmTab:Toggle({
    Title = "Auto Respawn",
    Value = true,
    Callback = function(v)
        Farm.dieOnFullBag = v
        bagKillTriggered = false
        if v then
            bagStartFarmed = Farm.farmed
            bagCheckEnabledAt = os.clock()
        end
    end,
})

FarmTab:Toggle({
    Title = "Anti Fling / Void",
    Value = false,
    Callback = function(v)
        Farm.protection = v
    end,
})

EspTab:Toggle({
    Title = "ESP Master",
    Value = false,
    Callback = function(v)
        ESPMaster = v
        if not v then
            clearAllESP()
        else
            refreshRoles()
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then createESP(plr) end
            end
        end
    end,
})

EspTab:Toggle({
    Title = "Names (ESP)",
    Value = false,
    Callback = function(v) espSettings.ESP.Enabled = v end,
})

EspTab:Toggle({
    Title = "Chams",
    Value = false,
    Callback = function(v) espSettings.Chams.Enabled = v end,
})

EspTab:Toggle({
    Title = "Tracers",
    Value = false,
    Callback = function(v) espSettings.Tracers.Enabled = v end,
})

EspTab:Toggle({
    Title = "Gun ESP",
    Value = true,
    Callback = function(v)
        espSettings.ESP.Gun = v
        espSettings.Chams.Gun = v
        espSettings.Tracers.Gun = v
    end,
})

EspTab:Toggle({
    Title = "Show Murderer",
    Value = true,
    Callback = function(v)
        espSettings.ESP.Murderer = v
        espSettings.Chams.Murderer = v
        espSettings.Tracers.Murderer = v
    end,
})

EspTab:Toggle({
    Title = "Show Sheriff/Hero",
    Value = true,
    Callback = function(v)
        espSettings.ESP.Sheriff = v
        espSettings.Chams.Sheriff = v
        espSettings.Tracers.Sheriff = v
    end,
})

EspTab:Toggle({
    Title = "Show Innocent",
    Value = true,
    Callback = function(v)
        espSettings.ESP.Innocent = v
        espSettings.Chams.Innocent = v
        espSettings.Tracers.Innocent = v
    end,
})

EspTab:Toggle({
    Title = "Show Everyone",
    Value = false,
    Callback = function(v)
        espSettings.ESP.Everyone = v
        espSettings.Chams.Everyone = v
        espSettings.Tracers.Everyone = v
    end,
})

EspTab:Colorpicker({
    Title = "Murderer Color",
    Default = Color3.fromRGB(255, 80, 80),
    Callback = function(c) espSettings.MurdererColor = c end,
})

EspTab:Colorpicker({
    Title = "Sheriff Color",
    Default = Color3.fromRGB(80, 140, 255),
    Callback = function(c) espSettings.SheriffColor = c end,
})

EspTab:Colorpicker({
    Title = "Hero Color",
    Default = Color3.fromRGB(255, 215, 0),
    Callback = function(c) espSettings.HeroColor = c end,
})

EspTab:Colorpicker({
    Title = "Innocent Color",
    Default = Color3.fromRGB(170, 255, 170),
    Callback = function(c) espSettings.InnocentColor = c end,
})

EspTab:Colorpicker({
    Title = "Gun Color",
    Default = Color3.fromRGB(255, 220, 0),
    Callback = function(c)
        espSettings.GunColor = c
    end,
})

VisualTab:Toggle({
    Title = "Self Aura",
    Value = false,
    Callback = function(v)
        SelfAuraEnabled = v
        if v then refreshSelfAura() else clearSelfAura() end
    end,
})

VisualTab:Dropdown({
    Title = "Aura Type",
    Values = PARTICLE_AURA_NAMES,
    Value = "starlight",
    Callback = function(opt)
        SelfAuraType = type(opt) == "table" and (opt.Title or opt[1] or opt) or opt
        if SelfAuraEnabled then refreshSelfAura() end
    end,
})

VisualTab:Colorpicker({
    Title = "Aura Color",
    Default = Color3.fromRGB(133, 220, 255),
    Callback = function(c)
        SelfAuraColor = c
        if SelfAuraEnabled then refreshSelfAura() end
    end,
})

SkyTab:Toggle({
    Title = "Enable Skybox",
    Value = false,
    Callback = function(v)
        SkyboxEnabled = v
        if v then
            Skybox_Apply(CurrentSkybox)
        else
            Skybox_RestoreDefault()
        end
    end,
})

SkyTab:Dropdown({
    Title = "Select Skybox",
    Values = skyboxList,
    Callback = function(opt)
        local name = type(opt) == "table" and (opt.Title or opt[1] or opt) or opt
        if not name or name == "" then return end
        CurrentSkybox = name
        if SkyboxEnabled then
            Skybox_Apply(CurrentSkybox)
        end
    end,
})

SkyTab:Button({
    Title = "Restore Default Sky",
    Callback = function()
        SkyboxEnabled = false
        Skybox_RestoreDefault()
        notify("SkyBox", "Небо сброшено")
    end,
})

ShaderTab:Dropdown({
    Title = "Time Shader",
    Values = {"Lite", "Morning", "Midday", "Afternoon", "Evening", "Night", "Midnight"},
    Value = "Lite",
    Callback = function(opt)
        local name = type(opt) == "table" and (opt.Title or opt[1] or opt) or opt
        if name == "Lite" then
            resetShader()
            notify("Shader", "Lite")
            return
        end
        if ShaderPresets[name] then
            applyShaderPreset(ShaderPresets[name])
            notify("Shader", name)
        end
    end,
})

ShaderTab:Dropdown({
    Title = "Weather Shader",
    Values = {"Lite", "Sunny", "Rain", "Snow", "Fog", "Storm"},
    Value = "Lite",
    Callback = function(opt)
        local name = type(opt) == "table" and (opt.Title or opt[1] or opt) or opt
        if name == "Lite" then
            resetShader()
            notify("Shader", "Lite")
            return
        end
        if ShaderPresets[name] then
            applyShaderPreset(ShaderPresets[name])
            notify("Shader", name)
        end
    end,
})

ShaderTab:Dropdown({
    Title = "Color Shader",
    Values = {"Lite", "Red", "Blue", "Green", "Purple", "Pink"},
    Value = "Lite",
    Callback = function(opt)
        local name = type(opt) == "table" and (opt.Title or opt[1] or opt) or opt
        if name == "Lite" then
            resetShader()
            notify("Shader", "Lite")
            return
        end
        if ShaderPresets[name] then
            applyShaderPreset(ShaderPresets[name])
            notify("Shader", name)
        end
    end,
})

