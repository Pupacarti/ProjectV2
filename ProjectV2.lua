local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = Workspace.CurrentCamera

-- ==========================================
-- 1. ตัวแปรควบคุมสถานะ (States)
-- ==========================================
local scriptActive = false      -- สคริปต์หลัก
local autoAimEnabled = false    -- ระบบเล็ง + ยิง
local wallCheckEnabled = true   -- เช็กกำแพงบัง
local autoEEnabled = false      -- กด E อัตโนมัติ

local isRightClicking = false
local isEngaging = false
local requiredZombieCount = 2
local lastShootTime = 0
local currentTarget = nil

local function getHumanizedCooldown()
    return 0.35 + (math.random(1, 15) / 100)
end
local currentCooldown = getHumanizedCooldown()

-- ==========================================
-- 2. ระบบคำนวณและเช็กสิ่งกีดขวาง (Wall Check)
-- ==========================================
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

local function isTargetVisible(targetHead)
    if not wallCheckEnabled then return true end
    if not targetHead then return false end
    if LocalPlayer.Character then
        raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    end

    local origin = Camera.CFrame.Position
    local direction = targetHead.Position - origin
    local result = Workspace:Raycast(origin, direction, raycastParams)
    
    if not result or result.Instance:IsDescendantOf(targetHead.Parent) then
        return true
    end
    return false
end

local function getVisibleNPCs()
    local visibleList = {}

    for _, obj in pairs(Workspace:GetChildren()) do
        local modelCandidates = {}
        if obj:IsA("Model") then
            table.insert(modelCandidates, obj)
        elseif obj:IsA("Folder") then
            for _, child in pairs(obj:GetChildren()) do
                if child:IsA("Model") then table.insert(modelCandidates, child) end
            end
        end

        for _, model in pairs(modelCandidates) do
            local head = model:FindFirstChild("Head")
            local humanoid = model:FindFirstChild("Humanoid")
            
            if head and humanoid and humanoid.Health > 0 then
                if not Players:GetPlayerFromCharacter(model) and model ~= LocalPlayer.Character then
                    local headPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                    if onScreen and isTargetVisible(head) then
                        table.insert(visibleList, model)
                    end
                end
            end
        end
    end
    return visibleList
end

-- ==========================================
-- 3. สร้าง UI (Modern Dark Theme)
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ModernZombieHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

local OpenBtn = Instance.new("TextButton")
OpenBtn.Size = UDim2.new(0, 140, 0, 40)
OpenBtn.Position = UDim2.new(0, 20, 0, 20)
OpenBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 27)
OpenBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
OpenBtn.Text = "⚡ ZOMBIE HUB"
OpenBtn.Font = Enum.Font.GothamBold
OpenBtn.TextSize = 14
OpenBtn.Parent = ScreenGui

local OpenBtnCorner = Instance.new("UICorner")
OpenBtnCorner.CornerRadius = UDim.new(0, 8)
OpenBtnCorner.Parent = OpenBtn

local OpenBtnStroke = Instance.new("UIStroke")
OpenBtnStroke.Color = Color3.fromRGB(99, 102, 241)
OpenBtnStroke.Thickness = 1.5
OpenBtnStroke.Parent = OpenBtn

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 380, 0, 260)
MainFrame.Position = UDim2.new(0.5, -190, 0.5, -130)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 20)
MainFrame.Visible = false
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(39, 39, 42)
MainStroke.Thickness = 1
MainStroke.Parent = MainFrame

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 45)
Header.BackgroundColor3 = Color3.fromRGB(24, 24, 27)
Header.Parent = MainFrame

local HeaderTitle = Instance.new("TextLabel")
HeaderTitle.Size = UDim2.new(1, -50, 1, 0)
HeaderTitle.Position = UDim2.new(0, 15, 0, 0)
HeaderTitle.BackgroundTransparency = 1
HeaderTitle.Text = "ZOMBIE HUNTER v2.0"
HeaderTitle.TextColor3 = Color3.fromRGB(244, 244, 245)
HeaderTitle.Font = Enum.Font.GothamBold
HeaderTitle.TextSize = 15
HeaderTitle.TextXAlignment = Enum.TextXAlignment.Left
HeaderTitle.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -38, 0.5, -15)
CloseBtn.BackgroundColor3 = Color3.fromRGB(39, 39, 42)
CloseBtn.TextColor3 = Color3.fromRGB(161, 161, 170)
CloseBtn.Text = "✕"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.Parent = Header

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -30, 1, -60)
Content.Position = UDim2.new(0, 15, 0, 50)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame

