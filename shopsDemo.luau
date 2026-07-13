--!strict
-- Connected Discord-GitHub

-- Services
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")

-- Folders
local StartEndFolder:Folder = workspace:WaitForChild("StartEnd")
local ShopsFolder:Folder = workspace:WaitForChild("Shops")
local PosGoFolder:Folder = workspace:WaitForChild("PosGo")
local InShopFolder:Folder? = ServerStorage:FindFirstChild("InShop") :: Folder?

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

-- Collision Groups Configuration
PhysicsService:RegisterCollisionGroup("Noobs")
PhysicsService:CollisionGroupSetCollidable("Noobs", "Noobs", false)
for _, Part in Noob:GetDescendants() do 
	if Part:IsA("BasePart") then Part.CollisionGroup = "Noobs" end 
end

-- NPC system is made through Metatables аor more structured work with them
local NoobEntity = {}
NoobEntity.__index = NoobEntity

export type NoobEntity = {
	Instance: Model,
	Humanoid: Humanoid,
	Balance: IntValue,
	Customize: (self: NoobEntity) -> (),
	FlashHeadColor: (self: NoobEntity, TargetColor: Color3, Duration: number) -> (),
	NavigateTo: (self: NoobEntity, TargetPos: Vector3) -> (),
	ConductShopping: (self: NoobEntity, Shop: Instance, Cost: number, ShopIndex: number) -> (),
	HandleBenchSitting: (self: NoobEntity, Bench: Instance) -> (),
	Route: (self: NoobEntity) -> (),
}

-- Constructor, that instantiates a new NPC wrapper setup with default validation checks
function NoobEntity.new(): NoobEntity?
	local TemplateBalance = Noob:FindFirstChild("Balance") :: IntValue?
	if TemplateBalance then TemplateBalance.Value = 20 + Day.Value * 2 end

	local Npc = Noob:Clone()
	local NpcHumanoid = Npc:FindFirstChildOfClass("Humanoid")
	local NpcBalance = Npc:FindFirstChild("Balance") :: IntValue?

	if not NpcHumanoid or not NpcBalance then
		Npc:Destroy()
		return nil
	end

	local selfInstance = setmetatable({
		Instance = Npc,
		Humanoid = NpcHumanoid,
		Balance = NpcBalance,
	}, NoobEntity)

	return (selfInstance :: any) :: NoobEntity
end

-- Safely claims network ownership asynchronously to eliminate lags from NPCs
function NoobEntity.ResetNetworkOwner(Npc: Instance)
	task.spawn(function()
		while Npc:IsDescendantOf(workspace) == false do Npc.AncestryChanged:Wait() end

		for _, Part in Npc:GetDescendants() do
			if Part:IsA("BasePart") and Part:CanSetNetworkOwnership() then
				Part:SetNetworkOwner(nil)
			end
		end
	end)
end

-- Handles appearance loading using randomized table arrays
function NoobEntity.Customize(self: NoobEntity)
	local Npc = self.Instance
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

	-- Resetting NetworkOwner to prevent NPCs from lagging to the player
	NoobEntity.ResetNetworkOwner(Npc)
end

-- Triggers temporary head part color updates to visually output current logic states
function NoobEntity.FlashHeadColor(self: NoobEntity, TargetColor: Color3, Duration: number)
	local Head = self.Instance:FindFirstChild("Head") :: BasePart?
	if not Head then return end

	local OldColor = Head.Color
	Head.Color = TargetColor
	task.wait(Duration)
	Head.Color = OldColor
end

-- Implemented advanced spatial navigation using PathfindingService to calculate waypoints (Instead of direct MoveTo, like it was before).
function NoobEntity.NavigateTo(self: NoobEntity, TargetPos: Vector3)
	local RootPart = self.Instance.PrimaryPart or self.Instance:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not RootPart then
		self.Humanoid:MoveTo(TargetPos)
		self.Humanoid.MoveToFinished:Wait()
		return
	end

	local Path = PathfindingService:CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = true})
	local Success, _ = pcall(function()
		Path:ComputeAsync(RootPart.Position, TargetPos)
	end)

	if Success and Path.Status == Enum.PathStatus.Success then
		local Waypoints = Path:GetWaypoints()
		for _, Waypoint in ipairs(Waypoints) do
			self.Humanoid:MoveTo(Waypoint.Position)
			if Waypoint.Action == Enum.PathWaypointAction.Jump then
				self.Humanoid.Jump = true
			end
			self.Humanoid.MoveToFinished:Wait()
		end
	else
		self.Humanoid:MoveTo(TargetPos)
		self.Humanoid.MoveToFinished:Wait()
	end
