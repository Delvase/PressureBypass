local WindUI
local windOk, windErr = pcall(function()
    WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)
if not windOk or not WindUI then
    windOk, windErr = pcall(function()
        WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
    end)
end
if not windOk or not WindUI then
    warn("[Hub] WindUI failed to load:", windErr)
    return
end

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

local function table_clear(t)
    if type(t) ~= "table" then return end
    local native = rawget(table, "clear")
    if native then
        native(t)
        return
    end
    for k in pairs(t) do
        t[k] = nil
    end
end

local WalkSpeedValue = 16
local JumpPowerValue = 50
local InfJump = false
local SpeedGlitch = false
local SpeedGlitchValue = 50

local AutoGrab = false
local GunNotify = false
local SuccessNotify = false
local isGrabbing = false
local PlayerStatus = "Spectate"
local statusLabelRef = nil

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

local function getPlayerStatus()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not hum or hum.Health <= 0 then
        return "Spectate"
    end

    local entry = roleTable and roleTable[LocalPlayer.Name]
    if entry then
        if entry.Dead then
            return "Spectate"
        end
        if entry.Role == "Murderer" or entry.Role == "Sheriff" or entry.Role == "Innocent" or entry.Role == "Hero" then
            return "Match"
        end
    end

    local m = nil
    pcall(function()
        m = require(ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("CurrentRoundClient"))
    end)
    if type(m) == "table" and type(m.PlayerData) == "table" then
        local me = m.PlayerData[LocalPlayer.Name]
        if me then
            if me.Dead then return "Spectate" end
            if me.Role == "Murderer" or me.Role == "Sheriff" or me.Role == "Innocent" or me.Role == "Hero" then
                return "Match"
            end
        end
    end

    if Workspace:FindFirstChild("GunDrop", true) then
        return "Match"
    end

    return "Spectate"
end

local function refreshPlayerStatus()
    PlayerStatus = getPlayerStatus()
    if statusLabelRef then
        pcall(function()
            if statusLabelRef.SetDesc then
                statusLabelRef:SetDesc(PlayerStatus)
            elseif statusLabelRef.Set then
                statusLabelRef:Set(PlayerStatus)
            end
        end)
    end
    return PlayerStatus
end

local function GrabGun(force)
    if not force then
        refreshPlayerStatus()
        if PlayerStatus ~= "Match" then
            return
        end
    end
    if isGrabbing then return end
    if hasGun() then return end

    isGrabbing = true

    local character = LocalPlayer.Character
    if not character then
        isGrabbing = false
        return
    end

    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then
        isGrabbing = false
        return
    end

    local maxAttempts = 55
    local attempts = 0
    local originalCFrame = root.CFrame

    while attempts < maxAttempts and not hasGun() do
        local gunDrop = Workspace:FindFirstChild("GunDrop", true)

        if gunDrop then
            local success = pcall(function()
                local target = root.CFrame * CFrame.new(
                    (math.random() - 0.5) * 0.4,
                    1.15 + math.random() * 0.3,
                    (math.random() - 0.5) * 0.4
                )

                if gunDrop:IsA("BasePart") then
                    gunDrop.Anchored = false
                    gunDrop.CanCollide = false
                    gunDrop.AssemblyLinearVelocity = Vector3.zero
                    gunDrop.AssemblyAngularVelocity = Vector3.zero
                    gunDrop.CFrame = target
                else
                    local part = gunDrop:FindFirstChild("Handle")
                        or gunDrop:FindFirstChildWhichIsA("BasePart")
                        or gunDrop.PrimaryPart

                    if part and part:IsA("BasePart") then
                        part.Anchored = false
                        part.CanCollide = false
                        part.AssemblyLinearVelocity = Vector3.zero
                        part.AssemblyAngularVelocity = Vector3.zero
                        part.CFrame = target
                    else
                        gunDrop:PivotTo(target)
                    end
                end
            end)

            if not success then
                pcall(function()
                    root.CFrame = gunDrop:IsA("BasePart") and gunDrop.CFrame or gunDrop:GetPivot()
                    task.wait(0.12)
                    root.CFrame = originalCFrame
                end)
            end
        end

        task.wait(0.018 + math.random() * 0.012)
        attempts = attempts + 1
    end

    if hasGun() and SuccessNotify then
        notify("GrabGun", "Gun successfully grabbed!")
    end

    isGrabbing = false
end

local function onGunDropDetected(gunDrop)
    if GunNotify then
        notify("Gun Dropped", "GunDrop appeared on the map!")
    end
    if AutoGrab then
        refreshPlayerStatus()
        if PlayerStatus == "Match" then
            task.spawn(GrabGun)
        end
    end
end

local function setupGunDropListener(parent)
    parent.ChildAdded:Connect(function(child)
        if child.Name == "GunDrop" then
            task.wait(0.1)
            onGunDropDetected(child)
        end
        if child:IsA("Model") or child:IsA("Folder") then
            setupGunDropListener(child)
        end
    end)
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("Model") or child:IsA("Folder") then
            setupGunDropListener(child)
        end
    end
end

setupGunDropListener(Workspace)