local function createToggle(name, positionY, defaultState, callback)
    local Container = Instance.new("Frame")
    Container.Size = UDim2.new(1, 0, 0, 42)
    Container.Position = UDim2.new(0, 0, 0, positionY)
    Container.BackgroundColor3 = Color3.fromRGB(24, 24, 27)
    Container.Parent = Content

    local ContainerCorner = Instance.new("UICorner")
    ContainerCorner.CornerRadius = UDim.new(0, 8)
    ContainerCorner.Parent = Container

    local ContainerStroke = Instance.new("UIStroke")
    ContainerStroke.Color = Color3.fromRGB(39, 39, 42)
    ContainerStroke.Thickness = 1
    ContainerStroke.Parent = Container

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.6, 0, 1, 0)
    Label.Position = UDim2.new(0, 12, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = name
    Label.TextColor3 = Color3.fromRGB(228, 228, 231)
    Label.Font = Enum.Font.GothamMedium
    Label.TextSize = 13
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Container

    local SwitchBg = Instance.new("Frame")
    SwitchBg.Size = UDim2.new(0, 44, 0, 22)
    SwitchBg.Position = UDim2.new(1, -54, 0.5, -11)
    SwitchBg.BackgroundColor3 = defaultState and Color3.fromRGB(99, 102, 241) or Color3.fromRGB(39, 39, 42)
    SwitchBg.Parent = Container

    local SwitchCorner = Instance.new("UICorner")
    SwitchCorner.CornerRadius = UDim.new(1, 0)
    SwitchCorner.Parent = SwitchBg

    local Circle = Instance.new("Frame")
    Circle.Size = UDim2.new(0, 16, 0, 16)
    Circle.Position = defaultState and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    Circle.BackgroundColor3 = defaultState and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(161, 161, 170)
    Circle.Parent = SwitchBg

    local CircleCorner = Instance.new("UICorner")
    CircleCorner.CornerRadius = UDim.new(1, 0)
    CircleCorner.Parent = Circle

    local Clickable = Instance.new("TextButton")
    Clickable.Size = UDim2.new(1, 0, 1, 0)
    Clickable.BackgroundTransparency = 1
    Clickable.Text = ""
    Clickable.Parent = Container

    local toggled = defaultState
    Clickable.MouseButton1Click:Connect(function()
        toggled = not toggled
        local bgGoal = toggled and Color3.fromRGB(99, 102, 241) or Color3.fromRGB(39, 39, 42)
        local circlePos = toggled and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        local circleColor = toggled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(161, 161, 170)

        TweenService:Create(SwitchBg, TweenInfo.new(0.2), {BackgroundColor3 = bgGoal}):Play()
        TweenService:Create(Circle, TweenInfo.new(0.2), {Position = circlePos, BackgroundColor3 = circleColor}):Play()

        if callback then callback(toggled) end
    end)
end

-- สร้างสวิตช์และผูกการทำงานกับตัวแปรจริง
createToggle("เปิดใช้งานสคริปต์หลัก", 0, false, function(state)
    scriptActive = state
    if not state then
        isEngaging = false
        currentTarget = nil
        if isRightClicking then
            isRightClicking = false
            local mousePos = UserInputService:GetMouseLocation()
            VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 1, false, game, 0)
        end
    end
end)

createToggle("ล็อกหัว + ยิงทีละนัด (Auto Aim)", 50, false, function(state)
    autoAimEnabled = state
end)

createToggle("เช็กกำแพงบัง (Wall Check)", 100, true, function(state)
    wallCheckEnabled = state
end)

createToggle("เก็บของอัตโนมัติ (Auto-Interact E)", 150, false, function(state)
    autoEEnabled = state
end)

-- ระบบลากหน้าต่าง UI
local dragging, dragInput, dragStart, startPos
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
Header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local function toggleFrame()
    MainFrame.Visible = not MainFrame.Visible
end
OpenBtn.MouseButton1Click:Connect(toggleFrame)
CloseBtn.MouseButton1Click:Connect(toggleFrame)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.RightShift then
        toggleFrame()
    end
end)

-- ==========================================
-- 4. Loop หลักประมวลผลการเล็งยิง (Heartbeat)
-- ==========================================
RunService.Heartbeat:Connect(function()
    if not scriptActive or not autoAimEnabled then return end

    local visibleZombies = getVisibleNPCs()
    local mousePos = UserInputService:GetMouseLocation()

    if not isEngaging then
        if #visibleZombies >= requiredZombieCount then
            isEngaging = true
        end
    end

    if isEngaging then
        if #visibleZombies > 0 then
            local target = nil
            local shortestDistance = math.huge

            for _, zombie in pairs(visibleZombies) do
                local headPos = Camera:WorldToViewportPoint(zombie.Head.Position)
                local dist = (Vector2.new(headPos.X, headPos.Y) - mousePos).Magnitude
                if dist < shortestDistance then
                    target = zombie
                    shortestDistance = dist
                end
            end

            if target and target:FindFirstChild("Head") then
                if currentTarget ~= target then
                    currentTarget = target
                    lastShootTime = 0 
                end

                -- สุ่มพิกัดให้เล็งสั่นธรรมชาติเล็กน้อย
                local aimJitter = Vector3.new(
                    (math.random(-15, 15) / 100),
                    (math.random(-15, 15) / 100),
                    (math.random(-15, 15) / 100)
                )
                local targetPosition = target.Head.Position + aimJitter
                
                local targetCFrame = CFrame.new(Camera.CFrame.Position, targetPosition)
                local smoothFactor = 0.25 + (math.random(1, 15) / 100)
                Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, smoothFactor)

                if not isRightClicking then
                    isRightClicking = true
                    VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 1, true, game, 0)
                end

                if tick() - lastShootTime >= currentCooldown then
                    lastShootTime = tick()
                    currentCooldown = getHumanizedCooldown()
                    
                    VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 0, true, game, 0)
                    local holdTime = 0.02 + (math.random(1, 3) / 100)
                    task.delay(holdTime, function()
                        VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 0, false, game, 0)
                    end)
                end
            end
        else
            isEngaging = false
            currentTarget = nil
            if isRightClicking then
                isRightClicking = false
                VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 1, false, game, 0)
            end
        end
    else
        if isRightClicking then
            isRightClicking = false
            VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 1, false, game, 0)
        end
    end
end)

-- ==========================================
-- 5. ระบบ Auto-E อัตโนมัติ
-- ==========================================
task.spawn(function()
    while true do
        local randomWait = 0.15 + (math.random(1, 20) / 100)
        task.wait(randomWait)
        
        if scriptActive and autoEEnabled then
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            local keyHold = 0.04 + (math.random(1, 3) / 100)
            task.wait(keyHold)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end
    end
end)
