-- =====================================================
-- ★ いちごハブ 完全統合版 v6.1
-- ★ 黒×赤 / 怪しい処理の整理 / ラグ安定化
-- =====================================================

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

Library.ForceCheckbox = false
Library.ShowToggleFrameInKeybinds = true
Library.CornerRadius = 18
Library.Scheme.FontColor = Color3.fromHex("ffffff")
Library.Scheme.MainColor = Color3.fromHex("b91c1c")
Library.Scheme.AccentColor = Color3.fromHex("ef4444")
Library.Scheme.BackgroundColor = Color3.fromHex("000000")
Library.Scheme.OutlineColor = Color3.fromHex("7f1d1d")

-- =====================================================
-- サービス
-- =====================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- =====================================================
-- Homeタブ用ヘルパー
-- =====================================================
local DiscordInvite = "https://discord.gg/aerKPPWCz"
local ScriptStartClock = os.clock()

local ExecutorName = (function()
	if identifyexecutor then
		local success, name = pcall(identifyexecutor)
		if success and name then return name end
	end
	if syn then return "Synapse" end
	if KRNL_LOADED then return "Krnl" end
	if fluxus then return "Fluxus" end
	return "Unknown"
end)()

local function GetAccountCreationDate()
	local success, accountAge = pcall(function() return LocalPlayer.AccountAge end)
	if not success or not accountAge then return "N/A" end
	local timestamp = os.time() - accountAge * 86400
	local success2, date = pcall(function() return os.date("%d.%m.%Y", timestamp) end)
	if success2 and date then return date end
	return "N/A"
end

local function GetAccountAge()
	local success, accountAge = pcall(function() return LocalPlayer.AccountAge end)
	if not success or not accountAge then return "N/A" end
	local years = math.floor(accountAge / 365)
	local months = math.floor(accountAge % 365 / 30)
	local days = accountAge % 30
	if years > 0 then return years .. "y " .. months .. "m" end
	if months > 0 then return months .. "m " .. days .. "d" end
	return days .. "d"
end

local GrabEvents = ReplicatedStorage:FindFirstChild("GrabEvents")
local MenuToys = ReplicatedStorage:FindFirstChild("MenuToys")
local SpawnToy = MenuToys and MenuToys:FindFirstChild("SpawnToyRemoteFunction")
local DestroyToy = MenuToys and MenuToys:FindFirstChild("DestroyToy")
local SetNetworkOwner = GrabEvents and GrabEvents:FindFirstChild("SetNetworkOwner")
local CreateGrabLine = GrabEvents and GrabEvents:FindFirstChild("CreateGrabLine")
local DestroyGrabLine = GrabEvents and GrabEvents:FindFirstChild("DestroyGrabLine")
local StickyEvent = ReplicatedStorage:FindFirstChild("PlayerEvents") and ReplicatedStorage.PlayerEvents:FindFirstChild("StickyPartEvent")

-- =====================================================
-- グローバル初期化
-- =====================================================
cons = {}
plr = LocalPlayer
Lines = 0
autoantilag = false
lagger = nil
spingrab = false
spinspeed = 50
_G.MLConn = nil
globalFriendWhitelist = false

DestroyLine = DestroyGrabLine
SetNetOwner = SetNetworkOwner
CreateGrabLineI = CreateGrabLine
ExtendGrabLine = GrabEvents and GrabEvents:FindFirstChild("ExtendGrabLine")
DestroyToyI = DestroyToy

arkadiaBlobKickActive = false
arkadiaBlobKickTask = nil
arkadia_adjX, arkadia_adjY, arkadia_adjZ = 0, 23, 0
arkadia_adjRadius, arkadia_adjSpeed = 18, 0.15
arkadia_angle = 0
arkadia_initialTargetPos = nil
arkadia_hasCaptured = false
arkadia_grabToggle = false

loopKill1Active = false
loopKill1TargetName = nil
loopKill2Active = false
loopKill2TargetName = nil
loopBlobKickSpamTask, loopBlobKickSpamActive = nil, false
loopBlobKickSpamTargetName = nil
kickLoopEnabled = false
snowballRagdollTask, snowballRagdollActive = nil, false
snowballRagdollTargetName = nil

-- =====================================================
-- 共通関数
-- =====================================================
-- 通知音（ちーん） / トグル音は末尾のパッチでカチカチ
local function PlayChime()
    pcall(function()
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://4590662766"
        sound.Volume = 0.8
        sound.Parent = game:GetService("SoundService")
        sound:Play()
        game:GetService("Debris"):AddItem(sound, 3)
    end)
end

local function Notify(title, content, time, silent)
    Library:Notify({ Title = title or "いちごハブ", Description = content or "", Time = time or 3 })
    if not silent then
        PlayChime()
    end
end

-- =====================================================
-- 安全モード / リモート送信制限（BAN・フラッシュ軽減）
-- =====================================================
local SafeMode = true
local _remoteBudget = 0
local _remoteBudgetMax = 80 -- 1秒あたりの目安
local _lastBudgetRefill = tick()

local function RemoteAllowed(cost)
    cost = cost or 1
    local now = tick()
    if now - _lastBudgetRefill >= 1 then
        _remoteBudget = 0
        _lastBudgetRefill = now
    end
    local maxBudget = SafeMode and _remoteBudgetMax or (_remoteBudgetMax * 3)
    if _remoteBudget + cost > maxBudget then
        return false
    end
    _remoteBudget = _remoteBudget + cost
    return true
end

local function SafeFire(remote, ...)
    if not remote then return false end
    if not RemoteAllowed(1) then return false end
    local args = {...}
    local ok = pcall(function()
        remote:FireServer(unpack(args))
    end)
    return ok
end

-- 参加・退出通知
Players.PlayerAdded:Connect(function(player)
    task.defer(function()
        task.wait(0.3)
        if SafeMode then
            Notify("入ってきました", player.DisplayName .. " (@" .. player.Name .. ")", 3, true)
        else
            Notify("入ってきました", player.DisplayName .. " (@" .. player.Name .. ")", 4)
        end
    end)
end)
Players.PlayerRemoving:Connect(function(player)
    if SafeMode then
        Notify("抜けました", player.DisplayName .. " (@" .. player.Name .. ")", 3, true)
    else
        Notify("抜けました", player.DisplayName .. " (@" .. player.Name .. ")", 4)
    end
end)


local function GetPlayerList()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(list, p.DisplayName .. " (@" .. p.Name .. ")")
        end
    end
    if #list == 0 then
        table.insert(list, "なし")
    end
    return list
end

local function GetNameFromDisplay(display)
    if not display or display == "" or display == "なし" or display == "プレイヤーがいません" then
        return nil
    end
    local name = display:match("%(@(.+)%)$") or display:match("@(.+)%)")
    return name
end

function ExtractUsername(selected)
    if not selected then return nil end
    return selected:match("%(@(.+)%)$")
end

local function GetMyRoot()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function GetMyHum()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function GetToysFolder()
    return Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
end

local function SpamOwnership(hrp)
    if SetNetworkOwner and hrp then
        pcall(function() SetNetworkOwner:FireServer(hrp, hrp.CFrame) end)
    end
end

local function stvel(part)
    if part and part:IsA("BasePart") then
        part.AssemblyLinearVelocity = Vector3.zero
        part.AssemblyAngularVelocity = Vector3.zero
    end
end

function FWC(Parent, Name, Time)
    return Parent:FindFirstChild(Name) or Parent:WaitForChild(Name, Time or 3)
end

function grab(prt)
    if not prt or not prt:IsA("BasePart") then return end
    local GE = ReplicatedStorage:FindFirstChild("GrabEvents")
    if GE and GE:FindFirstChild("SetNetworkOwner") then
        pcall(function() GE.SetNetworkOwner:FireServer(prt, prt.CFrame) end)
    end
end

function spawntoy(name, cframe, vector)
    local toyFolder = Workspace:FindFirstChild(LocalPlayer.Name .. 'SpawnedInToys')
    if not toyFolder then return nil end
    local spawnedToy = nil
    local connection
    connection = toyFolder.ChildAdded:Connect(function(toy)
        if toy.Name == name then
            spawnedToy = toy
            connection:Disconnect()
        end
    end)
    task.spawn(function()
        local MT = ReplicatedStorage:FindFirstChild("MenuToys")
        if MT and MT:FindFirstChild("SpawnToyRemoteFunction") then
            pcall(function()
                MT.SpawnToyRemoteFunction:InvokeServer(name, cframe, vector or Vector3.new())
            end)
        end
    end)
    local waitStart = tick()
    while not spawnedToy and tick() - waitStart < 4 do
        RunService.Heartbeat:Wait()
    end
    if connection then connection:Disconnect() end
    return spawnedToy
end

function isTargetable(player)
    if not player or player == LocalPlayer then return false end
    if globalFriendWhitelist then
        local isFriend = false
        pcall(function()
            isFriend = LocalPlayer:IsFriendsWith(player.UserId)
        end)
        if isFriend then return false end
    end
    return true
end

function GetTargetablePlayerNames()
    local names = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if isTargetable(player) then
            table.insert(names, player.DisplayName .. " (@" .. player.Name .. ")")
        end
    end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    return names
end

workspace.DescendantAdded:Connect(function(d)
    if d.Name == "GrabBeam" then
        Lines = Lines + 1
        lagger = d.Parent and d.Parent.Parent and d.Parent.Parent.Parent
    end
end)

-- =====================================================
-- Blobman
-- =====================================================
local Blob = {}
function Blob.Find()
    local f = GetToysFolder()
    return f and f:FindFirstChild("CreatureBlobman")
end
function Blob.Spawn()
    local root = GetMyRoot()
    if not root or not SpawnToy then return nil end
    pcall(function() SpawnToy:InvokeServer("CreatureBlobman", root.CFrame * CFrame.new(0,0,-5), Vector3.new(0,90,0)) end)
    task.wait(0.6)
    return Blob.Find()
end
function Blob.Destroy()
    local b = Blob.Find()
    if b and DestroyToy then pcall(function() DestroyToy:FireServer(b) end) end
end
function Blob.ForceSit()
    local blob = Blob.Find()
    if not blob then return false end
    local seat = blob:FindFirstChild("VehicleSeat")
    local hum = GetMyHum()
    if seat and hum and not hum.Sit then
        seat:Sit(hum)
        task.wait(0.5)
    end
    return true
end
function Blob.Grab(blob, target, side)
    if not blob then return end
    local det = blob:FindFirstChild(side .. "Detector")
    if not det then return end
    local weld = det:FindFirstChild(side .. "Weld") or det:FindFirstChild("RigidConstraint")
    local script = blob:FindFirstChild("BlobmanSeatAndOwnerScript", true)
    local remote = script and script:FindFirstChild("CreatureGrab")
    if remote then pcall(function() remote:FireServer(det, target, weld) end) end
end
function Blob.Drop(blob, target, side)
    if not blob then return end
    local det = blob:FindFirstChild(side .. "Detector")
    if not det then return end
    local script = blob:FindFirstChild("BlobmanSeatAndOwnerScript", true)
    local remote = script and script:FindFirstChild("CreatureDrop")
    if remote then pcall(function() remote:FireServer(det, target) end) end
end

-- =====================================================
-- ラグ
-- =====================================================
local lineLagEnabled = false
local lineLagThread = nil
lineLagEnabledI = false
lineLagThreadI = nil
local linelag = false
local lps = 100
local packetLagTask = nil
local packetLagActive = false
local packetLagStrength = 2000

local function StartLineLag(intensity)
    intensity = math.clamp(intensity or 10, 1, SafeMode and 20 or 40)
    if lineLagEnabled then
        _G.__IchigoLagIntensity = intensity
        return
    end
    lineLagEnabled = true
    _G.__IchigoLagIntensity = intensity
    local createLine = CreateGrabLine
    if not createLine then
        local ge = ReplicatedStorage:FindFirstChild("GrabEvents")
        createLine = ge and ge:FindFirstChild("CreateGrabLine")
        CreateGrabLine = createLine
    end
    if not createLine then
        lineLagEnabled = false
        Notify("ラグ", "CreateGrabLineがありません", 3)
        return
    end
    lineLagThread = task.spawn(function()
        while lineLagEnabled do
            local intensityNow = _G.__IchigoLagIntensity or 15
            local spawnLoc = Workspace:FindFirstChild("SpawnLocation") or Workspace:FindFirstChild("Spawn") or GetMyRoot()
            if spawnLoc and createLine then
                for _ = 1, intensityNow do
                    if not lineLagEnabled then break end
                    if RemoteAllowed(1) then
                        pcall(function()
                            createLine:FireServer(spawnLoc, CFrame.new(math.random(-80000, 80000), 0, math.random(-80000, 80000)))
                        end)
                    end
                end
            end
            task.wait(SafeMode and 0.05 or 0.02)
        end
    end)
end

local function StopLineLag()
    lineLagEnabled = false
    if lineLagThread then pcall(task.cancel, lineLagThread) lineLagThread = nil end
end

function startLineLagI()
    if lineLagEnabledI then return end
    local ge = GrabEvents or ReplicatedStorage:FindFirstChild("GrabEvents")
    local createLine = ge and ge:FindFirstChild("CreateGrabLine")
    if not createLine then
        Notify("ラグ", "CreateGrabLineがありません", 3)
        return
    end
    lineLagEnabledI = true
    lineLagThreadI = task.spawn(function()
        while lineLagEnabledI do
            local spawnLocation = Workspace:FindFirstChild("SpawnLocation") or Workspace:FindFirstChild("Spawn") or GetMyRoot()
            if spawnLocation then
                local randomX = math.random(-2000000, 2000000)
                local randomZ = math.random(-2000000, 2000000)
                local directions = {
                    CFrame.new(randomX, 0, randomZ),
                    CFrame.new(-randomX, 0, -randomZ),
                    CFrame.new(randomX, 0, -randomZ),
                    CFrame.new(-randomX, 0, randomZ),
                }
                for _, pos in pairs(directions) do
                    if not lineLagEnabledI then break end
                    pcall(function() createLine:FireServer(spawnLocation, pos) end)
                end
            end
            task.wait()
        end
    end)
end

function stopLineLagI()
    lineLagEnabledI = false
    if lineLagThreadI then
        pcall(task.cancel, lineLagThreadI)
        lineLagThreadI = nil
    end
end

-- =====================================================
-- Arkadia Blob Spam Kick
-- =====================================================
function Arkadia_GetMyToysFolder()
    return workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
end
function Arkadia_GetBlobman()
    local folder = Arkadia_GetMyToysFolder()
    return folder and folder:FindFirstChild("CreatureBlobman")
end
function Arkadia_SpawnBlobman()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local mt = ReplicatedStorage:FindFirstChild("MenuToys")
    local spawnFn = mt and mt:FindFirstChild("SpawnToyRemoteFunction")
    if not spawnFn then return end
    local spawnCF = root.CFrame * CFrame.new(0, 0, -5)
    pcall(function()
        spawnFn:InvokeServer("CreatureBlobman", spawnCF, Vector3.new(0, 90, 0))
    end)
end
function Arkadia_DestroyBlobman()
    local blob = Arkadia_GetBlobman()
    if not blob then return end
    local mt = ReplicatedStorage:FindFirstChild("MenuToys")
    local destroyFn = mt and mt:FindFirstChild("DestroyToy")
    if destroyFn then
        pcall(function() destroyFn:FireServer(blob) end)
    end
end
function Arkadia_BlobSpamKickLoop(targetName)
    local initialTargetPos = nil
    local hasCaptured = false
    local grabToggle = false
    local angle = 0
    while arkadiaBlobKickActive do
        local currentTarget = Players:FindFirstChild(targetName)
        local blob = Arkadia_GetBlobman()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChild("Humanoid")
        if not blob then
            Arkadia_SpawnBlobman()
            hasCaptured = false
            task.wait(0.5)
            continue
        end
        local seat = blob:FindFirstChildOfClass("VehicleSeat") or blob:FindFirstChildOfClass("Seat")
        if seat and hum and hum.SeatPart ~= seat then
            seat:Sit(hum)
        end
        local tChar = currentTarget and currentTarget.Character
        local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
        local tHum = tChar and tChar:FindFirstChild("Humanoid")
        local blobRoot = blob:FindFirstChild("HumanoidRootPart") or blob.PrimaryPart
        if tRoot and tHum and tHum.Health > 0 and blobRoot then
            if not initialTargetPos then
                initialTargetPos = tRoot.Position
            end
            local centerPoint = initialTargetPos + Vector3.new(arkadia_adjX, arkadia_adjY, arkadia_adjZ)
            if not hasCaptured then
                tRoot.CFrame = CFrame.new(centerPoint)
                tHum.PlatformStand = true
                if GrabEvents and GrabEvents.SetNetworkOwner then
                    GrabEvents.SetNetworkOwner:FireServer(tRoot, tRoot.CFrame)
                end
                task.wait(0.1)
                hasCaptured = true
            end
            angle = angle + arkadia_adjSpeed
            local offsetX = math.cos(angle) * arkadia_adjRadius
            local offsetZ = math.sin(angle) * arkadia_adjRadius
            local myNewPos = centerPoint + Vector3.new(offsetX, 0, offsetZ)
            blobRoot.CFrame = CFrame.new(myNewPos, centerPoint)
            blobRoot.AssemblyLinearVelocity = Vector3.zero
            tRoot.CFrame = CFrame.new(centerPoint)
            pcall(function()
                local scriptObj = blob:FindFirstChild("BlobmanSeatAndOwnerScript")
                if scriptObj then
                    local CG = scriptObj:FindFirstChild("CreatureGrab")
                    local CD = scriptObj:FindFirstChild("CreatureDrop")
                    local R_Det = blob:FindFirstChild("RightDetector")
                    local weld = R_Det and (R_Det:FindFirstChild("RightWeld") or R_Det:FindFirstChildWhichIsA("Weld"))
                    if weld then CD:FireServer(weld) end
                    grabToggle = not grabToggle
                    local targetToGrab = grabToggle and tRoot or blobRoot
                    if GrabEvents and GrabEvents.SetNetworkOwner then
                        GrabEvents.SetNetworkOwner:FireServer(tRoot, tRoot.CFrame)
                    end
                    if GrabEvents and GrabEvents:FindFirstChild("DestroyGrabLine") then
                        GrabEvents.DestroyGrabLine:FireServer(tRoot)
                    end
                    if CG and R_Det and weld then
                        CG:FireServer(R_Det, targetToGrab, weld)
                    end
                end
            end)
        else
            initialTargetPos = nil
            hasCaptured = false
        end
        RunService.Heartbeat:Wait()
    end
    Arkadia_DestroyBlobman()
end

-- =====================================================
-- Loop系関数
-- =====================================================
function LoopBlobKickSpamFunction()
    local GE = ReplicatedStorage:FindFirstChild("GrabEvents") or ReplicatedStorage:WaitForChild("GrabEvents", 5)
    if not GE then Notify("Error", "GrabEventsがありません") return end
    local REMOTE_DELAY = 0.002
    local lastRemote = 0
    local savedPos = nil
    while loopBlobKickSpamActive do
        local target = Players:FindFirstChild(loopBlobKickSpamTargetName)
        if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
            task.wait(0.3)
            continue
        end
        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local hum = char:WaitForChild("Humanoid")
        local seat = hum.SeatPart
        if not seat or seat.Parent.Name ~= "CreatureBlobman" then
            Notify("Loop Blob Kick Spam", "Blobmanに座ってください")
            if Toggles.LoopBlobKickSpamToggle then Toggles.LoopBlobKickSpamToggle:SetValue(false) end
            return
        end
        local blob = seat.Parent
        local blobRoot = blob:FindFirstChild("HumanoidRootPart") or blob.PrimaryPart
        local scriptObj = blob:WaitForChild("BlobmanSeatAndOwnerScript")
        local CG = scriptObj:WaitForChild("CreatureGrab")
        local CD = scriptObj:WaitForChild("CreatureDrop")
        local R_Det = blob:WaitForChild("RightDetector")
        savedPos = blobRoot.CFrame
        local dragging = false
        local grabStartTime = 0
        while loopBlobKickSpamActive do
            local currentTarget = Players:FindFirstChild(loopBlobKickSpamTargetName)
            if not currentTarget then break end
            char = LocalPlayer.Character
            hum = char and char:FindFirstChild("Humanoid")
            seat = hum and hum.SeatPart
            if not seat or seat.Parent.Name ~= "CreatureBlobman" then break end
            blobRoot = seat.Parent:FindFirstChild("HumanoidRootPart") or seat.Parent.PrimaryPart
            local tChar = currentTarget.Character
            local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
            local tHum = tChar and tChar:FindFirstChild("Humanoid")
            if tRoot and tHum and tHum.Health > 0 and blobRoot then
                tRoot.AssemblyLinearVelocity = Vector3.zero
                if not dragging then
                    blobRoot.CFrame = tRoot.CFrame
                    blobRoot.AssemblyLinearVelocity = Vector3.zero
                    if tick() - lastRemote >= REMOTE_DELAY then
                        lastRemote = tick()
                        pcall(function()
                            tHum.PlatformStand = true
                            tHum.Sit = true
                            local so = GE:FindFirstChild("SetNetworkOwner")
                            local dg = GE:FindFirstChild("DestroyGrabLine")
                            if so then so:FireServer(tRoot, blobRoot.CFrame) end
                            if dg then dg:FireServer(tRoot) end
                        end)
                    end
                    if grabStartTime == 0 then grabStartTime = tick() end
                    if tick() - grabStartTime > 0.35 then
                        dragging = true
                        grabStartTime = 0
                        blobRoot.CFrame = savedPos
                    end
                else
                    blobRoot.CFrame = savedPos
                    blobRoot.AssemblyLinearVelocity = Vector3.zero
                    local lockPos = savedPos * CFrame.new(0, 23, 0)
                    tRoot.CFrame = lockPos
                    tHum.PlatformStand = true
                    tHum.Sit = true
                    if tick() - lastRemote >= REMOTE_DELAY then
                        lastRemote = tick()
                        pcall(function()
                            local so = GE:FindFirstChild("SetNetworkOwner")
                            local dg = GE:FindFirstChild("DestroyGrabLine")
                            if so then so:FireServer(tRoot, lockPos) end
                            if dg then dg:FireServer(tRoot) end
                            local weld = R_Det:FindFirstChild("RightWeld") or R_Det:FindFirstChildWhichIsA("Weld")
                            if weld then
                                CD:FireServer(weld)
                                CG:FireServer(R_Det, tRoot, weld)
                            end
                        end)
                    end
                end
            else
                dragging = false
                grabStartTime = 0
            end
            RunService.Heartbeat:Wait()
        end
        if blobRoot then blobRoot.CFrame = savedPos end
    end
end

function RunLoopKill1(targetName)
    while loopKill1Active do
        local target = Players:FindFirstChild(targetName)
        if target and target.Character then
            local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
            local tHum = target.Character:FindFirstChild("Humanoid")
            if tRoot and tHum and tHum.Health > 0 then
                local myChar = LocalPlayer.Character
                local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
                if myRoot then
                    local currentPos = myRoot.CFrame
                    local attackStart = tick()
                    while tick() - attackStart < 0.35 and loopKill1Active do
                        if not tRoot.Parent then break end
                        myRoot.CFrame = tRoot.CFrame * CFrame.new(0, 0, 2)
                        myRoot.Velocity = Vector3.zero
                        pcall(function()
                            ReplicatedStorage.GrabEvents.SetNetworkOwner:FireServer(tRoot, myRoot.CFrame)
                            tHum.BreakJointsOnDeath = false
                            tHum:ChangeState(Enum.HumanoidStateType.Dead)
                            ReplicatedStorage.GrabEvents.CreateGrabLine:FireServer(tRoot, Vector3.zero, tRoot.Position, false)
                            ReplicatedStorage.GrabEvents.DestroyGrabLine:FireServer(tRoot)
                        end)
                        RunService.Heartbeat:Wait()
                    end
                    if myRoot then
                        myRoot.CFrame = currentPos
                        myRoot.Velocity = Vector3.zero
                    end
                end
            end
        end
        task.wait(0.05)
    end
end

function RunLoopKill2(targetName)
    local SETTINGS = { ATTACK_FRAME_LIMIT = 18, OFFSET = CFrame.new(0, 0, 2.5) }
    while loopKill2Active do
        local target = Players:FindFirstChild(targetName)
        if target and target.Character then
            local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
            local tHum = target.Character:FindFirstChildOfClass("Humanoid")
            if tRoot and tHum and tHum.Health > 0 then
                local myChar = LocalPlayer.Character
                local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
                if myRoot then
                    local originalPos = myRoot.CFrame
                    local frameCount = 0
                    while frameCount < SETTINGS.ATTACK_FRAME_LIMIT and tHum and tHum.Health > 0 and loopKill2Active do
                        frameCount = frameCount + 1
                        myRoot.CFrame = tRoot.CFrame * SETTINGS.OFFSET
                        myRoot.Velocity = Vector3.zero
                        myRoot.RotVelocity = Vector3.zero
                        pcall(function()
                            ReplicatedStorage.GrabEvents.SetNetworkOwner:FireServer(tRoot, myRoot.CFrame)
                            tHum.BreakJointsOnDeath = false
                            tHum:ChangeState(Enum.HumanoidStateType.Dead)
                            ReplicatedStorage.GrabEvents.CreateGrabLine:FireServer(tRoot, Vector3.new(0, -200, 0), tRoot.Position, true)
                            ReplicatedStorage.GrabEvents.DestroyGrabLine:FireServer(tRoot)
                        end)
                        RunService.Heartbeat:Wait()
                    end
                    if myRoot then myRoot.CFrame = originalPos end
                end
            end
        end
        task.wait(0.05)
    end
end

function RunKickSpam(targetName)
    local GE = ReplicatedStorage:WaitForChild("GrabEvents")
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    local savedPos = myRoot.CFrame
    local dragging, grabStartTime = false, 0
    while kickLoopEnabled do
        local target = Players:FindFirstChild(targetName)
        if not target or not target.Parent then
            kickLoopEnabled = false
            if Toggles.LoopKickToggle then Toggles.LoopKickToggle:SetValue(false) end
            break
        end
        local tChar, tRoot, tHum = target.Character, nil, nil
        if tChar then
            tRoot = tChar:FindFirstChild("HumanoidRootPart")
            tHum = tChar:FindFirstChild("Humanoid")
        end
        myChar = LocalPlayer.Character
        myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if tRoot and tHum and tHum.Health > 0 and myRoot then
            tRoot.AssemblyLinearVelocity = Vector3.zero
            if not dragging then
                myRoot.CFrame = tRoot.CFrame
                pcall(function()
                    tHum.PlatformStand = true tHum.Sit = true
                    GE.SetNetworkOwner:FireServer(tRoot, myRoot.CFrame)
                    GE.CreateGrabLine:FireServer(tRoot, Vector3.zero, tRoot.Position, false)
                end)
                if grabStartTime == 0 then grabStartTime = tick() end
                if tick() - grabStartTime > 0.35 then dragging = true grabStartTime = 0 end
            else
                myRoot.CFrame = savedPos
                local lockPos = savedPos * CFrame.new(0, 17, 0)
                tRoot.CFrame = lockPos
                tHum.PlatformStand = true tHum.Sit = false
                pcall(function()
                    GE.SetNetworkOwner:FireServer(tRoot, lockPos)
                    GE.CreateGrabLine:FireServer(tRoot, Vector3.zero, tRoot.Position, false)
                    GE.DestroyGrabLine:FireServer(tRoot)
                    GE.CreateGrabLine:FireServer(tRoot, Vector3.zero, tRoot.Position, false)
                end)
            end
        else
            dragging = false grabStartTime = 0
            if myRoot then myRoot.CFrame = savedPos end
        end
        RunService.Heartbeat:Wait()
    end
    if myRoot then myRoot.CFrame = savedPos end
end

function SnowballRagdollFunction()
    while snowballRagdollActive do
        local target = Players:FindFirstChild(snowballRagdollTargetName)
        if not target or not target.Character then task.wait(0.5) continue end
        local tChar = target.Character
        local torso = tChar and (tChar:FindFirstChild("UpperTorso") or tChar:FindFirstChild("Torso"))
        if not torso then task.wait() continue end
        pcall(function()
            local offset = Vector3.new(math.random(-30, 30) / 100, math.random(-30, 30) / 100, math.random(-30, 30) / 100)
            local SpawnRemote = ReplicatedStorage:WaitForChild("MenuToys"):WaitForChild("SpawnToyRemoteFunction")
            SpawnRemote:InvokeServer("BallSnowball", torso.CFrame * CFrame.new(offset), Vector3.zero)
        end)
        local folder = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
        if folder then
            for _, snowball in pairs(folder:GetChildren()) do
                if snowball.Name == "BallSnowball" and snowball.Parent then
                    local part = snowball.PrimaryPart or snowball:FindFirstChildWhichIsA("BasePart")
                    if part then
                        local offset = Vector3.new(math.random(-30, 30) / 100, math.random(-30, 30) / 100, math.random(-30, 30) / 100)
                        part.CFrame = torso.CFrame * CFrame.new(offset)
                        part.AssemblyLinearVelocity = Vector3.zero
                        part.AssemblyAngularVelocity = Vector3.zero
                    end
                end
            end
        end
        task.wait()
    end
