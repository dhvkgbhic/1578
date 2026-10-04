-- 星喵礼物收集系统 (Orion UI 版)
-- 使用 UI 库: dhvkgbhic/1578/main/ui

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local TweenService       = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")
local SoundService       = game:GetService("SoundService")
local player = Players.LocalPlayer

if _G.StarMeowGiftCleanup then
    pcall(_G.StarMeowGiftCleanup)
end

local scriptConnections = {}
_G.StarMeowGiftCleanup = function()
    for _, conn in pairs(scriptConnections) do
        if conn and conn.Connected then conn:Disconnect() end
    end
    table.clear(scriptConnections)
end

local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/dhvkgbhic/1578/refs/heads/main/ui"))()

local LBLG = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
LBLG.Name = "LBLG"
LBLG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local LBL = Instance.new("TextLabel", LBLG)
LBL.Name = "LBL"
LBL.BackgroundTransparency = 1
LBL.Position = UDim2.new(0.75, 0, 0.010, 0)
LBL.Size = UDim2.new(0, 133, 0, 30)
LBL.Font = Enum.Font.GothamSemibold
LBL.Text = "加载中..."
LBL.TextColor3 = Color3.new(1, 1, 1)
LBL.TextScaled = true
LBL.TextSize = 14
LBL.TextWrapped = true

RunService.Heartbeat:Connect(function()
    LBL.Text = "北京时间:"..os.date("%H").."时"..os.date("%M").."分"..os.date("%S").."秒"
end)

local Window = OrionLib:MakeWindow({
    Name = "星喵礼物收集系统",
    HidePremium = false,
    SaveConfig = true,
    IntroText = "星喵礼物收集系统 v1.0",
    ConfigFolder = "StarMeowGiftCollector"
})

game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "星喵",
    Text = "礼物收集系统已加载",
    Duration = 4
})

OrionLib:MakeNotification({
    Name = "星喵",
    Content = "欢迎使用礼物收集系统",
    Image = "rbxassetid://18270615016",
    Time = 2
})

local GiftSettings = {
    CollectNormal      = false,
    CollectGolden      = false,
    LegitCollection    = false,
    LegitSpeed         = 16,
    InstantTeleport    = true,
    TweenSpeed         = 60,
    DelayBetweenGifts  = 0.05,
    AutoBeacon         = false,
    AutoStartCollecting = false,
}

local tweening = false
local currentTween = nil
local availableNormalGifts = {}
local availableGoldenGifts = {}
local blacklistedGifts = {}

local function getChar(p) return p and p.Character end
local function getRoot(char)
    return char and (char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("Torso") or char.PrimaryPart)
end

local function notif(msg, title)
    pcall(function()
        OrionLib:MakeNotification({
            Name = title or "星喵",
            Content = msg,
            Image = "rbxassetid://18270615016",
            Time = 3
        })
    end)
end

local toggleRefs = {
    CollectNormal       = nil,
    CollectGolden       = nil,
    LegitCollection     = nil,
    AutoStartCollecting = nil,
    AutoBeacon          = nil,
    InstantTP           = nil,
}

local collectGiftsEngine = function() end
local stopAllCollection  = function() end

local function refreshGifts(normal, golden)
    table.clear(availableNormalGifts)
    table.clear(availableGoldenGifts)

    local dynamicPools = workspace:FindFirstChild("Item_Pools")
    local normalFolder = (dynamicPools and dynamicPools:FindFirstChild("Gift"))
                        or workspace:FindFirstChild("Gifts")
                        or workspace:FindFirstChild("SpawnedGifts")
    local goldenFolder = (dynamicPools and dynamicPools:FindFirstChild("GoldenGift")) or normalFolder

    if normal and normalFolder then
        for _, gift in ipairs(normalFolder:GetChildren()) do
            local isGolden = gift.Name:lower():find("golden") ~= nil
            if not isGolden then table.insert(availableNormalGifts, gift) end
        end
    end
    if golden and goldenFolder then
        for _, gift in ipairs(goldenFolder:GetChildren()) do
            local isGolden = gift.Name:lower():find("golden") ~= nil
            if isGolden then table.insert(availableGoldenGifts, gift) end
        end
    end
end

local function getClosestGift(giftList)
    local char = getChar(player)
    local root = getRoot(char)
    if not root then return nil end

    local closest, shortestDist = nil, math.huge
    for _, gift in ipairs(giftList) do
        if gift and gift.Parent and not blacklistedGifts[gift] then
            local part = gift:IsA("BasePart") and gift or gift:FindFirstChildWhichIsA("BasePart")
            if part then
                if part.Position == Vector3.new(0,0,0)
                   or part.Position.Y < -500
                   or part.Position.Y > 3000
                   or part.Position.Magnitude > 30000 then
                    blacklistedGifts[gift] = true
                    continue
                end
                local dist = (part.Position - root.Position).Magnitude
                if dist < shortestDist then
                    shortestDist = dist
                    closest = gift
                end
            end
        end
    end
    return closest
