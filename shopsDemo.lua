--Connected Discord-GitHub

local ServerStorage = game:GetService("ServerStorage") -- Local variables to use later in the script 
local ReplicatedStorage = game:GetService("ReplicatedStorage") -- ReplicatedStorage service
local PhysicsService = game:GetService("PhysicsService") -- PhysicsService serivce
local ServerScriptService = game:GetService("ServerScriptService") -- ServerScriptService service
local Lighting = game:GetService("Lighting") -- Lighting service
local TweenService = game:GetService("TweenService") -- TweenService service
local newday = ReplicatedStorage.NewDay -- RemoteEvent that will detect if player pressed "Next day" button
local noobsonmap = workspace.NoobsOnMap -- Folder with a noobs on map
local noob = ServerStorage:WaitForChild("Noob") -- Model of noob
local mpart = workspace.MPart -- Main part where map is
local day = script.Day -- Current player day
local balance = script.Balance -- Player balance
local daygoing = script.DayGoing -- Is day going now or not
local hairfolder = ServerStorage.Hairs -- Folder with hairs
local hairtable = hairfolder:GetChildren() -- Table with hairs for noobs
local noobsval = 8 -- Number of noobs at first day

local shirts = { -- Tables with shirts for noobs
	398635080,
	144076357,
	398633582,
	382537084,
	3670737443,
	382537805,
	398634487,
	398634294,
	382537084,
	382538058,
}
local pants = { -- Tables with pants for noobs
	129459076,
	129458425,
	382538502,
	398635336,
	398633811,
	398634485,
	7231091107,
	144076511,
	382537805,
}

PhysicsService:RegisterCollisionGroup("Noobs") -- creating new collision group especially for noobs 
PhysicsService:CollisionGroupSetCollidable("Noobs", "Noobs", false) -- disabling collisions between noobs
for i, v in pairs(noob:GetDescendants()) do 
	if v:IsA("BasePart") then
		v.CollisionGroup = "Noobs"
	end
end