end

-- Processes store interaction phases, updating location indices and handling financials
function NoobEntity.ConductShopping(self: NoobEntity, Shop: Instance, Cost: number, ShopIndex: number)
	local ShopNoobs = Shop:FindFirstChild("Noobs") :: IntValue?

	-- The entire script is checked for the presence of values ​​to ensure trouble-free and correct operation in all cases.
	if not ShopNoobs or not InShopFolder then return end

	ShopNoobs.Value += 1

	local RandomTarget = Shop:FindFirstChild(tostring(math.random(1, 3))) :: Model?
	if RandomTarget then
		local CenterPart = RandomTarget:FindFirstChild("Center") :: BasePart?
		if CenterPart then self:NavigateTo(CenterPart.Position - Vector3.new(4, 0, 0)) end
	end

	self.Instance.Parent = InShopFolder
	task.wait(ShopIndex * 1.5)

	Balance.Value += Cost
	self.Balance.Value -= Cost
	self.Instance.Parent = NoobsOnMap

	NoobEntity.ResetNetworkOwner(self.Instance)
	ShopNoobs.Value -= 1
end

-- Manages seat selection routines, verifying physical occupation to avoid race conditions
function NoobEntity.HandleBenchSitting(self: NoobEntity, Bench: Instance)
	local SelectedSeat: Seat? = nil
	local Attempts = 0
	local BenchSeats = Bench:FindFirstChild("Seats") :: IntValue?
	if not BenchSeats then return end

	-- Find an available seat (10 Attempts to eliminate coincidences when another customer leaves)
	while not SelectedSeat and Attempts < 10 do
		Attempts += 1
		local PotentialSeat = Bench:FindFirstChild(tostring(math.random(1, 3))) :: Seat?
		if PotentialSeat and PotentialSeat.Color ~= Color3.fromRGB(255, 255, 255) then
			SelectedSeat = PotentialSeat
			SelectedSeat.Color = Color3.fromRGB(255, 255, 255)
		end

		local allOccupied = true
		for i = 1, 3 do
			local Seat = Bench:FindFirstChild(tostring(i)) :: Seat?
			if not Seat or Seat.Occupant then continue end

			allOccupied = false
			break
		end

		if allOccupied then break end
	end

	if not SelectedSeat then return end

	-- Send the customer to sit through the Humanoid, then he returns to the stores
	BenchSeats.Value += 1
	self:NavigateTo(SelectedSeat.Position + Vector3.new(5, 0, 0))

	SelectedSeat:Sit(self.Humanoid)
	task.wait(2)

	SelectedSeat.Color = Color3.fromRGB(124, 92, 70)

	self.Humanoid.Sit = false
	task.wait(0.1) 
	self.Humanoid.Jump = true

	self:NavigateTo(SelectedSeat.Position + Vector3.new(5, 0, 0))

	-- Resetting NetworkOwner, since it can return to the player during the time the humanoid is sitting
	NoobEntity.ResetNetworkOwner(self.Instance)
	BenchSeats.Value -= 1
end