end

local function walkToPositionPathfinding(targetPos)
    local char = getChar(player)
    local root = getRoot(char)
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or not targetPos or targetPos == Vector3.new(0,0,0) then return false end

    humanoid.WalkSpeed = GiftSettings.LegitSpeed

    local path = PathfindingService:CreatePath({
        AgentRadius = 2, AgentHeight = 5, AgentCanJump = true,
        AgentJumpHeight = 10, AgentMaxSlope = 45
    })

    local success = pcall(function() path:ComputeAsync(root.Position, targetPos) end)
    if success and path.Status == Enum.PathStatus.Success then
        for _, waypoint in ipairs(path:GetWaypoints()) do
            if not tweening and not GiftSettings.AutoBeacon then
                humanoid:MoveTo(root.Position)
                return false
            end
            if waypoint.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
            humanoid:MoveTo(waypoint.Position)

            local moveCompleted = false
            local conn = humanoid.MoveToFinished:Connect(function() moveCompleted = true end)
            local timeout = 0
            while not moveCompleted and (tweening or GiftSettings.AutoBeacon) do
                task.wait(0.05)
                timeout += 0.05
                if timeout > 3 then break end
            end
            conn:Disconnect()
            if not moveCompleted then break end
        end
        return true
    else
        humanoid:MoveTo(targetPos)
        task.wait(0.5)
        return false
    end
end

local function walkToGiftPathfinding(targetGift)
    local targetPart = targetGift:IsA("BasePart") and targetGift or targetGift:FindFirstChildWhichIsA("BasePart")
    if not targetPart or targetPart.Position == Vector3.new(0,0,0) then return false end
    return walkToPositionPathfinding(targetPart.Position)
end

local function moveToGift(targetGift)
    if GiftSettings.LegitCollection then
        walkToGiftPathfinding(targetGift)
        return nil
    end
    local char = getChar(player)
    local root = getRoot(char)
    local targetPart = targetGift:IsA("BasePart") and targetGift or targetGift:FindFirstChildWhichIsA("BasePart")
    if not root or not targetPart or targetPart.Position == Vector3.new(0,0,0) then return nil end
    local targetCFrame = targetPart.CFrame + Vector3.new(0, 3, 0)

    if GiftSettings.InstantTeleport then
        root.CFrame = targetCFrame
        return nil
    end

    local distance = (targetPart.Position - root.Position).Magnitude
    local duration = math.max(0.01, distance / GiftSettings.TweenSpeed)
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    local tween = TweenService:Create(root, tweenInfo, {CFrame = targetCFrame})
    tween:Play()
    return tween
end

local function handleSpawnNavigation()
    for _, sName in ipairs({"Spawn", "SpawnLocation"}) do
        local targetSpawn = workspace:FindFirstChild(sName)
        if targetSpawn and targetSpawn:IsA("BasePart") and targetSpawn.Position ~= Vector3.new(0,0,0) then
            local char = getChar(player)
            local root = getRoot(char)
            if root then
                if GiftSettings.LegitCollection then
                    walkToPositionPathfinding(targetSpawn.Position)
                else
                    root.CFrame = targetSpawn.CFrame + Vector3.new(0, 5, 0)
                end
                return true
            end
        end
    end
    return false
end

stopAllCollection = function()
    tweening = false
    GiftSettings.CollectNormal = false
    GiftSettings.CollectGolden = false

    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end

    if toggleRefs.CollectNormal then pcall(function() toggleRefs.CollectNormal:Set(false) end) end
    if toggleRefs.CollectGolden then pcall(function() toggleRefs.CollectGolden:Set(false) end) end
end

