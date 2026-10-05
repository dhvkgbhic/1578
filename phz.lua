-- 星喵 MM2 多功能 (最终安全版)
-- 使用 UI 库: dhvkgbhic/1578/main/ui

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/dhvkgbhic/1578/refs/heads/main/ui"))()

local Window = OrionLib:MakeWindow({
    Name = "星喵 MM2 多功能",
    HidePremium = false,
    SaveConfig = true,
    IntroText = "星喵 MM2 多功能 v2.2",
    ConfigFolder = "StarMeowMM2"
})

local Settings = {
    AimEnabled       = false,
    TargetMurderer   = true,
    TargetSheriff    = false,
    AimFOV           = 200,
    ShowFOV          = true,

    ESPEnabled       = false,
    ESPInnocent      = true,
    ESPMurderer      = true,
    ESPSheriff       = true,
    ESPShowName      = true,
    ESPTransparency  = 0.3,
}

-- 鼠标左键状态
local mouseDown = false
UserInputService.InputBegan:Connect(function(input, gp)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        mouseDown = true
    end
end)
UserInputService.InputEnded:Connect(function(input, gp)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        mouseDown = false
    end
end)

-- 身份识别
local function hasTool(plr, toolNames)
    local char = plr.Character
    local backpack = plr:FindFirstChild("Backpack")
    if not char then return false end
    for _, name in ipairs(toolNames) do
        if char:FindFirstChild(name) then return true end
        if backpack and backpack:FindFirstChild(name) then return true end
    end
    return false
end

local function isMurderer(plr) return hasTool(plr, { "Knife" }) end
local function isSheriff(plr)  return hasTool(plr, { "Gun", "Revolver", "SheriffGun" }) end

local function getRole(plr)
    if isMurderer(plr) then return "Murderer"
    elseif isSheriff(plr) then return "Sheriff"
    else return "Innocent" end
end

local ROLE_COLORS = {
    Innocent = Color3.fromRGB(150, 150, 150),
    Murderer = Color3.fromRGB(255, 50, 50),
    Sheriff  = Color3.fromRGB(50, 130, 255),
}

local ROLE_NAMES = {
    Innocent = "平民",
    Murderer = "杀手",
    Sheriff  = "警长",
}

-- 检查自己是否装备了枪
local function hasGunEquipped()
    local char = LocalPlayer.Character
    if not char then return false end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local n = tool.Name:lower()
            if n == "gun" or n == "revolver" or n == "sheriffgun" then
                return true
            end
        end
    end
    return false
end

-- 目标缓存
local cachedTarget = nil
local lastCacheTime = 0

local function getClosestHead()
    local now = tick()
    if now - lastCacheTime < 0.1 then
        return cachedTarget
    end
    lastCacheTime = now

    local myChar = LocalPlayer.Character
    if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then
        cachedTarget = nil
        return nil
    end

    local viewportSize = Camera.ViewportSize
    local screenCenter = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    local closestHead, shortestDist = nil, Settings.AimFOV

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end

        local char = plr.Character
        if not char then continue end

        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end

        local role = getRole(plr)
        if role == "Murderer" and not Settings.TargetMurderer then continue end
        if role == "Sheriff"  and not Settings.TargetSheriff  then continue end
        if role == "Innocent" then continue end

        local head = char:FindFirstChild("Head")
        if not head then continue end

        local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
        if not onScreen then continue end

        local dist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
        if dist < shortestDist then
            shortestDist = dist
            closestHead = head
        end
    end

    cachedTarget = closestHead
    return closestHead
end

-- Raycast Hook (只在按鼠标+持枪时生效)
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()

    if method == "Raycast"
       and not checkcaller()
       and Settings.AimEnabled
       and mouseDown
       and hasGunEquipped() then

        local args = { ... }
        local origin = args[1]

        if typeof(origin) == "Vector3" then
            local target = getClosestHead()
            if target then
                return {
                    Instance = target,
                    Position = target.Position,
                    Normal = (origin - target.Position).Unit,
                    Material = Enum.Material.Plastic,
                    Distance = (target.Position - origin).Magnitude,
                }
            end
        end
    end

    return oldNamecall(self, ...)
