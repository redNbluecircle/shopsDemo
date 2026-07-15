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

-- Folders, workspace References
local StartEndFolder: Folder = workspace:WaitForChild("StartEnd")
local ShopsFolder: Folder = workspace:WaitForChild("Shops")
local PosGoFolder: Folder = workspace:WaitForChild("PosGo")
local InShopFolder: Folder? = ServerStorage:FindFirstChild("InShop") :: Folder?

local PStart = StartEndFolder:WaitForChild("PStart") :: BasePart
local PEnd = StartEndFolder:WaitForChild("PEnd") :: BasePart
local NoobsOnMap: Folder = workspace:WaitForChild("NoobsOnMap")
local Noob: Model = ServerStorage:WaitForChild("Noob")
local MPart: BasePart = workspace:WaitForChild("MPart")

-- Global variables
local NewDay: RemoteEvent = ReplicatedStorage:WaitForChild("NewDay")
local Day: IntValue = script:WaitForChild("Day")
local Balance: IntValue = script:WaitForChild("Balance")
local DayGoing: BoolValue = script:WaitForChild("DayGoing")

local HairFolder: Folder = ServerStorage:WaitForChild("Hairs")
local HairTable = HairFolder:GetChildren()
local NoobsVal = 8

-- Economy and customization presets
local CostValues = {10, 15, 25, 30, 40, 100}
local ShirtsList = {398635080, 144076357, 398633582, 382537084, 3670737443, 382537805, 398634487, 398634294, 382537084, 382538058}
local PantsList = {129459076, 129458425, 382538502, 398635336, 398633811, 398634485, 7231091107, 144076511, 382537805}

--[[
	Collision Setup
	
	Reasoning: Prevents NPCs from blocking each other's pathfinding by disabling internal collisions.
	This ensures fluid crowd movement during high-traffic game phases.
]]
PhysicsService:RegisterCollisionGroup("Noobs")
PhysicsService:CollisionGroupSetCollidable("Noobs", "Noobs", false)
for _, Part in Noob:GetDescendants() do 
	if Part:IsA("BasePart") then Part.CollisionGroup = "Noobs" end 
end

-- Entity Framework
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
	FindAvailableSeat: (self: NoobEntity, Bench: Instance) -> Seat?,
	HandleBenchSitting: (self: NoobEntity, Bench: Instance) -> (),
	ProcessSingleShop: (self: NoobEntity, Index: number) -> boolean,
	Route: (self: NoobEntity) -> (),
}

--[[
	Constructor: Initializes a new NPC
	
	Reasoning: Dynamically scaling the initial balance based on the current 'Day' to maintain 
	economic balance as the player progresses and unlocks more expensive shops.
]]
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

--[[
	Asynchronous Network Ownership Reset
	
	Reasoning: If a player gets too close to an NPC, Roblox automatically assigns network ownership 
	to the player, causing stuttering. Setting it strictly to 'nil' forces server authority, 
	keeping movement smooth regardless of player proximity.
]]
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

--[[
	Applies randomized cosmetic templates
	
	Reasoning: Generates visual variety across the NPC pool using predefined catalog IDs,
	preventing the game from looking repetitive.
]]
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

	NoobEntity.ResetNetworkOwner(Npc)
end

--[[
	Visual state indicator for debugging and player feedback
	
	Reasoning: Changes the NPC's head color temporarily to signal states like "frustrated" 
	(like example - when a shop is full), giving players visual cues without needing complex UI overhead.
]]
function NoobEntity.FlashHeadColor(self: NoobEntity, TargetColor: Color3, Duration: number)
	local Head = self.Instance:FindFirstChild("Head") :: BasePart?
	if not Head then return end

	local OldColor = Head.Color
	Head.Color = TargetColor
	task.wait(Duration)
	Head.Color = OldColor
end