Workspace.ChildAdded:Connect(function(child)
    if child:IsA("Model") or child:IsA("Folder") then
        setupGunDropListener(child)
    end
    if child.Name == "GunDrop" then
        task.wait(0.1)
        onGunDropDetected(child)
    end
end)

task.spawn(function()
    task.wait(1)
    local existing = Workspace:FindFirstChild("GunDrop", true)
    if existing then
        onGunDropDetected(existing)
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
    return false
end


local function getEspRoot(plr)
    local char = plr and plr.Character
    if not char then return nil, nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then return hrp, char end
    local head = char:FindFirstChild("Head")
    if head then return head, char end
    local part = char:FindFirstChildWhichIsA("BasePart")
    if part then return part, char end
    return nil, char
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

local BODY_PARTS = {
    "HumanoidRootPart", "Head", "Torso", "UpperTorso", "LowerTorso",
    "Left Arm", "Right Arm", "Left Leg", "Right Leg",
    "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
    "LeftHand", "RightHand", "LeftUpperLeg", "RightUpperLeg",
    "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot"
}

local function lightUninvis(char)
    for i = 1, #BODY_PARTS do
        local p = char:FindFirstChild(BODY_PARTS[i])
        if p and p:IsA("BasePart") and p.LocalTransparencyModifier ~= 0 then
            p.LocalTransparencyModifier = 0
        end
    end
end

local function applyHighlight(plr, color, chams, outline)
    local char = plr.Character
    if not char then return end
    if chams then
        lightUninvis(char)
    end
    local hl = highlightObjects[plr]
    if not hl or not hl.Parent then
        if hl then pcall(function() hl:Destroy() end) end
        hl = Instance.new("Highlight")
        hl.Name = "HubESP_" .. plr.Name
        hl.Adornee = char
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = espGuiParent
        highlightObjects[plr] = hl
    end
    hl.Adornee = char
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    if chams and outline then
        hl.FillColor = color
        hl.FillTransparency = 0.35
        hl.OutlineColor = color
        hl.OutlineTransparency = 0
    elseif chams then
        hl.FillColor = color
        hl.FillTransparency = 0.35
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
    if not obj then return end
    if obj.box then
        for _, line in pairs(obj.box) do
            if line then line.Visible = false end
        end
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
    pcall(createGunESP, obj)
    pcall(function()
        obj.AncestryChanged:Connect(function(_, parent)
            if not parent then
                pcall(removeGunESP, obj)
                pcall(removeGunHighlight, obj)
            end
        end)
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
            if not obj then
                createESP(plr)
                obj = espObjects[plr]
            end
            if not obj then continue end
            local root, char = getEspRoot(plr)
            local role = getRole(plr)
            local dead = isDead(plr)

            if not root then
                hideDrawings(obj)
                removeHighlight(plr)
            else
                local color = dead and espSettings.UnknownColor or getDisplayColor(role)
                local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)
                local dist = myHRP and (myHRP.Position - root.Position).Magnitude or 0
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
                        local head = char and char:FindFirstChild("Head")
                        local topPos = head and Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0)) or screenPos
                        local botPos = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
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
                        local head = char and char:FindFirstChild("Head")
                        obj.billboard.Adornee = head or root or char
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
        if ESPMaster then
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

pcall(function()
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if desc.Name == "GunDrop" then
            pcall(registerGunDrop, desc)
        end
    end
end)

Workspace.DescendantAdded:Connect(function(desc)
    if desc.Name == "GunDrop" then
        task.defer(registerGunDrop, desc)
    end
end)

RunService.RenderStepped:Connect(function()
    local ok, err = pcall(updateESP)
    if not ok then
        -- silent; avoid console spam
    end
end)

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
    table_clear(selfAuraParticles)
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



-- ==================== MURDER (логика из toolbox_mm2) ====================
local AutoThrowEnabled = false
local AutoKillAllEnabled = false
local autoThrowReady = true
local autoKillReady = true
local killingPlayer = nil

local function murderGetPlayers()
    return Players:GetPlayers()
end

local function throwKnife()
    task.spawn(function()
        if getRole(LocalPlayer) ~= "Murderer" then
            return
        end
        if isDead(LocalPlayer) then
            return
        end
        local Character = LocalPlayer.Character
        local hrp = Character and Character:FindFirstChild("HumanoidRootPart")
        if not hrp then
            return
        end

        local nearest = nil
        local nearestDist = math.huge
        for _, plr in ipairs(murderGetPlayers()) do
            if plr ~= LocalPlayer and not isDead(plr) and getRole(plr) ~= "Unknown" then
                local otherChar = plr.Character
                local otherHRP = otherChar and otherChar:FindFirstChild("HumanoidRootPart")
                if otherHRP then
                    local dist = (hrp.Position - otherHRP.Position).Magnitude
                    if dist < nearestDist then
                        nearestDist = dist
                        nearest = plr
                    end
                end
            end
        end
        if not nearest or not nearest.Character then
            return
        end
        local targetHRP = nearest.Character:FindFirstChild("HumanoidRootPart")
        if not targetHRP then
            return
        end

        local Knife = Character:FindFirstChild("Knife") or LocalPlayer.Backpack:FindFirstChild("Knife")
        if not Knife then
            return
        end
        if Character ~= Knife.Parent then
            Knife.Parent = Character
            task.wait(0.1)
        end
        local Knife2 = Character:FindFirstChild("Knife")
        if not Knife2 then
            return
        end
        local Handle = Knife2:FindFirstChild("Handle")
        local Events = Knife2:FindFirstChild("Events")
        local KnifeThrown = Events and Events:FindFirstChild("KnifeThrown")
        if not KnifeThrown or not Handle then
            return
        end
        KnifeThrown:FireServer(Handle.CFrame, CFrame.new(targetHRP.Position, hrp.Position))
    end)