-- The main function, that's  responsible for the passage of customers across the entire street visiting shops and benches
function NoobEntity.Route(self: NoobEntity)
	self:Customize()

	self.Instance:MoveTo(PStart.Position)
	self.Instance.Parent = NoobsOnMap
	self.Humanoid.WalkSpeed = math.random(self.Humanoid.WalkSpeed + 6, self.Humanoid.WalkSpeed + 15)

	-- Main route loop (6 because there are 6 stores)
	for Index = 1, 6 do
		local Shop = ShopsFolder:FindFirstChild(tostring(Index))
		if not Shop then continue end

		local ShopNoobs = Shop:FindFirstChild("Noobs") :: IntValue?
		local ShopLim = Shop:FindFirstChild("Lim") :: IntValue?
		if not ShopNoobs or not ShopLim then continue end

		local ShoppingCost = CostValues[Index]
		local IsBroke = self.Balance.Value < ShoppingCost

		-- Move to the current shop position
		local TargetPosGo = PosGoFolder:FindFirstChild(tostring(Index)) :: BasePart?
		if TargetPosGo then self:NavigateTo(TargetPosGo.Position) end

		-- Attempt to enter the shop if capacity allows
		if ShopNoobs.Value < ShopLim.Value then
			local FinalCost = if IsBroke then self.Balance.Value else ShoppingCost
			self:ConductShopping(Shop, FinalCost, Index)

			if IsBroke then break end
			continue
		end

		-- If shop is full, handle bench queuing logic
		local Bench
		for _, CheckingBench in ipairs(CollectionService:GetTagged("Bench")) do
			if CheckingBench.Name == tostring(Index) then Bench = CheckingBench break end
		end

		-- Skip if bench doesn't exist or isn't purchased
		if not Bench or Bench:FindFirstChild("BuyPart") then
			self:FlashHeadColor(Color3.fromRGB(255, 0, 0), 0.5)
			if IsBroke then break end
			continue
		end

		-- Check for available seats
		local BenchSeats = Bench:FindFirstChild("Seats") :: IntValue?
		if not BenchSeats or BenchSeats.Value > 2 then
			self:FlashHeadColor(Color3.fromRGB(255, 0, 0), 1)
			if IsBroke then break end
			continue
		end

		self:HandleBenchSitting(Bench)

		if ShopNoobs.Value < ShopLim.Value then
			local FinalCost = if IsBroke then self.Balance.Value else ShoppingCost
			self:ConductShopping(Shop, FinalCost, Index)
		end

		if IsBroke then break end
	end

	self.Humanoid.WalkSpeed += 15
	self:NavigateTo(PEnd.Position)
	self.Instance:Destroy()
end

----------

-- Trigger connections monitoring day data
NoobsOnMap.ChildAdded:Connect(function()
	DayGoing.Value = true
end)

NoobsOnMap.ChildRemoved:Connect(function()
	if #NoobsOnMap:GetChildren() == 0 and InShopFolder and #InShopFolder:GetChildren() == 0 then
		DayGoing.Value = false
	end
end)

-- The next day start handler, which starts the customer flow and makes other changes
NewDay.OnServerEvent:Connect(function()
	if #NoobsOnMap:GetChildren() == 0 and InShopFolder and #InShopFolder:GetChildren() == 0 then
		DayGoing.Value = false
	end

	-- Stopping the beginning of a new day if the previous one is active
	if DayGoing.Value == true then return end

	DayGoing.Value = true
	Day.Value += 1

	-- Sending a signal to all players (in this case, one player, because the demo is singleplayer) about the start of the next day for processing effects
	Lighting.ClockTime = math.random(7, 19) + (math.random(0, 59) / 60)
	ReplicatedStorage.Dayfire:FireAllClients(Day.Value)

	-- As an effect, we change the color of the ground for a while and then return it back
	local OldColor = MPart.Color
	MPart.Color = Color3.fromRGB(math.random(1, 255), math.random(1, 255), math.random(1, 255))
	task.wait(0.5)
	MPart.Color = OldColor

	-- Increasing the number of customrs by 2 every 5 days, so that over time the player earns more and faster
	if Day.Value % 5 == 0 then NoobsVal += 2 end

	for Index = 1, NoobsVal do
		task.spawn(function()
			local Npc = NoobEntity.new()
			if Npc then Npc:Route() end
		end)

		task.wait(0.5)
	end
end)