end

-- =====================================================
-- Blobman Kill System
-- =====================================================
BlobmanKill = {}
BlobmanKill.isRunning = false
BlobmanKill.isKillAura = false
BlobmanKill.isSelectedKill = false
BlobmanKill.selectedPlayer = nil
BlobmanKill.currentBlobman = nil
BlobmanKill.killAuraConnection = nil
BlobmanKill.selectedKillThread = nil
local TP_WAIT = 0.02
local GRAB_WAIT = 0.01
local RETRY_WAIT = 0.01
local MAX_RETRIES = 5
local MAX_BLOBMAN_DISTANCE = 500

local function GetSeatedBlobman()
    local char = LocalPlayer.Character
    if not char then return nil end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return nil end
    local seat = humanoid.SeatPart
    if not seat or not seat:IsA("VehicleSeat") then return nil end
    local obj = seat
    while obj do
        if obj:IsA("Model") and obj.Name == "CreatureBlobman" then
            return obj
        end
        obj = obj.Parent
    end
    return nil
end

function BlobmanKill.SpawnBlobman()
    local seatedBlobman = GetSeatedBlobman()
    if seatedBlobman then
        BlobmanKill.currentBlobman = seatedBlobman
        return seatedBlobman
    end
    if BlobmanKill.currentBlobman and BlobmanKill.currentBlobman.Parent then
        local blobmanPos = nil
        if BlobmanKill.currentBlobman.PrimaryPart then
            blobmanPos = BlobmanKill.currentBlobman.PrimaryPart.Position
        else
            local part = BlobmanKill.currentBlobman:FindFirstChildWhichIsA("BasePart")
            if part then blobmanPos = part.Position end
        end
        local character = LocalPlayer.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        local localPos = rootPart and rootPart.Position
        if blobmanPos and localPos and (blobmanPos - localPos).Magnitude < MAX_BLOBMAN_DISTANCE then
            local seat = BlobmanKill.currentBlobman:FindFirstChild("VehicleSeat")
            if seat then
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    seat:Sit(humanoid)
                    task.wait(0.08)
                end
            end
            return BlobmanKill.currentBlobman
        else
            pcall(function() BlobmanKill.currentBlobman:Destroy() end)
            BlobmanKill.currentBlobman = nil
        end
    end
    local character = LocalPlayer.Character
    if not character then return nil end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end
    local spawnPos = rootPart.CFrame * CFrame.new(0, 0, -5)
    local success = pcall(function()
        ReplicatedStorage.MenuToys.SpawnToyRemoteFunction:InvokeServer("CreatureBlobman", spawnPos, Vector3.new(0, 127, 0))
    end)
    if not success then return nil end
    local toyFolderName = LocalPlayer.Name .. "SpawnedInToys"
    local blobman = nil
    local startTime = tick()
    repeat
        local toyFolder = workspace:FindFirstChild(toyFolderName)
        if toyFolder then blobman = toyFolder:FindFirstChild("CreatureBlobman") end
        if blobman then break end
        task.wait()
    until tick() - startTime > 2
    if not blobman then return nil end
    BlobmanKill.currentBlobman = blobman
    local seat = blobman:FindFirstChild("VehicleSeat")
    if seat then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then seat:Sit(humanoid) end
    end
    task.wait(0.08)
    return blobman
end