end

local function killPlayer(target)
    task.spawn(function()
        local Character = LocalPlayer.Character
        if not Character then
            return
        end
        local targetChar = target.Character
        local targetHRP = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
        if not targetHRP then
            return
        end

        killingPlayer = target.Name

        local Knife = Character:FindFirstChild("Knife") or LocalPlayer.Backpack:FindFirstChild("Knife")
        if Knife and Character ~= Knife.Parent then
            Knife.Parent = Character
        end
        local Knife3 = Character:FindFirstChild("Knife")
        if not Knife3 then
            killingPlayer = nil
            return
        end

        local Handle = Knife3:FindFirstChild("Handle")
        local Events = Knife3:FindFirstChild("Events")
        local HandleTouched = Events and Events:FindFirstChild("HandleTouched")

        if Handle and HandleTouched then
            local Weld = Handle:FindFirstChildWhichIsA("Weld") or Handle:FindFirstChildWhichIsA("WeldConstraint")
            if Weld then
                Weld.Enabled = false
            end

            local HandleParent = Handle.Parent
            local HandleCFrame = Handle.CFrame

            Handle.Parent = workspace
            Handle.CFrame = targetHRP.CFrame
            task.wait()
            HandleTouched:FireServer(targetHRP)
            task.wait()
            Handle.CFrame = HandleCFrame
            Handle.Parent = HandleParent

            if Weld then
                Weld.Enabled = true
            end
        end

        killingPlayer = nil
    end)
end

local function killAll()
    task.spawn(function()
        local Character = LocalPlayer.Character
        if not Character then
            return
        end
        if getRole(LocalPlayer) ~= "Murderer" then
            return
        end
        if isDead(LocalPlayer) then
            return
        end

        local Knife = Character:FindFirstChild("Knife") or LocalPlayer.Backpack:FindFirstChild("Knife")
        if Knife and Character ~= Knife.Parent then
            Knife.Parent = Character
            task.wait(0.1)
        end
        local Knife4 = Character:FindFirstChild("Knife")
        if not Knife4 then
            return
        end
        local Handle = Knife4:FindFirstChild("Handle")
        local Events = Knife4:FindFirstChild("Events")
        local HandleTouched = Events and Events:FindFirstChild("HandleTouched")
        if not Handle or not HandleTouched then
            return
        end

        local targets = {}
        for _, plr in ipairs(murderGetPlayers()) do
            if plr ~= LocalPlayer and not isDead(plr) and getRole(plr) ~= "Unknown" then
                local otherChar = plr.Character
                local otherHRP = otherChar and otherChar:FindFirstChild("HumanoidRootPart")
                if otherHRP then
                    table.insert(targets, otherHRP)
                end
            end
        end
        if #targets == 0 then
            return
        end

        local Weld = Handle:FindFirstChildWhichIsA("Weld") or Handle:FindFirstChildWhichIsA("WeldConstraint")
        if Weld then
            Weld.Enabled = false
        end
        local HandleParent = Handle.Parent
        local HandleCFrame = Handle.CFrame
        Handle.Parent = workspace
        for _, hrpPart in ipairs(targets) do
            pcall(function()
                Handle.CFrame = hrpPart.CFrame
                task.wait()
                HandleTouched:FireServer(hrpPart)
                task.wait()
            end)
        end
        Handle.CFrame = HandleCFrame
        Handle.Parent = HandleParent
        if Weld then
            Weld.Enabled = true
        end
    end)
end

local function killSheriff()
    for _, plr in ipairs(murderGetPlayers()) do
        if plr ~= LocalPlayer and not isDead(plr) then
            local role = getRole(plr)
            if role == "Sheriff" or role == "Hero" then
                task.spawn(function()
                    killPlayer(plr)
                end)
                return
            end
        end
    end
end

RunService.Heartbeat:Connect(function()
    if AutoThrowEnabled and autoThrowReady then
        autoThrowReady = false
        throwKnife()
        task.delay(0.25, function()
            autoThrowReady = true
        end)
    end
end)

RunService.Heartbeat:Connect(function()
    if AutoKillAllEnabled and autoKillReady then
        autoKillReady = false
        killAll()
        task.delay(0.1, function()
            autoKillReady = true
        end)
    end
end)


-- ==================== CHINA HAT ====================
local ChinaHatEnabled = false
local ChinaHatColor = Color3.fromRGB(255, 105, 180)
local ChinaHatScale = Vector3.new(1.7, 1.1, 1.7)
local chinaHatPart = nil

local function destroyChinaHat()
    if chinaHatPart then
        pcall(function() chinaHatPart:Destroy() end)
        chinaHatPart = nil
    end
    local char = LocalPlayer.Character
    if char then
        for _, child in ipairs(char:GetChildren()) do
            if child.Name == "HubChinaHat" then
                pcall(function() child:Destroy() end)
            end
        end
    end