--[[
	Spatial Navigation via PathfindingService
	
	Reasoning: Using simple MoveTo() leads to NPCs getting stuck on newly built shops
	(In any case, the chance of this is higher than with PathFind),
	Computing a dynamic path ensures they navigate around obstacles correctly. 
	Early returns are used to fallback to simple movement if computation fails.
]]
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

	if not Success or Path.Status ~= Enum.PathStatus.Success then
		-- Fallback to linear movement if pathfinding completely fails
		self.Humanoid:MoveTo(TargetPos)
		self.Humanoid.MoveToFinished:Wait()
		return
	end

	local Waypoints = Path:GetWaypoints()
	for _, Waypoint in ipairs(Waypoints) do
		self.Humanoid:MoveTo(Waypoint.Position)
		if Waypoint.Action == Enum.PathWaypointAction.Jump then
			self.Humanoid.Jump = true
		end
		self.Humanoid.MoveToFinished:Wait()
	end
end

--[[
	Handles the transaction logic inside a shop
	
	Reasoning: Moves the NPC to a holding folder during the transaction to physically remove them 
	from the street, simulating being 'indoors', then applies the economic transaction logic.
]]
function NoobEntity.ConductShopping(self: NoobEntity, Shop: Instance, Cost: number, ShopIndex: number)
	local ShopNoobs = Shop:FindFirstChild("Noobs") :: IntValue?
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

--[[
	Helper Function
	Locates an empty seat on a specific bench
	
	Reasoning: Extracted to prevent excessive loop nesting within the HandleBenchSitting logic.
]]
function NoobEntity.FindAvailableSeat(self: NoobEntity, Bench: Instance): Seat?
	for _ = 1, 10 do
		local PotentialSeat = Bench:FindFirstChild(tostring(math.random(1, 3))) :: Seat?
		if PotentialSeat and PotentialSeat.Color ~= Color3.fromRGB(255, 255, 255) then
			return PotentialSeat
		end

		local AllOccupied = true
		for i = 1, 3 do
			local Seat = Bench:FindFirstChild(tostring(i)) :: Seat?
			if Seat and not Seat.Occupant then AllOccupied = false break end
		end

		if AllOccupied then break end
	end
	return nil
end

--[[
	Manages the queue logic when a shop is full
	
	Reasoning: Simulates realistic customer behavior by having them wait on nearby benches 
	instead of despawning immediately when a shop reaches capacity.
]]
function NoobEntity.HandleBenchSitting(self: NoobEntity, Bench: Instance)
	local BenchSeats = Bench:FindFirstChild("Seats") :: IntValue?
	if not BenchSeats then return end

	local SelectedSeat = self:FindAvailableSeat(Bench)
	if not SelectedSeat then return end

	SelectedSeat.Color = Color3.fromRGB(255, 255, 255)
	BenchSeats.Value += 1

	self:NavigateTo(SelectedSeat.Position + Vector3.new(5, 0, 0))
	SelectedSeat:Sit(self.Humanoid)
	task.wait(2)

	SelectedSeat.Color = Color3.fromRGB(124, 92, 70)
	self.Humanoid.Sit = false
	task.wait(0.1) 
	self.Humanoid.Jump = true

	self:NavigateTo(SelectedSeat.Position + Vector3.new(5, 0, 0))

	NoobEntity.ResetNetworkOwner(self.Instance)
	BenchSeats.Value -= 1
end