end))

-- ESP
local espFolder = Instance.new("Folder")
espFolder.Name = "StarMeowMM2ESP"
espFolder.Parent = workspace

local activeESP = {}

local function clearESP(plr)
    local data = activeESP[plr]
    if not data then return end
    if data.highlight and data.highlight.Parent then data.highlight:Destroy() end
    if data.billboard and data.billboard.Parent then data.billboard:Destroy() end
    activeESP[plr] = nil
end

local function clearAllESP()
    for plr, _ in pairs(activeESP) do clearESP(plr) end
    table.clear(activeESP)
end

local function createESP(plr)
    if plr == LocalPlayer then return end
    local char = plr.Character
    if not char then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    clearESP(plr)

    local role = getRole(plr)
    local color = ROLE_COLORS[role] or ROLE_COLORS.Innocent
    local roleName = ROLE_NAMES[role] or "平民"

    local highlight = Instance.new("Highlight")
    highlight.Name = "StarMeowESP"
    highlight.Adornee = char
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = color
    highlight.OutlineColor = color
    if role == "Sheriff" then
        highlight.FillTransparency = 0.5
    else
        highlight.FillTransparency = 1 - Settings.ESPTransparency
    end
    highlight.OutlineTransparency = 0
    highlight.Parent = espFolder

    local billboard
    if Settings.ESPShowName then
        local head = char:FindFirstChild("Head")
        if head then
            billboard = Instance.new("BillboardGui")
            billboard.Name = "StarMeowESPLabel"
            billboard.Adornee = head
            billboard.Size = UDim2.new(0, 200, 0, 50)
            billboard.StudsOffset = Vector3.new(0, 2.5, 0)
            billboard.AlwaysOnTop = true
            billboard.Parent = espFolder

            local nameLabel = Instance.new("TextLabel")
            nameLabel.Name = "NameLabel"
            nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
            nameLabel.Position = UDim2.new(0, 0, 0, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = string.format("[%s] %s", roleName, plr.Name)
            nameLabel.TextColor3 = color
            nameLabel.TextStrokeTransparency = 0
            nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
            nameLabel.TextScaled = true
            nameLabel.Font = Enum.Font.GothamBold
            nameLabel.Parent = billboard

            local distLabel = Instance.new("TextLabel")
            distLabel.Name = "DistLabel"
            distLabel.Size = UDim2.new(1, 0, 0.4, 0)
            distLabel.Position = UDim2.new(0, 0, 0.5, 0)
            distLabel.BackgroundTransparency = 1
            distLabel.Text = "0m"
            distLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
            distLabel.TextStrokeTransparency = 0
            distLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
            distLabel.TextScaled = true
            distLabel.Font = Enum.Font.Gotham
            distLabel.Parent = billboard
        end
    end

    activeESP[plr] = { highlight = highlight, billboard = billboard }
end

local function updateESP()
    if not Settings.ESPEnabled then
        if next(activeESP) then clearAllESP() end
        return
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local char = plr.Character
        if not char then clearESP(plr); continue end

        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then clearESP(plr); continue end

        local role = getRole(plr)
        local shouldShow = false
        if role == "Innocent" and Settings.ESPInnocent then shouldShow = true end
        if role == "Murderer" and Settings.ESPMurderer then shouldShow = true end
        if role == "Sheriff"  and Settings.ESPSheriff  then shouldShow = true end

        if not shouldShow then clearESP(plr); continue end

        if not activeESP[plr] or (activeESP[plr].highlight and activeESP[plr].highlight.Adornee ~= char) then
            createESP(plr)
        else
            local color = ROLE_COLORS[role] or ROLE_COLORS.Innocent
            local data = activeESP[plr]
            if data.highlight then
                data.highlight.FillColor = color
                data.highlight.OutlineColor = color
                if role == "Sheriff" then
                    data.highlight.FillTransparency = 0.5
                else
                    data.highlight.FillTransparency = 1 - Settings.ESPTransparency
                end
            end
        end

        local data = activeESP[plr]
        if data and data.billboard then
            local head = char:FindFirstChild("Head")
            local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if head and myRoot then
                local distLabel = data.billboard:FindFirstChild("DistLabel")
                if distLabel then
                    local dist = math.floor((head.Position - myRoot.Position).Magnitude + 0.5)
                    distLabel.Text = dist .. "m"
                end
            end
        end
    end

    for plr, _ in pairs(activeESP) do
        if not plr.Parent or not plr.Character then clearESP(plr) end
    end
end

Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function()
        task.wait(0.5)
        if Settings.ESPEnabled then createESP(plr) end
    end)