function BlobmanKill.KillPlayer(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return false end
    local humanoid = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    for _ = 1, MAX_RETRIES do
        local success = pcall(function()
            humanoid.BreakJointsOnDeath = false
            humanoid:ChangeState(Enum.HumanoidStateType.Dead)
        end)
        if success and humanoid.Health <= 0 then return true end
        task.wait(RETRY_WAIT)
    end
    return false
end

function BlobmanKill.GrabRelease(blobman, targetRoot)
    if not blobman or not targetRoot then return end
    pcall(function()
        local script = blobman:FindFirstChild("BlobmanSeatAndOwnerScript")
        if script then
            script.CreatureGrab:FireServer(blobman.LeftDetector, targetRoot, blobman.LeftDetector.LeftWeld)
            script.CreatureRelease:FireServer(blobman.LeftDetector.LeftWeld)
        end
    end)
end

function BlobmanKill.ProcessPlayer(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return false end
    local humanoid = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return false end
    local blobman = BlobmanKill.SpawnBlobman()
    if not blobman then return false end
    local localChar = LocalPlayer.Character
    if localChar and localChar:FindFirstChild("HumanoidRootPart") then
        localChar.HumanoidRootPart.CFrame = targetRoot.CFrame
        task.wait(TP_WAIT)
    end
    BlobmanKill.KillPlayer(targetPlayer)
    for _ = 1, 3 do
        BlobmanKill.GrabRelease(blobman, targetRoot)
        task.wait(GRAB_WAIT)
    end
    return true
end

function BlobmanKill.ProcessAllPlayers()
    local localChar = LocalPlayer.Character
    if not localChar or not localChar:FindFirstChild("HumanoidRootPart") then return end
    local rootPart = localChar.HumanoidRootPart
    local blobman = BlobmanKill.SpawnBlobman()
    if not blobman then return end
    local targets = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and isTargetable(player) and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(targets, player)
        end
    end
    for _, player in ipairs(targets) do
        if not BlobmanKill.isRunning then break end
        local targetChar = player.Character
        if not targetChar then continue end
        local humanoid = targetChar:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end
        local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
        if not targetRoot then continue end
        rootPart.CFrame = targetRoot.CFrame
        task.wait(TP_WAIT)
        BlobmanKill.KillPlayer(player)
        for _ = 1, 2 do
            BlobmanKill.GrabRelease(blobman, targetRoot)
            task.wait(GRAB_WAIT)
        end
    end
end

function BlobmanKill.StartSelectedKillLoop()
    if BlobmanKill.selectedKillThread then
        pcall(task.cancel, BlobmanKill.selectedKillThread)
        BlobmanKill.selectedKillThread = nil
    end
    if not BlobmanKill.selectedPlayer then return end
    BlobmanKill.selectedKillThread = task.spawn(function()
        while BlobmanKill.isSelectedKill and BlobmanKill.selectedPlayer and BlobmanKill.selectedPlayer.Parent do
            if BlobmanKill.selectedPlayer.Character and BlobmanKill.selectedPlayer.Character:FindFirstChild("HumanoidRootPart") then
                pcall(BlobmanKill.ProcessPlayer, BlobmanKill.selectedPlayer)
            end
            task.wait(0.5)
        end
    end)
end

function BlobmanKill.SetupKillAura()
    if BlobmanKill.killAuraConnection then
        BlobmanKill.killAuraConnection:Disconnect()
        BlobmanKill.killAuraConnection = nil
    end
    local auraRange = 40
    BlobmanKill.killAuraConnection = RunService.Heartbeat:Connect(function()
        if not (BlobmanKill.isKillAura or BlobmanKill.isRunning) then return end
        local localChar = LocalPlayer.Character
        if not localChar or not localChar:FindFirstChild("HumanoidRootPart") then return end
        local localRoot = localChar.HumanoidRootPart
        if not BlobmanKill.currentBlobman or not BlobmanKill.currentBlobman.Parent then
            BlobmanKill.currentBlobman = BlobmanKill.SpawnBlobman()
            if not BlobmanKill.currentBlobman then return end
        end
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and isTargetable(player) and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                local targetRoot = player.Character.HumanoidRootPart
                if (localRoot.Position - targetRoot.Position).Magnitude <= auraRange then
                    BlobmanKill.KillPlayer(player)
                    BlobmanKill.GrabRelease(BlobmanKill.currentBlobman, targetRoot)
                end
            end
        end
    end)
end

function BlobmanKill.UpdateKillAuraConnection()
    local shouldRun = BlobmanKill.isKillAura or BlobmanKill.isRunning
    if shouldRun then
        if not BlobmanKill.killAuraConnection then BlobmanKill.SetupKillAura() end
    else
        if BlobmanKill.killAuraConnection then
            BlobmanKill.killAuraConnection:Disconnect()
            BlobmanKill.killAuraConnection = nil
        end
    end
end

-- =====================================================
-- BlobmanBeta
-- =====================================================
local BlobmanBeta = {}
function BlobmanBeta.getLocalChar() return LocalPlayer.Character end
function BlobmanBeta.getLocalRoot()
    local char = BlobmanBeta.getLocalChar()
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
end
function BlobmanBeta.getLocalHum()
    local char = BlobmanBeta.getLocalChar()
    return char and char:FindFirstChildOfClass("Humanoid")
end
function BlobmanBeta.getInv() return Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys") end
function BlobmanBeta.SetNetworkOwner(part)
    pcall(function() ReplicatedStorage.GrabEvents.SetNetworkOwner:FireServer(part, BlobmanBeta.getLocalRoot().CFrame) end)
end
function BlobmanBeta.ungrab(part)
    pcall(function() ReplicatedStorage.GrabEvents.DestroyGrabLine:FireServer(part) end)
end
function BlobmanBeta.getBlobman()
    local inv = BlobmanBeta.getInv()
    if inv then
        local v = inv:FindFirstChild("CreatureBlobman")
        if v and v:FindFirstChild("VehicleSeat") then return v end
    end
    return nil
end
function BlobmanBeta.spawnBlobman()
    local root = BlobmanBeta.getLocalRoot()
    if not root then return nil end
    pcall(function() ReplicatedStorage.MenuToys.SpawnToyRemoteFunction:InvokeServer("CreatureBlobman", root.CFrame, Vector3.zero) end)
    task.wait(1.0)
    return BlobmanBeta.getBlobman()
end
function BlobmanBeta.destroyBlobman()
    local blob = BlobmanBeta.getBlobman()
    if blob then pcall(function() ReplicatedStorage.MenuToys.DestroyToy:FireServer(blob) end) end
end
function BlobmanBeta.isSittingOnBlobman()
    local hum = BlobmanBeta.getLocalHum()
    if not hum then return false end
    local blob = BlobmanBeta.getBlobman()
    if not blob or not blob:FindFirstChild("VehicleSeat") then return false end
    return hum.Sit and hum.SeatPart == blob.VehicleSeat
end
function BlobmanBeta.ensureSitBlobman()
    local blob = BlobmanBeta.getBlobman()
    if not blob or not blob:FindFirstChild("VehicleSeat") then return false end
    local seat = blob.VehicleSeat
    local hum = BlobmanBeta.getLocalHum()
    if hum and not hum.Sit then
        seat:Sit(hum)
        task.wait(0.6)
    end
    return BlobmanBeta.isSittingOnBlobman()
end
function BlobmanBeta.blobGrab(blob, target, side)
    if not blob then return end
    local detector = blob:FindFirstChild(side .. "Detector")
    if not detector then return end
    local weld = detector:FindFirstChild(side .. "Weld")
    if not weld then return end
    local script = blob:FindFirstChild("BlobmanSeatAndOwnerScript", true)
    if not script then return end
    local remote = script:FindFirstChild("CreatureGrab")
    if remote then pcall(function() remote:FireServer(detector, target, weld) end) end
end
function BlobmanBeta.blobDrop(blob, target, side)
    if not blob then return end
    local detector = blob:FindFirstChild(side .. "Detector")
    if not detector then return end
    local script = blob:FindFirstChild("BlobmanSeatAndOwnerScript", true)
    if not script then return end
    local remote = script:FindFirstChild("CreatureDrop")
    if remote then pcall(function() remote:FireServer(detector, target) end) end
end
function BlobmanBeta.blobKick(blob, targetRoot, side)
    BlobmanBeta.blobGrab(blob, BlobmanBeta.getLocalRoot(), side)
    task.wait(0.08)
    BlobmanBeta.SetNetworkOwner(targetRoot)
    task.wait(0.08)
    targetRoot.CFrame = targetRoot.CFrame + Vector3.new(0, 16, 0)
    task.wait(0.08)
    BlobmanBeta.ungrab(targetRoot)
    task.wait(0.08)
    BlobmanBeta.blobGrab(blob, targetRoot, side)
    task.wait(0.08)
    BlobmanBeta.blobDrop(blob, targetRoot, side)
    task.wait(0.08)
    BlobmanBeta.ungrab(targetRoot)
end

-- =====================================================
-- Window
-- =====================================================
local Window = Library:CreateWindow({
    Title = "いちごハブ完全統合版",
    Footer = "全機能保持 / 黒×赤 (Resonance)",
    NotifySide = "Right",
    ShowCustomCursor = true,
    Center = true,
    AutoShow = true,
    Resizable = true,
})

local Tabs = {
    Home = Window:AddTab("Home", "house"),
    Kick = Window:AddTab("キック", "swords"),
    Kill = Window:AddTab("キル", "skull"),
    Grab = Window:AddTab("グレイブ", "hand"),
    Ragdoll = Window:AddTab("Ragdoll", "hammer"),
    Extra = Window:AddTab("Extra", "star"),
    Lag = Window:AddTab("ラグ", "activity"),
    Defence = Window:AddTab("Defence", "shield"),
    Player = Window:AddTab("プレイヤー", "user"),
    Settings = Window:AddTab("Settings", "settings"),
}

-- =====================================================
-- Homeタブ
-- =====================================================
do
    local profileBox = Tabs.Home:AddLeftGroupbox("Profile & Status")
    local container = profileBox.Container or profileBox.ScrollBox or profileBox.MainFrame
    if container then
        local avatarContainer = Instance.new("Frame")
        avatarContainer.Size = UDim2.new(1, 0, 0, 280)
        avatarContainer.BackgroundTransparency = 1
        avatarContainer.Parent = container

        local avatarImage = Instance.new("ImageLabel")
        avatarImage.Size = UDim2.new(0, 160, 0, 160)
        avatarImage.Position = UDim2.new(0.5, 0, 0, 12)
        avatarImage.AnchorPoint = Vector2.new(0.5, 0)
        avatarImage.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        avatarImage.BorderSizePixel = 0
        avatarImage.Parent = avatarContainer

        local imgCorner = Instance.new("UICorner")
        imgCorner.CornerRadius = UDim.new(1, 0)
        imgCorner.Parent = avatarImage

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromHex("ef4444")
        stroke.Thickness = 2
        stroke.Parent = avatarImage

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, 0, 0, 30)
        nameLabel.Position = UDim2.new(0.5, 0, 0, 185)
        nameLabel.AnchorPoint = Vector2.new(0.5, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = LocalPlayer.DisplayName
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 19
        nameLabel.TextXAlignment = Enum.TextXAlignment.Center
        nameLabel.Parent = avatarContainer

        local statusLabel = Instance.new("TextLabel")
        statusLabel.Size = UDim2.new(1, 0, 0, 24)
        statusLabel.Position = UDim2.new(0.5, 0, 0, 218)
        statusLabel.AnchorPoint = Vector2.new(0.5, 0)
        statusLabel.BackgroundTransparency = 1
        statusLabel.Text = "Welcome to Ichigo Hub"
        statusLabel.TextColor3 = Color3.fromHex("fca5a5")
        statusLabel.Font = Enum.Font.Gotham
        statusLabel.TextSize = 15
        statusLabel.TextXAlignment = Enum.TextXAlignment.Center
        statusLabel.Parent = avatarContainer

        task.spawn(function()
            local success, content = pcall(function()
                return Players:GetUserThumbnailAsync(
                    LocalPlayer.UserId,
                    Enum.ThumbnailType.AvatarBust,
                    Enum.ThumbnailSize.Size420x420
                )
            end)
            if success and content then
                avatarImage.Image = content
                avatarImage.BackgroundTransparency = 1
            else
                statusLabel.Text = "Failed to load avatar."
            end
        end)
    end
end

do
    local welcomeBox = Tabs.Home:AddRightGroupbox("Welcome")
    welcomeBox:AddLabel("Welcome to Ichigo Hub")
    welcomeBox:AddLabel("いちごハブ完全統合版へようこそ。全機能を保持したまま、Homeタブと黒×赤（Resonance風）テーマを追加しました。快適なゲームライフを！", true)

    welcomeBox:AddButton({
        Text = "Copy Discord Link",
        Func = function()
            pcall(function()
                if setclipboard then
                    setclipboard(DiscordInvite)
                end
            end)
            Library:Notify({ Title = "いちごハブ", Description = "Discordリンクをコピーしました！", Time = 3 })
        end,
        Tooltip = DiscordInvite,
    })
end

do
    local infoBox = Tabs.Home:AddRightGroupbox("Information")
    infoBox:AddLabel("Display Name:  " .. LocalPlayer.DisplayName)
    infoBox:AddLabel("Username:  @" .. LocalPlayer.Name)
    infoBox:AddLabel("Account created:  " .. GetAccountCreationDate() .. " (" .. GetAccountAge() .. " ago)")
    infoBox:AddLabel("Executor:  " .. ExecutorName)

    local SessionJoinClock = os.clock()
    local SessionJoinUnix = os.time()

    local clockLabel = infoBox:AddLabel("現在時刻:  --:--:--")
    local uptimeLabel = infoBox:AddLabel("スクリプト稼働:  00:00:00")
    local sessionLabel = infoBox:AddLabel("サーバー滞在:  00:00:00")
    local joinLabel = infoBox:AddLabel("参加時刻:  " .. os.date("%H:%M:%S", SessionJoinUnix))

    local function fmtHMS(sec)
        sec = math.max(0, math.floor(sec))
        local h = math.floor(sec / 3600)
        local m = math.floor(sec % 3600 / 60)
        local s = sec % 60
        return string.format("%02d:%02d:%02d", h, m, s)
    end

    task.spawn(function()
        while true do
            task.wait(1)
            local now = os.time()
            local scriptElapsed = os.clock() - ScriptStartClock
            local sessionElapsed = os.clock() - SessionJoinClock
            pcall(function()
                clockLabel:SetText("現在時刻:  " .. os.date("%Y-%m-%d %H:%M:%S", now))
                uptimeLabel:SetText("スクリプト稼働:  " .. fmtHMS(scriptElapsed))
                sessionLabel:SetText("サーバー滞在:  " .. fmtHMS(sessionElapsed))
            end)
        end
    end)
end

do
    local timeBox = Tabs.Home:AddLeftGroupbox("Timer / 時間")
    local SessionJoinClock2 = os.clock()
    local stopwatchRunning = false
    local stopwatchStart = 0
    local stopwatchAcc = 0

    local serverTimeLabel = timeBox:AddLabel("サーバー時間:  00:00:00")
    local stopwatchLabel = timeBox:AddLabel("ストップウォッチ:  00:00:00")

    local function fmtHMS(sec)
        sec = math.max(0, math.floor(sec))
        return string.format("%02d:%02d:%02d", math.floor(sec / 3600), math.floor(sec % 3600 / 60), sec % 60)
    end

    timeBox:AddButton({
        Text = "ストップウォッチ 開始/停止",
        Func = function()
            if stopwatchRunning then
                stopwatchAcc = stopwatchAcc + (os.clock() - stopwatchStart)
                stopwatchRunning = false
                Notify("Timer", "ストップウォッチ停止", 2, true)
            else
                stopwatchStart = os.clock()
                stopwatchRunning = true
                Notify("Timer", "ストップウォッチ開始", 2, true)
            end
        end,
    })

    timeBox:AddButton({
        Text = "ストップウォッチ リセット",
        Func = function()
            stopwatchRunning = false
            stopwatchAcc = 0
            stopwatchStart = 0
            pcall(function() stopwatchLabel:SetText("ストップウォッチ:  00:00:00") end)
            Notify("Timer", "リセット", 2, true)
        end,
    })

    task.spawn(function()
        while true do
            task.wait(0.25)
            local sessionElapsed = os.clock() - SessionJoinClock2
            local sw = stopwatchAcc
            if stopwatchRunning then
                sw = sw + (os.clock() - stopwatchStart)
            end
            pcall(function()
                serverTimeLabel:SetText("サーバー滞在:  " .. fmtHMS(sessionElapsed))
                stopwatchLabel:SetText("ストップウォッチ:  " .. fmtHMS(sw))
            end)
        end
    end)
end

-- =====================================================
-- キックタブ
-- =====================================================
do
    local left = Tabs.Kick:AddLeftGroupbox("単体キック")
    local selectedKick = nil
    local kickDrop = left:AddDropdown("KickSelect", {
        Values = GetPlayerList(), Default = 1, Text = "プレイヤー選択",
        Callback = function(v) selectedKick = GetNameFromDisplay(v) end
    })
    task.spawn(function()
        while true do
            task.wait(2)
            pcall(function() kickDrop:SetValues(GetPlayerList()) end)
        end
    end)
    left:AddButton({
        Text = "Blobman Kick",
        Func = function()
            if not selectedKick then Notify("Error", "プレイヤーを選択") return end
            local target = Players:FindFirstChild(selectedKick)
            if not target or not target.Character then return end
            local tr = target.Character:FindFirstChild("HumanoidRootPart")
            if not tr then return end
            local blob = Blob.Find() or Blob.Spawn()
            if not blob then return end
            Blob.ForceSit()
            local my = GetMyRoot()
            if my then
                local old = my.CFrame
                my.CFrame = tr.CFrame
                task.wait(0.07)
                Blob.Grab(blob, tr, "Left")
                task.wait(0.12)
                my.CFrame = old
            end
            Blob.Destroy()
            Notify("Success", "キック完了")
        end
    })

    local updown = Tabs.Kick:AddLeftGroupbox("上下キック")
    local updownTarget = nil
    local updownRunning = false
    local updownInitialCFrame = nil
    local standOffDistance = 20
    local verticalRange = 12
    local tpInterval = 0.01
    local verticalDir = 1

    local updownDrop = updown:AddDropdown("UpDownSelect", {
        Values = GetPlayerList(), Default = 1, Text = "ターゲット",
        Callback = function(v) updownTarget = GetNameFromDisplay(v) end
    })
    task.spawn(function()
        while true do
            task.wait(2)
            pcall(function() updownDrop:SetValues(GetPlayerList()) end)
        end
    end)

    updown:AddButton({
        Text = "プレイヤーリストを更新",
        Func = function()
            updownDrop:SetValues(GetPlayerList())
            Notify("上下キック", "リスト更新しました", 2)
        end
    })

    updown:AddToggle("UpDownToggle", {
        Text = "上下キック 実行",
        Default = false,
        Callback = function(v)
            updownRunning = v
            if not v then
                if updownInitialCFrame and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    pcall(function()
                        LocalPlayer.Character.HumanoidRootPart.CFrame = updownInitialCFrame
                    end)
                end
                Notify("上下キック", "停止: 元の場所に戻りました", 3)
                return
            end
            if not updownTarget or updownTarget == "" then
                Notify("Error", "ターゲットを選択してください", 3)
                Toggles.UpDownToggle:SetValue(false)
                return
            end
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                updownInitialCFrame = LocalPlayer.Character.HumanoidRootPart.CFrame
            end
            local spawnLocation = Workspace:FindFirstChild("SpawnLocation")
            local SavedPos = spawnLocation and spawnLocation.CFrame or CFrame.new(0, 50, 0)
            local targetCenterCFrame = SavedPos + Vector3.new(0, 30, 0)
            Notify("上下キック", "ループ開始", 3)
            task.spawn(function()
                while updownRunning do
                    local target = Players:FindFirstChild(updownTarget)
                    if target and target ~= LocalPlayer and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                        and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        local blobman = nil
                        local spawned = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
                        if spawned then blobman = spawned:FindFirstChild("CreatureBlobman") end
                        if not blobman then
                            local mt = ReplicatedStorage:FindFirstChild("MenuToys")
                            local st = mt and mt:FindFirstChild("SpawnToyRemoteFunction")
                            if st then
                                local myRoot = LocalPlayer.Character.HumanoidRootPart
                                local spawnCF = myRoot and (myRoot.CFrame + Vector3.new(0, 5, 0)) or CFrame.new(0, 50, 0)
                                pcall(function() st:InvokeServer("CreatureBlobman", spawnCF, Vector3.zero) end)
                                task.wait(0.1)
                                spawned = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
                                if spawned then blobman = spawned:FindFirstChild("CreatureBlobman") end
                            end
                        end
                        if not blobman then
                            for _, obj in ipairs(Workspace:GetChildren()) do
                                if obj.Name == "CreatureBlobman" and obj:FindFirstChild("VehicleSeat") then
                                    blobman = obj
                                    break
                                end
                            end
                        end
                        if blobman then
                            local seat = blobman:FindFirstChild("VehicleSeat")
                            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
                            if seat and hum then
                                if seat.Occupant ~= hum then
                                    LocalPlayer.Character.HumanoidRootPart.CFrame = seat.CFrame + Vector3.new(0, 2, 0)
                                    task.wait(0.1)
                                    pcall(function() seat:Sit(hum) end)
                                    task.wait(0.2)
                                end
                            end
                            local scriptObj = blobman:FindFirstChild("BlobmanSeatAndOwnerScript")
                            local grabRemote = scriptObj and scriptObj:FindFirstChild("CreatureGrab")
                            local dropRemote = scriptObj and scriptObj:FindFirstChild("CreatureDrop")
                            local lDet = blobman:FindFirstChild("LeftDetector")
                            local rDet = blobman:FindFirstChild("RightDetector")
                            local lWeld = lDet and (lDet:FindFirstChild("LeftWeld") or lDet:FindFirstChild("RigidConstraint"))
                            local rWeld = rDet and (rDet:FindFirstChild("RightWeld") or rDet:FindFirstChild("RigidConstraint"))
                            local GE = ReplicatedStorage:FindFirstChild("GrabEvents")
                            if GE and grabRemote and dropRemote and ((lDet and lWeld) or (rDet and rWeld)) then
                                local blobRoot = blobman:FindFirstChild("HumanoidRootPart") or blobman.PrimaryPart
                                local Det = rDet or lDet
                                local Weld = rWeld or lWeld
                                local bringStart = tick()
                                while tick() - bringStart < 0.1 do
                                    if not updownRunning or not blobman or not blobman.Parent then break end
                                    if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                                        local tRoot = target.Character.HumanoidRootPart
                                        blobRoot.CFrame = tRoot.CFrame
                                        blobRoot.AssemblyLinearVelocity = Vector3.zero
                                        pcall(function()
                                            if Det then grabRemote:FireServer(Det, tRoot, Weld) end
                                            if GE:FindFirstChild("CreateGrabLine") then
                                                GE.CreateGrabLine:FireServer(tRoot, Vector3.zero, tRoot.Position, false)
                                            end
                                            if GE:FindFirstChild("SetNetworkOwner") then
                                                GE.SetNetworkOwner:FireServer(tRoot, blobRoot.CFrame)
                                            end
                                        end)
                                    end
                                    RunService.Heartbeat:Wait()
                                end
                                if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                                    local lastDropTime = tick()
                                    local dropCount = 0
                                    local lastTPTime = tick()
                                    while updownRunning and blobman and blobman.Parent do
                                        if not target or not target.Parent or not target.Character then break end
                                        local tChar = target.Character
                                        local tRoot = tChar:FindFirstChild("HumanoidRootPart")
                                        local tHum = tChar:FindFirstChild("Humanoid")
                                        if not tRoot or not tHum or tHum.Health <= 0 then break end
                                        if dropCount < 2 and (tick() - lastDropTime) > 0.8 then
                                            dropCount = dropCount + 1
                                            pcall(function()
                                                local currentWeld = Det:FindFirstChild("RightWeld") or Det:FindFirstChild("LeftWeld")
                                                    or Det:FindFirstChildWhichIsA("Weld") or Det:FindFirstChild("RigidConstraint")
                                                if currentWeld and dropRemote then
                                                    dropRemote:FireServer(currentWeld)
                                                end
                                                if GE:FindFirstChild("DestroyGrabLine") then
                                                    GE.DestroyGrabLine:FireServer(tRoot)
                                                end
                                            end)
                                            blobRoot.CFrame = SavedPos
                                            blobRoot.AssemblyLinearVelocity = Vector3.zero
                                            task.wait(0.1)
                                            local reCaptureStart = tick()
                                            while tick() - reCaptureStart < 0.35 do
                                                if not updownRunning or not blobman or not blobman.Parent then break end
                                                if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                                                    local currentTRoot = target.Character.HumanoidRootPart
                                                    blobRoot.CFrame = currentTRoot.CFrame
                                                    blobRoot.AssemblyLinearVelocity = Vector3.zero
                                                    pcall(function()
                                                        if Det then grabRemote:FireServer(Det, currentTRoot, Weld) end
                                                        if GE:FindFirstChild("CreateGrabLine") then
                                                            GE.CreateGrabLine:FireServer(currentTRoot, Vector3.zero, currentTRoot.Position, false)
                                                        end
                                                        if GE:FindFirstChild("SetNetworkOwner") then
                                                            GE.SetNetworkOwner:FireServer(currentTRoot, blobRoot.CFrame)
                                                        end
                                                    end)
                                                end
                                                RunService.Heartbeat:Wait()
                                            end
                                            lastDropTime = tick()
                                        end
                                        local now = tick()
                                        if now - lastTPTime >= tpInterval then
                                            lastTPTime = now
                                            verticalDir = -verticalDir
                                        end
                                        local yOffset = verticalDir * verticalRange
                                        local blobPos = targetCenterCFrame.Position + Vector3.new(0, yOffset, standOffDistance)
                                        blobRoot.CFrame = CFrame.new(blobPos)
                                        blobRoot.AssemblyLinearVelocity = Vector3.zero
                                        blobRoot.AssemblyAngularVelocity = Vector3.zero
                                        tRoot.CFrame = targetCenterCFrame
                                        tRoot.AssemblyLinearVelocity = Vector3.zero
                                        tRoot.AssemblyAngularVelocity = Vector3.zero
                                        pcall(function()
                                            tHum.PlatformStand = true
                                            tHum.Sit = true
                                            if GE:FindFirstChild("SetNetworkOwner") then
                                                GE.SetNetworkOwner:FireServer(tRoot, targetCenterCFrame)
                                            end
                                            local currentWeld = Det:FindFirstChild("RightWeld") or Det:FindFirstChild("LeftWeld")
                                                or Det:FindFirstChildWhichIsA("Weld") or Det:FindFirstChild("RigidConstraint")
                                            if currentWeld and dropRemote then
                                                dropRemote:FireServer(currentWeld)
                                            end
                                            if GE:FindFirstChild("DestroyGrabLine") then
                                                GE.DestroyGrabLine:FireServer(tRoot)
                                            end
                                            if Det then grabRemote:FireServer(Det, tRoot, Weld) end
                                            if GE:FindFirstChild("CreateGrabLine") then
                                                GE.CreateGrabLine:FireServer(tRoot, Vector3.zero, targetCenterCFrame.Position, false)
                                            end
                                        end)
                                        RunService.Heartbeat:Wait()
                                    end
                                end
                            end
                        end
                    end
                    task.wait(0.5)
                end
            end)
        end
    })

    local noblob = Tabs.Kick:AddRightGroupbox("ノーブロブキックオール (Destroy)")
    local noblobHeight = "Spawn"

    local function nb_getAllPlayers()
        local players = {}
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then table.insert(players, plr) end
        end
        return players
    end

    local function nb_spamOwnership(hrp)
        local ge = ReplicatedStorage:FindFirstChild("GrabEvents")
        local setOwner = ge and ge:FindFirstChild("SetNetworkOwner")
        if setOwner and hrp then pcall(function() setOwner:FireServer(hrp, hrp.CFrame) end) end
    end

    local function nb_teleportToPlayer(myHrp, targetHrp)
        if not myHrp or not targetHrp then return end
        pcall(function()
            myHrp.CFrame = targetHrp.CFrame * CFrame.new(0, 5, 5)
            myHrp.AssemblyLinearVelocity = Vector3.zero
        end)
    end

    local function nb_destroyLineOnPlayer(hrp)
        local ge = ReplicatedStorage:FindFirstChild("GrabEvents")
        local createLine = ge and ge:FindFirstChild("CreateGrabLine")
        local destroyLine = ge and ge:FindFirstChild("DestroyGrabLine")
        if not createLine or not destroyLine then return end
        pcall(function()
            createLine:FireServer(hrp, CFrame.new(0, 1e9, 0))
            task.wait()
            destroyLine:FireServer(hrp)
        end)
    end

    local nb_lineLagThread = nil
    local nb_lineLagEnabled = false

    local function nb_startLineLag()
        if nb_lineLagEnabled then return end
        nb_lineLagEnabled = true
        nb_lineLagThread = coroutine.create(function()
            local ge = ReplicatedStorage:FindFirstChild("GrabEvents")
            local createLine = ge and ge:FindFirstChild("CreateGrabLine")
            if not createLine then return end
            while nb_lineLagEnabled do
                local spawnLocation = Workspace:FindFirstChild("SpawnLocation")
                    or Workspace:FindFirstChild("Spawn")
                    or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"))
                if spawnLocation then
                    local randomX = math.random(-1e9, 1e9)
                    local randomZ = math.random(-1e9, 1e9)
                    local directions = {
                        CFrame.new(randomX, 0, randomZ),
                        CFrame.new(-randomX, 0, -randomZ),
                        CFrame.new(randomX, 0, -randomZ),
                        CFrame.new(-randomX, 0, randomZ)
                    }
                    for _, pos in pairs(directions) do
                        pcall(function() createLine:FireServer(spawnLocation, pos) end)
                    end
                end
                task.wait()
            end
        end)
        coroutine.resume(nb_lineLagThread)
    end

    local function nb_stopLineLag()
        nb_lineLagEnabled = false
        if nb_lineLagThread then
            pcall(coroutine.close, nb_lineLagThread)
            nb_lineLagThread = nil
        end
    end

    noblob:AddDropdown("NoblobHeight", {
        Values = {"Spawn (地上)", "Heaven (天国)"},
        Default = 1,
        Text = "破壊の高さモード",
        Callback = function(v)
            noblobHeight = (v == "Heaven (天国)") and "Heaven" or "Spawn"
        end
    })

    noblob:AddButton({
        Text = "Destroy Server",
        Func = function()
            task.spawn(function()
                local height = (noblobHeight == "Heaven") and 1e9 or 35
                nb_startLineLag()
                task.wait(1)
                local players = nb_getAllPlayers()
                if #players == 0 then
                    nb_stopLineLag()
                    Notify("Destroy", "対象プレイヤーがいません", 3)
                    return
                end
                local myChar = LocalPlayer.Character
                local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
                if not myHrp then nb_stopLineLag() return end
                local playerData = {}
                for _, plr in ipairs(players) do
                    local char = plr.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if hrp then table.insert(playerData, {player = plr, hrp = hrp}) end
                end
                for _, data in ipairs(playerData) do
                    nb_teleportToPlayer(myHrp, data.hrp)
                    task.wait(0.2)
                    nb_spamOwnership(data.hrp)
                    task.wait()
                end
                local radius = 40
                local angleStep = (math.pi * 2) / math.max(#playerData, 1)
                for idx, data in ipairs(playerData) do
                    local angle = (idx - 1) * angleStep
                    local x = math.cos(angle) * radius
                    local z = math.sin(angle) * radius
                    pcall(function()
                        data.hrp.CFrame = CFrame.new(x, height, z)
                        data.hrp.AssemblyLinearVelocity = Vector3.zero
                    end)
                    local bp = Instance.new("BodyPosition")
                    bp.MaxForce = Vector3.new(1e9, 1e9, 1e9)
                    bp.P = 40000000
                    bp.Position = Vector3.new(x, height, z)
                    bp.Parent = data.hrp
                    task.delay(2, function() pcall(function() bp:Destroy() end) end)
                    task.wait()
                end
                for i = 1, 8 do
                    for _, data in ipairs(playerData) do
                        nb_destroyLineOnPlayer(data.hrp)
                    end
                    task.wait(0.3)
                end
                Notify("Destroy", "完了！ラグは継続中です。", 3)
            end)
        end
    })

    noblob:AddButton({
        Text = "Stop Lag (ラグを止める)",
        Func = function()
            nb_stopLineLag()
            pcall(function() if StopLineLag then StopLineLag() end end)
            pcall(function() if stopLineLagI then stopLineLagI() end end)
            Notify("Lag", "ラグ処理を停止しました", 3)
        end
    })

    local imoKick = Tabs.Kick:AddRightGroupbox("いちごハブ キック系")
    local imoKickTarget = nil
    local imoKickDrop = imoKick:AddDropdown("ImoKickTarget", {
        Values = GetTargetablePlayerNames(), Default = 1, Text = "ターゲット",
        Callback = function(v) imoKickTarget = ExtractUsername(v) end
    })
    task.spawn(function()
        while true do
            task.wait(2)
            pcall(function() imoKickDrop:SetValues(GetTargetablePlayerNames()) end)
        end
    end)
    imoKick:AddSlider("ArkadiaAdjY", { Text = "高さ (Y)", Default = 23, Min = 0, Max = 1000, Rounding = 0, Callback = function(v) arkadia_adjY = v end })
    imoKick:AddSlider("ArkadiaAdjRadius", { Text = "旋回半径", Default = 18, Min = 5, Max = 100, Rounding = 0, Callback = function(v) arkadia_adjRadius = v end })
    imoKick:AddSlider("ArkadiaAdjSpeed", { Text = "旋回速度", Default = 15, Min = 0, Max = 100, Rounding = 1, Callback = function(v) arkadia_adjSpeed = v/100 end })
    imoKick:AddSlider("ArkadiaAdjX", { Text = "X オフセット", Default = 0, Min = -50, Max = 50, Rounding = 0, Callback = function(v) arkadia_adjX = v end })
    imoKick:AddSlider("ArkadiaAdjZ", { Text = "Z オフセット", Default = 0, Min = -50, Max = 50, Rounding = 0, Callback = function(v) arkadia_adjZ = v end })
    imoKick:AddToggle("ArkadiaBlobKickToggle", {
        Text = "blob spam kick (Arkadia)", Default = false,
        Callback = function(Value)
            arkadiaBlobKickActive = Value
            if Value and imoKickTarget then
                arkadia_angle = 0
                task.spawn(function() Arkadia_BlobSpamKickLoop(imoKickTarget) end)
                Notify("Arkadia", "Activated")
            elseif Value and not imoKickTarget then
                Notify("Error", "ターゲットを選択")
                Toggles.ArkadiaBlobKickToggle:SetValue(false)
            else
                Arkadia_DestroyBlobman()
                Notify("Arkadia", "Deactivated")
            end
        end
    })
    imoKick:AddToggle("LoopBlobKickSpamToggle", {
        Text = "Loop Blob Kick Spam", Default = false,
        Callback = function(Value)
            loopBlobKickSpamActive = Value
            if Value then
                loopBlobKickSpamTargetName = imoKickTarget
                if not loopBlobKickSpamTargetName then Notify("Error", "ターゲットを選択") Toggles.LoopBlobKickSpamToggle:SetValue(false) return end
                task.spawn(LoopBlobKickSpamFunction)
            end
        end
    })
    imoKick:AddToggle("LoopKickToggle", {
        Text = "Kick (spam grab)", Default = false,
        Callback = function(on)
            kickLoopEnabled = on
            if on and not imoKickTarget then Toggles.LoopKickToggle:SetValue(false) Notify("Error", "ターゲットを選択") return end
            if on then task.spawn(function() RunKickSpam(imoKickTarget) end) end
        end
    })


-- =====================================================
-- Drift + Grab Kick（ドリグラ）
-- =====================================================
do
    local DG_ACTIVE = false
    local DG_TARGET = nil
    local DG_HEIGHT = 23
    local DG_RADIUS = 18
    local DG_SPEED = 0.15
    local DG_pallet = nil
    local DG_spawning = false
    local DG_lagOn = false
    local DG_lagThread = nil

    local function DG_GetBlob()
        local folder = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
        return folder and folder:FindFirstChild("CreatureBlobman")
    end
    local function DG_SpawnBlob()
        local root = GetMyRoot and GetMyRoot() or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"))
        if not root or not SpawnToy then return end
        pcall(function()
            SpawnToy:InvokeServer("CreatureBlobman", root.CFrame * CFrame.new(0, 0, -5), Vector3.new(0, 90, 0))
        end)
    end
    local function DG_DestroyBlob()
        local blob = DG_GetBlob()
        if blob and DestroyToy then
            pcall(function() DestroyToy:FireServer(blob) end)
        end
    end
    local function DG_StartLag()
        if DG_lagOn then return end
        DG_lagOn = true
        DG_lagThread = task.spawn(function()
            local ge = GrabEvents or ReplicatedStorage:FindFirstChild("GrabEvents")
            local createLine = ge and ge:FindFirstChild("CreateGrabLine")
            if not createLine then DG_lagOn = false return end
            while DG_lagOn do
                local target = Workspace:FindFirstChild("SpawnLocation") or Workspace:FindFirstChild("Spawn") or GetMyRoot()
                if target then
                    for _ = 1, 10 do
                        if not DG_lagOn then break end
                        pcall(function()
                            createLine:FireServer(target, CFrame.new(math.random(-80000, 80000), 0, math.random(-80000, 80000)))
                        end)
                    end
                end
                task.wait(0.05)
            end
        end)
    end
    local function DG_StopLag()
        DG_lagOn = false
        if DG_lagThread then pcall(task.cancel, DG_lagThread) DG_lagThread = nil end
    end
    local function DG_SpawnPallet()
        if DG_spawning then return nil end
        DG_spawning = true
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp or not SpawnToy then DG_spawning = false return nil end
        local folder = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys") or Workspace
        local spawned = nil
        local conn = folder.ChildAdded:Connect(function(obj)
            if obj.Name == "PalletLightBrown" then spawned = obj end
        end)
        pcall(function()
            SpawnToy:InvokeServer("PalletLightBrown", hrp.CFrame * CFrame.new(0, 14, 20), Vector3.zero)
        end)
        local t = tick()
        repeat task.wait(0.05) until spawned or (tick() - t) > 4
        conn:Disconnect()
        if not spawned then DG_spawning = false return nil end
        local soundPart = spawned:FindFirstChild("SoundPart") or spawned:WaitForChild("SoundPart", 3)
        if not soundPart then pcall(function() spawned:Destroy() end) DG_spawning = false return nil end
        local setOwner = SetNetworkOwner or (GrabEvents and GrabEvents:FindFirstChild("SetNetworkOwner"))
        for _ = 1, 12 do
            if not DG_ACTIVE then pcall(function() spawned:Destroy() end) DG_spawning = false return nil end
            if setOwner then pcall(function() setOwner:FireServer(soundPart, soundPart.CFrame) end) end
            task.wait()
            if soundPart:FindFirstChild("PartOwner") then break end
        end
        if not soundPart:FindFirstChild("PartOwner") then
            pcall(function() spawned:Destroy() end)
            DG_spawning = false
            return nil
        end
        for _, v in pairs(spawned:GetDescendants()) do
            if v:IsA("BasePart") then
                v.CanCollide = false
                v.Transparency = 0.8
            end
        end
        spawned.Name = "RagdollPalete"
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(0, math.huge, 0)
        bv.Velocity = Vector3.new(0, 900, 0)
        bv.Parent = soundPart
        DG_spawning = false
        return spawned
    end

    local function DG_Loop(targetName)
        local initialPos = nil
        local hasCaptured = false
        local grabToggle = false
        local angle = 0
        DG_StartLag()
        local setOwner = SetNetworkOwner or (GrabEvents and GrabEvents:FindFirstChild("SetNetworkOwner"))
        local destroyLine = DestroyGrabLine or (GrabEvents and GrabEvents:FindFirstChild("DestroyGrabLine"))

        while DG_ACTIVE do
            local target = Players:FindFirstChild(targetName)
            local blob = DG_GetBlob()
            local myChar = LocalPlayer.Character
            local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")

            if not blob then
                DG_SpawnBlob()
                hasCaptured = false
                task.wait(0.5)
                continue
            end

            local seat = blob:FindFirstChildOfClass("VehicleSeat") or blob:FindFirstChildOfClass("Seat")
            if seat and myHum and myHum.SeatPart ~= seat then
                pcall(function() seat:Sit(myHum) end)
            end

            local tChar = target and target.Character
            local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
            local tHum = tChar and tChar:FindFirstChildOfClass("Humanoid")
            local blobRoot = blob:FindFirstChild("HumanoidRootPart") or blob.PrimaryPart

            if tRoot and tHum and tHum.Health > 0 and blobRoot and myRoot then
                if not initialPos then initialPos = tRoot.Position end
                local center = initialPos + Vector3.new(0, DG_HEIGHT, 0)

                if not hasCaptured then
                    tRoot.CFrame = CFrame.new(center)
                    tHum.PlatformStand = true
                    if setOwner then pcall(function() setOwner:FireServer(tRoot, tRoot.CFrame) end) end
                    task.wait(0.1)
                    hasCaptured = true
                end

                angle = angle + DG_SPEED
                local ox = math.cos(angle) * DG_RADIUS
                local oz = math.sin(angle) * DG_RADIUS
                local newPos = center + Vector3.new(ox, 0, oz)
                blobRoot.CFrame = CFrame.new(newPos, center)
                blobRoot.AssemblyLinearVelocity = Vector3.zero
                tRoot.CFrame = CFrame.new(center)

                pcall(function()
                    if setOwner then setOwner:FireServer(tRoot, tRoot.CFrame) end
                    if destroyLine then destroyLine:FireServer(tRoot) end
                end)

                tRoot.AssemblyLinearVelocity = Vector3.zero
                tRoot.AssemblyAngularVelocity = Vector3.zero

                local bp = tRoot:FindFirstChild("ControlBP")
                if not bp then
                    bp = Instance.new("BodyPosition")
                    bp.Name = "ControlBP"
                    bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                    bp.P = 800000
                    bp.Parent = tRoot
                end
                bp.Position = myRoot.Position + Vector3.new(5, 10, 5)

                pcall(function()
                    local scriptObj = blob:FindFirstChild("BlobmanSeatAndOwnerScript")
                    if scriptObj then
                        local CG = scriptObj:FindFirstChild("CreatureGrab")
                        local CD = scriptObj:FindFirstChild("CreatureDrop")
                        local R_Det = blob:FindFirstChild("RightDetector")
                        local weld = R_Det and (R_Det:FindFirstChild("RightWeld") or R_Det:FindFirstChildWhichIsA("Weld"))
                        if weld and CD then CD:FireServer(weld) end
                        grabToggle = not grabToggle
                        local targetToGrab = grabToggle and tRoot or blobRoot
                        if CG and R_Det and weld then
                            CG:FireServer(R_Det, targetToGrab, weld)
                        end
                    end
                end)

                if DG_pallet and DG_pallet:IsDescendantOf(Workspace) then
                    local sound = DG_pallet:FindFirstChild("SoundPart")
                    if sound and not sound:FindFirstChild("PartOwner") then
                        pcall(function() DG_pallet:Destroy() end)
                        DG_pallet = nil
                    end
                end
                if not DG_spawning and (not DG_pallet or not DG_pallet:IsDescendantOf(Workspace)) then
                    DG_pallet = DG_SpawnPallet()
                end
                if DG_pallet and DG_pallet:FindFirstChild("SoundPart") then
                    local ragdolled = tHum:FindFirstChild("Ragdolled")
                    if ragdolled and not ragdolled.Value then
                        DG_pallet.SoundPart.Position = tRoot.Position
                    end
                end
            else
                initialPos = nil
                hasCaptured = false
            end
            RunService.Heartbeat:Wait()
        end

        -- 終了時ラグは止めない（元スクリプト仕様）
        DG_DestroyBlob()
        if DG_pallet then pcall(function() DG_pallet:Destroy() end) DG_pallet = nil end
        local target = Players:FindFirstChild(targetName)
        if target and target.Character then
            local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
            if tRoot and tRoot:FindFirstChild("ControlBP") then
                tRoot.ControlBP:Destroy()
            end
        end
    end

    local dg = Tabs.Kick:AddLeftGroupbox("Drift + Grab Kick")
    local dgDrop = dg:AddDropdown("DG_Target", {
        Text = "ターゲット",
        Values = GetPlayerList(),
        Default = 1,
        Callback = function(v)
            DG_TARGET = GetNameFromDisplay(v)
        end,
    })
    task.spawn(function()
        while true do
            task.wait(2)
            pcall(function() dgDrop:SetValues(GetPlayerList()) end)
        end
    end)

    dg:AddSlider("DG_Height", {
        Text = "高さ",
        Default = 23,
        Min = 5,
        Max = 80,
        Rounding = 0,
        Callback = function(v) DG_HEIGHT = v end,
    })
    dg:AddSlider("DG_Radius", {
        Text = "旋回半径",
        Default = 18,
        Min = 5,
        Max = 60,
        Rounding = 0,
        Callback = function(v) DG_RADIUS = v end,
    })
    dg:AddSlider("DG_Speed", {
        Text = "旋回速度",
        Default = 15,
        Min = 1,
        Max = 50,
        Rounding = 0,
        Callback = function(v) DG_SPEED = v / 100 end,
    })

    dg:AddToggle("DG_LagOnly", {
        Text = "Lag Only（ラグ継続）",
        Default = false,
        Callback = function(v)
            if v then
                DG_StartLag()
                Notify("Drift", "ラグ開始（継続）", 2)
            else
                DG_StopLag()
                Notify("Drift", "ラグ停止", 2)
            end
        end,
    })

    dg:AddButton({
        Text = "ラグ強制停止",
        Func = function()
            DG_StopLag()
            if Toggles.DG_LagOnly then Toggles.DG_LagOnly:SetValue(false) end
            Notify("Drift", "ラグ停止", 2)
        end,
    })

    dg:AddToggle("DG_DriftGrabKick", {
        Text = "Drift + Grab Kick",
        Default = false,
        Callback = function(v)
            DG_ACTIVE = v
            if v then
                if not DG_TARGET then
                    Notify("Drift", "ターゲットを選択", 3)
                    DG_ACTIVE = false
                    if Toggles.DG_DriftGrabKick then Toggles.DG_DriftGrabKick:SetValue(false) end
                    return
                end
                task.spawn(function()
                    DG_Loop(DG_TARGET)
                end)
                Notify("Drift", "ON → " .. tostring(DG_TARGET), 2)
            else
                DG_DestroyBlob()
                if DG_pallet then pcall(function() DG_pallet:Destroy() end) DG_pallet = nil end
                Notify("Drift", "停止（ラグは継続可）", 2)
            end
        end,
    })
end


    local masaKick = Tabs.Kick:AddRightGroupbox("Blobman Kick (詳細)")
    local masaKickTarget, isExecutingMasaKick = nil, false
    local masaDrop = masaKick:AddDropdown("MasaKickPlayer", {
        Text = "Select Player", Values = {}, Default = nil, Multi = false,
        Callback = function(Value) masaKickTarget = Value end
    })
    local function UpdateMasaKickPlayerList()
        local names = {}
        for _, plr in Players:GetPlayers() do
            if plr ~= LocalPlayer then table.insert(names, plr.Name) end
        end
        masaDrop:SetValues(names)
    end
    UpdateMasaKickPlayerList()
    Players.PlayerAdded:Connect(UpdateMasaKickPlayerList)
    Players.PlayerRemoving:Connect(UpdateMasaKickPlayerList)
    masaKick:AddButton({ Text = "Refresh Player List", Func = function() UpdateMasaKickPlayerList() end })
    masaKick:AddButton({
        Text = "Kick Selected Player",
        Func = function()
            if isExecutingMasaKick then Notify("Error", "Already executing...") return end
            if not masaKickTarget then Notify("Error", "Playerを選択") return end
            local targetPlayer = Players:FindFirstChild(masaKickTarget)
            if not targetPlayer then Notify("Error", "Player not found") return end
            local targetChar = targetPlayer.Character
            if not targetChar then Notify("Error", "Target has no character") return end
            local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
            if not targetRoot then Notify("Error", "Target has no HRP") return end
            isExecutingMasaKick = true
            task.spawn(function()
                local blob = BlobmanBeta.getBlobman()
                if not blob then
                    blob = BlobmanBeta.spawnBlobman()
                    if not blob then Notify("Error", "Failed to spawn Blobman") isExecutingMasaKick = false return end
                end
                if not BlobmanBeta.isSittingOnBlobman() then
                    BlobmanBeta.ensureSitBlobman()
                    if not BlobmanBeta.isSittingOnBlobman() then Notify("Error", "Not sitting on Blobman") isExecutingMasaKick = false return end
                end
                local myRoot = BlobmanBeta.getLocalRoot()
                if myRoot and targetRoot then
                    local oldPos = myRoot.CFrame
                    myRoot.CFrame = targetRoot.CFrame
                    task.wait(0.07)
                    BlobmanBeta.blobKick(blob, targetRoot, "Left")
                    task.wait(0.25)
                    myRoot.CFrame = oldPos
                end
                BlobmanBeta.destroyBlobman()
                Notify("Success", "Kicked " .. targetPlayer.Name .. "!")
                isExecutingMasaKick = false
            end)
        end
    })

    local groundBreak = Tabs.Kick:AddRightGroupbox("地面破壊 (手裏剣)")
    local DestroyToyRemote = nil
    local stickyEventG = nil
    for _, v in pairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") and v.Name == "DestroyToy" then
            DestroyToyRemote = v
        end
    end
    pcall(function()
        stickyEventG = ReplicatedStorage:WaitForChild("PlayerEvents"):WaitForChild("StickyPartEvent")
    end)
    local AutoGroundBreakEnabled = false
    local groundSpawnedShurikens = {}
    local function cleanupGroundShurikens()
        if DestroyToyRemote then
            for _, shuriken in pairs(groundSpawnedShurikens) do
                if shuriken and shuriken.Parent then
                    pcall(function() DestroyToyRemote:FireServer(shuriken) end)
                end
            end
        end
        groundSpawnedShurikens = {}
    end
    local function spawnAndBreakPart(targetPart, shurikenTable)
        if not targetPart or targetPart:IsA("Terrain") then return end
        task.spawn(function()
            local plr = LocalPlayer
            local canSpawn = plr:WaitForChild("CanSpawnToy")
            local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local function CheckForHome()
                if not Workspace.PlotItems.PlayersInPlots:FindFirstChild(plr.Name) then return false end
                for _, v in pairs(Workspace.Plots:GetChildren()) do
                    local sign = v:FindFirstChild("PlotSign")
                    local owners = sign and sign:FindFirstChild("ThisPlotsOwners")
                    if owners then
                        for _, b in pairs(owners:GetChildren()) do
                            if b.Value == plr.Name then
                                local folder = Workspace.PlotItems:FindFirstChild(v.Name)
                                if folder then return true, folder end
                            end
                        end
                    end
                end
                return false
            end
            local boolik, house = CheckForHome()
            local inv = Workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
            local targetContainer = (boolik and house) or inv
            local preExisting = {}
            if targetContainer then
                for _, child in pairs(targetContainer:GetChildren()) do
                    if child.Name == "NinjaShuriken" then table.insert(preExisting, child) end
                end
            end
            if canSpawn.Value and SpawnToy then
                pcall(function()
                    SpawnToy:InvokeServer("NinjaShuriken", hrp.CFrame * CFrame.new(0, 2, 8), Vector3.new(0, 0, 0))
                end)
                local newShuriken = nil
                if targetContainer then
                    local searchStart = tick()
                    while tick() - searchStart < 2 do
                        for _, child in pairs(targetContainer:GetChildren()) do
                            if child.Name == "NinjaShuriken" and not table.find(preExisting, child) then
                                newShuriken = child
                                break
                            end
                        end
                        if newShuriken then
                            local soundPart = newShuriken:FindFirstChild("SoundPart") or newShuriken:WaitForChild("SoundPart", 0.1)
                            if soundPart then pcall(function() SpamOwnership(soundPart) end) end
                            break
                        end
                        task.wait()
                    end
                end
                if newShuriken and newShuriken:FindFirstChild("StickyPart") and stickyEventG then
                    table.insert(shurikenTable, newShuriken)
                    pcall(function()
                        stickyEventG:FireServer(newShuriken.StickyPart, targetPart, CFrame.new(0, -1000000000, 0))
                    end)
                end
            end
        end)
    end
    groundBreak:AddToggle("AutoGroundBreak", {
        Text = "地面破壊 (自動)", Default = false,
        Callback = function(Value)
            AutoGroundBreakEnabled = Value
            if AutoGroundBreakEnabled then
                task.spawn(function()
                    while AutoGroundBreakEnabled do
                        local character = LocalPlayer.Character
                        local hrp = character and character:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local rayParams = RaycastParams.new()
                            rayParams.FilterDescendantsInstances = {character}
                            rayParams.FilterType = Enum.RaycastFilterType.Exclude
                            local rayResult = Workspace:Raycast(hrp.Position, Vector3.new(0, -10, 0), rayParams)
                            local targetPart = rayResult and rayResult.Instance
                            if targetPart and targetPart:IsA("BasePart") and not targetPart:IsA("Terrain") then
                                spawnAndBreakPart(targetPart, groundSpawnedShurikens)
                            end
                        end
                        task.wait(0.8)
                    end
                end)
            else
                cleanupGroundShurikens()
            end
        end
    })
    local clickConnection = nil
    groundBreak:AddToggle("ClickDeleteGround", {
        Text = "地面破壊 (クリック)", Default = false,
        Callback = function(Value)
            local mouse = LocalPlayer:GetMouse()
            if Value then
                clickConnection = mouse.Button1Down:Connect(function()
                    local targetPart = mouse.Target
                    if targetPart and targetPart:IsA("BasePart") and not targetPart:IsA("Terrain") then
                        spawnAndBreakPart(targetPart, groundSpawnedShurikens)
                    end
                end)
            else
                if clickConnection then clickConnection:Disconnect() clickConnection = nil end
                cleanupGroundShurikens()
            end
        end
    })
end

-- =====================================================
-- Grab Kick (BETA)
-- =====================================================
local grabKickGroup = Tabs.Kick:AddLeftGroupbox("Grab Kick (BETA)")

local gk_selectedDisplay = ""
local gk_selectedName = nil
local gk_active = false
local gk_paletteActive = false
local gk_palette = nil
local gk_paletteBusy = false
local gk_renderConn = nil
local gk_lagRunning = false
local gk_range = 25

local function gk_getPlayerList()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(list, p.DisplayName .. " (@" .. p.Name .. ")")
        end
    end
    return list
end

local function gk_getPlayerFromDisplay(display)
    for _, p in ipairs(Players:GetPlayers()) do
        if (p.DisplayName .. " (@" .. p.Name .. ")") == display then
            return p
        end
    end
    return nil
end

local function gk_teleportNear(target, myRoot)
    if not target.Character then return end
    local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
    if not tRoot or not myRoot then return end
    local orig = myRoot.CFrame
    myRoot.CFrame = tRoot.CFrame * CFrame.new(0, 0, 2)
    local setNet = ReplicatedStorage:FindFirstChild("GrabEvents") and ReplicatedStorage.GrabEvents:FindFirstChild("SetNetworkOwner")
    if setNet then
        for _ = 1, 15 do
            pcall(function() setNet:FireServer(tRoot, tRoot.CFrame) end)
            task.wait()
        end
    end
    myRoot.CFrame = orig
end

local function gk_spawnToy(name)
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")
    local waitCount = 0
    while LocalPlayer:FindFirstChild("InPlot") and LocalPlayer.InPlot.Value and LocalPlayer:FindFirstChild("InOwnedPlot") and not LocalPlayer.InOwnedPlot.Value and waitCount < 50 do
        task.wait(0.1); waitCount = waitCount + 1
    end
    waitCount = 0
    while LocalPlayer:FindFirstChild("CanSpawnToy") and not LocalPlayer.CanSpawnToy.Value and waitCount < 50 do
        task.wait(0.1); waitCount = waitCount + 1
    end
    local spawnCF = hrp.CFrame * CFrame.new(0, 14, 20)
    local folder = workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
        or (workspace:FindFirstChild("PlotItems") and workspace.PlotItems:FindFirstChild("Plot1"))
        or workspace
    local spawned = nil
    local conn = folder.ChildAdded:Connect(function(c)
        if c.Name == name then spawned = c end
    end)
    local menuToys = ReplicatedStorage:FindFirstChild("MenuToys")
    local spawnRemote = menuToys and menuToys:FindFirstChild("SpawnToyRemoteFunction")
    if spawnRemote then
        task.spawn(function() pcall(function() spawnRemote:InvokeServer(name, spawnCF, Vector3.zero) end) end)
    end
    local t0 = tick()
    repeat task.wait(0.05) until spawned or (tick() - t0) > 5
    pcall(function() conn:Disconnect() end)
    return spawned
end

local function gk_claimOwner(part)
    if not part or not part:IsA("BasePart") then return end
    local setNet = ReplicatedStorage:FindFirstChild("GrabEvents") and ReplicatedStorage.GrabEvents:FindFirstChild("SetNetworkOwner")
    if setNet then pcall(function() setNet:FireServer(part, part.CFrame) end) end
    task.wait()
end

local function gk_hasOwner(part)
    return part and part:FindFirstChild("PartOwner") ~= nil
end

local function gk_createPalette()
    if gk_paletteBusy then return nil end
    gk_paletteBusy = true
    local toy = gk_spawnToy("PalletLightBrown")
    if not toy then gk_paletteBusy = false; return nil end
    local soundPart = toy:FindFirstChild("SoundPart") or toy:WaitForChild("SoundPart", 3)
    if not soundPart then pcall(function() toy:Destroy() end); gk_paletteBusy = false; return nil end
    for _ = 1, 10 do
        if not gk_paletteActive then pcall(function() toy:Destroy() end); gk_paletteBusy = false; return nil end
        gk_claimOwner(soundPart)
        task.wait()
        if gk_hasOwner(soundPart) then break end
    end
    if not gk_hasOwner(soundPart) then pcall(function() toy:Destroy() end); gk_paletteBusy = false; return nil end
    for _, d in pairs(toy:GetDescendants()) do
        if d:IsA("BasePart") then d.CanCollide = false; d.Transparency = 0.8 end
    end
    toy.Name = "RagdollPalete"
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(0, math.huge, 0)
    bv.Velocity = Vector3.new(0, 900, 0)
    bv.Parent = soundPart
    gk_paletteBusy = false
    return toy
end

local function gk_startLag()
    if gk_lagRunning then return end
    local createLine = ReplicatedStorage:FindFirstChild("GrabEvents") and ReplicatedStorage.GrabEvents:FindFirstChild("CreateGrabLine")
    if not createLine then return end
    gk_lagRunning = true
    task.spawn(function()
        while gk_lagRunning do
            local spawnLoc = Workspace:FindFirstChild("SpawnLocation")
                or Workspace:FindFirstChild("Spawn")
                or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"))
            if spawnLoc then
                pcall(function()
                    createLine:FireServer(spawnLoc, CFrame.new(math.random(-2010000000, 2000000001), 0, math.random(-2008100000, 2000200000)))
                end)
            end
            task.wait()
        end
    end)
end

local function gk_stopLag()
    gk_lagRunning = false
end

local gkDrop = grabKickGroup:AddDropdown("GrabKickTarget", {
    Text = "Target Player",
    Values = gk_getPlayerList(),
    Default = 1,
    Callback = function(v)
        gk_selectedDisplay = v
        local p = gk_getPlayerFromDisplay(v)
        gk_selectedName = p and p.Name or nil
    end
})
task.spawn(function()
    while true do
        task.wait(2)
        pcall(function() gkDrop:SetValues(gk_getPlayerList()) end)
    end
end)

grabKickGroup:AddSlider("GrabKickRange", {
    Text = "Teleport Range",
    Default = 25, Min = 5, Max = 100, Rounding = 0,
    Callback = function(v) gk_range = v end
})

grabKickGroup:AddToggle("GrabKickToggle", {
    Text = "Grab kick (BETA)",
    Default = false,
    Callback = function(Value)
        gk_active = Value
        gk_paletteActive = Value
        if Value then
            gk_startLag()
        else
            gk_stopLag()
        end
        if Value then
            task.spawn(function()
                while gk_active do
                    local target = gk_selectedName and Players:FindFirstChild(gk_selectedName)
                    local myChar = LocalPlayer.Character
                    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
                    if target and myRoot then
                        local tChar = target.Character
                        local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
                        if tRoot then
                            local dist = (myRoot.Position - tRoot.Position).Magnitude
                            if dist > gk_range then
                                gk_teleportNear(target, myRoot)
                            end
                            local setNet = ReplicatedStorage:FindFirstChild("GrabEvents") and ReplicatedStorage.GrabEvents:FindFirstChild("SetNetworkOwner")
                            local destroyLine = ReplicatedStorage:FindFirstChild("GrabEvents") and ReplicatedStorage.GrabEvents:FindFirstChild("DestroyGrabLine")
                            if setNet then pcall(function() setNet:FireServer(tRoot, tRoot.CFrame) end) end
                            if destroyLine then pcall(function() destroyLine:FireServer(tRoot) end) end
                            tRoot.AssemblyLinearVelocity = Vector3.zero
                            tRoot.AssemblyAngularVelocity = Vector3.zero
                            local bp = tRoot:FindFirstChild("ControlBP")
                            if not bp then
                                bp = Instance.new("BodyPosition")
                                bp.Name = "ControlBP"
                                bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                                bp.P = 800000
                                bp.Parent = tRoot
                            end
                            bp.Position = myRoot.Position + Vector3.new(5, 10, 5)
                        end
                    end
                    task.wait()
                end
                local target = gk_selectedName and Players:FindFirstChild(gk_selectedName)
                if target and target.Character then
                    local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
                    if tRoot and tRoot:FindFirstChild("ControlBP") then
                        tRoot.ControlBP:Destroy()
                    end
                end
            end)
            local folder = workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
            gk_renderConn = RunService.RenderStepped:Connect(function()
                if not gk_paletteActive or not gk_selectedName then return end
                local target = Players:FindFirstChild(gk_selectedName)
                if not target or not target.Character then return end
                local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
                local tHum = target.Character:FindFirstChild("Humanoid")
                if not tRoot or not tHum then return end
                if gk_palette and gk_palette:IsDescendantOf(workspace) then
                    local sp = gk_palette:FindFirstChild("SoundPart")
                    if sp then
                        if not gk_hasOwner(sp) then
                            pcall(function() gk_palette:Destroy() end)
                            gk_palette = nil
                        end
                    else
                        pcall(function() gk_palette:Destroy() end)
                        gk_palette = nil
                    end
                end
                if not gk_paletteBusy and (not gk_palette or not gk_palette:IsDescendantOf(workspace)) then
                    gk_palette = (folder and folder:FindFirstChild("RagdollPalete")) or gk_createPalette()
                end
                if gk_palette and gk_palette:FindFirstChild("SoundPart") then
                    local rag = tHum:FindFirstChild("Ragdolled")
                    if rag and not rag.Value then
                        gk_palette.SoundPart.Position = tRoot.Position
                    end
                end
            end)
        else
            if gk_renderConn then
                gk_renderConn:Disconnect()
                gk_renderConn = nil
            end
            if gk_palette then
                pcall(function() gk_palette:Destroy() end)
                gk_palette = nil
            end
        end
    end
})

-- =====================================================
-- Kick All
-- =====================================================
local kickAllGroup = Tabs.Kick:AddRightGroupbox("Kick All")

local ka_currentBlob = nil
local ka_isActive = false
local ka_playerStatus = {}
local ka_whitelistFriends = false

Players.PlayerRemoving:Connect(function(player)
    local status = ka_playerStatus[player.UserId]
    if status == "Kicked" then
        Notify("キックしました", player.DisplayName .. " (@" .. player.Name .. ")", 5)
    elseif status then
        Notify("退出しました", player.DisplayName .. " (@" .. player.Name .. ")", 5)
    end
    ka_playerStatus[player.UserId] = nil
end)

local function ka_GetAllPlayers()
    local players = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local isFriend = false
            if ka_whitelistFriends then
                pcall(function() isFriend = LocalPlayer:IsFriendsWith(player.UserId) end)
            end
            if not isFriend then
                table.insert(players, player)
            end
        end
    end
    return players
end

local function ka_GetMyRoot()
    return LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
end

local function ka_ResetTargets()
    for id, status in pairs(ka_playerStatus) do
        if status == "Targeting" then ka_playerStatus[id] = nil end
    end
end

local function ka_KickAll()
    if ka_isActive then return end
    ka_isActive = true
    local allPlayers = ka_GetAllPlayers()
    if #allPlayers == 0 then
        Notify("対象がいません", "キックできるプレイヤーがいません。", 3)
        ka_isActive = false
        return
    end
    for _, targetPlayer in ipairs(allPlayers) do
        ka_playerStatus[targetPlayer.UserId] = "Targeting"
    end
    local rootPart = ka_GetMyRoot()
    if rootPart then
        local spawnPos = rootPart.CFrame * CFrame.new(0, 0, -5)
        pcall(function()
            ReplicatedStorage.MenuToys.SpawnToyRemoteFunction:InvokeServer("CreatureBlobman", spawnPos, Vector3.new(0, 127, 0))
        end)
    end
    task.wait(0.5)
    local toyFolder = workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
    ka_currentBlob = toyFolder and toyFolder:FindFirstChild("CreatureBlobman")
    if not ka_currentBlob then
        ka_ResetTargets()
        ka_isActive = false
        Notify("Error", "Blobman生成失敗", 3)
        return
    end
    local vehicleSeat = ka_currentBlob:FindFirstChild("VehicleSeat")
    if vehicleSeat and LocalPlayer.Character then
        pcall(function()
            vehicleSeat:Sit(LocalPlayer.Character:FindFirstChildOfClass("Humanoid"))
        end)
    end
    task.wait(0.3)
    local myRoot = ka_GetMyRoot()
    if not myRoot then
        ka_ResetTargets()
        ka_isActive = false
        return
    end
    for _, targetPlayer in ipairs(allPlayers) do
        local targetRoot = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if targetRoot then
            myRoot.CFrame = targetRoot.CFrame
            task.wait(0.02)
            for i = 1, 5 do
                pcall(function()
                    ka_currentBlob.BlobmanSeatAndOwnerScript.CreatureGrab:FireServer(
                        ka_currentBlob.LeftDetector, targetRoot, ka_currentBlob.LeftDetector.LeftWeld
                    )
                    ka_currentBlob.BlobmanSeatAndOwnerScript.CreatureRelease:FireServer(ka_currentBlob.LeftDetector.LeftWeld)
                end)
                if i < 5 then task.wait(0.08) end
            end
        end
    end
    myRoot.CFrame = CFrame.new(0, 100, 0)
    task.wait(0.1)
    for _, part in ipairs(ka_currentBlob:GetDescendants()) do
        if part:IsA("BasePart") then pcall(function() part.Anchored = true end) end
    end
    task.wait(0.1)
    local radius = 15
    for i, targetPlayer in ipairs(allPlayers) do
        local targetRoot = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if targetRoot then
            local angle = math.rad((i - 1) * (360 / #allPlayers))
            local x = radius * math.cos(angle)
            local z = radius * math.sin(angle)
            targetRoot.CFrame = CFrame.new(x, 110, z)
        end
    end
    task.wait(0.1)
    for _ = 1, 2 do
        for _, targetPlayer in ipairs(allPlayers) do
            local targetRoot = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
            if targetRoot then
                task.spawn(function()
                    pcall(function()
                        ReplicatedStorage.GrabEvents.SetNetworkOwner:FireServer(targetRoot, CFrame.new(targetRoot.Position))
                        ReplicatedStorage.GrabEvents.DestroyGrabLine:FireServer(targetRoot)
                    end)
                end)
            end
        end
        task.wait(0.1)
    end
    task.wait(0.3)
    for _, targetPlayer in ipairs(allPlayers) do
        local targetRoot = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if targetRoot then
            task.spawn(function()
                pcall(function()
                    ka_currentBlob.BlobmanSeatAndOwnerScript.CreatureGrab:FireServer(
                        ka_currentBlob.LeftDetector, targetRoot, ka_currentBlob.LeftDetector.LeftWeld
                    )
                    ka_currentBlob.BlobmanSeatAndOwnerScript.CreatureGrab:FireServer(
                        ka_currentBlob.RightDetector, targetRoot, ka_currentBlob.RightDetector.RightWeld
                    )
                end)
            end)
        end
    end
    task.wait(0.1)
    for _, targetPlayer in ipairs(allPlayers) do
        if targetPlayer and targetPlayer.Parent == Players then
            ka_playerStatus[targetPlayer.UserId] = "Kicked"
        end
    end
    myRoot.CFrame = CFrame.new(0, -50000, 0)
    for _, part in ipairs(ka_currentBlob:GetDescendants()) do
        if part:IsA("BasePart") then pcall(function() part.Anchored = false end) end
    end
    task.wait(1)
    ka_isActive = false
    Notify("Kick All", "完了", 3)
end

kickAllGroup:AddButton({
    Text = "Kick All",
    Func = function() task.spawn(ka_KickAll) end
})

kickAllGroup:AddToggle("KickAllWhitelistFriends", {
    Text = "Whitelist Friends",
    Default = false,
    Callback = function(Value) ka_whitelistFriends = Value end
})



-- =====================================================
-- Loop Kick（高速 / 家回避 / 自動乗車）
-- =====================================================
do
    local loopKickBlobActive = false
    local loopKickBlobAllActive = false
    local loopKickBlobMode = "Default"
    local loopKickBlobTarget = nil
    local lkExcludeFriends = true
    local skyFloor = nil

    local function LK_IsInsideHouse(player)
        if not player then return false end
        local ok, inside = pcall(function()
            local plotItems = Workspace:FindFirstChild("PlotItems")
            if not plotItems then return false end
            local pip = plotItems:FindFirstChild("PlayersInPlots")
            if not pip then return false end
            if pip:FindFirstChild(player.Name) then return true end
            if pip:FindFirstChild(tostring(player.UserId)) then return true end
            return false
        end)
        return ok and inside
    end

    local function LK_AmIInsideHouse()
        return LK_IsInsideHouse(LocalPlayer)
    end

    local function LK_FindBlobman()
        local folder = GetToysFolder and GetToysFolder() or Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
        if folder then
            local b = folder:FindFirstChild("CreatureBlobman")
            if b then return b end
        end
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj.Name == "CreatureBlobman" and obj:FindFirstChild("VehicleSeat") then
                return obj
            end
        end
        return nil
    end

    local function LK_EnsureSkyFloor()
        if skyFloor and skyFloor.Parent then return skyFloor end
        local part = Instance.new("Part")
        part.Name = "SkyKickFloor"
        part.Anchored = true
        part.CanCollide = true
        part.Size = Vector3.new(50, 1, 50)
        part.CFrame = CFrame.new(12000, 7900, 12000)
        part.Transparency = 1
        part.Parent = Workspace
        skyFloor = part
        return part
    end

    local function LK_RemoveSkyFloor()
        if skyFloor and skyFloor.Parent then
            pcall(function() skyFloor:Destroy() end)
            skyFloor = nil
        end
    end

    local function LK_SpawnAndSit()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = GetMyRoot and GetMyRoot() or (char and char:FindFirstChild("HumanoidRootPart"))
        if not hum or not root then return nil end

        if hum.SeatPart and hum.SeatPart.Parent and hum.SeatPart.Parent.Name == "CreatureBlobman" and hum.SeatPart.Parent.Parent then
            return hum.SeatPart.Parent
        end

        local blob = LK_FindBlobman()
        if not blob and SpawnToy then
            pcall(function()
                SpawnToy:InvokeServer("CreatureBlobman", root.CFrame * CFrame.new(0, 3, 0), Vector3.new(0, 127, 0))
            end)
            local t = tick()
            repeat task.wait(0.04); blob = LK_FindBlobman() until blob or tick() - t > 1.0
        end
        if not blob then return nil end

        local seat = blob:FindFirstChild("VehicleSeat")
        if seat and seat.Occupant ~= hum then
            for _ = 1, 5 do
                if not blob.Parent then break end
                root.CFrame = seat.CFrame + Vector3.new(0, 2, 0)
                task.wait(0.02)
                pcall(function() seat:Sit(hum) end)
                task.wait(0.05)
                if hum.SeatPart and hum.SeatPart.Parent == blob then return blob end
            end
        end
        return blob
    end

    local function LK_Maintain()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then return nil end
        local seated = hum.SeatPart and hum.SeatPart.Parent
        if seated and seated.Name == "CreatureBlobman" and seated.Parent then
            return seated
        end
        return LK_SpawnAndSit()
    end

    local function LoopKickBlobFunction(arg)
        local grabEvents = ReplicatedStorage:FindFirstChild("GrabEvents")
        if not grabEvents then
            Notify("Loop Kick", "GrabEventsがありません", 3)
            loopKickBlobActive = false
            return
        end

        if LK_AmIInsideHouse() then
            Notify("Loop Kick", "家の中のため停止（Blobman保護）", 2)
            loopKickBlobActive = false
            if Toggles.LoopKickBlobToggle then Toggles.LoopKickBlobToggle:SetValue(false) end
            return
        end

        local blob = LK_SpawnAndSit()
        if not blob then
            Notify("Loop Kick", "Blobmanに乗れませんでした", 3)
            loopKickBlobActive = false
            if Toggles.LoopKickBlobToggle then Toggles.LoopKickBlobToggle:SetValue(false) end
            return
        end

        local character = LocalPlayer.Character
        local humanoidRootPart = blob:FindFirstChild("HumanoidRootPart") or blob.PrimaryPart
        local scriptObj = blob:FindFirstChild("BlobmanSeatAndOwnerScript")
        local creatureGrab = scriptObj and scriptObj:FindFirstChild("CreatureGrab")
        local creatureDrop = scriptObj and scriptObj:FindFirstChild("CreatureDrop")
        local rightDetector = blob:FindFirstChild("RightDetector")

        local cframe = CFrame.new(12000, 7900, 12000)
        if loopKickBlobMode == "TP to Sky" then
            LK_EnsureSkyFloor()
            local cframe2 = CFrame.new(12000, 8000, 12000)
            pcall(function()
                if humanoidRootPart then humanoidRootPart.CFrame = cframe2 end
                local myRoot = character and character:FindFirstChild("HumanoidRootPart")
                if myRoot then myRoot.CFrame = cframe2 end
            end)
            task.wait(0.06)
            cframe = cframe2
        end

        local cFrame = (loopKickBlobMode == "TP to Sky") and cframe or (humanoidRootPart and humanoidRootPart.CFrame or cframe)
        local flag, n, n2 = false, 0, 0

        while loopKickBlobActive do
            local v4 = Players:FindFirstChild(arg)
            if not v4 then break end

            if LK_IsInsideHouse(v4) then
                Notify("Loop Kick", "ターゲットが家の中のため停止", 2)
                loopKickBlobActive = false
                if Toggles.LoopKickBlobToggle then Toggles.LoopKickBlobToggle:SetValue(false) end
                break
            end
            if LK_AmIInsideHouse() then
                Notify("Loop Kick", "家の中のため停止（Blobman保護）", 2)
                loopKickBlobActive = false
                if Toggles.LoopKickBlobToggle then Toggles.LoopKickBlobToggle:SetValue(false) end
                break
            end

            local parent2 = LK_Maintain()
            if parent2 then
                humanoidRootPart = parent2:FindFirstChild("HumanoidRootPart") or parent2.PrimaryPart
                scriptObj = parent2:FindFirstChild("BlobmanSeatAndOwnerScript")
                if scriptObj then
                    creatureGrab = scriptObj:FindFirstChild("CreatureGrab") or creatureGrab
                    creatureDrop = scriptObj:FindFirstChild("CreatureDrop") or creatureDrop
                end
                rightDetector = parent2:FindFirstChild("RightDetector") or rightDetector

                local character3 = v4.Character
                local humanoidRootPart2 = character3 and character3:FindFirstChild("HumanoidRootPart")
                local humanoid_2 = character3 and character3:FindFirstChildOfClass("Humanoid")

                if humanoidRootPart2 and humanoid_2 and humanoid_2.Health > 0 and humanoidRootPart then
                    humanoidRootPart2.AssemblyLinearVelocity = Vector3.zero

                    if not flag then
                        humanoidRootPart.CFrame = humanoidRootPart2.CFrame
                        humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
                        if tick() - n >= 0.002 then
                            n = tick()
                            pcall(function()
                                humanoid_2.PlatformStand = true
                                humanoid_2.Sit = true
                                local setOwner = grabEvents:FindFirstChild("SetNetworkOwner")
                                local destroyLine = grabEvents:FindFirstChild("DestroyGrabLine")
                                if setOwner then setOwner:FireServer(humanoidRootPart2, humanoidRootPart.CFrame) end
                                if destroyLine then destroyLine:FireServer(humanoidRootPart2) end
                            end)
                        end
                        if n2 == 0 then n2 = tick() end
                        if tick() - n2 > 0.12 then
                            humanoidRootPart.CFrame = cFrame
                            humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
                            flag = true
                            n2 = 0
                        end
                    else
                        humanoidRootPart.CFrame = cFrame
                        humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
                        local cFrame2 = cFrame * CFrame.new(0, 23, 0)
                        humanoidRootPart2.CFrame = cFrame2
                        humanoid_2.PlatformStand = true
                        humanoid_2.Sit = true
                        if tick() - n >= 0.002 then
                            n = tick()
                            pcall(function()
                                local setOwner = grabEvents:FindFirstChild("SetNetworkOwner")
                                local destroyLine = grabEvents:FindFirstChild("DestroyGrabLine")
                                if setOwner then setOwner:FireServer(humanoidRootPart2, cFrame2) end
                                if destroyLine then destroyLine:FireServer(humanoidRootPart2) end
                                if rightDetector and creatureDrop and creatureGrab then
                                    local rightWeld = rightDetector:FindFirstChild("RightWeld") or rightDetector:FindFirstChildWhichIsA("Weld")
                                    if rightWeld then
                                        creatureDrop:FireServer(rightWeld)
                                        creatureGrab:FireServer(rightDetector, humanoidRootPart2, rightWeld)
                                    end
                                end
                            end)
                        end
                    end
                else
                    flag = false
                    n2 = 0
                end
                RunService.Heartbeat:Wait()
            else
                task.wait(0.06)
                if not LK_Maintain() then
                    Notify("Loop Kick", "Blobman復旧失敗", 2)
                    break
                end
            end
        end

        if humanoidRootPart then
            pcall(function()
                humanoidRootPart.CFrame = cFrame
                humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
            end)
        end
        if loopKickBlobMode == "TP to Sky" and not loopKickBlobAllActive then
            LK_RemoveSkyFloor()
        end
    end

    local function LoopKickAllFunction()
        Notify("Loop Kick All", "開始 (Beta)", 2)
        if LK_AmIInsideHouse() then
            Notify("Loop Kick All", "家の中のため開始不可", 2)
            loopKickBlobAllActive = false
            if Toggles.LoopKickAllBeta then Toggles.LoopKickAllBeta:SetValue(false) end
            return
        end
        if not LK_SpawnAndSit() then
            Notify("Loop Kick All", "Blobmanに乗れませんでした", 3)
            loopKickBlobAllActive = false
            if Toggles.LoopKickAllBeta then Toggles.LoopKickAllBeta:SetValue(false) end
            return
        end

        while loopKickBlobAllActive do
            if LK_AmIInsideHouse() then
                Notify("Loop Kick All", "家の中のため停止", 2)
                break
            end
            if not LK_Maintain() then
                Notify("Loop Kick All", "Blobman維持失敗", 2)
                break
            end
            for _, plr in ipairs(Players:GetPlayers()) do
                if not loopKickBlobAllActive then break end
                if plr == LocalPlayer then continue end
                if lkExcludeFriends then
                    local skip = false
                    pcall(function()
                        if LocalPlayer:IsFriendsWith(plr.UserId) then skip = true end
                    end)
                    if skip then continue end
                end
                if LK_IsInsideHouse(plr) then continue end

                loopKickBlobActive = true
                task.spawn(function()
                    LoopKickBlobFunction(plr.Name)
                end)
                task.wait(0.18)
                loopKickBlobActive = false
                task.wait(0.02)
            end
            task.wait(0.04)
        end
        loopKickBlobActive = false
        LK_RemoveSkyFloor()
        Notify("Loop Kick All", "停止", 2)
    end

    local lkGroup = Tabs.Kick:AddLeftGroupbox("Loop Kick（高速・家回避）")
    local lkSet = Tabs.Kick:AddRightGroupbox("Loop Kick Settings")

    local lkDrop = lkGroup:AddDropdown("LoopKickTarget", {
        Text = "Loop Kick Target",
        Values = GetPlayerList(),
        Default = 1,
        Callback = function(v) loopKickBlobTarget = GetNameFromDisplay(v) end,
    })
    task.spawn(function()
        while true do
            task.wait(2)
            pcall(function() lkDrop:SetValues(GetPlayerList()) end)
        end
    end)

    lkGroup:AddToggle("LoopKickBlobToggle", {
        Text = "Loop Kick Blob (Single)",
        Default = false,
        Callback = function(v)
            loopKickBlobActive = v
            if v then
                if not loopKickBlobTarget or loopKickBlobTarget == "" then
                    Notify("Loop Kick", "ターゲットを選択", 3)
                    loopKickBlobActive = false
                    if Toggles.LoopKickBlobToggle then Toggles.LoopKickBlobToggle:SetValue(false) end
                    return
                end
                task.spawn(function()
                    LoopKickBlobFunction(loopKickBlobTarget)
                    if Toggles.LoopKickBlobToggle and Toggles.LoopKickBlobToggle.Value then
                        Toggles.LoopKickBlobToggle:SetValue(false)
                    end
                end)
            end
        end,
    })

    lkGroup:AddLabel("自動乗車 / 高速 / 家の中は狙わない")

    lkSet:AddDropdown("LoopKickMode", {
        Text = "Loop Kick Mode",
        Values = { "Default", "TP to Sky" },
        Default = 1,
        Callback = function(v)
            loopKickBlobMode = v
        end,
    })

    lkSet:AddToggle("LoopKickAllBeta", {
        Text = "Loop Kick All (Beta)",
        Default = false,
        Callback = function(v)
            loopKickBlobAllActive = v
            if v then
                task.spawn(LoopKickAllFunction)
            else
                loopKickBlobActive = false
                LK_RemoveSkyFloor()
            end
        end,
    })

    lkSet:AddToggle("LoopKickExcludeFriends", {
        Text = "Exclude Friends (All用)",
        Default = true,
        Callback = function(v) lkExcludeFriends = v end,
    })
end


-- =====================================================
-- キルタブ
-- =====================================================
do
    local left = Tabs.Kill:AddLeftGroupbox("いちごハブ キル系")
    local killTarget = nil
    local killDrop = left:AddDropdown("KillTarget", {
        Values = GetTargetablePlayerNames(), Default = 1, Text = "ターゲット",
        Callback = function(v) killTarget = ExtractUsername(v) end
    })
    task.spawn(function()
        while true do
            task.wait(2)
            pcall(function() killDrop:SetValues(GetTargetablePlayerNames()) end)
        end
    end)
    left:AddToggle("LoopKillToggle", {
        Text = "Loop Kill 1", Default = false,
        Callback = function(Value)
            loopKill1Active = Value
            if Value then
                loopKill1TargetName = killTarget
                if not loopKill1TargetName then Notify("Error", "ターゲットを選択") Toggles.LoopKillToggle:SetValue(false) return end
                task.spawn(function() RunLoopKill1(loopKill1TargetName) end)
            end
        end
    })
    left:AddToggle("LoopKill2Toggle", {
        Text = "Loop Kill 2", Default = false,
        Callback = function(Value)
            loopKill2Active = Value
            if Value then
                loopKill2TargetName = killTarget
                if not loopKill2TargetName then Notify("Error", "ターゲットを選択") Toggles.LoopKill2Toggle:SetValue(false) return end
                task.spawn(function() RunLoopKill2(loopKill2TargetName) end)
            end
        end
    })

    local right = Tabs.Kill:AddRightGroupbox("Blobman Kill System")
    local blobKillTarget = nil
    local blobKillDrop = right:AddDropdown("BlobmanKillSelectedPlayer", {
        Values = GetTargetablePlayerNames(), Default = 1, Text = "Select Player",
        Callback = function(Value)
            blobKillTarget = ExtractUsername(Value)
            BlobmanKill.selectedPlayer = blobKillTarget and Players:FindFirstChild(blobKillTarget)
            if BlobmanKill.isSelectedKill then BlobmanKill.StartSelectedKillLoop() end
        end
    })
    task.spawn(function()
        while true do
            task.wait(2)
            pcall(function() blobKillDrop:SetValues(GetTargetablePlayerNames()) end)
        end
    end)
    right:AddToggle("BlobmanKillAll", {
        Text = "Kill All", Default = false,
        Callback = function(Value)
            BlobmanKill.isRunning = Value
            if Value then
                if Toggles.BlobmanKillAura then Toggles.BlobmanKillAura:SetValue(false) end
                BlobmanKill.UpdateKillAuraConnection()
                task.spawn(function()
                    while BlobmanKill.isRunning do
                        BlobmanKill.ProcessAllPlayers()
                        task.wait()
                    end
                end)
            else
                BlobmanKill.UpdateKillAuraConnection()
            end
        end
    })
    right:AddToggle("BlobmanKillAura", {
        Text = "Kill Aura", Default = false,
        Callback = function(Value)
            BlobmanKill.isKillAura = Value
            if Value then
                if Toggles.BlobmanKillAll then Toggles.BlobmanKillAll:SetValue(false) end
                BlobmanKill.SpawnBlobman()
            end
            BlobmanKill.UpdateKillAuraConnection()
        end
    })
    right:AddToggle("BlobmanSelectedKill", {
        Text = "Selected Kill (Loop)", Default = false,
        Callback = function(Value)
            BlobmanKill.isSelectedKill = Value
            if Value then
                if not BlobmanKill.selectedPlayer then Notify("Error", "プレイヤーを選択") Toggles.BlobmanSelectedKill:SetValue(false) return end
                BlobmanKill.StartSelectedKillLoop()
            else
                if BlobmanKill.selectedKillThread then pcall(task.cancel, BlobmanKill.selectedKillThread) BlobmanKill.selectedKillThread = nil end
            end
        end
    })
end

-- =====================================================
-- グレイブタブ
-- =====================================================
do
    local throwGroup = Tabs.Grab:AddLeftGroupbox("Grab & Throw")
    local strengthConnection
    local nageru = 400
    throwGroup:AddSlider("ThrowStrength", { Text = "Throw strength", Default = 400, Min = 300, Max = 100000, Rounding = 0, Callback = function(Value) nageru = Value end })
    throwGroup:AddToggle("ThrowToggle", {
        Text = "Throw", Default = false,
        Callback = function(enabled)
            if enabled then
                strengthConnection = Workspace.ChildAdded:Connect(function(model)
                    if model.Name == "GrabParts" then
                        local grabPart = model:WaitForChild("GrabPart", 5)
                        if not grabPart then return end
                        local weld = grabPart:WaitForChild("WeldConstraint", 5)
                        if not weld then return end
                        local partToImpulse = weld.Part1
                        if partToImpulse then
                            local velocityObj = Instance.new("BodyVelocity")
                            velocityObj.Parent = partToImpulse
                            velocityObj.MaxForce = Vector3.zero
                            model:GetPropertyChangedSignal("Parent"):Connect(function()
                                if not model.Parent then
                                    local lastInput = UserInputService:GetLastInputType()
                                    if lastInput == Enum.UserInputType.MouseButton2 or lastInput == Enum.UserInputType.Touch then
                                        velocityObj.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                                        velocityObj.Velocity = Camera.CFrame.LookVector * nageru
                                        Debris:AddItem(velocityObj, 1)
                                    else
                                        velocityObj:Destroy()
                                    end
                                end
                            end)
                        end
                    end
                end)
            else
                if strengthConnection then strengthConnection:Disconnect() strengthConnection = nil end
            end
        end
    })

    local exploits = Tabs.Grab:AddRightGroupbox("Grab Exploits")
    exploits:AddSlider("MasslessSensitivity", { Text = "Massless Sensitivity", Default = 200, Min = 10, Max = 1000, Rounding = 0, Callback = function(Value) _G.MLSense = Value end })
    exploits:AddToggle("MasslessGrab", {
        Text = "Massless Grab", Default = false,
        Callback = function(v)
            _G.MassLessGrab = v
            if not v then
                if _G.MLConn then _G.MLConn:Disconnect() _G.MLConn = nil end
                return
            end
            if _G.MLConn then _G.MLConn:Disconnect() _G.MLConn = nil end
            _G.MLConn = RunService.Heartbeat:Connect(function()
                if not _G.MassLessGrab then return end
                local gp = workspace:FindFirstChild("GrabParts")
                if not gp then return end
                local dp = gp:FindFirstChild("DragPart")
                if not dp then return end
                local ap = dp:FindFirstChild("AlignPosition")
                local ao = dp:FindFirstChild("AlignOrientation")
                if ap then ap.Responsiveness = _G.MLSense ap.MaxForce = math.huge ap.MaxVelocity = math.huge end
                if ao then ao.Responsiveness = _G.MLSense ao.MaxTorque = math.huge end
            end)
        end
    })
    exploits:AddToggle("KillGrab", {
        Text = "Kill Grab", Default = false,
        Callback = function(v)
            if v then
                cons["KillGrab"] = workspace.ChildAdded:Connect(function(c)
                    if c.Name == "GrabParts" then
                        local part = c:FindFirstChild("GrabPart") or c:WaitForChild("GrabPart", 1)
                        if part then
                            local weld = part:FindFirstChild("WeldConstraint") or part:WaitForChild("WeldConstraint", 1)
                            if weld and weld.Part1 and weld.Part1.Parent and weld.Part1.Parent:FindFirstChild("HumanoidRootPart") then
                                local hum = weld.Part1.Parent:FindFirstChild("Humanoid")
                                if hum then
                                    hum.BreakJointsOnDeath = false
                                    hum:ChangeState(Enum.HumanoidStateType.Dead)
                                    task.wait(0.1)
                                    if DestroyLine then pcall(function() DestroyLine:FireServer(weld.Part1) end) end
                                end
                            end
                        end
                    end
                end)
            else
                if cons["KillGrab"] then cons["KillGrab"]:Disconnect() cons["KillGrab"] = nil end
            end
        end
    })
    exploits:AddToggle("SpinGrab", {
        Text = "Spin Grab", Default = false,
        Callback = function(v)
            spingrab = v
            if spingrab then
                cons["spingrabConnection"] = workspace.ChildAdded:Connect(function(e)
                    if e.Name == "GrabParts" and e:FindFirstChild("GrabPart") then
                        local dragPart = workspace:FindFirstChild("GrabParts") and workspace.GrabParts:FindFirstChild("DragPart")
                        if dragPart then
                            local ao = dragPart:FindFirstChild("AlignOrientation")
                            if ao then ao:Destroy() end
                        end
                        local part1 = e.GrabPart:FindFirstChild("WeldConstraint") and e.GrabPart.WeldConstraint.Part1
                        if part1 and part1.Parent then
                            task.spawn(function()
                                while workspace:FindFirstChild("GrabParts") and spingrab and task.wait() do
                                    if part1.Parent then part1.AssemblyAngularVelocity = Vector3.new(0, spinspeed, 0) else break end
                                end
                            end)
                        end
                    end
                end)
            else
                if cons["spingrabConnection"] then cons["spingrabConnection"]:Disconnect() cons["spingrabConnection"] = nil end
            end
        end
    })
    exploits:AddToggle("RagdollGrab", {
        Text = "Ragdoll Grab", Default = false,
        Callback = function(v)
            if v then
                local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                local HRP = char:WaitForChild("HumanoidRootPart")
                local ragd = spawntoy("PalletLightBrown", HRP.CFrame * CFrame.new(5, 5, 20))
                if not ragd then Notify("Error", "Pallet spawn失敗") return end
                local partt = ragd:WaitForChild("SoundPart", 0.5)
                if not partt then Notify("Error", "SoundPart not found") return end
                ragd.Name = "ragdoll"
                task.spawn(function()
                    for _, v in pairs(ragd:GetDescendants()) do
                        if v:IsA("BasePart") then v.Transparency = 1 v.CanCollide = false end
                    end
                end)
                cons["rgarab1"] = workspace.ChildAdded:Connect(function(c)
                    if c.Name == "GrabParts" then
                        local part = c:FindFirstChild("GrabPart") or c:WaitForChild("GrabPart", 3)
                        if part and part:FindFirstChild("WeldConstraint") and part.WeldConstraint.Part1 then
                            local obj = part.WeldConstraint.Part1
                            task.spawn(function()
                                while workspace:FindFirstChild("GrabParts") and task.wait(0.05) do
                                    if obj and obj.Parent and obj.Parent:FindFirstChild("HumanoidRootPart") then
                                        local hum = obj.Parent:FindFirstChild("Humanoid")
                                        if hum and hum:FindFirstChild("Ragdolled") and not hum.Ragdolled.Value then
                                            if partt and partt.Parent then
                                                partt.CFrame = obj.Parent.HumanoidRootPart.CFrame
                                                task.wait(0.05)
                                                partt.CFrame = CFrame.new(0, 1e9, 0)
                                            end
                                        end
                                    else break end
                                end
                            end)
                        end
                    end
                end)
            else
                if cons["rgarab1"] then cons["rgarab1"]:Disconnect() cons["rgarab1"] = nil end
                local inv = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
                if inv and inv:FindFirstChild("ragdoll") and DestroyToy then
                    pcall(function() DestroyToy:FireServer(inv.ragdoll) end)
                end
            end
        end
    })
    exploits:AddToggle("KickGrab", {
        Text = "Kick Grab", Default = false,
        Callback = function(v)
            if v then
                cons["KickGrab"] = workspace.ChildAdded:Connect(function(c)
                    if c.Name ~= "GrabParts" then return end
                    local GrabPart = c:WaitForChild("GrabPart", 0.1)
                    if not GrabPart then return end
                    task.wait(0.1)
                    local weld = GrabPart:FindFirstChild("WeldConstraint")
                    if not weld or not weld.Part1 then return end
                    local part = weld.Part1
                    if part.Parent and Players:FindFirstChild(part.Parent.Name) then
                        task.spawn(function()
                            while GrabPart and GrabPart.Parent and part and part.Parent do
                                if DestroyLine then pcall(function() DestroyLine:FireServer(part) end) end
                                RunService.RenderStepped:Wait()
                                if SetNetOwner then pcall(function() SetNetOwner:FireServer(part, part.CFrame) end) end
                                RunService.RenderStepped:Wait()
                            end
                        end)
                    end
                end)
            else
                if cons["KickGrab"] then cons["KickGrab"]:Disconnect() cons["KickGrab"] = nil end
            end
        end
    })

    local gucciGroup = Tabs.Grab:AddRightGroupbox("Gucci Break")
    local loopGucciActive = false
    gucciGroup:AddButton({
        Text = "All Gucci Break",
        Func = function()
            local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not root then return end
            local orig = root.CFrame
            for _, obj in pairs(workspace:GetDescendants()) do
                if obj.Name == "CreatureBlobman" and obj:IsA("Model") then
                    local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                    local seat = obj:FindFirstChild("VehicleSeat")
                    if seat and not seat:FindFirstChild("SeatWeld") then
                        local prompt = seat:FindFirstChildOfClass("ProximityPrompt")
                        if prompt then
                            root.CFrame = seat.CFrame
                            for _ = 1, 20 do
                                pcall(fireproximityprompt, prompt)
                                task.wait(0.01)
                                if seat:FindFirstChild("SeatWeld") then break end
                            end
                            if seat:FindFirstChild("SeatWeld") then hum.Sit = false task.wait(0.1) end
                        end
                    end
                end
            end
            root.CFrame = orig
            Notify("Gucci Break", "完了")
        end
    })
    gucciGroup:AddToggle("LoopAllGucciBreak", {
        Text = "Loop All Gucci Break", Default = false,
        Callback = function(Value)
            loopGucciActive = Value
            if Value then
                task.spawn(function()
                    while loopGucciActive do
                        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        if root then
                            local orig = root.CFrame
                            for _, obj in pairs(workspace:GetDescendants()) do
                                if obj.Name == "CreatureBlobman" and obj:IsA("Model") then
                                    local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                                    local seat = obj:FindFirstChild("VehicleSeat")
                                    if seat and not seat:FindFirstChild("SeatWeld") then
                                        local prompt = seat:FindFirstChildOfClass("ProximityPrompt")
                                        if prompt then
                                            root.CFrame = seat.CFrame
                                            for _ = 1, 20 do
                                                pcall(fireproximityprompt, prompt)
                                                task.wait(0.01)
                                                if seat:FindFirstChild("SeatWeld") then break end
                                            end
                                            if seat:FindFirstChild("SeatWeld") then hum.Sit = false task.wait(0.1) end
                                        end
                                    end
                                end
                            end
                            root.CFrame = orig
                        end
                        task.wait(1)
                    end
                end)
            end
        end
    })
end

-- =====================================================
-- Silent Target 系
-- =====================================================
local silentGrab = Tabs.Grab:AddLeftGroupbox("Silent Target系")

local st_selected = nil
local st_lockActive = false
local st_silentAim = false
local st_autoGrab = false
local st_lockConn = nil
local st_aimConn = nil

local function st_getPlayerList()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(list, p.DisplayName .. " (@" .. p.Name .. ")")
        end
    end
    return list
end

local function st_nameFromDisplay(display)
    if not display or display == "" then return nil end
    local s = string.find(display, "%(@")
    if s then return string.sub(display, s + 2, -2) end
    return nil
end

local stDrop = silentGrab:AddDropdown("ST_Target", {
    Text = "ターゲット",
    Values = st_getPlayerList(),
    Default = 1,
    Callback = function(v) st_selected = st_nameFromDisplay(v) end
})
task.spawn(function()
    while true do
        task.wait(2)
        pcall(function() stDrop:SetValues(st_getPlayerList()) end)
    end
end)

silentGrab:AddToggle("ST_LockTarget", {
    Text = "ターゲットロック (カメラ追従)",
    Default = false,
    Callback = function(v)
        st_lockActive = v
        if st_lockConn then st_lockConn:Disconnect(); st_lockConn = nil end
        if v then
            if not st_selected then
                Notify("Error", "ターゲットを選択", 2)
                if Toggles.ST_LockTarget then Toggles.ST_LockTarget:SetValue(false) end
                return
            end
            st_lockConn = RunService.RenderStepped:Connect(function()
                if not st_lockActive or not st_selected then return end
                local target = Players:FindFirstChild(st_selected)
                if not target or not target.Character then return end
                local head = target.Character:FindFirstChild("Head") or target.Character:FindFirstChild("HumanoidRootPart")
                if head and Workspace.CurrentCamera then
                    local cam = Workspace.CurrentCamera
                    local look = (head.Position - cam.CFrame.Position).Unit
                    cam.CFrame = CFrame.new(cam.CFrame.Position, cam.CFrame.Position + look)
                end
            end)
        end
    end
})

silentGrab:AddToggle("ST_SilentAim", {
    Text = "Silent Aim (簡易)",
    Default = false,
    Callback = function(v)
        st_silentAim = v
        if st_aimConn then st_aimConn:Disconnect(); st_aimConn = nil end
        if v then
            if not st_selected then
                Notify("Error", "ターゲットを選択", 2)
                if Toggles.ST_SilentAim then Toggles.ST_SilentAim:SetValue(false) end
                return
            end
            st_aimConn = RunService.Heartbeat:Connect(function()
                if not st_silentAim or not st_selected then return end
                local target = Players:FindFirstChild(st_selected)
                if not target or not target.Character then return end
                local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
                if not tRoot then return end
                local cam = Workspace.CurrentCamera
                if cam then
                    local dir = (tRoot.Position - cam.CFrame.Position).Unit
                    cam.CFrame = cam.CFrame:Lerp(CFrame.new(cam.CFrame.Position, cam.CFrame.Position + dir), 0.35)
                end
            end)
        end
    end
})

silentGrab:AddToggle("ST_AutoGrab", {
    Text = "Auto Grab (ターゲットにグラブ)",
    Default = false,
    Callback = function(v)
        st_autoGrab = v
        if v then
            if not st_selected then
                Notify("Error", "ターゲットを選択", 2)
                if Toggles.ST_AutoGrab then Toggles.ST_AutoGrab:SetValue(false) end
                return
            end
            task.spawn(function()
                while st_autoGrab do
                    local target = Players:FindFirstChild(st_selected)
                    if target and target.Character then
                        local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
                        if tRoot then
                            local GE = ReplicatedStorage:FindFirstChild("GrabEvents")
                            local setNet = GE and GE:FindFirstChild("SetNetworkOwner")
                            local destroyLine = GE and GE:FindFirstChild("DestroyGrabLine")
                            if setNet then
                                for _ = 1, 5 do
                                    pcall(function() setNet:FireServer(tRoot, tRoot.CFrame) end)
                                end
                            end
                            if destroyLine then
                                pcall(function() destroyLine:FireServer(tRoot) end)
                            end
                            local folder = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
                            local blob = folder and folder:FindFirstChild("CreatureBlobman")
                            if blob then
                                local scriptObj = blob:FindFirstChild("BlobmanSeatAndOwnerScript")
                                local grab = scriptObj and scriptObj:FindFirstChild("CreatureGrab")
                                local det = blob:FindFirstChild("RightDetector") or blob:FindFirstChild("LeftDetector")
                                local weld = det and (det:FindFirstChild("RightWeld") or det:FindFirstChild("LeftWeld") or det:FindFirstChildWhichIsA("Weld"))
                                if grab and det and weld then
                                    pcall(function() grab:FireServer(det, tRoot, weld) end)
                                end
                            end
                        end
                    end
                    task.wait(0.08)
                end
            end)
        end
    end
})

silentGrab:AddButton({
    Text = "ターゲットにテレポート",
    Func = function()
        if not st_selected then Notify("Error", "ターゲットを選択", 2) return end
        local target = Players:FindFirstChild(st_selected)
        if not target or not target.Character then Notify("Error", "ターゲットなし", 2) return end
        local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
        local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if tRoot and myRoot then
            myRoot.CFrame = tRoot.CFrame * CFrame.new(0, 0, 3)
            Notify("Silent", "テレポートしました", 2)
        end
    end
})

silentGrab:AddButton({
    Text = "ターゲットをBring (簡易)",
    Func = function()
        if not st_selected then Notify("Error", "ターゲットを選択", 2) return end
        local target = Players:FindFirstChild(st_selected)
        if not target or not target.Character then return end
        local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
        local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not tRoot or not myRoot then return end
        local GE = ReplicatedStorage:FindFirstChild("GrabEvents")
        local setNet = GE and GE:FindFirstChild("SetNetworkOwner")
        if setNet then
            for _ = 1, 20 do
                pcall(function() setNet:FireServer(tRoot, tRoot.CFrame) end)
            end
        end
        tRoot.CFrame = myRoot.CFrame * CFrame.new(0, 0, -5)
        tRoot.AssemblyLinearVelocity = Vector3.zero
        Notify("Silent", "Bring実行", 2)
    end
})

-- =====================================================
-- Ragdollタブ
-- =====================================================
do
    local group = Tabs.Ragdoll:AddLeftGroupbox("Ragdoll Kill")
    local selectedRag = nil
    local isRagdollActive = false
    local isBananaLoop = false
    local ragDrop = group:AddDropdown("RagSelect", {
        Values = GetPlayerList(), Default = 1, Text = "Select Player",
        Callback = function(v) selectedRag = GetNameFromDisplay(v) end
    })
    task.spawn(function()
        while true do
            task.wait(2)
            pcall(function() ragDrop:SetValues(GetPlayerList()) end)
        end
    end)
    local function destroyAllPencils()
        local folder = GetToysFolder()
        if not folder or not DestroyToy then return end
        for _, child in pairs(folder:GetChildren()) do
            if child.Name == "ToolPencil" then
                pcall(function() DestroyToy:FireServer(child) end)
            end
        end
    end
    local function doSticky()
        if not selectedRag then return end
        local target = Players:FindFirstChild(selectedRag)
        if not target or not target.Character then return end
        local head = target.Character:FindFirstChild("Head")
        if not head then return end
        destroyAllPencils()
        task.wait(0.05)
        local pencil = nil
        local folder = GetToysFolder()
        if folder and SpawnToy then
            local conn = folder.ChildAdded:Connect(function(c)
                if c.Name == "ToolPencil" then pencil = c conn:Disconnect() end
            end)
            pcall(function() SpawnToy:InvokeServer("ToolPencil", GetMyRoot().CFrame * CFrame.new(0,14,20), Vector3.zero) end)
            local t = tick()
            repeat task.wait(0.05) until pencil or tick()-t > 3
            if conn then conn:Disconnect() end
        end
        if pencil and pencil:FindFirstChild("StickyPart") and StickyEvent then
            local sticky = pencil.StickyPart
            local sound = pencil:FindFirstChild("SoundPart")
            if sound then SpamOwnership(sound) end
            pcall(function()
                StickyEvent:FireServer(sticky, head, CFrame.new(0, -1e8, 0))
                StickyEvent:FireServer(sticky, head, CFrame.new(0, -1e8, 0))
            end)
        end
    end
    group:AddToggle("RagdollKill", {
        Text = "Ragdoll Kill (Pencil)", Default = false,
        Callback = function(v)
            isRagdollActive = v
            if v then
                if not selectedRag then Notify("Error", "プレイヤーを選択") return end
                doSticky()
                task.spawn(function()
                    while isRagdollActive do
                        local folder = GetToysFolder()
                        local count = 0
                        if folder then
                            for _, c in pairs(folder:GetChildren()) do
                                if c.Name == "ToolPencil" then count = count + 1 end
                            end
                        end
                        if count == 0 or count >= 2 then
                            destroyAllPencils()
                            task.wait(0.05)
                            doSticky()
                        end
                        task.wait(0.15)
                    end
                    destroyAllPencils()
                end)
            else
                destroyAllPencils()
            end
        end
    })
    group:AddToggle("BananaLoop", {
        Text = "Loop Banana Ragdoll", Default = false,
        Callback = function(v)
            isBananaLoop = v
            if not v then return end
            if not selectedRag then Notify("Error", "プレイヤーを選択") return end
            task.spawn(function()
                while isBananaLoop do
                    local hrp = GetMyRoot()
                    if not hrp then task.wait(0.5) continue end
                    local banana = nil
                    local folder = GetToysFolder()
                    if folder and SpawnToy then
                        local conn = folder.ChildAdded:Connect(function(c)
                            if c.Name == "FoodBanana" then banana = c conn:Disconnect() end
                        end)
                        pcall(function() SpawnToy:InvokeServer("FoodBanana", hrp.CFrame * CFrame.new(0,14,20), Vector3.zero) end)
                        local t = tick()
                        repeat task.wait(0.05) until banana or tick()-t > 3
                        if conn then conn:Disconnect() end
                    end
                    if banana then
                        local holdPart = banana:FindFirstChild("HoldPart")
                        if holdPart then
                            local holdRemote = holdPart:FindFirstChild("HoldItemRemoteFunction")
                            if holdRemote then pcall(function() holdRemote:InvokeServer(banana, LocalPlayer.Character) end) end
                        end
                        task.wait(0.5)
                        local useEvent = ReplicatedStorage:FindFirstChild("HoldEvents") and ReplicatedStorage.HoldEvents:FindFirstChild("Use")
                        if useEvent then pcall(function() useEvent:FireServer(banana) end) end
                        task.wait(2.3)
                        if holdPart then
                            local dropRemote = holdPart:FindFirstChild("DropItemRemoteFunction")
                            local target = Players:FindFirstChild(selectedRag)
                            local leg = target and target.Character and (target.Character:FindFirstChild("Left Leg") or target.Character:FindFirstChild("HumanoidRootPart"))
                            if dropRemote and leg then pcall(function() dropRemote:InvokeServer(banana, leg.CFrame, leg.CFrame) end) end
                        end
                    end
                    task.wait(0.5)
                end
            end)
        end
    })

    local snowGroup = Tabs.Ragdoll:AddRightGroupbox("Snowball Ragdoll")
    local snowTarget = nil
    local snowDrop = snowGroup:AddDropdown("SnowTarget", {
        Values = GetTargetablePlayerNames(), Default = 1, Text = "ターゲット",
        Callback = function(v) snowTarget = ExtractUsername(v) end
    })
    task.spawn(function()
        while true do
            task.wait(2)
            pcall(function() snowDrop:SetValues(GetTargetablePlayerNames()) end)
        end
    end)
    snowGroup:AddToggle("SnowballRagdollToggle", {
        Text = "Snowball Ragdoll", Default = false,
        Callback = function(Value)
            snowballRagdollActive = Value
            if Value then
                snowballRagdollTargetName = snowTarget
                if not snowballRagdollTargetName then Notify("Error", "ターゲットを選択") Toggles.SnowballRagdollToggle:SetValue(false) return end
                task.spawn(SnowballRagdollFunction)
            end
        end
    })
end

-- =====================================================
-- Advanced Banana Ragdoll
-- =====================================================
local advGroup = Tabs.Ragdoll:AddRightGroupbox("Advanced Banana Ragdoll")

local adv_selectedPlayer = nil
local adv_isLooping = false
local adv_loopConnection = nil
local adv_monitorConnection = nil
local adv_currentBanana = nil
local adv_isTargetDead = false

local function adv_getHRP()
    return LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
end

local function adv_getFolder()
    return Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
end

local function adv_setNetworkOwner(part)
    if not part then return end
    local ge = ReplicatedStorage:FindFirstChild("GrabEvents")
    local setNet = ge and ge:FindFirstChild("SetNetworkOwner")
    if setNet then pcall(function() setNet:FireServer(part, part.CFrame) end) end
end

local function adv_destroyGrabLine(part)
    if not part then return end
    local ge = ReplicatedStorage:FindFirstChild("GrabEvents")
    local dl = ge and ge:FindFirstChild("DestroyGrabLine")
    if dl then pcall(function() dl:FireServer(part) end) end
end

local function adv_destroyBanana(banana)
    if not banana then return end
    local mt = ReplicatedStorage:FindFirstChild("MenuToys")
    local dt = mt and mt:FindFirstChild("DestroyToy")
    if dt then pcall(function() dt:FireServer(banana) end) end
end

local function adv_spawnBanana()
    local hrp = adv_getHRP()
    if not hrp then return nil end
    local mt = ReplicatedStorage:FindFirstChild("MenuToys")
    local spawnRemote = mt and mt:FindFirstChild("SpawnToyRemoteFunction")
    if not spawnRemote then return nil end
    local folder = adv_getFolder()
    if not folder then return nil end
    local spawned = nil
    local conn = folder.ChildAdded:Connect(function(child)
        if child.Name == "FoodBanana" then spawned = child; conn:Disconnect() end
    end)
    task.spawn(function()
        pcall(function() spawnRemote:InvokeServer("FoodBanana", hrp.CFrame * CFrame.new(0, 14, 20), Vector3.zero) end)
    end)
    local start = tick()
    repeat task.wait(0.05) until spawned or (tick() - start) > 3
    if conn then pcall(function() conn:Disconnect() end) end
    return spawned
end

local function adv_holdBanana(banana)
    if not banana then return end
    local holdPart = banana:FindFirstChild("HoldPart")
    if not holdPart then return end
    local holdRemote = holdPart:FindFirstChild("HoldItemRemoteFunction")
    if not holdRemote then return end
    local char = LocalPlayer.Character
    if not char then return end
    for i = 1, 5 do
        if not banana or not banana.Parent then break end
        if pcall(function() return holdRemote:InvokeServer(banana, char) end) then return true end
        task.wait(0.05)
    end
    return false
end

local function adv_useBanana(banana)
    if not banana then return end
    local useEvent = ReplicatedStorage:FindFirstChild("HoldEvents") and ReplicatedStorage.HoldEvents:FindFirstChild("Use")
    if useEvent then pcall(function() useEvent:FireServer(banana) end) end
end

local function adv_dropBanana(banana)
    if not banana then return end
    local holdPart = banana:FindFirstChild("HoldPart")
    if not holdPart then return end
    local dropRemote = holdPart:FindFirstChild("DropItemRemoteFunction")
    if not dropRemote then return end
    local hrp = adv_getHRP()
    if not hrp then return end
    local dropPos = hrp.CFrame * CFrame.new(0, 15, 0)
    pcall(function() dropRemote:InvokeServer(banana, dropPos, dropPos) end)
end

local function adv_getTargetLeg()
    if not adv_selectedPlayer then return nil end
    local target = Players:FindFirstChild(adv_selectedPlayer)
    if target and target.Character then return target.Character:FindFirstChild("Left Leg") end
    return nil
end

local function adv_getTargetHealth()
    if not adv_selectedPlayer then return 0 end
    local target = Players:FindFirstChild(adv_selectedPlayer)
    if target and target.Character then
        local hum = target.Character:FindFirstChildOfClass("Humanoid")
        if hum then return hum.Health end
    end
    return 0
end

local function adv_fullBananaCycle()
    if not adv_selectedPlayer or adv_selectedPlayer == "" then return false end
    local banana = adv_spawnBanana()
    if not banana then return false end
    adv_holdBanana(banana)
    task.wait(0.05)
    adv_holdBanana(banana)
    task.wait(0.5)
    adv_useBanana(banana)
    task.wait(2.3)
    adv_dropBanana(banana)
    task.wait(0.05)
    adv_dropBanana(banana)
    task.wait(0.3)
    return banana
end

local function adv_stopLoop()
    adv_isLooping = false
    if adv_loopConnection then adv_loopConnection:Disconnect(); adv_loopConnection = nil end
    if adv_monitorConnection then adv_monitorConnection:Disconnect(); adv_monitorConnection = nil end
    if adv_currentBanana then
        adv_destroyBanana(adv_currentBanana)
        local hitbox = adv_currentBanana:FindFirstChild("HitboxPart")
        if hitbox then
            local bp = hitbox:FindFirstChild("BodyPosition"); if bp then bp:Destroy() end
            local bg = hitbox:FindFirstChild("BodyGyro"); if bg then bg:Destroy() end
        end
        adv_currentBanana = nil
    end
    local folder = adv_getFolder()
    if folder then
        for _, child in pairs(folder:GetChildren()) do
            if child.Name == "FoodBanana" then adv_destroyBanana(child) end
        end
    end
end

local function adv_restartLoop(banana)
    if adv_loopConnection then adv_loopConnection:Disconnect(); adv_loopConnection = nil end
    adv_currentBanana = banana
    local hitboxPart = banana:FindFirstChild("HitboxPart")
    if not hitboxPart then return end
    adv_loopConnection = RunService.Heartbeat:Connect(function()
        if not adv_isLooping then return end
        if not adv_currentBanana or not adv_currentBanana.Parent then return end
        local folder = adv_getFolder()
        local bananaExists = false
        if folder then
            for _, child in pairs(folder:GetChildren()) do
                if child.Name == "FoodBanana" then
                    bananaExists = true
                    adv_currentBanana = child
                    hitboxPart = child:FindFirstChild("HitboxPart")
                    break
                end
            end
        end
        if not bananaExists or not hitboxPart then
            if adv_loopConnection then adv_loopConnection:Disconnect(); adv_loopConnection = nil end
            adv_currentBanana = nil
            return
        end
        local hrp = adv_getHRP()
        if not hrp then return end
        local targetPos, targetCFrame
        local health = adv_getTargetHealth()
        if health <= 0 then
            adv_isTargetDead = true
            targetPos = hrp.CFrame * CFrame.new(0, 7, 0)
            targetCFrame = CFrame.new(targetPos.Position)
        else
            adv_isTargetDead = false
            local leg = adv_getTargetLeg()
            if leg then
                targetPos = leg.CFrame * CFrame.new(0, 0.5, 0)
                targetCFrame = leg.CFrame
            else
                targetPos = hrp.CFrame * CFrame.new(0, 7, 0)
                targetCFrame = CFrame.new(targetPos.Position)
            end
        end
        adv_setNetworkOwner(hitboxPart)
        adv_destroyGrabLine(hitboxPart)
        local bp = hitboxPart:FindFirstChild("BodyPosition")
        if not bp then
            bp = Instance.new("BodyPosition")
            bp.P = 10000; bp.D = 100
            bp.MaxForce = Vector3.new(1e9, 1e9, 1e9)
            bp.Parent = hitboxPart
        end
        bp.Position = targetPos.Position
        local bg = hitboxPart:FindFirstChild("BodyGyro")
        if not bg then
            bg = Instance.new("BodyGyro")
            bg.P = 10000; bg.D = 100
            bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
            bg.Parent = hitboxPart
        end
        bg.CFrame = targetCFrame
    end)
end

local function adv_startLoop()
    if adv_isLooping then return end
    if not adv_selectedPlayer or adv_selectedPlayer == "" then return end
    adv_isLooping = true
    adv_isTargetDead = false
    local banana = adv_fullBananaCycle()
    if banana then adv_restartLoop(banana) end
    adv_monitorConnection = RunService.Heartbeat:Connect(function()
        if not adv_isLooping then return end
        local folder = adv_getFolder()
        local bananaExists = false
        if folder then
            for _, child in pairs(folder:GetChildren()) do
                if child.Name == "FoodBanana" then bananaExists = true; break end
            end
        end
        if not bananaExists then
            if adv_loopConnection then adv_loopConnection:Disconnect(); adv_loopConnection = nil end
            task.wait(0.05)
            local newBanana = adv_fullBananaCycle()
            if newBanana then adv_restartLoop(newBanana) end
        end
    end)
end

local advDrop = advGroup:AddDropdown("AdvBananaTarget", {
    Text = "Select Player",
    Values = GetPlayerList and GetPlayerList() or {},
    Default = 1,
    Callback = function(v)
        local name = nil
        if GetNameFromDisplay then
            name = GetNameFromDisplay(v)
        elseif type(v) == "string" then
            local s = string.find(v, "%(@")
            if s then name = string.sub(v, s+2, -2) end
        end
        adv_selectedPlayer = name
    end
})
task.spawn(function()
    while true do
        task.wait(2)
        pcall(function()
            if GetPlayerList then advDrop:SetValues(GetPlayerList()) end
        end)
    end
end)

advGroup:AddToggle("AdvLoopBananaRagdoll", {
    Text = "Loop Banana Ragdoll (Advanced)",
    Default = false,
    Callback = function(v)
        if v then
            if not adv_selectedPlayer or adv_selectedPlayer == "" then
                Notify("Error", "プレイヤーを選択")
                if Toggles.AdvLoopBananaRagdoll then Toggles.AdvLoopBananaRagdoll:SetValue(false) end
                return
            end
            adv_stopLoop()
            adv_startLoop()
            Notify("Banana Ragdoll", "Started", 2)
        else
            adv_stopLoop()
            Notify("Banana Ragdoll", "Stopped", 2)
        end
    end
})

-- =====================================================
-- Extraタブ
-- =====================================================
do
    local floor = Tabs.Extra:AddLeftGroupbox("床落とし")
    floor:AddButton({
        Text = "視線の床を固定",
        Func = function()
            local ray = Camera:ViewportPointToRay(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = {LocalPlayer.Character}
            local result = Workspace:Raycast(ray.Origin, ray.Direction * 120, params)
            if result and result.Instance and result.Instance:IsA("BasePart") then
                result.Instance.Anchored = true
                Notify("床落とし", "固定")
            else
                Notify("床落とし", "対象なし")
            end
        end
    })
    floor:AddButton({
        Text = "視線の床を解除",
        Func = function()
            local ray = Camera:ViewportPointToRay(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = {LocalPlayer.Character}
            local result = Workspace:Raycast(ray.Origin, ray.Direction * 120, params)
            if result and result.Instance and result.Instance:IsA("BasePart") then
                result.Instance.Anchored = false
                Notify("床落とし", "解除")
            else
                Notify("床落とし", "対象なし")
            end
        end
    })

    local tsunami = Tabs.Extra:AddRightGroupbox("Tsunami")
    local isTsunamiRunning = false
    tsunami:AddButton({
        Text = "Tsunami Break",
        Func = function()
            if isTsunamiRunning then return end
            isTsunamiRunning = true
            task.spawn(function()
                local map = Workspace:FindFirstChild("Map")
                local always = map and map:FindFirstChild("AlwaysHereTweenedObjects")
                local ocean = always and always:FindFirstChild("Ocean")
                local object = ocean and ocean:FindFirstChild("Object")
                local objectModel = object and object:FindFirstChild("ObjectModel")
                if not objectModel then Notify("Tsunami", "ターゲットなし") isTsunamiRunning = false return end
                local children = objectModel:GetChildren()
                local target = children[17]
                if not (target and target:IsA("BasePart")) then Notify("Tsunami", "Partなし") isTsunamiRunning = false return end
                target.Anchored = false
                for i = 1, 12 do
                    if not isTsunamiRunning then break end
                    local shuriken = nil
                    local folder = GetToysFolder()
                    if folder and SpawnToy then
                        local conn = folder.ChildAdded:Connect(function(c)
                            if c.Name == "NinjaShuriken" then shuriken = c conn:Disconnect() end
                        end)
                        pcall(function() SpawnToy:InvokeServer("NinjaShuriken", GetMyRoot().CFrame * CFrame.new(0,14,20), Vector3.zero) end)
                        local t = tick()
                        repeat task.wait(0.05) until shuriken or tick()-t > 2
                        if conn then conn:Disconnect() end
                    end
                    if shuriken and shuriken:FindFirstChild("StickyPart") then
                        local sp = shuriken.StickyPart
                        SpamOwnership(sp)
                        local bp = Instance.new("BodyPosition")
                        bp.Position = Vector3.new(math.random(-100,100), 1000, math.random(-100,100))
                        bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                        bp.Parent = sp
                    end
                    task.wait(0.15)
                end
                task.wait(0.3)
                local folder = GetToysFolder()
                if folder then
                    for _, toy in ipairs(folder:GetChildren()) do
                        if toy.Name == "NinjaShuriken" and toy:FindFirstChild("StickyPart") and StickyEvent then
                            pcall(function()
                                SpamOwnership(toy.StickyPart)
                                StickyEvent:FireServer(toy.StickyPart, target, CFrame.new(0, -2.147e9, 0))
                            end)
                            task.wait(0.05)
                        end
                    end
                end
                if ocean then pcall(function() ocean.Collision = false end) end
                isTsunamiRunning = false
                Notify("Tsunami", "完了")
            end)
        end
    })
end

-- =====================================================
-- バリア破壊
-- =====================================================
local barrierGroup = Tabs.Extra:AddLeftGroupbox("バリア破壊")

local autoBarrierRunning = false
local autoBarrierNoTPRunning = false

local function executeBarrierBreak()
    local player, playerName = LocalPlayer, LocalPlayer.Name
    local plotItems = Workspace:FindFirstChild("PlotItems")
    if plotItems then
        local playersInPlots = plotItems:FindFirstChild("PlayersInPlots")
        if playersInPlots and playersInPlots:FindFirstChild(playerName) then
            Notify("⚠️ Error", "Please execute outside your house", 3)
            return false
        end
    end
    autoBarrierRunning = true
    local success, result = pcall(function()
        if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            Notify("⚠️ Error", "Character not found", 3)
            return false
        end
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if not humanoid then
            Notify("⚠️ Error", "Humanoid not found", 3)
            return false
        end
        local originalWalkSpeed = humanoid.WalkSpeed
        local originalPosition = LocalPlayer.Character.HumanoidRootPart.CFrame
        humanoid.WalkSpeed = 0
        if not ReplicatedStorage:FindFirstChild("MenuToys") then
            humanoid.WalkSpeed = originalWalkSpeed
            Notify("⚠️ Error", "MenuToys not found", 3)
            return false
        end
        ReplicatedStorage.MenuToys.SpawnToyRemoteFunction:InvokeServer("InstrumentWoodwindOcarina",
            CFrame.new(184.148834, -5.54824972, 498.136749, 0.829037189, -0.214714944, 0.516328275, 0, 0.923344612, 0.383972496, -0.559193552, -0.318327487, 0.765486956),
            Vector3.new(0, 34, 0))
        task.wait(0.4)
        local toyFolder = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
        if not toyFolder or not toyFolder:FindFirstChild("InstrumentWoodwindOcarina") then
            humanoid.WalkSpeed = originalWalkSpeed
            Notify("⚠️ Error", "Ocarina not found", 3)
            return false
        end
        local ocarina = toyFolder:FindFirstChild("InstrumentWoodwindOcarina")
        if not ocarina or not ocarina:FindFirstChild("HoldPart") then
            humanoid.WalkSpeed = originalWalkSpeed
            Notify("⚠️ Error", "Ocarina HoldPart not found", 3)
            return false
        end
        ocarina.HoldPart.HoldItemRemoteFunction:InvokeServer(ocarina, Workspace[LocalPlayer.Name])
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(304.06, 25.77, 488.54)
        end
        task.wait(0.21)
        if toyFolder and toyFolder:FindFirstChild("InstrumentWoodwindOcarina") then
            ReplicatedStorage.MenuToys.DestroyToy:FireServer(toyFolder.InstrumentWoodwindOcarina)
        end
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character.HumanoidRootPart.CFrame = originalPosition
        end
        task.wait(0.7)
        ReplicatedStorage.MenuToys.SpawnToyRemoteFunction:InvokeServer("Campfire",
            CFrame.new(257.638672, -5.57392979, 450.103638, -0.950906992, -0.171067372, 0.257899135, 0, 0.833338678, 0.552762806, -0.309477001, 0.525626004, -0.79242748),
            Vector3.new(0, 161.9720001220703, 0))
        task.wait(0.7)
        local campfirePosition = Vector3.new(257.638672, -5.57392979, 450.103638)
        local toyFolder2 = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
        if toyFolder2 and toyFolder2:FindFirstChild("Campfire") then
            local campfire = toyFolder2:FindFirstChild("Campfire")
            local primaryPart = campfire.PrimaryPart or campfire:FindFirstChildWhichIsA("BasePart")
            if primaryPart then
                local distance = (primaryPart.Position - campfirePosition).Magnitude
                if distance < 10 then
                    task.wait(1)
                    humanoid.WalkSpeed = originalWalkSpeed
                    Notify("✅ Success", "Barrier破壊に成功！", 5)
                    return true
                end
            end
        end
        humanoid.WalkSpeed = originalWalkSpeed
        Notify("⚠️ Failed", "Campfire placement failed", 3)
        return false
    end)
    if not success then
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then humanoid.WalkSpeed = 16 end
        end
        Notify("❌ Error", "Execution error: " .. tostring(result), 3)
        return false
    end
    autoBarrierRunning = false
    return result
end

local function executeBarrierBreakNoTP()
    local player, playerName = LocalPlayer, LocalPlayer.Name
    local plotItems = Workspace:FindFirstChild("PlotItems")
    if plotItems then
        local playersInPlots = plotItems:FindFirstChild("PlayersInPlots")
        if playersInPlots and playersInPlots:FindFirstChild(playerName) then
            Notify("⚠️ エラー", "家の外で実行してください", 3)
            return false
        end
    end
    autoBarrierNoTPRunning = true
    local success, err = pcall(function()
        if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
            error("キャラクターが見つかりません")
        end
        local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
        if not humanoid then error("Humanoidが見つかりません") end
        humanoid.WalkSpeed = 0
        if not ReplicatedStorage:FindFirstChild("MenuToys") then
            humanoid.WalkSpeed = 16
            error("MenuToysが見つかりません")
        end
        local spawnResult = ReplicatedStorage.MenuToys.SpawnToyRemoteFunction:InvokeServer("InstrumentWoodwindOcarina",
            CFrame.new(184.148834, -5.54824972, 498.136749, 0.829037189, -0.214714944, 0.516328275, 0, 0.923344612, 0.383972496, -0.559193552, -0.318327487, 0.765486956),
            Vector3.new(0, 34, 0))
        if not spawnResult then
            humanoid.WalkSpeed = 16
            error("オカリナのスポーンに失敗しました")
        end
        task.wait(0.4)
        local toyFolder = Workspace:FindFirstChild(playerName .. "SpawnedInToys")
        if not toyFolder then
            humanoid.WalkSpeed = 16
            error("トイフォルダが見つかりません")
        end
        local ocarina = toyFolder:FindFirstChild("InstrumentWoodwindOcarina")
        if not ocarina then
            humanoid.WalkSpeed = 16
            error("オカリナが見つかりません")
        end
        if not ocarina:FindFirstChild("HoldPart") then
            humanoid.WalkSpeed = 16
            error("オカリナのHoldPartが見つかりません")
        end
        local holdResult = Workspace[playerName .. "SpawnedInToys"].InstrumentWoodwindOcarina.HoldPart.HoldItemRemoteFunction:InvokeServer(
            Workspace[playerName .. "SpawnedInToys"].InstrumentWoodwindOcarina,
            Workspace[playerName])
        if not holdResult then
            humanoid.WalkSpeed = 16
            error("オカリナを持つことに失敗しました")
        end
        task.wait(0.2)
        local dropResult = Workspace[playerName .. "SpawnedInToys"].InstrumentWoodwindOcarina.HoldPart.DropItemRemoteFunction:InvokeServer(
            Workspace[playerName .. "SpawnedInToys"].InstrumentWoodwindOcarina,
            CFrame.new(304.06, 25.77, 488.54),
            Vector3.new(0, 70.48600006103516, 0))
        if not dropResult then
            humanoid.WalkSpeed = 16
            error("オカリナを落とすことに失敗しました")
        end
        task.wait(0.1)
        if not Workspace:FindFirstChild(playerName .. "SpawnedInToys") then
            humanoid.WalkSpeed = 16
            error("トイフォルダが消失しました")
        end
        if not Workspace[playerName .. "SpawnedInToys"]:FindFirstChild("InstrumentWoodwindOcarina") then
            humanoid.WalkSpeed = 16
            error("オカリナが既に消失しています")
        end
        ReplicatedStorage.MenuToys.DestroyToy:FireServer(Workspace[playerName .. "SpawnedInToys"].InstrumentWoodwindOcarina)
        task.wait(1.5)
        local campfireSpawnResult = ReplicatedStorage.MenuToys.SpawnToyRemoteFunction:InvokeServer("Campfire",
            CFrame.new(257.638672, -5.57392979, 450.103638, -0.950906992, -0.171067372, 0.257899135, 0, 0.833338678, 0.552762806, -0.309477001, 0.525626004, -0.79242748),
            Vector3.new(0, 161.9720001220703, 0))
        if not campfireSpawnResult then
            humanoid.WalkSpeed = 16
            error("Campfireのスポーンに失敗しました")
        end
        task.wait(1)
        if not Workspace:FindFirstChild(playerName .. "SpawnedInToys") then
            humanoid.WalkSpeed = 16
            error("トイフォルダが消失しました")
        end
        if not Workspace[playerName .. "SpawnedInToys"]:FindFirstChild("Campfire") then
            humanoid.WalkSpeed = 16
            error("Campfireが見つかりません")
        end
        humanoid.WalkSpeed = 16
        Notify("✅ 成功", "Barrier破壊に成功しました！", 3)
        return true
    end)
    if not success then
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid.WalkSpeed = 16 end
        Notify("❌ 失敗", tostring(err), 3)
        return false
    end
    autoBarrierNoTPRunning = false
    return true
end

barrierGroup:AddButton({
    Text = "Break Barrier (1回実行)",
    Func = function() executeBarrierBreak() end
})

barrierGroup:AddToggle("AutoBarrierBreak", {
    Text = "🔄 Auto Barrier破壊",
    Default = false,
    Callback = function(Value)
        autoBarrierRunning = Value
        if Value then
            Notify("▶️ Start", "Auto executing until success", 2)
            task.spawn(function()
                while autoBarrierRunning do
                    local result = executeBarrierBreak()
                    if result then
                        if Toggles.AutoBarrierBreak then Toggles.AutoBarrierBreak:SetValue(false) end
                        break
                    end
                    task.wait(1)
                end
            end)
        else
            Notify("⏸️ Stop", "Auto execution stopped", 2)
        end
    end
})

barrierGroup:AddLabel("家の外で実行してください / 成功したら自動OFF")

barrierGroup:AddButton({
    Text = "Break Barrier NoTP (1回実行)",
    Func = function() executeBarrierBreakNoTP() end
})

barrierGroup:AddToggle("AutoBarrierBreakNoTP", {
    Text = "🔄 Auto Barrier破壊 NoTP (Beta)",
    Default = false,
    Callback = function(Value)
        autoBarrierNoTPRunning = Value
        if Value then
            Notify("▶️ 開始", "成功するまで自動実行します", 2)
            task.spawn(function()
                while autoBarrierNoTPRunning do
                    local result = executeBarrierBreakNoTP()
                    if result then
                        if Toggles.AutoBarrierBreakNoTP then Toggles.AutoBarrierBreakNoTP:SetValue(false) end
                        break
                    end
                    task.wait(1.5)
                end
            end)
        else
            Notify("⏸️ 停止", "Auto実行を停止しました", 2)
        end
    end
})

barrierGroup:AddLabel("NoTP版はベータ / 成功率低めの場合あり")

-- =====================================================
-- ラグタブ
-- =====================================================
do
    local lag = Tabs.Lag:AddLeftGroupbox("いちごハブ ラグ")
    lag:AddButton({ Text = "ラグ開始（強）", Func = function() StartLineLag(20) Notify("ラグ", "強") end })
    lag:AddButton({ Text = "ラグ開始（中）", Func = function() StartLineLag(10) Notify("ラグ", "中") end })
    lag:AddButton({
        Text = "20秒だけラグ",
        Func = function()
            StartLineLag(15)
            Notify("ラグ", "20秒実行")
            task.delay(20, function() if lineLagEnabled then StopLineLag() Notify("ラグ", "停止") end end)
        end
    })
    lag:AddButton({ Text = "ラグ停止", Func = function() StopLineLag() Notify("ラグ", "停止") end })

    local lagI = Tabs.Lag:AddRightGroupbox("いちごハブ Lags")
    lagI:AddSlider("LPS", { Text = "Lines Per Second", Default = 100, Min = 1, Max = 1000, Rounding = 0, Callback = function(v) lps = v end })
    lagI:AddToggle("LineLag", {
        Text = "Line Lag", Default = false,
        Callback = function(v)
            linelag = v
            if not v then return end
            local ge = GrabEvents or ReplicatedStorage:FindFirstChild("GrabEvents")
            local CreateLine = ge and ge:FindFirstChild("CreateGrabLine")
            if not CreateLine then
                Notify("ラグ", "CreateGrabLineがありません", 3)
                linelag = false
                if Toggles.LineLag then Toggles.LineLag:SetValue(false) end
                return
            end
            task.spawn(function()
                while linelag do
                    local spawnLoc = Workspace:FindFirstChild("SpawnLocation") or Workspace:FindFirstChild("Spawn") or GetMyRoot()
                    if spawnLoc then
                        local count = tonumber(lps) or 100
                        for _ = 1, count do
                            if not linelag then break end
                            pcall(function() CreateLine:FireServer(spawnLoc, CFrame.new(0, 500000, 0)) end)
                        end
                    end
                    task.wait(1)
                end
            end)
        end
    })
    lagI:AddSlider("PacketLagStrength", { Text = "Packet Strength", Default = 500, Min = 0, Max = 20000, Rounding = 1, Callback = function(Value) packetLagStrength = Value end })
    lagI:AddToggle("PacketLagToggle", {
        Text = "Packet Lag", Default = false,
        Callback = function(Value)
            packetLagActive = Value
            if Value then
                packetLagTask = task.spawn(function()
                    local GE = ReplicatedStorage:FindFirstChild("GrabEvents") or ReplicatedStorage:WaitForChild("GrabEvents", 5)
                    if not GE then
                        Notify("ラグ", "GrabEventsがありません", 3)
                        packetLagActive = false
                        if Toggles.PacketLagToggle then Toggles.PacketLagToggle:SetValue(false) end
                        return
                    end
                    local Extend = GE:FindFirstChild("ExtendGrabLine") or GE:WaitForChild("ExtendGrabLine", 5)
                    if not Extend then
                        Notify("ラグ", "ExtendGrabLineがありません", 3)
                        packetLagActive = false
                        if Toggles.PacketLagToggle then Toggles.PacketLagToggle:SetValue(false) end
                        return
                    end
                    -- 制限付きパケット（フラッシュ・検知を抑える）
                    local payload = string.rep("X", SafeMode and 8000 or 20000)
                    while packetLagActive do
                        local strength = (Options.PacketLagStrength and Options.PacketLagStrength.Value) or packetLagStrength or 500
                        strength = math.clamp(tonumber(strength) or 500, 1, SafeMode and 5000 or 20000)
                        local reps = math.clamp(math.floor(strength / 200), 1, SafeMode and 15 or 80)
                        for _ = 1, reps do
                            if not packetLagActive then break end
                            if RemoteAllowed(2) then
                                pcall(function() Extend:FireServer(payload) end)
                            else
                                task.wait(0.05)
                            end
                        end
                        task.wait(SafeMode and 0.35 or 0.15)
                    end
                end)
            else
                if packetLagTask then pcall(task.cancel, packetLagTask) packetLagTask = nil end
            end
        end
    })
end

-- =====================================================
-- プレイヤータブ
-- =====================================================
do
    local left = Tabs.Player:AddLeftGroupbox("移動・視点")
    local speedOn = false
    local speedVal = 0.2
    left:AddToggle("Speed", { Text = "Speed Hack", Default = false, Callback = function(v) speedOn = v end })
    left:AddSlider("SpeedSlider", { Text = "Multiplier", Default = 0.2, Min = 0.1, Max = 3, Rounding = 2, Callback = function(v) speedVal = v end })
    left:AddToggle("ThirdPerson", {
        Text = "三人称視点", Default = false,
        Callback = function(s)
            if s then
                LocalPlayer.CameraMode = Enum.CameraMode.Classic
                LocalPlayer.CameraMaxZoomDistance = 100
                LocalPlayer.CameraMinZoomDistance = 0.5
            else
                LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
                LocalPlayer.CameraMaxZoomDistance = 0.5
                LocalPlayer.CameraMinZoomDistance = 0.5
            end
        end
    })
    RunService.Heartbeat:Connect(function()
        if speedOn then
            local hum = GetMyHum()
            local root = GetMyRoot()
            if hum and root then
                root.CFrame = root.CFrame + hum.MoveDirection * speedVal
            end
        end
    end)
    local global = Tabs.Player:AddRightGroupbox("Global Settings")
    global:AddToggle("GlobalWhitelistToggle", {
        Text = "Whitelist Friends", Default = false,
        Callback = function(Value) globalFriendWhitelist = Value Notify("Friend Whitelist", Value and "Enabled" or "Disabled") end
    })
end

-- =====================================================
-- Defenceタブ
-- =====================================================
local DefenceGroup = Tabs.Defence:AddLeftGroupbox('Protection', 'shield')
local DefenceRight = Tabs.Defence:AddRightGroupbox('Counter', 'zap')

local TP_CE       = ReplicatedStorage:WaitForChild("CharacterEvents", 15)
local TP_GrabEv   = ReplicatedStorage:WaitForChild("GrabEvents", 15)
local TP_PlayerEv = ReplicatedStorage:WaitForChild("PlayerEvents", 15)
local TP_Menu     = ReplicatedStorage:WaitForChild("MenuToys", 15)
local TP_Struggle = TP_CE:WaitForChild("Struggle", 10)
local TP_RagdollR = TP_CE:WaitForChild("RagdollRemote", 10)
local TP_SetNet   = TP_GrabEv:WaitForChild("SetNetworkOwner", 10)
local TP_CreateLn = TP_GrabEv:FindFirstChild("CreateGrabLine")
local TP_DestroyLn= TP_GrabEv:FindFirstChild("DestroyGrabLine")
local TP_StickyEv = TP_PlayerEv and TP_PlayerEv:WaitForChild("StickyPartEvent", 10)
local TP_SpawnToy = TP_Menu:WaitForChild("SpawnToyRemoteFunction", 10)
local TP_DestroyT = TP_Menu:FindFirstChild("DestroyToy")
local TP_IsHeld   = LocalPlayer:FindFirstChild("IsHeld")
local TP_CanSpawn = LocalPlayer:FindFirstChild("CanSpawnToy")
local function SafePlayerScript(name)
    local ok, ps = pcall(function() return LocalPlayer:FindFirstChild("PlayerScripts") or LocalPlayer:WaitForChild("PlayerScripts", 3) end)
    if not ok or not ps then return nil end
    return ps:FindFirstChild(name)
end
local TP_AntiLineLag  = SafePlayerScript("CharacterAndBeamMove")
local TP_AntiShuriLag = SafePlayerScript("StickyPartsTouchDetection")
-- 遅延で再取得（読み込み遅い環境対策）
task.spawn(function()
    task.wait(2)
    TP_AntiLineLag  = TP_AntiLineLag  or SafePlayerScript("CharacterAndBeamMove")
    TP_AntiShuriLag = TP_AntiShuriLag or SafePlayerScript("StickyPartsTouchDetection")
end)

local function TP_getHRP() local c = LocalPlayer.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function TP_getFolder() return Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys") end
local function TP_sno(part) if TP_SetNet and part then pcall(function() TP_SetNet:FireServer(part, part.CFrame) end) end end
local function TP_owner(part) return part and part:FindFirstChild("PartOwner") and part.PartOwner.Value == LocalPlayer.Name end

local TP = {
    AntiGrab = false, AntiRagdoll = false, AntiGrabRG = false, AntiSit = false, AntiBurn = false, AntiExplosion = false, AntiBanana = false, AntiPaint = false, AntiInput = false, AntiLag = false, AntiSitTask = nil, AntiBurnConn = nil, AntiExpConn = nil, AntiBananaConn = nil, AntiGrabRGProc = false, Antbananadest = false, paintPartsBackup = {}, paintConnections = {}, originalVoidHeight = nil, antiGrabConn = nil, antiRagConn = nil, antiLagConn = nil, antiStickyConn = nil, antiLagPlayerConn = nil, antiLagLoop = nil, counterMode = "Fling", counterOn = false, counterTask = nil
}

DefenceGroup:AddToggle("TP_AntiGrab", {
    Text = "Anti-Grab (BEST)", Default = true,
    Callback = function(Value)
        TP.AntiGrab = Value; if TP.antiGrabConn then TP.antiGrabConn:Disconnect(); TP.antiGrabConn = nil end
        if Value then
            TP.antiGrabConn = RunService.Heartbeat:Connect(function()
                local char = LocalPlayer.Character; local hrp = char and char:FindFirstChild("HumanoidRootPart"); local hum = char and char:FindFirstChild("Humanoid"); local head = char and char:FindFirstChild("Head")
                if hrp and hum and head then
                    local isHeld = TP_IsHeld and TP_IsHeld.Value; local headOwner = head:FindFirstChild("PartOwner")
                    if isHeld or headOwner ~= nil or hrp.ReceiveAge ~= 0 then
                        hrp.Anchored = true; hrp.AssemblyLinearVelocity = Vector3.zero; hrp.AssemblyAngularVelocity = Vector3.zero
                        if TP_IsHeld then pcall(function() TP_IsHeld.Value = false end) end
                        task.spawn(function() for i = 1, 5 do pcall(function() TP_Struggle:FireServer(LocalPlayer) end); task.wait(0.01) end end)
                        if hum.PlatformStand then hum.PlatformStand = false end
                        local ragdolled = hum:FindFirstChild("Ragdolled"); if ragdolled and ragdolled.Value then pcall(function() TP_RagdollR:FireServer(hrp, 0) end) end
                        for _, v in pairs(char:GetDescendants()) do if v:IsA("Weld") or v:IsA("WeldConstraint") or v:IsA("RigidConstraint") or v:IsA("Motor6D") then if v.Name ~= "RootJoint" and v.Name ~= "Neck" and v.Name ~= "Right Shoulder" and v.Name ~= "Left Shoulder" and v.Name ~= "Right Hip" and v.Name ~= "Left Hip" then pcall(function() v:Destroy() end) end end end
                        if headOwner then pcall(function() headOwner:Destroy() end) end
                        for _, v in pairs(hrp:GetChildren()) do if v.Name == "PartOwner" then pcall(function() v:Destroy() end) end end
                        hum.AutoRotate = true; if hrp:FindFirstChild("RootJoint") then hrp.RootJoint.Enabled = true end
                        task.wait(0.1); hrp.Anchored = false
                    end
                end
            end)
        end
    end,
})
DefenceGroup:AddToggle("TP_AntiRagdoll", {
    Text = "Anti-Ragdoll", Default = true,
    Callback = function(Value)
        TP.AntiRagdoll = Value; if TP.antiRagConn then TP.antiRagConn:Disconnect(); TP.antiRagConn = nil end
        if Value then
            TP.antiRagConn = RunService.Heartbeat:Connect(function()
                local char = LocalPlayer.Character; local hrp = char and char:FindFirstChild("HumanoidRootPart"); local hum = char and char:FindFirstChild("Humanoid")
                if hrp and hum then if hum.PlatformStand then hum.PlatformStand = false end; if hum.Sit and not hum.SeatPart then hum.Sit = false end; local rd = hum:FindFirstChild("Ragdolled"); if rd and rd.Value then pcall(function() TP_RagdollR:FireServer(hrp, 0) end) end end
            end)
        end
    end,
})
DefenceGroup:AddToggle("TP_AntiLag", {
    Text = "Anti-Lag (ULTRA)", Default = true,
    Callback = function(Value)
        TP.AntiLag = Value; if TP_AntiLineLag then TP_AntiLineLag.Enabled = not Value end; if TP_AntiShuriLag then TP_AntiShuriLag.Enabled = not Value end
        if Value then
            if TP.antiLagConn then TP.antiLagConn:Disconnect(); TP.antiLagConn = nil end
            if TP.antiLagPlayerConn then TP.antiLagPlayerConn:Disconnect(); TP.antiLagPlayerConn = nil end
            if TP.antiLagLoop then task.cancel(TP.antiLagLoop); TP.antiLagLoop = nil end
            local antiLagRadius = 80
            TP.antiLagConn = workspace.DescendantAdded:Connect(function(child) pcall(function()
                if child:IsA("Highlight") or child:IsA("SelectionBox") or child:IsA("BillboardGui") or child:IsA("SurfaceGui") then task.defer(function() if child and child.Parent then child:Destroy() end end); return end
                local myRoot = TP_getHRP(); if not myRoot then return end
                local pos = nil; if child:IsA("BasePart") then pos = child.Position elseif child.Parent and child.Parent:IsA("BasePart") then pos = child.Parent.Position end
                if pos and (pos - myRoot.Position).Magnitude > antiLagRadius then
                    if child:IsA("Beam") or child:IsA("Trail") then task.defer(function() if child and child.Parent then child:Destroy() end end)
                    elseif child:IsA("ParticleEmitter") or child:IsA("Fire") or child:IsA("Smoke") or child:IsA("Sparkles") or child:IsA("Explosion") then task.defer(function() if child and child.Parent then child.Enabled = false; child:Destroy() end end)
                    elseif child:IsA("Sound") then task.defer(function() if child and child.Parent then child:Stop(); child:Destroy() end end)
                    elseif child:IsA("Texture") or child:IsA("Decal") then task.defer(function() if child and child.Parent then child:Destroy() end end) end
                end
            end) end)
            task.spawn(function()
                local myRoot = TP_getHRP(); if not myRoot then return end
                for _, obj in ipairs(workspace:GetDescendants()) do pcall(function()
                    if obj:IsA("Highlight") or obj:IsA("SelectionBox") or obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then obj:Destroy(); return end
                    local pos = nil; if obj:IsA("BasePart") then pos = obj.Position elseif obj.Parent and obj.Parent:IsA("BasePart") then pos = obj.Parent.Position end
                    if pos and (pos - myRoot.Position).Magnitude > antiLagRadius then
                        if obj:IsA("Beam") or obj:IsA("Trail") then obj:Destroy()
                        elseif obj:IsA("ParticleEmitter") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then obj.Enabled = false; obj:Destroy()
                        elseif obj:IsA("Sound") then obj:Stop(); obj:Destroy()
                        elseif obj:IsA("Texture") or obj:IsA("Decal") then obj:Destroy() end
                    end
                end) end
            end)
            local function simplifyCharacter(char)
                if not char or char == LocalPlayer.Character then return end
                local myRoot = TP_getHRP(); if not myRoot then return end
                local charRoot = char:FindFirstChild("HumanoidRootPart"); if not charRoot then return end
                if (charRoot.Position - myRoot.Position).Magnitude > antiLagRadius then
                    for _, p in pairs(char:GetDescendants()) do pcall(function()
                        if p:IsA("ParticleEmitter") or p:IsA("Fire") or p:IsA("Smoke") then p.Enabled = false; p:Destroy()
                        elseif p:IsA("Sound") then p:Stop(); p:Destroy()
                        elseif p:IsA("Texture") or p:IsA("Decal") then p:Destroy()
                        elseif p:IsA("BasePart") and p:IsA("MeshPart") then p.RenderFidelity = Enum.RenderFidelity.Automatic end
                    end) end
                end
            end
            for _, plr in ipairs(Players:GetPlayers()) do if plr ~= LocalPlayer then simplifyCharacter(plr.Character); plr.CharacterAdded:Connect(simplifyCharacter) end end
            TP.antiLagPlayerConn = Players.PlayerAdded:Connect(function(plr) plr.CharacterAdded:Connect(simplifyCharacter) end)
            TP.antiLagLoop = task.spawn(function()
                while TP.AntiLag do
                    local myRoot = TP_getHRP()
                    if myRoot then
                        for _, obj in ipairs(workspace:GetChildren()) do pcall(function()
                            if obj.Name:match("^Plot%d+$") or obj.Name:match("SpawnedInToys$") then
                                if obj:IsA("Model") or obj:IsA("Folder") then
                                    local pivot = obj:GetPivot().Position
                                    if (pivot - myRoot.Position).Magnitude > antiLagRadius then
                                        for _, p in pairs(obj:GetDescendants()) do
                                            if p:IsA("BasePart") then p.Transparency = 1; p.CanCollide = false; p.CanTouch = false; p.CanQuery = false; p.CastShadow = false
                                            elseif p:IsA("ParticleEmitter") or p:IsA("Fire") or p:IsA("Smoke") then p.Enabled = false; p:Destroy()
                                            elseif p:IsA("Sound") then p:Stop(); p:Destroy()
                                            elseif p:IsA("Decal") or p:IsA("Texture") then p:Destroy() end
                                        end
                                    end
                                end
                            end
                        end) end
                    end
                    task.wait(0.5)
                end
            end)
            Library:Notify("Anti-Lag (ULTRA+): ON", 2)
        else
            if TP.antiLagConn then TP.antiLagConn:Disconnect(); TP.antiLagConn = nil end
            if TP.antiLagPlayerConn then TP.antiLagPlayerConn:Disconnect(); TP.antiLagPlayerConn = nil end
            if TP.antiLagLoop then task.cancel(TP.antiLagLoop); TP.antiLagLoop = nil end
            Library:Notify("Anti-Lag (ULTRA+): OFF", 2)
        end
    end,
})
DefenceGroup:AddToggle("TP_AntiSticky", {
    Text = "Anti-Sticky (Loop Kill対策)", Default = false,
    Callback = function(Value)
        if Value then
            if TP_AntiShuriLag then TP_AntiShuriLag.Enabled = false end
            if TP.antiStickyConn then TP.antiStickyConn:Disconnect() end
            TP.antiStickyConn = RunService.Heartbeat:Connect(function()
                local char = LocalPlayer.Character; local head = char and char:FindFirstChild("Head"); if not head then return end
                local partOwner = head:FindFirstChild("PartOwner"); local stickyWeld = head:FindFirstChild("StickyWeld")
                if partOwner or stickyWeld then
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if obj.Name == "ToolPencil" and (obj:FindFirstChild("StickyPart") or obj:FindFirstChild("SoundPart")) then
                            local stickyPart = obj:FindFirstChild("StickyPart") or obj:FindFirstChild("SoundPart"); local weld = stickyPart and stickyPart:FindFirstChild("StickyWeld")
                            if weld and weld.Part1 == head then pcall(function() if ReplicatedStorage.MenuToys and ReplicatedStorage.MenuToys:FindFirstChild("DestroyToy") then ReplicatedStorage.MenuToys.DestroyToy:FireServer(obj) end; obj:Destroy() end) end
                        end
                    end
                    if partOwner then pcall(function() partOwner:Destroy() end) end; if stickyWeld then pcall(function() stickyWeld:Destroy() end) end
                    local hum = char:FindFirstChildOfClass("Humanoid"); if hum then hum.PlatformStand = false; local rd = hum:FindFirstChild("Ragdolled"); if rd then rd.Value = false end end
                end
            end)
        else if TP.antiStickyConn then TP.antiStickyConn:Disconnect(); TP.antiStickyConn = nil end; if TP_AntiShuriLag then TP_AntiShuriLag.Enabled = true end end
    end,
})
DefenceGroup:AddToggle("TP_AntiVoid", {
    Text = "Anti-Void", Default = false,
    Callback = function(Value)
        if Value then if not TP.originalVoidHeight then TP.originalVoidHeight = Workspace.FallenPartsDestroyHeight end; Workspace.FallenPartsDestroyHeight = -1e95
        else Workspace.FallenPartsDestroyHeight = TP.originalVoidHeight or -100 end
    end,
})
DefenceGroup:AddToggle("TP_AntiSit", {
    Text = "Anti-Sit", Default = false,
    Callback = function(Value)
        TP.AntiSit = Value; if TP.AntiSitTask then task.cancel(TP.AntiSitTask); TP.AntiSitTask = nil end
        if Value then TP.AntiSitTask = task.spawn(function()
            while TP.AntiSit do
                local char = LocalPlayer.Character; local hum = char and char:FindFirstChild("Humanoid"); local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hum and hrp and hum.Health > 0 then hum.Sit = false; hum:ChangeState(Enum.HumanoidStateType.Running); local cam = workspace.CurrentCamera; if cam then local v = cam.CFrame.LookVector; hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + Vector3.new(v.X, 0, v.Z)) end end
                task.wait()
            end
        end) end
    end,
})
DefenceGroup:AddToggle("TP_AntiBurn", {
    Text = "Anti-Burn", Default = false,
    Callback = function(Value)
        TP.AntiBurn = Value; if TP.AntiBurnConn then TP.AntiBurnConn:Disconnect(); TP.AntiBurnConn = nil end
        if Value then TP.AntiBurnConn = RunService.Heartbeat:Connect(function()
            local char = LocalPlayer.Character; local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then for _, v in pairs(hrp:GetChildren()) do if v.Name == "FireLight" or v.Name == "FireParticleEmitter" or v.Name == "Fire" then v:Destroy() end end end
        end) end
    end,
})
DefenceGroup:AddToggle("TP_AntiExplosion", {
    Text = "Anti-Explosion", Default = false,
    Callback = function(Value)
        TP.AntiExplosion = Value; if TP.AntiExpConn then TP.AntiExpConn:Disconnect(); TP.AntiExpConn = nil end
        if Value then TP.AntiExpConn = workspace.ChildAdded:Connect(function(model)
            local char = LocalPlayer.Character; local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if model.Name == "Part" and hrp and (model.Position - hrp.Position).Magnitude <= 20 then hrp.Anchored = true; task.wait(0.01); hrp.Anchored = false end
        end) end
    end,
})
DefenceGroup:AddToggle("TP_AntiBanana", {
    Text = "Anti-Banana (Destroy)", Default = false,
    Callback = function(Value)
        TP.Antbananadest = Value; if TP.AntiBananaConn then TP.AntiBananaConn:Disconnect(); TP.AntiBananaConn = nil end
        if not Value then return end
        local function handle(banana)
            if not banana then return end
            local hp = banana:FindFirstChild("HoldPart"); if not hp then return end
            local hRF = hp:FindFirstChild("HoldItemRemoteFunction"); local dRF = hp:FindFirstChild("DropItemRemoteFunction"); local rc = hp:FindFirstChild("RigidConstraint")
            if rc and rc:FindFirstChild("Attachment1") then repeat task.wait() until not rc:FindFirstChild("Attachment1") or not banana.Parent end
            if dRF and hRF then repeat task.wait(); task.spawn(function() pcall(function() hRF:InvokeServer(banana, LocalPlayer.Character) end) end); pcall(function() dRF:InvokeServer(banana, CFrame.new(0, -51000, 0), Vector3.zero) end) until not banana.Parent or not TP.Antbananadest end
        end
        for _, p in pairs(Players:GetPlayers()) do
            local ct = workspace:FindFirstChild(p.Name .. "SpawnedInToys")
            if ct then
                for _, c in pairs(ct:GetChildren()) do if c.Name == "FoodBanana" then task.spawn(handle, c) end end
                TP.AntiBananaConn = ct.ChildAdded:Connect(function(nc) if nc.Name == "FoodBanana" then task.wait(0.1) task.spawn(handle, nc) end end)
            end
        end
    end,
})
DefenceGroup:AddToggle("TP_AntiPaint", {
    Text = "Anti-Paint", Default = false,
    Callback = function(Value)
        if Value then
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and obj.Name == "PaintPlayerPart" then local clone = obj:Clone(); clone.Archivable = true; TP.paintPartsBackup[obj:GetDebugId()] = { clone = clone, parent = obj.Parent }; obj:Destroy() end
            end
            table.insert(TP.paintConnections, workspace.DescendantAdded:Connect(function(obj)
                if obj:IsA("BasePart") and obj.Name == "PaintPlayerPart" then task.defer(function() if obj and obj.Parent then local clone = obj:Clone(); clone.Archivable = true; TP.paintPartsBackup[obj:GetDebugId()] = { clone = clone, parent = obj.Parent }; obj:Destroy() end end) end
            end))
        else
            for _, conn in ipairs(TP.paintConnections) do if conn.Connected then conn:Disconnect() end end
            TP.paintConnections = {}
            for id, data in pairs(TP.paintPartsBackup) do if data.clone and data.parent then data.clone.Parent = data.parent end end
            TP.paintPartsBackup = {}
        end
    end,
})

local ADLActive = false
local ADLConn = nil
local function PerformADL(char)
    if not char then return end
    task.wait(0.5)
    if not ADLActive then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid") or char:FindFirstChild("Humanoid")
    local torso = char:FindFirstChild("Torso")
    local ll = char:FindFirstChild("Left Leg")
    local rl = char:FindFirstChild("Right Leg")
    if hrp and hum and torso and ll and rl then
        local void = Workspace.FallenPartsDestroyHeight
        local pos = torso.CFrame
        pcall(function() Workspace.FallenPartsDestroyHeight = -100 end)
        local rr = ReplicatedStorage:FindFirstChild("CharacterEvents")
        rr = rr and rr:FindFirstChild("RagdollRemote")
        if rr then pcall(function() rr:FireServer(hrp, 2) end)
        elseif TP_RagdollR then pcall(function() TP_RagdollR:FireServer(hrp, 2) end) end
        task.wait(0.5)
        if ll and rl then
            pcall(function() rl.CFrame = CFrame.new(0, -10000, 0) end)
            pcall(function() ll.CFrame = CFrame.new(0, -10000, 0) end)
        end
        task.wait(0.3)
        if torso then pcall(function() torso.CFrame = CFrame.new(0, -9970, 0) end) end
        task.wait(0.5)
        if torso then pcall(function() torso.CFrame = pos end) end
        task.wait(0.5)
        pcall(function() Workspace.FallenPartsDestroyHeight = void end)
        -- tanpopo: 足削除後のHipHeight維持
        task.spawn(function()
            while ADLActive and char.Parent and hum.Health > 0 and not char:FindFirstChild("Left Leg") and not char:FindFirstChild("Right Leg") do
                pcall(function()
                    local gui = LocalPlayer:FindFirstChild("PlayerGui")
                    local c = gui and gui:FindFirstChild("ControlsGui")
                    if c and c:FindFirstChild("PCFrame") and c.PCFrame:FindFirstChild("Stand") then
                        hum.HipHeight = (c.PCFrame.Stand.Visible == false) and 2 or 0
                    end
                end)
                task.wait()
            end
        end)
    end
end
DefenceGroup:AddToggle("TP_AutoDeleteLegs", {
    Text = "オートレッグデリート",
    Default = false,
    Callback = function(Value)
        ADLActive = Value
        if Value then
            task.spawn(function() PerformADL(LocalPlayer.Character) end)
            if not ADLConn then
                ADLConn = LocalPlayer.CharacterAdded:Connect(function(nc)
                    if ADLActive then task.spawn(function() PerformADL(nc) end) end
                end)
            end
        else
            if ADLConn then ADLConn:Disconnect(); ADLConn = nil end
        end
    end,
})

local ItemMap = {
    ["ピザ（チーズ）"]="FoodPizzaCheese", ["ピザ（ペパロニ）"]="FoodPizzaPepperoni", ["コーラ"]="FoodSodaCan", ["ハンバーガー"]="FoodHamburger", ["ホットドッグ"]="FoodHotdog",
    ["マヨネーズ"]="FoodMayonnaise", ["肉"]="FoodMeatStick", ["毒キノコ"]="FoodMushroomPoison", ["ピンクケーキ"]="FoodCakePink", ["ココナッツ"]="FoodCoconut", ["目玉焼き"]="FoodDippyEgg",
    ["ドーナツ"]="FoodDonut", ["フライドポテト"]="FoodFrenchFries", ["バナナ"]="FoodBanana", ["パン"]="FoodBread", ["ブロッコリー"]="FoodBroccoli",
    ["マグカップ（茶）"]="CupMugBrown", ["マグカップ（白）"]="CupMugWhite", ["うんち"]="PoopPile", ["キラキラうんち"]="PoopPileSparkle",
    ["キーボード"]="InstrumentPianoKeyboard", ["メロディカ"]="InstrumentPianoMelodica", ["マイク"]="InstrumentVoiceMicrophone", ["鳥の笛"]="InstrumentWoodwindOcarina",
    ["サックス"]="InstrumentWoodwindSaxophone", ["アコースティックギター"]="InstrumentGuitarAcoustic", ["バンジョー"]="InstrumentGuitarBanjo", ["ライア"]="InstrumentGuitarLyre",
    ["パイナップルギター"]="InstrumentGuitarUkulele", ["バイオリン"]="InstrumentGuitarViolin", ["ラッパ"]="InstrumentBrassBugle", ["トランペット"]="InstrumentBrassTrumpet",
    ["笛"]="InstrumentBrassVuvuzela", ["2個の太鼓"]="InstrumentDrumBongos", ["スネアドラム"]="InstrumentDrumSnare",
}
local DisplayItems = {}
for k, _ in pairs(ItemMap) do table.insert(DisplayItems, k) end
table.sort(DisplayItems)
local AIConfig = { targetToy="InstrumentGuitarBanjo", targetToyJP="バンジョー", loopActive=false, task=nil, respawnConn=nil }
local function AI_destroyExisting()
    local f = workspace:FindFirstChild(LocalPlayer.Name.."SpawnedInToys"); if not f then return end
    for _, v in pairs(f:GetChildren()) do if v.Name == AIConfig.targetToy and TP_DestroyT then pcall(function() TP_DestroyT:FireServer(v) end) end end
end
local function AI_start()
    if AIConfig.loopActive then return end
    AI_destroyExisting(); AIConfig.loopActive = true
    AIConfig.task = task.spawn(function()
        while AIConfig.loopActive do
            local char = LocalPlayer.Character; local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then RunService.Heartbeat:Wait() continue end
            if TP_CanSpawn and not TP_CanSpawn.Value then RunService.Heartbeat:Wait() continue end
            local f = workspace:FindFirstChild(LocalPlayer.Name.."SpawnedInToys"); local toy = f and f:FindFirstChild(AIConfig.targetToy)
            if not toy then pcall(function() TP_SpawnToy:InvokeServer(AIConfig.targetToy, hrp.CFrame * CFrame.new(0, 14, 20), Vector3.new(0,90,0)) end); task.wait(0.05)
            else
                local head = char:FindFirstChild("Head"); local hp = toy:FindFirstChild("HoldPart")
                if hp and head then
                    local hR = hp:FindFirstChild("HoldItemRemoteFunction"); local dR = hp:FindFirstChild("DropItemRemoteFunction")
                    if hR and dR then local dp = head.CFrame * CFrame.new(0, 3, 0); task.spawn(function() pcall(function() hR:InvokeServer(toy, char); dR:InvokeServer(toy, dp, dp) end) end) end
                end
            end
            RunService.Heartbeat:Wait()
        end
    end)
    AIConfig.respawnConn = LocalPlayer.CharacterAdded:Connect(function() if not AIConfig.loopActive then return end; task.wait(0.5); AIConfig.loopActive = false; if AIConfig.task then task.cancel(AIConfig.task); AIConfig.task = nil end; AI_destroyExisting(); task.wait(0.2); AI_start() end)
end
local function AI_stop()
    AIConfig.loopActive = false; if AIConfig.task then task.cancel(AIConfig.task); AIConfig.task = nil end
    if AIConfig.respawnConn then AIConfig.respawnConn:Disconnect(); AIConfig.respawnConn = nil end; AI_destroyExisting()
end
DefenceGroup:AddDropdown("TP_AntiInputItem", { Text = "Anti-Input アイテム", Values = DisplayItems, Default = "バンジョー", Callback = function(Value) AIConfig.targetToyJP = Value; AIConfig.targetToy = ItemMap[Value] or "InstrumentGuitarBanjo"; if AIConfig.loopActive then AI_stop(); task.wait(0.1); AI_start() end end })
DefenceGroup:AddToggle("TP_AntiInput", { Text = "Anti-Input", Default = false, Callback = function(Value) if Value then AI_start() else AI_stop() end end })

DefenceRight:AddDropdown("TP_CounterMode", { Text = "Counter Attack Mode", Values = {"Fling", "Kill", "Send to Heaven", "Kick", "Ragdoll", "Hell"}, Default = "Fling", Callback = function(v) TP.counterMode = v end })
local function pFling(a)
    if not a or not a.Character then return end; local r = a.Character:FindFirstChild("HumanoidRootPart"); if not r then return end
    pcall(function()
        if TP_SetNet then TP_SetNet:FireServer(r, r.CFrame) end; if TP_DestroyLn then TP_DestroyLn:FireServer(r) end
        local mr = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"); if not mr then return end
        local aw = (r.Position - mr.Position).Unit; aw = Vector3.new(aw.X, 0, aw.Z) * 90000
        local bv = Instance.new("BodyVelocity"); bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge); bv.Velocity = aw; bv.P = 12500; bv.Parent = r; Debris:AddItem(bv, 0.01)
    end)
end
local function pKill(a) if not a or not a.Character then return end; local hum = a.Character:FindFirstChildOfClass("Humanoid"); if hum then pcall(function() hum.BreakJointsOnDeath = false; hum:ChangeState(Enum.HumanoidStateType.Dead) end) end end
local function pHeaven(a)
    if not a or not a.Character then return end; local r = a.Character:FindFirstChild("HumanoidRootPart"); if not r then return end
    r.CFrame = CFrame.new(0, 200, 0); local bv = Instance.new("BodyVelocity"); bv.MaxForce = Vector3.new(0, math.huge, 0); bv.Velocity = Vector3.new(0, 200, 0); bv.Parent = r; Debris:AddItem(bv, 0.01)
end
local function pKick(a)
    if not a or not a.Character then return end; local r = a.Character:FindFirstChild("HumanoidRootPart"); if not r then return end
    r.CFrame = CFrame.new(0, 999999999999, 0); local bv = Instance.new("BodyVelocity"); bv.MaxForce = Vector3.new(0, math.huge, 0); bv.Velocity = Vector3.new(0, 99999999999999, 0); bv.Parent = r; Debris:AddItem(bv, 0.01)
end
local function pRagdoll(a) if not a or not a.Character then return end; local hum = a.Character:FindFirstChildOfClass("Humanoid"); local rd = hum and hum:FindFirstChild("Ragdolled"); if rd then rd.Value = true end end
local function pHell(a)
    if not a or not a.Character then return end; local r = a.Character:FindFirstChild("HumanoidRootPart"); if not r then return end
    local bv = Instance.new("BodyVelocity"); bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge); bv.Velocity = Vector3.new(0, -100000000, 0); bv.Parent = r; Debris:AddItem(bv, 0.01)
end
DefenceRight:AddToggle("TP_CounterAttack", { Text = "触るとキル（Counter Attacks）", Default = false, Callback = function(Value)
    TP.counterOn = Value; if TP.counterTask then task.cancel(TP.counterTask); TP.counterTask = nil end
    if Value then TP.counterTask = task.spawn(function()
        while TP.counterOn do
            local char = LocalPlayer.Character; local head = char and char:FindFirstChild("Head")
            if head then local owner = head:FindFirstChild("PartOwner"); if owner and owner:IsA("StringValue") then local attacker = Players:FindFirstChild(owner.Value)
                if attacker and attacker ~= LocalPlayer then
                    if TP.counterMode == "Fling" then pFling(attacker) elseif TP.counterMode == "Kill" then pKill(attacker) elseif TP.counterMode == "Send to Heaven" then pHeaven(attacker) elseif TP.counterMode == "Kick" then pKick(attacker) elseif TP.counterMode == "Ragdoll" then pRagdoll(attacker) elseif TP.counterMode == "Hell" then pHell(attacker) end
                end
            end end
            task.wait(0.05)
        end
    end) end
end })

-- Anti Kick
shurikenAntiKickActive = false


-- ===== アンチキック [ITEM] (tanpopo) =====
do
    local AntiKickItemActive = false
    local MyPCLD = nil
    local pcldConn = nil
    local SelectedToy = "SpookyCandle1"

    local function GetMagnitude(a, b)
        return (a.Position - b.Position).Magnitude
    end
    local function FWD(p, n, t)
        return p:FindFirstChild(n) or p:WaitForChild(n, t or 1)
    end
    local function CheckNetworkOwnerOnPart(Part)
        local po = Part:FindFirstChild("PartOwner")
        return po and po.Value == LocalPlayer.Name
    end
    local function sno(part)
        pcall(function()
            local ge = ReplicatedStorage:FindFirstChild("GrabEvents")
            local s = ge and ge:FindFirstChild("SetNetworkOwner")
            if s then s:FireServer(part, part.CFrame) end
        end)
    end
    local function CheckForHomeItem()
        local plotItems = Workspace:FindFirstChild("PlotItems")
        local plots = Workspace:FindFirstChild("Plots")
        if plots and plotItems then
            for i = 1, 8 do
                local Plot = plots:FindFirstChild("Plot" .. i)
                if Plot then
                    local sign = Plot:FindFirstChild("PlotSign")
                    local owners = sign and sign:FindFirstChild("ThisPlotsOwners")
                    if owners then
                        for _, v in pairs(owners:GetChildren()) do
                            if v.Value == LocalPlayer.Name then
                                return plotItems:FindFirstChild("Plot" .. i)
                            end
                        end
                    end
                end
            end
        end
        return nil
    end
    local function SpawnToyAntiKick(ToyName)
        local InPlot = LocalPlayer:FindFirstChild("InPlot")
        local InOwnedPlot = LocalPlayer:FindFirstChild("InOwnedPlot")
        local CanSpawnToy = LocalPlayer:FindFirstChild("CanSpawnToy")
        local inv = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
        if InPlot and InPlot.Value and InOwnedPlot and not InOwnedPlot.Value then
            pcall(function() InPlot:GetPropertyChangedSignal("Value"):Wait() end)
        end
        if CanSpawnToy and not CanSpawnToy.Value then
            pcall(function() CanSpawnToy:GetPropertyChangedSignal("Value"):Wait() end)
        end
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return nil end
        local SpawnCF = hrp.CFrame * CFrame.new(0, 14, 20)
        local Container = (InOwnedPlot and InOwnedPlot.Value) and CheckForHomeItem() or inv
        if not Container then return nil end
        local spawnedObject = nil
        local connection = Container.ChildAdded:Connect(function(child)
            if child.Name == ToyName then spawnedObject = child end
        end)
        task.spawn(function()
            pcall(function()
                local mt = ReplicatedStorage:FindFirstChild("MenuToys")
                local sr = mt and mt:FindFirstChild("SpawnToyRemoteFunction")
                if sr then sr:InvokeServer(ToyName, SpawnCF, Vector3.zero) end
            end)
        end)
        local start = tick()
        repeat task.wait() until spawnedObject or (tick() - start) > 2.5
        if connection then connection:Disconnect() end
        return spawnedObject
    end
    local function FindPCLD(hrp)
        if pcldConn then pcldConn:Disconnect() end
        MyPCLD = nil
        pcldConn = RunService.Heartbeat:Connect(function()
            if MyPCLD or not hrp or not hrp.Parent then
                if pcldConn then pcldConn:Disconnect() pcldConn = nil end
                return
            end
            for _, v in pairs(Workspace:GetChildren()) do
                if v.Name == "PlayerCharacterLocationDetector" and v:IsA("BasePart") then
                    if GetMagnitude(v, hrp) <= 2 then
                        MyPCLD = v
                        break
                    end
                end
            end
        end)
    end

    DefenceGroup:AddToggle("AntiKickItem", {
        Text = "アンチキック [ITEM]",
        Default = false,
        Callback = function(Val)
            AntiKickItemActive = Val
            if Val then
                task.spawn(function()
                    local Item, SoundPart
                    while AntiKickItemActive and task.wait() do
                        local char = LocalPlayer.Character
                        local hrp = char and char:FindFirstChild("HumanoidRootPart")
                        local hum = char and char:FindFirstChildOfClass("Humanoid")
                        local inPlot = LocalPlayer:FindFirstChild("InPlot")
                        local inv = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
                        local destroyToy = ReplicatedStorage:FindFirstChild("MenuToys")
                        destroyToy = destroyToy and destroyToy:FindFirstChild("DestroyToy")
                        if not hrp or not hum or hum.Health <= 0 or not inv then continue end
                        if inPlot and inPlot.Value then continue end
                        if not MyPCLD and not pcldConn then FindPCLD(hrp) end
                        Item = inv:FindFirstChild("AntiKickItem")
                        SoundPart = Item and Item:FindFirstChild("Hitbox")
                        if not Item or not SoundPart then
                            for _, v in pairs(inv:GetChildren()) do
                                if v.Name == "AntiKickItem" and destroyToy then
                                    pcall(function() destroyToy:FireServer(v) end)
                                end
                            end
                            Item = SpawnToyAntiKick(SelectedToy)
                            if not Item then continue end
                            SoundPart = Item and FWD(Item, "Hitbox", 0.5)
                            if SoundPart then sno(SoundPart) end
                            for _, v in pairs(Item:GetChildren()) do
                                if v:IsA("BasePart") then
                                    v.CanCollide = false
                                    v.Transparency = 0.8
                                    v.Color = Color3.fromRGB(0, 255, 255)
                                end
                            end
                            Item.Name = "AntiKickItem"
                        end
                        if SoundPart and not CheckNetworkOwnerOnPart(SoundPart) then sno(SoundPart) end
                        local targetPart = MyPCLD or hrp:FindFirstChild("FirePlayerPart") or hrp
                        if SoundPart and targetPart then
                            SoundPart.CFrame = targetPart.CFrame
                            SoundPart.AssemblyLinearVelocity = Vector3.zero
                            SoundPart.AssemblyAngularVelocity = Vector3.zero
                        end
                    end
                end)
            else
                if pcldConn then pcldConn:Disconnect() pcldConn = nil end
                MyPCLD = nil
                task.spawn(function()
                    local inv = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
                    local destroyToy = ReplicatedStorage:FindFirstChild("MenuToys")
                    destroyToy = destroyToy and destroyToy:FindFirstChild("DestroyToy")
                    if inv and destroyToy then
                        for _, v in pairs(inv:GetChildren()) do
                            if v.Name == "AntiKickItem" then
                                pcall(function() destroyToy:FireServer(v) end)
                            end
                        end
                    end
                end)
            end
        end,
    })
end

DefenceGroup:AddToggle("AntiKickToggle", {
    Text = "Anti Kick",
    Default = false,
    Callback = function(Value)
        shurikenAntiKickActive = Value
        local function ClearKunai()
            local inv = Workspace:FindFirstChild(LocalPlayer.Name.."SpawnedInToys")
            local destroyrem = ReplicatedStorage:FindFirstChild("MenuToys") and ReplicatedStorage.MenuToys:FindFirstChild("DestroyToy")
            if inv and destroyrem then
                for _, v in pairs(inv:GetChildren()) do
                    if v.Name == "AntiKick" or v.Name == "NinjaShuriken" then
                        pcall(function() destroyrem:FireServer(v) end)
                    end
                end
            end
        end
        if Value then
            task.spawn(function()
                local setOwner = ReplicatedStorage:WaitForChild("GrabEvents"):WaitForChild("SetNetworkOwner")
                local stickyEvent = ReplicatedStorage:WaitForChild("PlayerEvents"):WaitForChild("StickyPartEvent")
                local spawnRemote = ReplicatedStorage:WaitForChild("MenuToys"):WaitForChild("SpawnToyRemoteFunction")
                local canSpawn = LocalPlayer:WaitForChild("CanSpawnToy")
                local function getHRP()
                    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        return LocalPlayer.Character.HumanoidRootPart
                    else
                        local character = LocalPlayer.CharacterAdded:Wait()
                        return character:WaitForChild("HumanoidRootPart")
                    end
                end
                local function CheckForHome()
                    local plotItems = Workspace:FindFirstChild("PlotItems")
                    local plots = Workspace:FindFirstChild("Plots")
                    if not plotItems or not plots then return false end
                    local pip = plotItems:FindFirstChild("PlayersInPlots")
                    if not pip or not pip:FindFirstChild(LocalPlayer.Name) then return false end
                    for _, v in pairs(plots:GetChildren()) do
                        local sign = v:FindFirstChild("PlotSign")
                        local owners = sign and sign:FindFirstChild("ThisPlotsOwners")
                        if owners then
                            for _, b in pairs(owners:GetChildren()) do
                                if b.Value == LocalPlayer.Name then
                                    local folder = Workspace.PlotItems:FindFirstChild(v.Name)
                                    if folder then return true, folder end
                                end
                            end
                        end
                    end
                    return false
                end
                local function StickKunai(kunai)
                    if not kunai or not kunai:FindFirstChild("StickyPart") then return end
                    local currentHRP = getHRP()
                    if not currentHRP then return end
                    local firePart = currentHRP:FindFirstChild("FirePlayerPart") or currentHRP:WaitForChild("FirePlayerPart", 5)
                    if not firePart then return end
                    for _, obj in pairs(kunai:GetChildren()) do
                        if obj:IsA("BasePart") then
                            obj.CanTouch = false
                            obj.CanCollide = false
                            obj.CanQuery = false
                            obj.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                            obj.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                            if obj.Name == "Pyramid" then
                                obj.Transparency = 0
                                if not obj:FindFirstChild("Highlight") then
                                    local high = Instance.new("Highlight", obj)
                                    high.FillColor = Color3.fromRGB(0, 0, 0)
                                end
                            elseif obj.Name == "Main" then
                                obj.Transparency = 0
                                if not obj:FindFirstChild("Highlight") then
                                    local high = Instance.new("Highlight", obj)
                                    high.FillColor = Color3.fromRGB(255, 255, 255)
                                end
                            else
                                obj.Transparency = 1
                            end
                        end
                    end
                    if kunai:FindFirstChild("SoundPart") then
                        if not kunai.SoundPart:FindFirstChild("PartOwner") or kunai.SoundPart.PartOwner.Value ~= LocalPlayer.Name then
                            pcall(function() setOwner:FireServer(kunai.SoundPart, kunai.SoundPart.CFrame) end)
                        end
                    end
                    local targetCFrame = firePart.CFrame * CFrame.Angles(0, math.rad(90), math.rad(90))
                    kunai:PivotTo(targetCFrame)
                    stickyEvent:FireServer(kunai.StickyPart, firePart, CFrame.new(0,0,0) * CFrame.Angles(0,math.rad(90),math.rad(90)))
                end
                local function SpawnToy(name)
                    local t = tick()
                    while not canSpawn.Value do
                        if not shurikenAntiKickActive or tick() - t > 5 then return nil end
                        task.wait(0.1)
                    end
                    local currentHRP = getHRP()
                    if currentHRP then
                        task.spawn(function()
                            pcall(function()
                                spawnRemote:InvokeServer(name, currentHRP.CFrame * CFrame.new(0, 2, 2), Vector3.new(0,0,0))
                            end)
                        end)
                    end
                    local boolik, house = CheckForHome()
                    local inv = Workspace:FindFirstChild(LocalPlayer.Name.."SpawnedInToys")
                    if boolik and house then return house:WaitForChild(name, 2)
                    elseif not (Workspace:FindFirstChild("PlotItems") and Workspace.PlotItems:FindFirstChild("PlayersInPlots") and Workspace.PlotItems.PlayersInPlots:FindFirstChild(LocalPlayer.Name)) and inv then return inv:WaitForChild(name, 2) end
                    return nil
                end
                while shurikenAntiKickActive do
                    task.wait(0.05)
                    local _ch = LocalPlayer.Character; local _hum = _ch and _ch:FindFirstChildOfClass("Humanoid"); if not _hum or _hum.Health <= 0 then continue end
                    local inv = Workspace:FindFirstChild(LocalPlayer.Name.."SpawnedInToys")
                    local kunai = inv and inv:FindFirstChild("NinjaShuriken") or (inv and inv:FindFirstChild("AntiKick"))
                    if Workspace:FindFirstChild("PlotItems") and Workspace.PlotItems:FindFirstChild("PlayersInPlots") and Workspace.PlotItems.PlayersInPlots:FindFirstChild(LocalPlayer.Name) then
                        local boolik, house = CheckForHome()
                        if boolik and house and Workspace.Plots:FindFirstChild(house.Name) then
                            local sign = Workspace.Plots[house.Name]:FindFirstChild("PlotSign")
                            if sign and sign.ThisPlotsOwners.Value.TimeRemainingNum.Value > 89 then
                                if not kunai then kunai = SpawnToy("NinjaShuriken") end
                                if kunai == nil then continue end
                                kunai.Name = "AntiKick"
                                StickKunai(kunai)
                            end
                        end
                    end
                    if not kunai then
                        if Workspace:FindFirstChild("PlotItems") and Workspace.PlotItems:FindFirstChild("PlayersInPlots") and Workspace.PlotItems.PlayersInPlots:FindFirstChild(LocalPlayer.Name) then continue end
                        kunai = SpawnToy("NinjaShuriken")
                        if kunai == nil then continue end
                        kunai.Name = "AntiKick"
                        if not kunai then continue end
                    end
                    if kunai and kunai:FindFirstChild("StickyPart") then
                        local isWelded = kunai.StickyPart:FindFirstChild("StickyWeld") and kunai.StickyPart.StickyWeld.Part1 ~= nil
                        if not isWelded and kunai.StickyPart.CanTouch == true then
                            StickKunai(kunai)
                            kunai.Name = "AntiKick"
                            task.wait(0.1)
                        end
                        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                            if (LocalPlayer.Character.HumanoidRootPart.Position - kunai.StickyPart.Position).Magnitude >= 20 then
                                ClearKunai()
                            end
                        end
                    end
                end
                ClearKunai()
            end)
        else
            ClearKunai()
        end
    end
})

DefenceGroup:AddToggle("AntiKickBreakPCLD", {
    Text = "Anti kick（break PCLD）",
    Default = false,
    Callback = function(Value)
        if Value then
            local serverPos = CFrame.new(-272.2197265625, -7.350403785705566, 475.0108947753906)
            local oldFPDH = Workspace.FallenPartsDestroyHeight
            pcall(function() Workspace.FallenPartsDestroyHeight = -50000 end) -- NaNは使わない
            local storedJoints = {}
            local root
            local conn
            local active = false
            local function breakPCLD()
                local char = LocalPlayer.Character
                if not char then return end
                root = char:WaitForChild("HumanoidRootPart")
                for _, v in ipairs(char:GetDescendants()) do
                    if v:IsA("Motor6D") then
                        storedJoints[v] = v.Part0
                        v.Part0 = nil
                    end
                end
                root.CFrame = serverPos
                conn = RunService.RenderStepped:Connect(function()
                    if root and root.Parent then
                        root.AssemblyLinearVelocity = Vector3.zero
                        root.AssemblyAngularVelocity = Vector3.zero
                    end
                end)
            end
            local function restore()
                if conn then
                    conn:Disconnect()
                    conn = nil
                end
                for m, p0 in pairs(storedJoints) do
                    if m and m.Parent then
                        m.Part0 = p0
                    end
                end
                storedJoints = {}
            end
            local function toggle()
                active = not active
                if active then
                    breakPCLD()
                else
                    restore()
                end
            end
            toggle()
            task.wait(0.12)
            toggle()
            LocalPlayer.CharacterAdded:Once(function()
                task.wait(0.25)
                toggle()
                task.wait(0.12)
                toggle()
            end)
        end
    end
})


-- =====================================================
-- Security（一括防衛・安全設定）
-- =====================================================
do
    local sec = Tabs.Defence:AddLeftGroupbox("Security")
    local secR = Tabs.Defence:AddRightGroupbox("Security Extra")

    local secHideName = false
    local secLockFriends = false
    local nameHideConn = nil

    local function ApplyCoreProtection(on)
        local list = { "TP_AntiGrab", "TP_AntiRagdoll", "TP_AntiLag", "TP_AntiVoid", "TP_AntiSit" }
        for _, name in ipairs(list) do
            if Toggles[name] then
                pcall(function() Toggles[name]:SetValue(on) end)
            end
        end
        if Toggles.AntiKickToggle then
            pcall(function() Toggles.AntiKickToggle:SetValue(on) end)
        end
        Notify("Security", on and "コア防衛 ON" or "コア防衛 OFF", 3)
    end

    sec:AddButton({
        Text = "一括ON（推奨防衛）",
        Func = function()
            ApplyCoreProtection(true)
            globalFriendWhitelist = true
            if Toggles.FriendWhitelist then pcall(function() Toggles.FriendWhitelist:SetValue(true) end) end
        end,
    })

    sec:AddButton({
        Text = "一括OFF",
        Func = function()
            ApplyCoreProtection(false)
        end,
    })

    sec:AddToggle("SafeModeToggle", {
        Text = "セーフモード（BAN軽減・推奨）",
        Default = true,
        Callback = function(v)
            SafeMode = v
            _remoteBudgetMax = v and 80 or 200
            Notify("Security", v and "セーフモード ON" or "セーフモード OFF", 2)
        end,
    })

    sec:AddToggle("SecFriendLock", {
        Text = "フレンドを攻撃対象外（全体）",
        Default = false,
        Callback = function(v)
            globalFriendWhitelist = v
            secLockFriends = v
            Notify("Security", v and "フレンド除外 ON" or "フレンド除外 OFF", 2)
        end,
    })

    sec:AddToggle("SecPanicStop", {
        Text = "パニック停止（攻撃系全停止）",
        Default = false,
        Callback = function(v)
            if not v then return end
            -- 攻撃ループ系フラグを落とす
            pcall(function()
                arkadiaBlobKickActive = false
                loopKill1Active = false
                loopKill2Active = false
                loopBlobKickSpamActive = false
                kickLoopEnabled = false
                snowballRagdollActive = false
            end)
            -- 主要な攻撃トグルをOFF
            for name, toggle in pairs(Toggles) do
                if toggle and type(name) == "string" then
                    local n = name:lower()
                    if n:find("kick") or n:find("kill") or n:find("ragdoll") or n:find("aura") or n:find("lag") or n:find("loop") then
                        -- 防衛系は残す
                        if not n:find("anti") and not n:find("defence") and not n:find("defense") then
                            pcall(function()
                                if toggle.Value == true then toggle:SetValue(false) end
                            end)
                        end
                    end
                end
            end
            pcall(function() StopLineLag() end)
            pcall(function() stopLineLagI() end)
            linelag = false
            packetLagActive = false
            if Toggles.LineLag then pcall(function() Toggles.LineLag:SetValue(false) end) end
            Notify("Security", "パニック停止実行", 3)
            task.defer(function()
                if Toggles.SecPanicStop then Toggles.SecPanicStop:SetValue(false) end
            end)
        end,
    })

    secR:AddToggle("SecHideName", {
        Text = "自分のネームタグ隠す（簡易）",
        Default = false,
        Callback = function(v)
            secHideName = v
            local function hide(char)
                if not char then return end
                for _, inst in ipairs(char:GetDescendants()) do
                    if inst:IsA("BillboardGui") or inst:IsA("Humanoid") then
                        if inst:IsA("Humanoid") then
                            pcall(function()
                                inst.DisplayDistanceType = v and Enum.HumanoidDisplayDistanceType.None or Enum.HumanoidDisplayDistanceType.Viewer
                            end)
                        elseif inst.Name:lower():find("name") or inst.Name:lower():find("tag") then
                            inst.Enabled = not v
                        end
                    end
                end
            end
            if nameHideConn then nameHideConn:Disconnect(); nameHideConn = nil end
            if v then
                hide(LocalPlayer.Character)
                nameHideConn = LocalPlayer.CharacterAdded:Connect(function(char)
                    task.wait(0.5)
                    if secHideName then hide(char) end
                end)
            else
                hide(LocalPlayer.Character)
            end
            Notify("Security", v and "ネーム隠す ON" or "ネーム隠す OFF", 2)
        end,
    })

    secR:AddToggle("SecAntiAfk", {
        Text = "Anti-AFK",
        Default = false,
        Callback = function(v)
            if _G.__IchigoAntiAfk then
                pcall(function() _G.__IchigoAntiAfk:Disconnect() end)
                _G.__IchigoAntiAfk = nil
            end
            if v then
                local VU = game:GetService("VirtualUser")
                _G.__IchigoAntiAfk = LocalPlayer.Idled:Connect(function()
                    pcall(function()
                        VU:CaptureController()
                        VU:ClickButton2(Vector2.new())
                    end)
                end)
                Notify("Security", "Anti-AFK ON", 2)
            else
                Notify("Security", "Anti-AFK OFF", 2)
            end
        end,
    })

    secR:AddButton({
        Text = "ラグ全停止",
        Func = function()
            pcall(StopLineLag)
            pcall(stopLineLagI)
            linelag = false
            packetLagActive = false
            if packetLagTask then pcall(task.cancel, packetLagTask) packetLagTask = nil end
            if Toggles.LineLag then pcall(function() Toggles.LineLag:SetValue(false) end) end
            Notify("Security", "ラグ停止", 2)
        end,
    })

    secR:AddLabel("推奨: 一括ON → 必要なら個別調整")
end


task.spawn(function()
    task.wait(2.5)
    -- 自動ONは防衛のみ・控えめ
    if Toggles.TP_AntiGrab then pcall(function() Toggles.TP_AntiGrab:SetValue(true) end) end
    if Toggles.TP_AntiRagdoll then pcall(function() Toggles.TP_AntiRagdoll:SetValue(true) end) end
    -- AntiLag自動ONはしない（挙動が目立ちやすい）
    if TP_AntiLineLag then pcall(function() TP_AntiLineLag.Enabled = false end) end
    if TP_AntiShuriLag then pcall(function() TP_AntiShuriLag.Enabled = false end) end
end)


-- =====================================================
-- ESP（プレイヤー）
-- =====================================================
do
    local espEnabled = false
    local espShowDist = true
    local espShowHealth = true
    local espTeamColor = false
    local espDrawings = {}

    local function ESP_ClearOne(player)
        local d = espDrawings[player]
        if not d then return end
        pcall(function() if d.highlight then d.highlight:Destroy() end end)
        pcall(function() if d.billboard then d.billboard:Destroy() end end)
        espDrawings[player] = nil
    end

    local function ESP_ClearAll()
        for plr in pairs(espDrawings) do
            ESP_ClearOne(plr)
        end
        espDrawings = {}
    end

    local function ESP_Apply(player)
        if player == LocalPlayer then return end
        if not player.Character then return end
        local char = player.Character
        local head = char:FindFirstChild("Head")
        local hum = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if not head or not root then return end

        ESP_ClearOne(player)

        local hl = Instance.new("Highlight")
        hl.Name = "IchigoESP"
        hl.Adornee = char
        hl.FillColor = Color3.fromRGB(0, 0, 0)
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = 0.55
        hl.OutlineTransparency = 0.1
        pcall(function() hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop end)
        hl.Parent = char

        local bb = Instance.new("BillboardGui")
        bb.Name = "IchigoESPLabel"
        bb.Adornee = head
        bb.Size = UDim2.new(0, 200, 0, 40)
        bb.StudsOffset = Vector3.new(0, 2.5, 0)
        bb.AlwaysOnTop = true
        bb.Parent = head

        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(1, 0, 1, 0)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 14
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextStrokeTransparency = 0.3
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        label.Text = player.DisplayName
        label.Parent = bb

        espDrawings[player] = { highlight = hl, billboard = bb, text = label }
    end

    local function ESP_UpdateText(player)
        local d = espDrawings[player]
        if not d or not d.text then return end
        local char = player.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

        local parts = { player.DisplayName }
        if espShowHealth and hum then
            table.insert(parts, string.format("[%d HP]", math.floor(hum.Health)))
        end
        if espShowDist and root and myRoot then
            local dist = (root.Position - myRoot.Position).Magnitude
            table.insert(parts, string.format("%dm", math.floor(dist)))
        end
        d.text.Text = table.concat(parts, "  ")
    end

    local function ESP_RefreshAll()
        if not espEnabled then
            ESP_ClearAll()
            return
        end
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    if not espDrawings[player] or not espDrawings[player].highlight or not espDrawings[player].highlight.Parent then
                        ESP_Apply(player)
                    end
                    ESP_UpdateText(player)
                else
                    ESP_ClearOne(player)
                end
            end
        end
    end

    Players.PlayerRemoving:Connect(function(player)
        ESP_ClearOne(player)
    end)

    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function()
            task.wait(0.5)
            if espEnabled then ESP_Apply(player) end
        end)
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            player.CharacterAdded:Connect(function()
                task.wait(0.5)
                if espEnabled then ESP_Apply(player) end
            end)
        end
    end

    task.spawn(function()
        while true do
            if espEnabled then
                pcall(ESP_RefreshAll)
            end
            task.wait(0.4)
        end
    end)

    local espGroup = Tabs.Player:AddLeftGroupbox("ESP")
    espGroup:AddToggle("ESPEnabled", {
        Text = "Player ESP",
        Default = false,
        Callback = function(v)
            espEnabled = v
            if v then
                ESP_RefreshAll()
                Notify("ESP", "ON", 2, true)
            else
                ESP_ClearAll()
                Notify("ESP", "OFF", 2, true)
            end
        end,
    })
    espGroup:AddToggle("ESPShowDist", {
        Text = "距離を表示",
        Default = true,
        Callback = function(v) espShowDist = v end,
    })
    espGroup:AddToggle("ESPShowHealth", {
        Text = "HPを表示",
        Default = true,
        Callback = function(v) espShowHealth = v end,
    })
end


-- =====================================================
-- Settings
-- =====================================================
do
    local menu = Tabs.Settings:AddLeftGroupbox("Menu")
    menu:AddButton({
        Text = "Unload",
        Func = function()
            pcall(StopLineLag)
            pcall(stopLineLagI)
            linelag = false
            packetLagActive = false
            Library:Unload()
        end
    })
    menu:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })
end

do
    local uiBox = Tabs.Settings:AddRightGroupbox("UI Settings")
    uiBox:AddToggle("KeybindMenuOpen", {
        Default = Library.KeybindFrame and Library.KeybindFrame.Visible or false,
        Text = "Open Keybind Menu",
        Callback = function(visible)
            if Library.KeybindFrame then Library.KeybindFrame.Visible = visible end
        end,
    })
    uiBox:AddToggle("ShowCustomCursor", {
        Text = "Custom Cursor",
        Default = Library.ShowCustomCursor,
        Callback = function(showCustomCursor)
            Library.ShowCustomCursor = showCustomCursor
        end,
    })
    uiBox:AddToggle("AlwaysOnTop", {
        Text = "Always On Top",
        Default = Window.AlwaysOnTop,
        Callback = function(value)
            pcall(function() Window:SetAlwaysOnTop(value) end)
        end,
    })
    uiBox:AddDropdown("NotificationSide", {
        Values = { "Left", "Right" },
        Default = "Right",
        Text = "Notification Side",
        Callback = function(side)
            pcall(function() Library:SetNotifySide(side) end)
        end,
    })
    uiBox:AddDropdown("DPIDropdown", {
        Values = { "50%", "75%", "100%", "125%", "150%", "175%", "200%" },
        Default = "100%",
        Text = "DPI Scale",
        Callback = function(value)
            pcall(function() Library:SetDPIScale(tonumber(value:gsub("%%", ""))) end)
        end,
    })
    uiBox:AddSlider("UICornerSlider", {
        Text = "Corner Radius",
        Default = 18,
        Min = 0,
        Max = 20,
        Rounding = 0,
        Callback = function(value)
            pcall(function() Window:SetCornerRadius(value) end)
        end,
    })
end

Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({"MenuKeybind"})
ThemeManager:SetFolder("IchigoHub")
SaveManager:SetFolder("IchigoHub/config")
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)
SaveManager:LoadAutoloadConfig()
Window:SetCornerRadius(18)

-- 起動時チャット自動送信は削除（不要・目立つため）


-- =====================================================
-- トグル カチカチ音（全ON/OFF）
-- =====================================================
do
    local function PlayClickSound()
        pcall(function()
            local s = Instance.new("Sound")
            s.SoundId = "rbxassetid://6895079853"
            s.Volume = 0.6
            s.Parent = game:GetService("SoundService")
            s:Play()
            game:GetService("Debris"):AddItem(s, 1)
        end)
    end

    -- 起動直後の自動SetValueでは鳴らさない
    local suppressClick = true
    task.delay(2, function() suppressClick = false end)

    local patched = {}
    local function patchAll()
        for name, toggle in pairs(Toggles) do
            if toggle and toggle.Callback and not patched[toggle] then
                patched[toggle] = true
                local original = toggle.Callback
                toggle.Callback = function(...)
                    local ok, result = pcall(original, ...)
                    if not suppressClick then
                        PlayClickSound()
                    end
                    if ok then return result end
                end
            end
        end
    end
    patchAll()
    -- 遅延追加分も拾う
    task.delay(1, patchAll)
    task.delay(3, patchAll)
end

print("[いちごハブ] Ready")