collectGiftsEngine = function(isGoldenTarget)
    if tweening then return end
    tweening = true
    table.clear(blacklistedGifts)

    task.spawn(function()
        local failedAttempts = 0
        while tweening do
            if isGoldenTarget and not GiftSettings.CollectGolden then break end
            if not isGoldenTarget and not GiftSettings.CollectNormal then break end

            local char = getChar(player)
            local root = getRoot(char)
            if root and not GiftSettings.LegitCollection then
                root.AssemblyLinearVelocity = Vector3.new(0,0,0)
            end

            refreshGifts(not isGoldenTarget, isGoldenTarget)
            local targetPool = isGoldenTarget and availableGoldenGifts or availableNormalGifts
            local gift = getClosestGift(targetPool)

            if not gift then
                failedAttempts += 1
                if not isGoldenTarget then
                    if failedAttempts >= 3 or #availableNormalGifts == 0 then
                        notif("普通礼物已收完，自动切换到金色礼物", "收集系统")
                        GiftSettings.CollectNormal = false
                        if toggleRefs.CollectNormal then pcall(function() toggleRefs.CollectNormal:Set(false) end) end
                        GiftSettings.CollectGolden = true
                        if toggleRefs.CollectGolden then pcall(function() toggleRefs.CollectGolden:Set(true) end) end
                        tweening = false
                        task.defer(function() collectGiftsEngine(true) end)
                        return
                    end
                else
                    if failedAttempts >= 3 or #availableGoldenGifts == 0 then
                        notif("金色礼物已收完，停止收集", "收集系统")
                        if GiftSettings.AutoBeacon then handleSpawnNavigation() end
                        stopAllCollection()
                        break
                    end
                end
                task.wait(0.5)
                table.clear(blacklistedGifts)
                continue
            end

            failedAttempts = 0
            blacklistedGifts[gift] = true
            currentTween = moveToGift(gift)

            if currentTween then
                currentTween.Completed:Wait()
            elseif not GiftSettings.LegitCollection then
                RunService.Heartbeat:Wait()
            end

            if GiftSettings.DelayBetweenGifts and GiftSettings.DelayBetweenGifts > 0 then
                task.wait(GiftSettings.DelayBetweenGifts)
            end
        end
        stopAllCollection()
    end)
end

local GiftTab = Window:MakeTab({
    Name = "礼物收集",
    Icon = "rbxassetid://18270615016",
    PremiumOnly = false
})

GiftTab:AddParagraph("自动收集地图上的礼物")
GiftTab:AddParagraph("普通礼物收完后会自动切换到金色礼物")

toggleRefs.AutoStartCollecting = GiftTab:AddToggle({
    Name = "自动开始收集 (NewLevel 音效触发)",
    Default = false,
    Save = true,
    Flag = "AutoStartCollecting",
    Callback = function(Value)
        GiftSettings.AutoStartCollecting = Value
        if Value then
            local sfxFolder = SoundService:FindFirstChild("SFXFolder")
            local newLevelSound = sfxFolder and sfxFolder:FindFirstChild("NewLevel")
            if newLevelSound and newLevelSound:IsA("Sound") then
                if scriptConnections["AutoStartCollectingConn"] then
                    pcall(function() scriptConnections["AutoStartCollectingConn"]:Disconnect() end)
                end
                scriptConnections["AutoStartCollectingConn"] = newLevelSound.Played:Connect(function()
                    if GiftSettings.AutoStartCollecting then
                        GiftSettings.CollectNormal = true
                        if toggleRefs.CollectNormal then pcall(function() toggleRefs.CollectNormal:Set(true) end) end
                        if tweening then stopAllCollection(); task.wait(0.1) end
                        collectGiftsEngine(false)
                        notif("检测到新关卡，已自动开始收集", "收集系统")
                    end
                end)
            else
                notif("未找到 SoundService.SFXFolder.NewLevel", "收集系统")
            end
        else
            if scriptConnections["AutoStartCollectingConn"] then
                pcall(function() scriptConnections["AutoStartCollectingConn"]:Disconnect() end)
                scriptConnections["AutoStartCollectingConn"] = nil
            end
        end
    end
})

toggleRefs.CollectNormal = GiftTab:AddToggle({
    Name = "收集普通礼物",
    Default = false,
    Save = true,
    Flag = "CollectNormal",
    Callback = function(Value)
        GiftSettings.CollectNormal = Value
        if Value then
            if GiftSettings.CollectGolden then
                GiftSettings.CollectGolden = false
                if toggleRefs.CollectGolden then pcall(function() toggleRefs.CollectGolden:Set(false) end) end
            end
            collectGiftsEngine(false)
        else
            if not GiftSettings.CollectGolden and tweening then stopAllCollection() end
        end
    end
})

toggleRefs.CollectGolden = GiftTab:AddToggle({
    Name = "收集金色礼物",
    Default = false,
    Save = true,
    Flag = "CollectGolden",
    Callback = function(Value)
        GiftSettings.CollectGolden = Value
        if Value then
            if GiftSettings.CollectNormal then
                GiftSettings.CollectNormal = false
                if toggleRefs.CollectNormal then pcall(function() toggleRefs.CollectNormal:Set(false) end) end
            end
            collectGiftsEngine(true)
        else
            if not GiftSettings.CollectNormal and tweening then stopAllCollection() end
        end
    end
})