--[[
	Helper Function
	Processes logic for a single shop visit
	
	Reasoning: Extracted from the main Route function to reduce nesting depth and comply 
	with clean code standards. Returns a boolean indicating if the NPC ran out of money.
]]
function NoobEntity.ProcessSingleShop(self: NoobEntity, Index: number): boolean
	local Shop = ShopsFolder:FindFirstChild(tostring(Index))
	if not Shop then return false end

	local ShopNoobs = Shop:FindFirstChild("Noobs") :: IntValue?
	local ShopLim = Shop:FindFirstChild("Lim") :: IntValue?
	if not ShopNoobs or not ShopLim then return false end

	local ShoppingCost = CostValues[Index]
	local IsBroke = self.Balance.Value < ShoppingCost

	local TargetPosGo = PosGoFolder:FindFirstChild(tostring(Index)) :: BasePart?
	if TargetPosGo then self:NavigateTo(TargetPosGo.Position) end

	if ShopNoobs.Value < ShopLim.Value then
		local FinalCost = if IsBroke then self.Balance.Value else ShoppingCost
		self:ConductShopping(Shop, FinalCost, Index)
		return IsBroke
	end

	local Bench
	for _, CheckingBench in ipairs(CollectionService:GetTagged("Bench")) do
		if CheckingBench.Name == tostring(Index) then Bench = CheckingBench break end
	end

	if not Bench or Bench:FindFirstChild("BuyPart") then
		self:FlashHeadColor(Color3.fromRGB(255, 0, 0), 0.5)
		return IsBroke
	end

	local BenchSeats = Bench:FindFirstChild("Seats") :: IntValue?
	if not BenchSeats or BenchSeats.Value > 2 then
		self:FlashHeadColor(Color3.fromRGB(255, 0, 0), 1)
		return IsBroke
	end

	self:HandleBenchSitting(Bench)

	if ShopNoobs.Value < ShopLim.Value then
		local FinalCost = if IsBroke then self.Balance.Value else ShoppingCost
		self:ConductShopping(Shop, FinalCost, Index)
	end

	return IsBroke
end

--[[
	The primary AI controller loop
	
	Reasoning: Guides the NPC across the entire street layout sequentially. Stops executing early 
	if the NPC runs out of funds, maximizing efficiency.
]]
function NoobEntity.Route(self: NoobEntity)
	self:Customize()
	self.Instance:MoveTo(PStart.Position)
	self.Instance.Parent = NoobsOnMap
	self.Humanoid.WalkSpeed = math.random(self.Humanoid.WalkSpeed + 6, self.Humanoid.WalkSpeed + 15)

	for Index = 1, 6 do
		local ShouldStop = self:ProcessSingleShop(Index)
		if ShouldStop then break end
	end

	self.Humanoid.WalkSpeed += 15
	self:NavigateTo(PEnd.Position)
	self.Instance:Destroy()
end

----------

--[[
	Environment State Observers
	
	Reasoning: Automatically tracks if a day is active based on the physical presence of 
	NPCs on the map or inside shops, preventing overlapping day cycles.
]]
NoobsOnMap.ChildAdded:Connect(function() DayGoing.Value = true end)
NoobsOnMap.ChildRemoved:Connect(function()
	if #NoobsOnMap:GetChildren() == 0 and InShopFolder and #InShopFolder:GetChildren() == 0 then
		DayGoing.Value = false
	end
end)

--[[
	Day Cycle Handler
	
	Reasoning: Triggers the global state progression, updates lighting, and spawns the 
	required amount of entities concurrently.
]]
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
		task.spawn(function()
			local Npc = NoobEntity.new()
			if Npc then Npc:Route() end
		end)
		task.wait(0.5)
	end
end)

--[[
	Helper Function
	Animates a single physical part using Delta-Time interpolation
	
	Reasoning: Extracted from BuildingAnimation to prevent excessive nesting. Manual CFrame 
	interpolation is used over TweenService for parts to allow custom easing formulas.
]]
local function AnimateSinglePart(Part: BasePart, TargetCFrame: CFrame, OriginalTransparency: number, AnimDuration: number)
	local RandomOffset = Vector3.new(math.random(-30, 30), math.random(20, 50), math.random(-30, 30))
	local RandomRotation = CFrame.Angles(math.rad(math.random(0, 360)), math.rad(math.random(0, 360)), math.rad(math.random(0, 360)))

	Part.CFrame = CFrame.new(TargetCFrame.Position + RandomOffset) * RandomRotation
	Part.Transparency = 1

	local ElapsedTimeValue = 0
	local Connection: RBXScriptConnection

	Connection = RunService.Heartbeat:Connect(function(DeltaTime)
		ElapsedTimeValue += DeltaTime
		local Alpha = math.clamp(ElapsedTimeValue / AnimDuration, 0, 1) 
		local EasedAlpha = Alpha * Alpha * (3 - 2 * Alpha) 

		Part.CFrame = Part.CFrame:Lerp(TargetCFrame, EasedAlpha)
		Part.Transparency = 1 - (1 - OriginalTransparency) * EasedAlpha

		if Alpha >= 1 then
			Part.CFrame = TargetCFrame
			Part.Transparency = OriginalTransparency
			Connection:Disconnect()
		end
	end)