end)

Players.PlayerRemoving:Connect(function(plr) clearESP(plr) end)

if LocalPlayer.Character then
    LocalPlayer.CharacterAdded:Connect(function()
        clearAllESP()
        task.wait(1)
        if Settings.ESPEnabled then updateESP() end
    end)
end

RunService.RenderStepped:Connect(updateESP)

-- FOV 圆环
local fovGui = Instance.new("ScreenGui")
fovGui.Name = "StarMeowMM2FOV"
fovGui.ResetOnSpawn = false
fovGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local fovFrame = Instance.new("Frame")
fovFrame.BackgroundTransparency = 1
fovFrame.AnchorPoint = Vector2.new(0.5, 0.5)
fovFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
fovFrame.Size = UDim2.new(0, Settings.AimFOV * 2, 0, Settings.AimFOV * 2)
fovFrame.Parent = fovGui

local fovCorner = Instance.new("UICorner")
fovCorner.CornerRadius = UDim.new(1, 0)
fovCorner.Parent = fovFrame

local fovStroke = Instance.new("UIStroke")
fovStroke.Color = Color3.fromRGB(0, 255, 150)
fovStroke.Thickness = 1
fovStroke.Transparency = 0.4
fovStroke.Parent = fovFrame

RunService.RenderStepped:Connect(function()
    fovFrame.Visible = Settings.AimEnabled and Settings.ShowFOV
    fovFrame.Size = UDim2.new(0, Settings.AimFOV * 2, 0, Settings.AimFOV * 2)
    if Settings.AimEnabled then
        if getClosestHead() then
            fovStroke.Color = Color3.fromRGB(255, 80, 80)
        else
            fovStroke.Color = Color3.fromRGB(0, 255, 150)
        end
    end
end)

-- UI
local AimTab = Window:MakeTab({
    Name = "子弹追踪",
    Icon = "rbxassetid://18270615016",
    PremiumOnly = false
})

AimTab:AddParagraph("MM2 子弹追踪")
AimTab:AddParagraph("按住鼠标左键 + 持枪时才生效")
AimTab:AddParagraph("松开鼠标或收枪自动停止")

AimTab:AddToggle({
    Name = "启用子弹追踪",
    Default = false,
    Save = true,
    Flag = "MM2RaycastAim",
    Callback = function(Value)
        Settings.AimEnabled = Value
        OrionLib:MakeNotification({
            Name = "星喵",
            Content = Value and "子弹追踪已开启" or "子弹追踪已关闭",
            Image = "rbxassetid://18270615016",
            Time = 2
        })
    end
})

AimTab:AddToggle({
    Name = "追踪杀手",
    Default = true,
    Save = true,
    Flag = "TargetMurderer",
    Callback = function(Value) Settings.TargetMurderer = Value end
})

AimTab:AddToggle({
    Name = "追踪警长",
    Default = false,
    Save = true,
    Flag = "TargetSheriff",
    Callback = function(Value) Settings.TargetSheriff = Value end
})

AimTab:AddToggle({
    Name = "显示 FOV 圆环",
    Default = true,
    Save = true,
    Flag = "ShowFOV",
    Callback = function(Value) Settings.ShowFOV = Value end
})

AimTab:AddSlider({
    Name = "FOV 范围",
    Min = 50, Max = 800, Default = 200,
    Color = Color3.fromRGB(0, 255, 150),
    Increment = 10,
    ValueName = "像素",
    Callback = function(Value) Settings.AimFOV = Value end
})

local ESPTab = Window:MakeTab({
    Name = "身份透视",
    Icon = "rbxassetid://18270615016",
    PremiumOnly = false
})