toggleRefs.LegitCollection = GiftTab:AddToggle({
    Name = "合法寻路模式 (慢速)",
    Default = false,
    Save = true,
    Flag = "LegitCollection",
    Callback = function(Value)
        GiftSettings.LegitCollection = Value
        if Value then notif("已启用合法寻路模式", "收集系统") end
    end
})

GiftTab:AddTextbox({
    Name = "合法模式速度",
    Default = "16",
    TextDisappear = false,
    Callback = function(Value)
        local num = tonumber(Value)
        if num and num > 0 then
            GiftSettings.LegitSpeed = num
            notif("合法速度设为 "..num, "收集系统")
        end
    end
})

toggleRefs.InstantTP = GiftTab:AddToggle({
    Name = "瞬间传送收集",
    Default = true,
    Save = true,
    Flag = "InstantTP",
    Callback = function(Value)
        GiftSettings.InstantTeleport = Value
    end
})

GiftTab:AddTextbox({
    Name = "Tween 移动速度 (关闭瞬移时生效)",
    Default = "60",
    TextDisappear = false,
    Callback = function(Value)
        local num = tonumber(Value)
        if num and num > 0 then
            GiftSettings.TweenSpeed = num
            notif("Tween 速度设为 "..num, "收集系统")
        end
    end
})

GiftTab:AddTextbox({
    Name = "每个礼物间隔(秒)",
    Default = "0.05",
    TextDisappear = false,
    Callback = function(Value)
        local num = tonumber(Value)
        if num and num >= 0 then
            GiftSettings.DelayBetweenGifts = num
            notif("间隔设为 "..num.." 秒", "收集系统")
        end
    end
})

toggleRefs.AutoBeacon = GiftTab:AddToggle({
    Name = "收集完自动前往出生点",
    Default = false,
    Save = true,
    Flag = "AutoBeacon",
    Callback = function(Value)
        GiftSettings.AutoBeacon = Value
    end
})

GiftTab:AddButton({
    Name = "取消礼物收集",
    Callback = function()
        stopAllCollection()
        notif("已取消礼物收集", "收集系统")
    end
})

local StatusTab = Window:MakeTab({
    Name = "状态",
    Icon = "rbxassetid://18270615016",
    PremiumOnly = false
})

StatusTab:AddParagraph("实时状态显示")
StatusTab:AddDivider()

local statusLabel = StatusTab:AddLabel("加载中...")

task.spawn(function()
    while task.wait(0.5) do
        local statusText = string.format(
            "普通礼物: %s   金色礼物: %s\n寻路模式: %s   瞬移: %s\n当前礼物池: %d 普通 / %d 金色\n运行状态: %s",
            GiftSettings.CollectNormal and "开启" or "关闭",
            GiftSettings.CollectGolden and "开启" or "关闭",
            GiftSettings.LegitCollection and "开启" or "关闭",
            GiftSettings.InstantTeleport and "开启" or "关闭",
            #availableNormalGifts,
            #availableGoldenGifts,
            tweening and "运行中" or "空闲"
        )
        pcall(function() statusLabel:Set(statusText) end)
    end
end)

local HelpTab = Window:MakeTab({
    Name = "说明",
    Icon = "rbxassetid://18270615016",
    PremiumOnly = false
})

HelpTab:AddParagraph("使用方法")
HelpTab:AddParagraph("1. 打开[收集普通礼物]开关即可开始收集")
HelpTab:AddParagraph("2. 普通礼物收完后会自动切换到金色礼物")
HelpTab:AddParagraph("3. 想快速收集: 保持[瞬间传送]开启")
HelpTab:AddParagraph("4. 想隐蔽一点: 开启[合法寻路模式]")
HelpTab:AddDivider()
HelpTab:AddParagraph("三种收集模式对比")
HelpTab:AddParagraph("瞬移模式: 速度最快, 隐蔽性低")
HelpTab:AddParagraph("Tween模式: 中等速度, 过渡自然")
HelpTab:AddParagraph("合法寻路: 速度最慢, 隐蔽性最高")
HelpTab:AddDivider()
HelpTab:AddParagraph("注意事项")
HelpTab:AddParagraph("普通/金色礼物开关互斥")
HelpTab:AddParagraph("Auto Beacon 会在收完后自动去出生点")
HelpTab:AddParagraph("配置会自动保存, 下次运行无需重设")

notif("礼物收集系统加载完成", "星喵")
print("[星喵礼物收集] 加载完成")