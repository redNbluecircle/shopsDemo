--!strict
-- Connected Discord-GitHub

-- Services
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local ServerScriptService = game:GetService("ServerScriptService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

-- Folders
local StartEndFolder:Folder = workspace:WaitForChild("StartEnd")
local ShopsFolder:Folder = workspace:WaitForChild("Shops")
local BenchesFolder:Folder = workspace:WaitForChild("Benches")
local PosGoFolder:Folder = workspace:WaitForChild("PosGo")
local ClicksFolder:Folder = workspace:WaitForChild("Clicks")
local InShopFolder:Folder = ServerStorage:FindFirstChild("InShop")

local PStart = StartEndFolder:WaitForChild("PStart") :: BasePart
local PEnd = StartEndFolder:WaitForChild("PEnd") :: BasePart

-- Variables
local NewDay:RemoteEvent = ReplicatedStorage:WaitForChild("NewDay")
local NoobsOnMap:Folder = workspace:WaitForChild("NoobsOnMap")
local Noob:Model = ServerStorage:WaitForChild("Noob")
local MPart:BasePart = workspace:WaitForChild("MPart")

local Day:IntValue = script:WaitForChild("Day")
local Balance:IntValue = script:WaitForChild("Balance")
local DayGoing:BoolValue = script:WaitForChild("DayGoing")

local HairFolder:Folder = ServerStorage:WaitForChild("Hairs")
local HairTable = HairFolder:GetChildren()
local NoobsVal = 8

local CostValues = {10, 15, 25, 30, 40, 100}

local ShirtsList = {398635080, 144076357, 398633582, 382537084, 3670737443, 382537805, 398634487, 398634294, 382537084, 382538058}
local PantsList = {129459076, 129458425, 382538502, 398635336, 398633811, 398634485, 7231091107, 144076511, 382537805}

-- Collisions
pcall(function()
	PhysicsService:RegisterCollisionGroup("Noobs")
end)
PhysicsService:CollisionGroupSetCollidable("Noobs", "Noobs", false)

for _, Part in Noob:GetDescendants() do 
	if Part:IsA("BasePart") then
		Part.CollisionGroup = "Noobs"
	end
end

-- NPC Customization
local function CustomizeNpc(Npc: Model)
	if #HairTable > 0 then
		local Hair = HairTable[math.random(1, #HairTable)]:Clone()
		Hair.Parent = Npc
	end

	local ShirtInstance = Instance.new("Shirt")
	ShirtInstance.ShirtTemplate = "rbxassetid://" .. ShirtsList[math.random(1, #ShirtsList)]
	ShirtInstance.Parent = Npc

	local PantsInstance = Instance.new("Pants")
	PantsInstance.PantsTemplate = "rbxassetid://" .. PantsList[math.random(1, #PantsList)]
	PantsInstance.Parent = Npc
	
	task.spawn(function()
		while Npc:IsDescendantOf(workspace) == false do task.wait() end
		
		for _, Part in Npc:GetDescendants() do
			if Part:IsA("BasePart") then
				local BasePartInstance = Part :: BasePart
				BasePartInstance:SetNetworkOwner(nil)
			end
		end
	end)	
end

local function FlashHeadColor(Npc: Model, TargetColor: Color3, Duration: number)
	local Head = Npc:FindFirstChild("Head") :: BasePart
	if not Head then return end
	
	local OldColor = Head.Color
	Head.Color = TargetColor
	task.wait(Duration)
	Head.Color = OldColor
end

local function ConductShopping(Npc: Model, NpcHumanoid: Humanoid, Shop: Instance, Cost: number, ShopIndex: number)
	local ShopNoobs = Shop:FindFirstChild("Noobs") :: IntValue
	local NpcBalance = Npc:FindFirstChild("Balance") :: IntValue
	if not ShopNoobs or not NpcBalance then return end

	ShopNoobs.Value += 1

	local RandomTarget = Shop:FindFirstChild(tostring(math.random(1, 3))) :: Model
	if RandomTarget then
		local CenterPart = RandomTarget:FindFirstChild("Center") :: BasePart
		if CenterPart then
			NpcHumanoid:MoveTo(CenterPart.Position - Vector3.new(4, 0, 0))
		end
	end
	NpcHumanoid.MoveToFinished:Wait()

	Npc.Parent = ServerStorage:FindFirstChild("InShop")
	task.wait(ShopIndex * 1.5)

	Balance.Value += Cost
	NpcBalance.Value -= Cost
	Npc.Parent = NoobsOnMap
	ShopNoobs.Value -= 1
end

local function HandleBenchSitting(Npc: Model, NpcHumanoid: Humanoid, Bench: Instance)
	local SelectedSeat: Seat? = nil
	local Attempts = 0
	local BenchSeats = Bench:FindFirstChild("Seats") :: IntValue
	if not BenchSeats then return end

	while not SelectedSeat and Attempts < 10 do
		Attempts += 1
		local PotentialSeat = Bench:FindFirstChild(tostring(math.random(1, 3))) :: Seat
		if PotentialSeat and PotentialSeat.Color ~= Color3.fromRGB(255, 255, 255) then
			SelectedSeat = PotentialSeat
			SelectedSeat.Color = Color3.fromRGB(255, 255, 255)
		end

		local Seat1 = Bench:FindFirstChild("1") :: Seat
		local Seat2 = Bench:FindFirstChild("2") :: Seat
		local Seat3 = Bench:FindFirstChild("3") :: Seat
		if Seat1 and Seat2 and Seat3 and Seat1.Occupant and Seat2.Occupant and Seat3.Occupant then
			break
		end
	end

	if not SelectedSeat then return end

	BenchSeats.Value += 1
	NpcHumanoid:MoveTo(SelectedSeat.Position + Vector3.new(5, 0, 0))
	NpcHumanoid.MoveToFinished:Wait()

	SelectedSeat:Sit(NpcHumanoid)
	task.wait(2)

	SelectedSeat.Color = Color3.fromRGB(124, 92, 70)
	NpcHumanoid.Jump = true
	Npc:MoveTo(SelectedSeat.Position + Vector3.new(5, 0, 0))
	BenchSeats.Value -= 1
end

-- Main route handler
local function NoobRoute()
	local TemplateBalance = Noob:FindFirstChild("Balance") :: IntValue
	if TemplateBalance then
		TemplateBalance.Value = 20 + Day.Value * 2
	end

	local Npc = Noob:Clone()
	local NpcHumanoid = Npc:FindFirstChildOfClass("Humanoid")
	local NpcBalance = Npc:FindFirstChild("Balance") :: IntValue
	if not NpcHumanoid or not NpcBalance then return end

	CustomizeNpc(Npc)

	Npc:MoveTo(PStart.Position)
	Npc.Parent = NoobsOnMap
	NpcHumanoid.WalkSpeed = math.random(NpcHumanoid.WalkSpeed + 6, NpcHumanoid.WalkSpeed + 15)

	for Index = 1, 6 do
		local Shop = ShopsFolder:FindFirstChild(tostring(Index))
		if not Shop then continue end 

		local ShopNoobs = Shop:FindFirstChild("Noobs") :: IntValue
		local ShopLim = Shop:FindFirstChild("Lim") :: IntValue
		if not ShopNoobs or not ShopLim then continue end

		local ShoppingCost = CostValues[Index]

		local TargetPosGo = PosGoFolder:FindFirstChild(tostring(Index)) :: BasePart
		if TargetPosGo then
			NpcHumanoid:MoveTo(TargetPosGo.Position)
		end
		NpcHumanoid.MoveToFinished:Wait()

		if NpcBalance.Value >= ShoppingCost then
			if ShopNoobs.Value < ShopLim.Value then
				ConductShopping(Npc, NpcHumanoid, Shop, ShoppingCost, Index)
			else
				local Bench = BenchesFolder:FindFirstChild(tostring(Index))
				if Bench and not Bench:FindFirstChild("BuyPart") then
					local BenchSeats = Bench:FindFirstChild("Seats") :: IntValue
					
					if BenchSeats and BenchSeats.Value <= 2 then
						HandleBenchSitting(Npc, NpcHumanoid, Bench)
						if ShopNoobs.Value < ShopLim.Value then
							ConductShopping(Npc, NpcHumanoid, Shop, ShoppingCost, Index)
						end
					else
						FlashHeadColor(Npc, Color3.fromRGB(255, 0, 0), 1)
					end
				else
					FlashHeadColor(Npc, Color3.fromRGB(255, 0, 0), 0.5)
				end
			end
		else
			FlashHeadColor(Npc, Color3.fromRGB(0, 255, 0), 1)
			ShopNoobs.Value += 1

			local RandomTarget = Shop:FindFirstChild(tostring(math.random(1, 3))) :: Model
			if RandomTarget then
				local CenterPart = RandomTarget:FindFirstChild("Center") :: BasePart
				if CenterPart then
					NpcHumanoid:MoveTo(CenterPart.Position - Vector3.new(3, 0, 0))
				end
			end
			NpcHumanoid.MoveToFinished:Wait()

			Npc.Parent = ServerStorage:FindFirstChild("InShop")
			task.wait(Index * 1.5)

			Balance.Value += NpcBalance.Value
			NpcBalance.Value = 0
			Npc.Parent = NoobsOnMap
			ShopNoobs.Value -= 1
			break 
		end
	end

	NpcHumanoid.WalkSpeed += 15
	NpcHumanoid:MoveTo(PEnd.Position)
	NpcHumanoid.MoveToFinished:Wait()
	Npc:Destroy()
end

-- Events
NoobsOnMap.ChildAdded:Connect(function()
	DayGoing.Value = true
end)

NoobsOnMap.ChildRemoved:Connect(function()
	if #NoobsOnMap:GetChildren() == 0 and InShopFolder and #InShopFolder:GetChildren() == 0 then
		DayGoing.Value = false
	end
end)

NewDay.OnServerEvent:Connect(function()
	if #NoobsOnMap:GetChildren() == 0 and InShopFolder and #InShopFolder:GetChildren() == 0 then 
		DayGoing.Value = false
	end

	if DayGoing.Value == true then return end 

	DayGoing.Value = true
	Day.Value += 1

	Lighting.ClockTime = math.random(7, 19) + (math.random(0, 59) / 60)

	ReplicatedStorage.Dayfire:FireAllClients(Day.Value)
	
	local OldColor = MPart.Color 
	MPart.Color = Color3.fromRGB(math.random(1, 255), math.random(1, 255), math.random(1, 255))
	task.wait(0.5)
	MPart.Color = OldColor

	if Day.Value % 5 == 0 then NoobsVal += 2 end

	for Index = 1, NoobsVal do
		task.spawn(NoobRoute)
		task.wait(0.5)
	end
end)

-- Building animations
function BuildingAnimation(Building: Model, Duration: number)
	local TimeMin, TimeMax = Duration - math.random(1, 10) / 10, Duration
	if TimeMin < 0 then TimeMin = 0 end

	for _, Child in Building:GetDescendants() do
		if Child:IsA("Model") then continue end
		if Child:IsA("SurfaceGui") then 
			local Gui = Child :: SurfaceGui
			Gui.Enabled = false 
		end

		task.spawn(function()
			if Child:IsA("BasePart") then
				local OriginalTransparency = Child.Transparency
				local OriginalSize = Child.Size

				Child.Transparency = 1
				Child.Size = OriginalSize + Vector3.new(math.random(1, 5), math.random(1, 5), math.random(1, 5))
				task.wait()

				local CustomTweenInfo = TweenInfo.new(math.random(TimeMin, TimeMax), Enum.EasingStyle.Linear, Enum.EasingDirection.In)
				local Tween = TweenService:Create(Child, CustomTweenInfo, {Transparency = OriginalTransparency, Size = OriginalSize})
				Tween:Play()
				Tween.Completed:Wait()
				Tween:Destroy()
			elseif Child:IsA("Decal") or Child:IsA("Texture") then
				Child.Transparency = 1
				local CustomTweenInfo = TweenInfo.new(math.random(TimeMin, TimeMax), Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				local Tween = TweenService:Create(Child, CustomTweenInfo, {Transparency = 0})
				Tween:Play()
				Tween.Completed:Wait()
				Tween:Destroy()
			elseif Child:IsA("SurfaceGui") then
				task.wait(TimeMax)
				Child.Enabled = true
			end
		end)	
	end
end

-- Shop buying logic
for _, Button:BasePart in ClicksFolder:GetChildren() do
	local Cost = Button:FindFirstChild("Cost") :: IntValue
	local ClickDetector = Button:FindFirstChild("ClickDetector") :: ClickDetector
	local SurfaceGui = Button:FindFirstChild("SurfaceGui") :: SurfaceGui

	if SurfaceGui and Cost then
		local PriceText = SurfaceGui:FindFirstChild("PriceText") :: TextLabel
		if PriceText then PriceText.Text = tostring(Cost.Value) end
	end

	if not ClickDetector or not Cost then continue end
	
	ClickDetector.MouseClick:Connect(function()
		if Balance.Value < Cost.Value then return end

		Balance.Value -= Cost.Value

		local TargetFolder = ServerStorage:FindFirstChild("Folder") :: Folder
		if not TargetFolder then return end

		local Shop = TargetFolder:FindFirstChild(Button.Name) :: Model
		if not Shop then return end

		Shop.Parent = ShopsFolder
		BuildingAnimation(Shop, tonumber(Button.Name) or 1)
		Button:Destroy()
	end)
end

-- Benches
for _, Bench:Model in BenchesFolder:GetChildren() do
	local BuyPart = Bench:FindFirstChild("BuyPart") :: BasePart

	if not BuyPart then continue end

	local Cost = BuyPart:FindFirstChild("Cost") :: IntValue
	local ClickDetector = Bench:FindFirstChild("ClickDetector", true) :: ClickDetector

	if not ClickDetector or not Cost then continue end

	ClickDetector.MouseClick:Connect(function()
		if Balance.Value < Cost.Value then return end
		Balance.Value -= Cost.Value

		for _, Child in Bench:GetChildren() do
			if Child:IsA("BasePart") and not Child:IsA("Seat") then 
				local Part:BasePart = Child
				Part.Transparency = 0 
			end
		end

		BuyPart:Destroy()
	end)
end