ESPTab:AddParagraph("平民=灰色 / 杀手=红色 / 警长=蓝色(50%透明)")

ESPTab:AddToggle({
    Name = "启用身份透视",
    Default = false,
    Save = true,
    Flag = "ESPEnabled",
    Callback = function(Value)
        Settings.ESPEnabled = Value
        if not Value then clearAllESP() end
        OrionLib:MakeNotification({
            Name = "星喵",
            Content = Value and "身份透视已开启" or "身份透视已关闭",
            Image = "rbxassetid://18270615016",
            Time = 2
        })
    end
})

ESPTab:AddToggle({
    Name = "显示平民 (灰色)",
    Default = true,
    Save = true,
    Flag = "ESPInnocent",
    Callback = function(Value)
        Settings.ESPInnocent = Value
        if not Value then
            for plr, _ in pairs(activeESP) do
                if getRole(plr) == "Innocent" then clearESP(plr) end
            end
        end
    end
})

ESPTab:AddToggle({
    Name = "显示杀手 (红色)",
    Default = true,
    Save = true,
    Flag = "ESPMurderer",
    Callback = function(Value)
        Settings.ESPMurderer = Value
        if not Value then
            for plr, _ in pairs(activeESP) do
                if getRole(plr) == "Murderer" then clearESP(plr) end
            end
        end
    end
})

ESPTab:AddToggle({
    Name = "显示警长 (蓝色50%)",
    Default = true,
    Save = true,
    Flag = "ESPSheriff",
    Callback = function(Value)
        Settings.ESPSheriff = Value
        if not Value then
            for plr, _ in pairs(activeESP) do
                if getRole(plr) == "Sheriff" then clearESP(plr) end
            end
        end
    end
})

ESPTab:AddToggle({
    Name = "显示名字和距离",
    Default = true,
    Save = true,
    Flag = "ESPShowName",
    Callback = function(Value)
        Settings.ESPShowName = Value
        for _, data in pairs(activeESP) do
            if data.billboard then data.billboard.Enabled = Value end
        end
    end
})

ESPTab:AddSlider({
    Name = "透视透明度",
    Min = 0, Max = 100, Default = 30,
    Color = Color3.fromRGB(0, 255, 150),
    Increment = 5,
    ValueName = "%",
    Callback = function(Value)
        Settings.ESPTransparency = Value / 100
        for plr, data in pairs(activeESP) do
            if data.highlight then
                local role = getRole(plr)
                if role == "Sheriff" then
                    data.highlight.FillTransparency = 0.5
                else
                    data.highlight.FillTransparency = 1 - Settings.ESPTransparency
                end
            end
        end
    end
})

local InfoTab = Window:MakeTab({
    Name = "说明",
    Icon = "rbxassetid://18270615016",
    PremiumOnly = false
})

InfoTab:AddParagraph("安全机制")
InfoTab:AddParagraph("1. 只在鼠标按下时 Hook")
InfoTab:AddParagraph("2. 只在你持有枪时 Hook")
InfoTab:AddParagraph("3. 目标缓存 0.1 秒")
InfoTab:AddParagraph("4. 不持枪时完全不干扰游戏")
InfoTab:AddDivider()
InfoTab:AddParagraph("使用步骤")
InfoTab:AddParagraph("1. 先打开身份透视, 确认能看到红蓝描边")
InfoTab:AddParagraph("2. 拿到枪后打开子弹追踪")
InfoTab:AddParagraph("3. 按住鼠标左键瞄准杀手方向")
InfoTab:AddParagraph("4. 圆环红=已锁定, 绿=无目标")
InfoTab:AddDivider()
InfoTab:AddParagraph("身份识别")
InfoTab:AddParagraph("杀手: 持有 Knife")
InfoTab:AddParagraph("警长: 持有 Gun/Revolver")
InfoTab:AddParagraph("平民: 无武器")

OrionLib:MakeNotification({
    Name = "星喵",
    Content = "MM2 多功能已加载",
    Image = "rbxassetid://18270615016",
    Time = 3
})

print("[星喵MM2多功能] 加载完成")