end

--[[
	Procedural Building Animation
	
	Reasoning: Provides player feedback during purchases. It iterates through the model's structure
	and delegates animation logic based on ClassName to keep the architecture clean.
]]
function BuildingAnimation(Building: Model, Duration: number)
	local TimeMin = math.max(0, Duration - 1)
	local TimeMax = Duration

	for _, Child in Building:GetDescendants() do
		if Child:IsA("Model") then continue end
		if Child:IsA("SurfaceGui") then Child.Enabled = false end

		task.spawn(function()
			if Child:IsA("BasePart") then
				local AnimDuration = math.random(TimeMin * 10, TimeMax * 10) / 10
				AnimateSinglePart(Child, Child.CFrame, Child.Transparency, AnimDuration)
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

--[[
	Helper Function
	Processes shop unlocking logic
]]
local function HandleShopPurchase(Button: BasePart, Cost: IntValue)
	if Balance.Value < Cost.Value then return end
	Balance.Value -= Cost.Value

	local TargetFolder = ServerStorage:FindFirstChild("Folder") :: Folder?
	if not TargetFolder then return end

	local Shop = TargetFolder:FindFirstChild(Button.Name) :: Model?
	if not Shop then return end

	Shop.Parent = ShopsFolder
	BuildingAnimation(Shop, tonumber(Button.Name) or 1)
	Button:Destroy()
end

--[[
	Shop Purchase Initialization
	
	Reasoning: Uses CollectionService tags to dynamically bind interactions to any object 
	labeled 'BuyShopPart', eliminating the need to hardcode paths to specific buttons.
]]
for _, Button: BasePart in CollectionService:GetTagged("BuyShopPart") do
	local Cost = Button:FindFirstChild("Cost") :: IntValue?
	local ClickDetector = Button:FindFirstChild("ClickDetector") :: ClickDetector?
	local SurfaceGui = Button:FindFirstChild("SurfaceGui") :: SurfaceGui?

	if SurfaceGui and Cost then
		local PriceText = SurfaceGui:FindFirstChild("PriceText") :: TextLabel?
		if PriceText then PriceText.Text = tostring(Cost.Value) end
	end

	if not ClickDetector or not Cost then continue end
	ClickDetector.MouseClick:Connect(function() HandleShopPurchase(Button, Cost) end)
end

--[[
	Helper Function
	
	Processes bench unlocking logic
]]
local function HandleBenchPurchase(Bench: Model, BuyPart: BasePart, Cost: IntValue)
	if Balance.Value < Cost.Value then return end
	Balance.Value -= Cost.Value

	for _, Child in Bench:GetChildren() do
		if not Child:IsA("BasePart") or Child:IsA("Seat") then continue end
		local Part: BasePart = Child
		Part.Transparency = 0
	end

	BuyPart:Destroy()
end

--[[
	Bench Purchase Initialization
	
	Reasoning: Iterates through tagged benches globally to safely connect purchase signals
]]
for _, Bench: Model in CollectionService:GetTagged("Bench") do
	local BuyPart = Bench:FindFirstChild("BuyPart") :: BasePart?
	if not BuyPart then continue end

	local Cost = BuyPart:FindFirstChild("Cost") :: IntValue?
	local ClickDetector = Bench:FindFirstChild("ClickDetector", true) :: ClickDetector?

	if not ClickDetector or not Cost then continue end
	ClickDetector.MouseClick:Connect(function() HandleBenchPurchase(Bench, BuyPart, Cost) end)
end