end

local function createChinaHat(character)
    destroyChinaHat()
    if not ChinaHatEnabled or not character then return end
    local Head = character:FindFirstChild("Head")
    if not Head then return end

    local Cone = Instance.new("Part")
    Cone.Name = "HubChinaHat"
    Cone.Size = Vector3.new(1, 1, 1)
    Cone.Material = Enum.Material.Neon
    Cone.Transparency = 0.2
    Cone.Anchored = false
    Cone.CanCollide = false
    Cone.Massless = true
    Cone.Color = ChinaHatColor

    local Mesh = Instance.new("SpecialMesh")
    Mesh.MeshType = Enum.MeshType.FileMesh
    Mesh.MeshId = "rbxassetid://1033714"
    Mesh.Scale = ChinaHatScale
    Mesh.Parent = Cone

    local Weld = Instance.new("Weld")
    Weld.Part0 = Head
    Weld.Part1 = Cone
    Weld.C0 = CFrame.new(0, 0.9, 0)
    Weld.Parent = Cone

    local Light = Instance.new("PointLight")
    Light.Color = ChinaHatColor
    Light.Brightness = 0
    Light.Range = 12
    Light.Shadows = true
    Light.Parent = Cone

    Cone.Parent = character
    chinaHatPart = Cone
end

LocalPlayer.CharacterAdded:Connect(function(character)
    task.wait(0.5)
    if ChinaHatEnabled then
        createChinaHat(character)
    end
end)

if LocalPlayer.Character and ChinaHatEnabled then
    createChinaHat(LocalPlayer.Character)
end

-- ==================== UI (WindUI) ====================
local MainTab = Window:Tab({ Title = "Main", Icon = "zap" })
local GunTab = Window:Tab({ Title = "Gun", Icon = "target" })
local MurderTab = Window:Tab({ Title = "Murder", Icon = "skull" })
local EspTab = Window:Tab({ Title = "ESP", Icon = "eye" })
local VisualTab = Window:Tab({ Title = "Visuals", Icon = "sparkles" })
local SkyTab = Window:Tab({ Title = "SkyBox", Icon = "cloud-sun" })
local ShaderTab = Window:Tab({ Title = "Shaders", Icon = "palette" })
local StatusTab = Window:Tab({ Title = "Status", Icon = "activity" })

statusLabelRef = StatusTab:Paragraph({
    Title = "Current Status",
    Desc = PlayerStatus,
})

StatusTab:Button({
    Title = "Refresh Status",
    Callback = function()
        local s = refreshPlayerStatus()
        notify("Status", s)
        pcall(function()
            if statusLabelRef and statusLabelRef.SetDesc then
                statusLabelRef:SetDesc(s)
            end
        end)
    end,
})

StatusTab:Paragraph({
    Title = "Info",
    Desc = "Spectate = lobby / dead\nMatch = alive in round\nGrab Gun works only in Match",
})

task.spawn(function()
    while true do
        refreshPlayerStatus()
        task.wait(1)
    end
end)

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
        if v then
            refreshPlayerStatus()
            if PlayerStatus == "Match" and Workspace:FindFirstChild("GunDrop", true) and not hasGun() then
                task.spawn(GrabGun)
            end
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
        task.spawn(function() GrabGun(true) end)
    end,
})

GunTab:Button({
    Title = "Status",
    Callback = function()
        local has = hasGun()
        local drop = Workspace:FindFirstChild("GunDrop", true)
        notify("Status", has and "Gun in inventory" or (drop and "GunDrop on map" or "No gun"))
    end,
})


MurderTab:Button({
    Title = "Kill All",
    Callback = function()
        killAll()
    end,
})

MurderTab:Button({
    Title = "Kill Sheriff",
    Callback = function()
        killSheriff()
    end,
})

MurderTab:Button({
    Title = "Throw Knife (Nearest)",
    Callback = function()
        throwKnife()
    end,
})

MurderTab:Toggle({
    Title = "Auto Throw Nearest",
    Value = false,
    Callback = function(v)
        AutoThrowEnabled = v
    end,
})