-- Construction animations using CFRame via delta-time interpolation
function BuildingAnimation(Building: Model, Duration: number)
	local TimeMin = math.max(0, Duration - 1)
	local TimeMax = Duration

	for _, Child in Building:GetDescendants() do
		if Child:IsA("Model") then continue end
		if Child:IsA("SurfaceGui") then Child.Enabled = false end

		task.spawn(function()
			if Child:IsA("BasePart") then
				local Part = Child :: BasePart
				local TargetCFrame = Part.CFrame
				local OriginalTransparency = Part.Transparency

				-- Calculating randomized origin points and rotational angles
				local RandomOffset = Vector3.new(math.random(-30, 30), math.random(20, 50), math.random(-30, 30))
				local RandomRotation = CFrame.Angles(math.rad(math.random(0, 360)), math.rad(math.random(0, 360)), math.rad(math.random(0, 360)))

				-- Apply initial state
				Part.CFrame = CFrame.new(TargetCFrame.Position + RandomOffset) * RandomRotation
				Part.Transparency = 1

				local AnimDuration = math.random(TimeMin * 10, TimeMax * 10) / 10
				local ElapsedTimeValue = 0
				local Connection: RBXScriptConnection

				-- RunService loop for manual CFrame interpolation
				Connection = RunService.Heartbeat:Connect(function(DeltaTime)
					ElapsedTimeValue += DeltaTime
					local Alpha = math.clamp(ElapsedTimeValue / AnimDuration, 0, 1) -- Normalize time between 0 and 1
					local EasedAlpha = Alpha * Alpha * (3 - 2 * Alpha) -- Smoothing for fluid motion 

					-- CFrame lerp operation bridging origin and target
					Part.CFrame = Part.CFrame:Lerp(TargetCFrame, EasedAlpha)
					Part.Transparency = 1 - (1 - OriginalTransparency) * EasedAlpha

					-- Animation termination and cleanup
					if Alpha >= 1 then
						Part.CFrame = TargetCFrame
						Part.Transparency = OriginalTransparency
						Connection:Disconnect()
					end
				end)
			elseif Child:IsA("Decal") or Child:IsA("Texture") then
				Child.Transparency = 1
				local CustomTweenInfo = TweenInfo.new(math.random(TimeMin * 10, TimeMax * 10) / 10, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
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

-- Shop buying logic (Through CollectionService, so that if the folder name changes, the code remains working)
for _, Button:BasePart in (CollectionService:GetTagged("BuyShopPart")) do
	local Cost = Button:FindFirstChild("Cost") :: IntValue?
	local ClickDetector = Button:FindFirstChild("ClickDetector") :: ClickDetector?
	local SurfaceGui = Button:FindFirstChild("SurfaceGui") :: SurfaceGui?

	if SurfaceGui and Cost then
		local PriceText = SurfaceGui:FindFirstChild("PriceText") :: TextLabel?
		if PriceText then PriceText.Text = tostring(Cost.Value) end
	end

	if not ClickDetector or not Cost then continue end

	ClickDetector.MouseClick:Connect(function()
		if Balance.Value < Cost.Value then return end

		Balance.Value -= Cost.Value

		local TargetFolder = ServerStorage:FindFirstChild("Folder") :: Folder?
		if not TargetFolder then return end

		local Shop = TargetFolder:FindFirstChild(Button.Name) :: Model?
		if not Shop then return end

		Shop.Parent = ShopsFolder
		BuildingAnimation(Shop, tonumber(Button.Name) or 1)
		Button:Destroy()
	end)
end

-- Benches buying logic (Same with CollectionService, as with shop buying logic)
for _, Bench:Model in (CollectionService:GetTagged("Bench")) do
	local BuyPart = Bench:FindFirstChild("BuyPart") :: BasePart?

	if not BuyPart then continue end

	local Cost = BuyPart:FindFirstChild("Cost") :: IntValue?
	local ClickDetector = Bench:FindFirstChild("ClickDetector", true) :: ClickDetector?

	if not ClickDetector or not Cost then continue end

	ClickDetector.MouseClick:Connect(function()
		if Balance.Value < Cost.Value then return end
		Balance.Value -= Cost.Value

		for _, Child in Bench:GetChildren() do
			if not Child:IsA("BasePart") or Child:IsA("Seat") then continue end

			local Part:BasePart = Child
			Part.Transparency = 0
		end

		BuyPart:Destroy()
	end)
end