local function noobroute() -- Main function that will set the noobs route and what they will do
	noob.Balance.Value = 20 + day.Value * 2 -- increasing noobs balance everyday
	local npc = noob:Clone() -- creating noob
	local humanoid = npc.Humanoid -- npc humanoid
	local hair = hairtable[math.random(1, #hairtable)]:Clone() -- random hair that will be used
	hair.Parent = npc -- setting hair parent as npc
	
	local randshirt = shirts[math.random(1, #shirts)] -- generating random shirt
	local shirt = Instance.new("Shirt") -- creating new shirt
	shirt.ShirtTemplate = "rbxassetid://" .. randshirt -- setting shirt id
	shirt.Parent = npc -- setting shirt parent as npc
	local randpants = pants[math.random(1, #pants)] -- like shirt but pants
	local onepants = Instance.new("Pants")
	onepants.PantsTemplate = "rbxassetid://" .. randpants
	onepants.Parent = npc
	npc:MoveTo(workspace.StartEnd.PStart.Position) -- moving npc to start position and workspace. let's go!
	npc.Parent = noobsonmap
	for i, v in pairs(npc:GetDescendants()) do
		if v:IsA("BasePart") then
			v:SetNetworkOwner(nil) -- preventing humanoid:MoveTo() lags
		end
	end
	npc.Humanoid.WalkSpeed = math.random(humanoid.WalkSpeed + 6, humanoid.WalkSpeed + 15) -- generating random speed, to create situations when shops is full
	for i = 1, 6, 1 do -- starting loop of npc route. NPC will check every shop if it's built or not
		humanoid:MoveTo(workspace.PosGo[i].Position)
		humanoid.MoveToFinished:Wait()
		local foundShop = workspace.Shops:FindFirstChild(i)
		
		if foundShop ~= nil then -- if shop exists
			local costValues = {10, 15, 25, 30, 40, 100}
			local shoppingCost = costValues[i] -- how many it cost's to shopping in current shop

			if npc.Balance.Value >= shoppingCost then -- if noob's balance more than how many he can spend 
				if foundShop.Noobs.Value < foundShop.Lim.Value then -- we are checking if store if full
					foundShop.Noobs.Value+=1 -- one noob is going to enter the store. other noobs need to wait if store is full
					humanoid:MoveTo(foundShop[math.random(1,3)].Center.Position - Vector3.new(4, 0, 0))
					humanoid.MoveToFinished:Wait() -- when noob is finally came at the shop
					npc.Parent = ServerStorage.InShop -- noob is will be in server storage when he is in shop
					task.wait(i * 1.5) -- the time that noob is going to be in the shop by the shop level (if first shop, noob will wait some second, but if fifth then noob will wait more)
					balance.Value = balance.Value + shoppingCost -- after noob left from the shop, player will get money
					npc.Balance.Value-=shoppingCost -- and noob is going to loose money
					npc.Parent = workspace.NoobsOnMap -- adding noob to folder with noobs in workspace, so game can know if there is a more noobs on map and can we move on next day
					foundShop.Noobs.Value-=1 -- one noob is left from store, so other can enter
				else 
					if workspace.Benches:FindFirstChild(i):FindFirstChild("BuyPart") == nil then -- if shop is full, then noob would like to sit on bench and wait
						local selectedSeat = nil -- creating selected seat variable
						if workspace.Benches:FindFirstChild(i).Seats.Value <= 2 then -- if there is at least one seat, then noob will sit on it
							while selectedSeat == nil do -- loop that will find the free seat
								selectedSeat = workspace.Benches:FindFirstChild(i)[math.random(1,3)]
								if selectedSeat.Color ~= Color3.fromRGB(255, 255, 255) then -- to prevent bugs we will find the seat using color
									selectedSeat.Color = Color3.fromRGB(255, 255, 255)
								else
									selectedSeat = nil
								end
								if workspace.Benches:FindFirstChild(i)[1].Occupant ~= nil and workspace.Benches:FindFirstChild(i)[2].Occupant ~= nil and workspace.Benches:FindFirstChild(i)[3].Occupant ~= nil then -- to prevent bugs, we will do one more checks
									break -- breaking loop if there are no free seats
								end
							end
							workspace.Benches:FindFirstChild(i).Seats.Value+=1 -- noob is already took that seat
							humanoid:MoveTo(selectedSeat.Position + Vector3.new(5, 0, 0)) -- moving to behind of the bench
							humanoid.MoveToFinished:Wait() -- if move is finished
							selectedSeat:Sit(humanoid) -- noob is sitting
							task.wait(2) -- let's wait some seconds
							selectedSeat.Color = Color3.fromRGB(124, 92, 70) -- setting seat color back to brown, so other noob can seat (if he wants)
							humanoid.Jump = true -- leaving seat using jump
							npc:MoveTo(selectedSeat.Position + Vector3.new(5, 0, 0)) -- moving behind bench
							workspace.Benches:FindFirstChild(i).Seats.Value-=1

							if foundShop.Noobs.Value < foundShop.Lim.Value then -- noob is going to the shop again
								foundShop.Noobs.Value+=1
								humanoid:MoveTo(foundShop[math.random(1,3)].Center.Position - Vector3.new(3, 0, 0))
								humanoid.MoveToFinished:Wait()
								npc.Parent = ServerStorage.InShop
								task.wait(i * 1.5)
								balance.Value+=shoppingCost
								npc.Balance.Value-=shoppingCost
								npc.Parent = noobsonmap
								foundShop.Noobs.Value-=1
							end
						else
							local oldc = npc.Head.Color -- shop is full? again??????
							npc.Head.Color = Color3.fromRGB(255, 0, 0)
							task.wait(1)
							npc.Head.Color = oldc
						end
					else -- he is angry because he can't spend his money in shop
						local oldc = npc.Head.Color
						npc.Head.Color = Color3.fromRGB(255, 0, 0) -- red head
						task.wait(0.5)
						npc.Head.Color = oldc -- okay, noob will just leave this shop and try next one
					end
				end
			else
				local oldc = npc.Head.Color -- noob is happy because he spent all his money
				npc.Head.Color = Color3.fromRGB(0, 255, 0) -- green head
				task.wait(1)
				npc.Head.Color = oldc
				foundShop.Noobs.Value+=1 -- noob is going to the shop and spent all his money, that he have
				humanoid:MoveTo(foundShop[math.random(1,3)].Center.Position - Vector3.new(3, 0, 0))
				humanoid.MoveToFinished:Wait()
				npc.Parent = ServerStorage.InShop
				task.wait(i * 1.5)
				balance.Value = balance.Value + npc.Balance.Value -- player will get all of the noob balance that he had
				npc.Balance.Value = 0 -- noob's balance is now zero (0)
				npc.Parent = noobsonmap
				foundShop.Noobs.Value-=1
				break -- breaking the loop, because noob can't spend any money
			end
		end
	end
	humanoid.WalkSpeed+=15 -- extra speed for noob, so he can leave this place faster (and day will be over faster if this noob is being last)
	humanoid:MoveTo(workspace.StartEnd.PEnd.Position) -- moving to the map end position
	humanoid.MoveToFinished:Wait()
	npc:Destroy() -- noob is left from the map
end
noobsonmap.ChildAdded:Connect(function() -- checking if there are any noobs on the map, so we can edit if day is going or not
	daygoing.Value = true
end)
noobsonmap.ChildRemoved:Connect(function() -- checking if there are no noobs, so player can start new day
	if #noobsonmap:GetChildren() == 0 and #ServerStorage.InShop:GetChildren() == 0 then
		daygoing.Value = false
	end
end)
newday.OnServerEvent:Connect(function()
	if #noobsonmap:GetChildren() == 0 and #ServerStorage.InShop:GetChildren() == 0 then -- doing extra check again
		daygoing.Value = false
	end
	if daygoing.Value == false then -- if previous day is over we will start new
		daygoing.Value = true -- new day begun
		day.Value+=1
		Lighting.TimeOfDay = tostring(math.random(7, 20)) .. ":" .. tostring(math.random(1, 59)) .. ":" .. tostring(math.random(1,59)) -- generating random time of the day
		ReplicatedStorage.Dayfire:FireAllClients(day.Value) -- player need to know, that new day has begun
		local oldc = mpart.Color 
		mpart.Color = Color3.fromRGB(math.random(1, 255), math.random(1, 255), math.random(1, 255)) -- changing the grass color to random lol
		task.wait(0.5)
		mpart.Color = oldc -- making the grass color back to green
		if day.Value % 5 == 0 then -- if day value can divide on 5, we will add more noobs everyday
			noobsval = noobsval + 2
		end
		for i = 1, noobsval, 1 do
			local nrcoro = coroutine.create(noobroute) -- using coroutine we will rule all noobs at the same time
			coroutine.resume(nrcoro)
			task.wait(0.5)
		end
	end
end)

function BuildingAnimation(ch:Model, timee) -- this function will be used to animate the buildings
	local twait1, twait2 = timee - math.random(1, 10) / 10, timee -- random time between animations
	if twait1 < 0 then twait1 = 0 end

	for i, v:Instance in pairs(ch:GetDescendants()) do -- looping through all descendants of the building
		if v:IsA("SurfaceGui") then v.Enabled = false end -- disabling surfaceguis, because they will be enabled after

		if v:IsA("Model") then continue end -- if it is a model, we will skip it, because we don't need to animate models

		task.spawn(function()
			if v:IsA("BasePart") then
				local origtran = v.Transparency
				v.Transparency = 1

				local oldsize = v.Size
				local newsize = v.Size + Vector3.new(math.random(1,5), math.random(1,5), math.random(1,5))

				v.Size = newsize

				local x, y, z = v.Size.X, v.Size.Y, v.Size.Z

				task.wait()
				local ti = TweenInfo.new(math.random(twait1, twait2), Enum.EasingStyle.Linear, Enum.EasingDirection.In)
				local Tween = TweenService:Create(v, ti, {Transparency = origtran, Size = oldsize})
				Tween:Play()
				Tween.Completed:Wait()
				Tween = nil
			elseif v:IsA("Decal") or v:IsA("Texture") then
				local origtran = v.Transparency
				v.Transparency = 1
				local ti = TweenInfo.new(math.random(twait1, twait2), Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				local Tween = TweenService:Create(v, ti, {Transparency = 0})
				Tween:Play()
				Tween.Completed:Wait()
				Tween = nil
			elseif v:IsA("SurfaceGui") then
				v.Enabled = false
				task.wait(twait2)
				v.Enabled = true
			end
		end)	
	end
end

for i, v in pairs(workspace.Clicks:GetChildren()) do -- looping through all the shop buttons
	v.SurfaceGui.PriceText.Text = v.Cost.Value -- setting the price of the shop

	v.ClickDetector.MouseClick:Connect(function()
		if ServerScriptService.Script.Balance.Value >= v.Cost.Value then
			ServerScriptService.Script.Balance.Value-= v.Cost.Value
			local shop = ServerStorage.Folder[v.Name]
			shop.Parent = workspace.Shops
			BuildingAnimation(shop, tonumber(v.Name))
			v:Destroy()
		end
	end)
end