MurderTab:Toggle({
    Title = "Auto Kill All",
    Value = false,
    Callback = function(v)
        AutoKillAllEnabled = v
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


VisualTab:Toggle({
    Title = "China Hat",
    Value = false,
    Callback = function(v)
        ChinaHatEnabled = v
        if v then
            createChinaHat(LocalPlayer.Character)
        else
            destroyChinaHat()
        end
    end,
})

VisualTab:Colorpicker({
    Title = "China Hat Color",
    Default = Color3.fromRGB(255, 105, 180),
    Callback = function(c)
        ChinaHatColor = c
        if chinaHatPart and chinaHatPart.Parent then
            chinaHatPart.Color = c
            local light = chinaHatPart:FindFirstChildOfClass("PointLight")
            if light then light.Color = c end
        elseif ChinaHatEnabled then
            createChinaHat(LocalPlayer.Character)
        end
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
        notify("SkyBox", "Sky reset")
    end,
})

ShaderTab:Dropdown({
    Title = "Time Shader",
    Values = {"Lite", "Morning", "Midday", "Afternoon", "Evening", "Night", "Midnight"},
    Callback = function(opt)
        local name = type(opt) == "table" and (opt.Title or opt[1] or opt) or opt
        if not name or name == "" then return end
        if name == "Lite" then
            resetShader()
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
    Callback = function(opt)
        local name = type(opt) == "table" and (opt.Title or opt[1] or opt) or opt
        if not name or name == "" then return end
        if name == "Lite" then
            resetShader()
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
    Callback = function(opt)
        local name = type(opt) == "table" and (opt.Title or opt[1] or opt) or opt
        if not name or name == "" then return end
        if name == "Lite" then
            resetShader()
            return
        end
        if ShaderPresets[name] then
            applyShaderPreset(ShaderPresets[name])
            notify("Shader", name)
        end
    end,
})



local SheriffTab = Window:Tab({ Title = "Sheriff", Icon = "crosshair" })

local SA = {
    enabled = false,
    am_sheriff = false,
    predict = true,
    force = false,
    auto_on = false,
    auto_delay = 0.25,
    fire_gap = 0.15,
    stand_off = 30,
    last_shot = 0,
}

local SP = {
    lead_scale = 1.0,
    lead_add = 0,
    min_span = 8,
    max_span = 60,
}

local TR = {
    vel = Vector3.zero,
    fresh = Vector3.zero,
    fresh_ok = false,
    ready = false,
    air = false,
    jumping = false,
    jump_v = 0,
    air_since = 0,
}

local _SNAP_CAP = 64
local snap_t = {}
local snap_p = {}
for i = 1, _SNAP_CAP do
    snap_t[i] = 0
    snap_p[i] = Vector3.zero
end
local snap_n, snap_i = 0, 0

local function snap_push(t, p)
    snap_i = snap_i % _SNAP_CAP + 1
    snap_t[snap_i] = t
    snap_p[snap_i] = p
    if snap_n < _SNAP_CAP then snap_n = snap_n + 1 end
end

local function snap_get(k)
    local idx = (snap_i - k - 1) % _SNAP_CAP + 1
    return snap_t[idx], snap_p[idx]
end

local target_char = nil
local target_part = nil
local target_hum = nil
local round_mod = nil
local MAX_RANGE = 1000

local function grav()
    local ok, g = pcall(function() return Workspace.Gravity end)
    return (ok and g) or 196.2
end

local _ray_params = RaycastParams.new()
_ray_params.FilterType = Enum.RaycastFilterType.Exclude
_ray_params.IgnoreWater = true

local function trace(origin, delta)
    local char = LocalPlayer.Character
    _ray_params.FilterDescendantsInstances = char and {char} or {}
    return Workspace:Raycast(origin, delta, _ray_params)
end

local function get_round()
    if not round_mod then
        local ok, m = pcall(function()
            return require(ReplicatedStorage:WaitForChild("Modules", 5):WaitForChild("CurrentRoundClient", 5))
        end)
        if ok and type(m) == "table" then round_mod = m end
    end
    return round_mod
end

local function find_murderer()
    local m = get_round()
    if not m then return nil end
    local data = m.PlayerData
    if type(data) ~= "table" then return nil end
    for name, info in pairs(data) do
        if type(info) == "table" and not info.Dead and info.Role == "Murderer" and name ~= LocalPlayer.Name then
            local pl = Players:FindFirstChild(name)
            if pl and pl.Character then return pl.Character end
        end
    end
    return nil
end

local function refresh_target()
    local m = get_round()
    if m then
        local data = m.PlayerData
        local me = data and data[LocalPlayer.Name]
        if me then
            SA.am_sheriff = not me.Dead and (me.Role == "Sheriff" or me.Role == "Hero")
        else
            SA.am_sheriff = false
        end
    else
        local char = LocalPlayer.Character
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        SA.am_sheriff = (char and char:FindFirstChild("Gun") ~= nil)
            or (bp and bp:FindFirstChild("Gun") ~= nil)
    end

    local char = find_murderer()
    if char then
        target_char = char
        target_part = char:FindFirstChild("HumanoidRootPart")
            or char:FindFirstChild("UpperTorso")
            or char:FindFirstChild("Torso")
            or char:FindFirstChild("Head")
        target_hum = char:FindFirstChildOfClass("Humanoid")
    else
        target_char = nil
        target_part = nil
        target_hum = nil
    end
end

local function target_alive()
    if not target_char or not target_part then return false end
    if not target_part.Parent then return false end
    if target_hum and target_hum.Health <= 0 then return false end
    return true
end

local _ping_samples = {}
local _PING_CAP = 12

local function sample_ping()
    local ok, p = pcall(function() return LocalPlayer:GetNetworkPing() end)
    if ok and type(p) == "number" and p == p and p >= 0 then
        table.insert(_ping_samples, 1, p)
        if #_ping_samples > _PING_CAP then
            _ping_samples[_PING_CAP + 1] = nil
        end
    end
end

local function ping_avg()
    local n = #_ping_samples
    if n == 0 then return 0.07 end
    local s = 0
    for i = 1, n do s = s + _ping_samples[i] end
    return s / n
end

local function lead_time()
    return ping_avg() * SP.lead_scale + SP.lead_add
end

local function track(now)
    local part = target_part
    if not part or not part.Parent then return end
    local pos = part.Position
    snap_push(now, pos)

    if snap_n >= 2 then
        local t0, p0 = snap_get(0)
        local t1, p1 = snap_get(1)
        local dt = t0 - t1
        if dt > 0.001 then
            TR.fresh = (p0 - p1) / dt
            TR.fresh_ok = true
        end
    end

    if snap_n >= 3 then
        local t0, p0 = snap_get(0)
        local tn, pn = snap_get(math.min(snap_n - 1, 15))
        local dt = t0 - tn
        if dt > 0.05 then
            TR.vel = (p0 - pn) / dt
            TR.ready = true
        end
    end
end

local function predict_from(base, vel_y, dt, vel_h)
    local g = grav()
    local pred = base + vel_h * dt
    if TR.air then
        local vy = (TR.fresh_ok and TR.fresh.Y) or vel_y
        pred = Vector3.new(pred.X, pred.Y + vy * dt - 0.5 * g * dt * dt, pred.Z)
    end
    return pred
end

local pred_stamp = 0
local pred_off = Vector3.zero

local function lead_offset()
    local part = target_part
    if not part or not part.Parent then return Vector3.zero end
    if not SA.predict or not TR.ready then return Vector3.zero end
    local base = part.Position
    local now = os.clock()
    local fh = Vector3.new(TR.fresh.X, 0, TR.fresh.Z)
    local pt = predict_from(base, 0, lead_time(), fh)
    pred_stamp = now
    pred_off = pt - base
    return pred_off
end

local _hit_priority = {
    "HumanoidRootPart", "UpperTorso", "Torso", "LowerTorso", "Head",
    "RightUpperArm", "LeftUpperArm", "Right Arm", "Left Arm",
    "RightUpperLeg", "LeftUpperLeg", "Right Leg", "Left Leg",
    "RightLowerLeg", "LeftLowerLeg",
}

local _hit_cache = {}
local _hit_count = 0
local _hit_char = nil

local function refresh_parts()
    local char = target_char
    if char == _hit_char then return end
    for k in pairs(_hit_cache) do _hit_cache[k] = nil end
    _hit_count = 0
    _hit_char = char
    if not char then return end
    for k = 1, #_hit_priority do
        local p = char:FindFirstChild(_hit_priority[k])
        if p and p:IsA("BasePart") then
            _hit_count = _hit_count + 1
            _hit_cache[_hit_count] = p
        end
    end
end

local function los_clear(origin, point)
    if not origin or not point then return false end
    local delta = point - origin
    local dist = delta.Magnitude
    if dist < 0.5 then return true end
    if dist > MAX_RANGE then return false end
    local hit = trace(origin, delta)
    if not hit then return true end
    local inst = hit.Instance
    local char = target_char
    if inst and char and (inst == char or inst:IsDescendantOf(char)) then return true end
    return (hit.Position - origin).Magnitude >= dist - 0.75
end

local function pick_point(origin, strict)
    refresh_parts()
    if _hit_count == 0 then return nil end
    local off = lead_offset()
    local first = nil
    for k = 1, _hit_count do
        local part = _hit_cache[k]
        if not part or not part.Parent then
            _hit_char = nil
        else
            local point = part.Position + off
            if not origin then return point end
            if not first then first = point end
            if los_clear(origin, point) then return point end
        end
    end
    if strict then return nil end
    return first
end

local function gun_attachment()
    local char = LocalPlayer.Character
    if not char then return nil end
    local gun = char:FindFirstChild("Gun")
    if not gun then return nil end
    local handle = gun:FindFirstChild("Handle") or gun:FindFirstChildWhichIsA("BasePart")
    if not handle then return nil end
    return handle:FindFirstChild("GunAttachment")
        or handle:FindFirstChild("ShootAttachment")
        or handle:FindFirstChild("MuzzleAttachment")
        or handle:FindFirstChildWhichIsA("Attachment")
end

local function origin_cframe()
    local att = gun_attachment()
    if att then
        local ok, cf = pcall(function() return att.WorldCFrame end)
        if ok then return cf end
    end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then return hrp.CFrame end
    return nil
end

local force_att = nil
local force_saved = nil
local force_stamp = 0

local function restore_origin()
    local att = force_att
    if not att then return end
    local saved = force_saved
    force_att = nil
    force_saved = nil
    if saved then
        pcall(function()
            if att.Parent then att.CFrame = saved end
        end)
    end
end

local function push_origin(cf)
    local att = gun_attachment()
    if not att then return false end
    if force_att and force_att ~= att then restore_origin() end
    if not force_att then
        local ok, saved = pcall(function() return att.CFrame end)
        if not ok or typeof(saved) ~= "CFrame" then return false end
        force_att = att
        force_saved = saved
    end
    force_stamp = os.clock()
    local ok = pcall(function() att.WorldCFrame = cf end)
    if not ok then
        restore_origin()
        return false
    end
    task.defer(restore_origin)
    return true
end

local function shot_shift(dt)
    if not SA.predict or not TR.ready or dt <= 0 then return Vector3.zero end
    local shift = Vector3.new(TR.vel.X * dt, 0, TR.vel.Z * dt)
    if TR.air then
        local g = grav()
        local lt = lead_time()
        local vy = TR.vel.Y
        local phase = math.max(0, os.clock() - TR.air_since)
        local modeled = TR.jump_v - g * phase
        if TR.jumping and TR.jump_v > 0 and g > 0 and phase <= TR.jump_v / g and modeled > vy then
            vy = modeled
        end
        shift = Vector3.new(shift.X, vy * dt - g * lt * dt - 0.5 * g * dt * dt, shift.Z)
    end
    return shift
end

local function compensate_resolve(cf)
    if SA.force or typeof(cf) ~= "CFrame" then return cf end
    return CFrame.new(cf.Position + shot_shift(math.max(0, os.clock() - pred_stamp)))
end

local function resolve_force()
    local part = target_part
    if not part or not part.Parent then return nil end
    local live = part.Position
    local vel = (TR.fresh_ok and TR.fresh) or TR.vel
    local dt = lead_time()

    local dir
    if vel and vel.Magnitude > 3 then
        dir = vel.Unit
    else
        local mine = origin_cframe()
        if mine then
            local delta = live - mine.Position
            if delta.Magnitude > 2 then dir = delta.Unit end
        end
        if not dir then dir = Vector3.new(0, -1, 0) end
    end

    local front_dist = math.max(SP.min_span, vel.Magnitude * dt + 8)
    local back = live - dir * 6
    local front = live + dir * front_dist

    local hit = trace(back, front - back)
    if hit and hit.Instance then
        local inst = hit.Instance
        local char = target_char
        if not (char and (inst == char or inst:IsDescendantOf(char))) then
            back = live - dir * 2
        end
    end

    local u = (front - back).Unit
    local want = SA.stand_off
    while want > 0 do
        local probe = back - u * want
        if (front - probe).Magnitude <= SP.max_span and los_clear(probe, live) then
            back = probe
            break
        end
        want = want - 3
    end

    if (front - back).Magnitude > SP.max_span then
        back = front - u * SP.max_span
    end

    return CFrame.new(back, front), CFrame.new(front)
end

local function compensate_force(ocf, acf, started)
    local shift = shot_shift(math.max(0, os.clock() - started))
    if shift == Vector3.zero then return ocf, acf end
    return CFrame.new(ocf.Position + shift, acf.Position + shift), CFrame.new(acf.Position + shift)
end

local function resolve_shot()
    if not SA.enabled or not SA.am_sheriff or not target_alive() then
        return nil
    end

    if SA.force then
        local started = os.clock()
        local ocf, acf = resolve_force()
        if ocf and acf then
            ocf, acf = compensate_force(ocf, acf, started)
            if push_origin(ocf) then return acf end
        end
    end

    local cf = origin_cframe()
    local aim = pick_point(cf and cf.Position or nil, false)
    if not aim then return nil end
    return CFrame.new(aim)
end

local _wsvc = nil
local orig_mouse = nil
local orig_screen = nil
local hook_mouse = nil
local hook_screen = nil

local function get_weapon_service()
    if _wsvc then return _wsvc end
    local ok, m = pcall(function()
        return require(ReplicatedStorage:WaitForChild("ClientServices", 5):WaitForChild("WeaponService", 5))
    end)
    if ok and type(m) == "table" then _wsvc = m end
    return _wsvc
end

local function install_hooks()
    local m = get_weapon_service()
    if not m then return end

    local hf = nil
    pcall(function() hf = hookfunction end)
    if type(hf) ~= "function" and getgenv then
        pcall(function() hf = getgenv().hookfunction end)
    end

    if not hook_mouse then
        hook_mouse = function(self, ...)
            sample_ping()
            if SA.enabled and SA.am_sheriff then
                local ok, cf = pcall(resolve_shot)
                if ok and cf then return compensate_resolve(cf) end
            end
            if type(orig_mouse) == "function" then
                return orig_mouse(self, ...)
            end
        end

        hook_screen = function(self, x, y, ...)
            sample_ping()
            if SA.enabled and SA.am_sheriff then
                local ok, cf = pcall(resolve_shot)
                if ok and cf then return compensate_resolve(cf) end
            end
            if type(orig_screen) == "function" then
                return orig_screen(self, x, y, ...)
            end
        end
    end

    if type(m.GetMouseTargetCFrame) == "function" and not orig_mouse then
        if type(hf) == "function" then
            local ok, res = pcall(function()
                return hf(m.GetMouseTargetCFrame, hook_mouse)
            end)
            if ok and type(res) == "function" then
                orig_mouse = res
            end
        end
        if not orig_mouse then
            pcall(function()
                if type(setreadonly) == "function" then setreadonly(m, false) end
            end)
            orig_mouse = m.GetMouseTargetCFrame
            pcall(function() m.GetMouseTargetCFrame = hook_mouse end)
        end
    end

    if type(m.GetTargetPosition) == "function" and not orig_screen then
        if type(hf) == "function" then
            local ok, res = pcall(function()
                return hf(m.GetTargetPosition, hook_screen)
            end)
            if ok and type(res) == "function" then
                orig_screen = res
            end
        end
        if not orig_screen then
            pcall(function()
                if type(setreadonly) == "function" then setreadonly(m, false) end
            end)
            orig_screen = m.GetTargetPosition
            pcall(function() m.GetTargetPosition = hook_screen end)
        end
    end
end

local gap_gun = nil
local want_since = 0
local last_fire_stamp = 0
local gap_samples = {}
local _GAP_CAP = 8

local function gap_reset()
    for k in pairs(gap_samples) do gap_samples[k] = nil end
end

local function gap_push(dt)
    table.insert(gap_samples, 1, dt)
    if #gap_samples > _GAP_CAP then gap_samples[_GAP_CAP + 1] = nil end
end

local function fire_gap_avg()
    local n = #gap_samples
    if n == 0 then return SA.fire_gap end
    local s = 0
    for i = 1, n do s = s + gap_samples[i] end
    return s / n
end

local function get_gun()
    local char = LocalPlayer.Character
    if char then
        local g = char:FindFirstChild("Gun")
        if g then return g, true end
    end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then
        local g = bp:FindFirstChild("Gun")
        if g then return g, false end
    end
    return nil, false
end

local function fire_gun(gun, start_cf, aim_cf)
    if not gun or not start_cf or not aim_cf then return false end
    local remote = gun:FindFirstChild("Shoot")
    if not remote or not remote:IsA("RemoteEvent") then return false end
    return (pcall(function() remote:FireServer(start_cf, aim_cf) end))
end

local function auto_step(now)
    if not SA.auto_on or not SA.enabled or not SA.am_sheriff or not target_alive() then
        want_since = 0
        return
    end

    local gun, equipped = get_gun()
    if not gun then want_since = 0 return end

    if gun ~= gap_gun then
        gap_gun = gun
        gap_reset()
    end

    if not equipped then
        want_since = 0
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum:EquipTool(gun) end) end
        return
    end

    if want_since == 0 then want_since = now end

    local hold = math.max(SA.auto_delay, fire_gap_avg())
    local since = last_fire_stamp > 0 and last_fire_stamp or SA.last_shot
    if now - since < hold then return end

    if SA.force then
        local started = os.clock()
        local ocf, acf = resolve_force()
        if not ocf or not acf then return end
        ocf, acf = compensate_force(ocf, acf, started)
        if fire_gun(gun, ocf, acf) then SA.last_shot = now end
        return
    end

    local cf = origin_cframe()
    if not cf then return end
    local aim = pick_point(cf.Position, true)
    if not aim then return end
    local acf = compensate_resolve(CFrame.new(aim))
    if fire_gun(gun, cf, acf) then SA.last_shot = now end
end

local _gun_fired_conn = nil

local function connect_gun_fired()
    if _gun_fired_conn then return end
    local m = get_weapon_service()
    if not m or typeof(m.GunFired) ~= "Instance" then return end
    _gun_fired_conn = m.GunFired.OnClientEvent:Connect(function(tool)
        local char = LocalPlayer.Character
        if not char or typeof(tool) ~= "Instance" then return end
        local ok, mine = pcall(function() return tool:IsDescendantOf(char) end)
        if not ok or not mine then return end
        local now = os.clock()
        if last_fire_stamp > 0 and want_since > 0 and want_since <= last_fire_stamp then
            gap_push(now - last_fire_stamp)
        end
        last_fire_stamp = now
    end)
end

local _next_role = 0
local _next_hook = 0

RunService.Heartbeat:Connect(function()
    if force_att and os.clock() - force_stamp > 0.05 then
        restore_origin()
    end

    if not SA.enabled then return end
    local now = os.clock()

    if now >= _next_role then
        _next_role = now + 0.2
        pcall(refresh_target)
    end

    sample_ping()
    pcall(track, now)

    if now >= _next_hook then
        _next_hook = now + 1
        pcall(install_hooks)
        pcall(connect_gun_fired)
    end

    pcall(auto_step, now)
end)

SheriffTab:Toggle({
    Title = "Silent Aim",
    Value = false,
    Callback = function(v)
        SA.enabled = v
        if v then
            task.spawn(function()
                pcall(install_hooks)
                pcall(connect_gun_fired)
                pcall(refresh_target)
            end)
            notify("Sheriff", "Silent Aim ON")
        else
            restore_origin()
            notify("Sheriff", "Silent Aim OFF")
        end
    end,
})

SheriffTab:Toggle({
    Title = "Prediction",
    Value = true,
    Callback = function(v) SA.predict = v end,
})

SheriffTab:Toggle({
    Title = "Force Mode",
    Value = false,
    Callback = function(v) SA.force = v end,
})

SheriffTab:Toggle({
    Title = "Auto Shoot",
    Value = false,
    Callback = function(v) SA.auto_on = v end,
})

SheriffTab:Slider({
    Title = "Auto Delay",
    Step = 0.05,
    Value = { Min = 0.1, Max = 1, Default = 0.25 },
    Callback = function(v) SA.auto_delay = v end,
})

SheriffTab:Slider({
    Title = "Lead Scale",
    Step = 0.1,
    Value = { Min = 0.5, Max = 2, Default = 1 },
    Callback = function(v) SP.lead_scale = v end,
})

SheriffTab:Slider({
    Title = "Stand Off",
    Step = 1,
    Value = { Min = 10, Max = 50, Default = 30 },
    Callback = function(v) SA.stand_off = v end,
})
