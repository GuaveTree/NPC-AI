
--!strict
--tables & Setup OOP Monster
local Monster = {}
Monster.__index = Monster

export type mytype = {
	Name : string,
	Health :number,
	Attack : number,
	Defense : number,
	AttackCooldown :number,
	Range : number,
	Speed : number,
	Body : Instance,
	HitboxSize : Vector3,
	AttackRange : number,
	Hittarget : {[Model]: number},
	pathID : number,
	VisibleWaypointsMonster : {Part}?,
	waypoints : {PathWaypoint}?,
	PathInfo : {[string]:any},
	Costs : {[string]:number},
	target : Model?,
	lasttargetsearch : number
}

local Normal: {[string]:any}= {
	Name = "Monster",
	Health = 100,
	Attack = 10,
	Defense = 40,
	AttackCooldown = 1,
	Range = 10,
	HitboxSize = Vector3.new(3, 5, 3),
	AttackRange = 2.5,
	Speed = 10,
	PathInfo = {
		AgentRadius = 2,       
		AgentHeight = 5,      
		AgentCanJump = true,    
		AgentCanClimb = false,   
		WaypointSpacing = 5,
		Costs = {
			Water = 20,
			DangerZone = math.huge
		}
	}
} 

setmetatable(Monster, {__index = Normal})
--------------------------------------

--Services
local Players = game:GetService("Players")-- i love this game["Players"]
local PathService = game:GetService("PathfindingService")
--------------------------------------

--Variables
local lastmonsterattack = setmetatable({}, {__mode = "k"}) :: {[mytype]: number}

local waitingtime : number = 2
local targetdist : number = 2.5
local timeout : number = 3
local DebugMode : boolean = true --مهم 


--------------------------------------

local function VisibleDebugingHitBox(monster:mytype)
	local body = monster.Body
	local Humanoid = body:FindFirstChild("Humanoid") :: Humanoid?
	local HumanoidRootPart = body:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not Humanoid or not HumanoidRootPart then warn("rootpart or humanoid error") return end
	local folder = game.Workspace:FindFirstChild("VisibleDebugingPartsAI_Script") or Instance.new("Folder")

	folder.Name = "VisibleDebugingPartsAI_Script"
	folder.Parent = workspace

	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 0.6
	part.CFrame = HumanoidRootPart.CFrame * CFrame.new(0, 0, -monster.AttackRange)
	part.Size = monster.HitboxSize
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 0, 0)
	part.Parent = folder
	game.Debris:AddItem(part, 0.2)
end

local function VisibleDebugingWaypoints(monster:mytype, ID )
	local folder = game.Workspace:FindFirstChild("VisibleWaypointsfolder") ::Folder?
	if not folder then 
		folder = Instance.new("Folder") :: Folder
		folder.Name = "VisibleWaypointsfolder"
		folder.Parent = workspace
	end



	local Waypionts = monster.waypoints :: {PathWaypoint}?
	if not Waypionts then return end 

	for _, waypiont:PathWaypoint in ipairs(Waypionts) do
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Transparency = 0.6
		part.Size = Vector3.new(1,1,1)
		part.Shape = Enum.PartType.Ball
		part.Material = Enum.Material.Neon
		part.Position = waypiont.Position
		part.Color = Color3.fromRGB(85, 0, 255)
		part.Parent = folder
		game.Debris:AddItem(part, 0.2)
	end

end


function Monster.CreateNewMonster(info: {[string|Instance]: any}) :mytype?
	if not info then warn("error num"..100) return nil end

	local self = setmetatable({}, Monster)

	self.Name = info.Name 
	self.Body = info.Body 
	self.Health = info.Health 
	self.Attack = info.Attack 
	self.Defense = info.Defense 
	self.AttackCooldown = info.AttackCooldown 
	self.Range = info.Range 
	self.AttackRange = info.AttackRange 
	self.Speed = info.Speed 
	self.HitboxSize = info.HitboxSize 
	self.pathID = info.pathID or 0
	self.waypoints = info.waypoints or {}
	self.PathInfo = info.PathInfo
	self.target = nil ::Model?
	self.lasttargetsearch = -math.huge

	self.Hittarget = setmetatable({}, {__mode = "k"}) :: {[Model]: number}

	return self :: mytype
end


function Monster.GetMonsterInfo(currentmonster: mytype) : {[string]: any}
	return {
		Name = currentmonster.Name,
		Body = currentmonster.Body,
		Health = currentmonster.Health,
		Attack = currentmonster.Attack,
		Defense = currentmonster.Defense,
		AttackCooldown = currentmonster.AttackCooldown,
		Range = currentmonster.Range,
		Speed = currentmonster.Speed,
	} 
end


function Monster.PerformAttack(monster:mytype)

	if not lastmonsterattack[monster] then lastmonsterattack[monster] = -math.huge end
	if os.clock() - lastmonsterattack[monster] <= monster.AttackCooldown then return end
	--Setup
	local AttackPower:number = monster.Attack
	local Cooldown:number = monster.AttackCooldown
	local Range:number = monster.Range
	local body:Instance = monster.Body
	local monstersonattack:{Instance} = {}

	if not AttackPower or not Cooldown or not Range or not body then warn("error num 101") return end

	table.insert(monstersonattack, body)
	local Humanoid = body:FindFirstChild("Humanoid") :: Humanoid?
	local HumanoidRootPart = body:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not Humanoid or not HumanoidRootPart then warn("error num 102") return end

	--------------------------------------------------

	-- Variables
	local PlayersFound:{Humanoid} = {}

	--------------------------------------------------
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = monstersonattack

	local hitpartslist = workspace:GetPartBoundsInBox(HumanoidRootPart.CFrame * CFrame.new(0,0,-monster.AttackRange), monster.HitboxSize, params)

	if DebugMode then
		VisibleDebugingHitBox(monster)
	end

	local currentTime = os.clock()
	-- loop 
	for _, hit in ipairs(hitpartslist) do

		local hitparent = hit.Parent
		if hitparent and hitparent:IsA("Model") and hitparent:FindFirstChild("Humanoid") and not table.find(PlayersFound, hitparent:FindFirstChildOfClass("Humanoid")::Humanoid) then
			local CR = hitparent
			if not Players:GetPlayerFromCharacter(CR) then
				continue
			end

			local Humanoidplayer = CR:FindFirstChildOfClass("Humanoid") :: Humanoid?
			local HumanoidRootPartplayer = CR:FindFirstChild("HumanoidRootPart") :: BasePart?

			if not Humanoidplayer or not HumanoidRootPartplayer then continue end
			if Humanoidplayer.Health <= 0 then continue end

			if currentTime - (monster.Hittarget[CR] or 0) <= Cooldown then continue end
			table.insert(PlayersFound, Humanoidplayer)
		end
	end
	if #PlayersFound <= 0 then return end

	local target = nil
	local CRtarget = nil
	local distMin = math.huge


	for _, player in ipairs(PlayersFound) do
		local CR = player.Parent :: Model
		local playerrootpart = CR:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not playerrootpart then continue end
		local dist = (playerrootpart.Position - HumanoidRootPart.Position).Magnitude
		if dist >= distMin then continue end
		distMin = dist
		local humanoid = CR:FindFirstChildOfClass("Humanoid") :: Humanoid?
		if not humanoid or humanoid.Health <= 0 then continue end
		target = humanoid
		CRtarget = CR
	end

	if target and CRtarget then
		monster.Hittarget[CRtarget] = currentTime
		target:TakeDamage(AttackPower)
		lastmonsterattack[monster] = currentTime
	end	
end


local function FindTarget(monster: mytype, playerslist: {Player}): Model?
	local rootpart = monster.Body:FindFirstChild("HumanoidRootPart") :: BasePart?
	local target = nil ::Model?
	local MaxDistance = monster.Range
	local targetDistance:number = math.huge

	if #playerslist < 1 then print("error num 1021") return nil end 
	for _, player:Player in ipairs(playerslist) do
		local character = player.Character ::Model?
		if not character then continue end

		local player_human = character:FindFirstChild("Humanoid") :: Humanoid?
		local player_rootpart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not player_rootpart or not rootpart or not player_human then continue end

		if player_human.Health <= 0 then continue end

		local dist:number = (rootpart.Position - player_rootpart.Position).Magnitude

		if dist >= MaxDistance then continue end
		if dist >= targetDistance then continue end


		targetDistance = dist
		target = character
	end
	if not target then return nil end

	return target 
end

-- العصب الحي للنظام او فارس العصب للأندومي😎😎

function Monster.FindPath(monster:mytype, target:Model)

	local pathID:number = monster.pathID
	local Body:Instance = monster.Body
	local humanoid = Body:FindFirstChild("Humanoid") :: Humanoid?
	local rootpart = Body:FindFirstChild("HumanoidRootPart") :: BasePart?
	local targethuman = target:FindFirstChild("Humanoid") :: Humanoid?
	local targetroot = target:FindFirstChild("HumanoidRootPart") :: BasePart?

	if not humanoid or not rootpart or not targetroot or not targethuman then return end

	local path:Path = PathService:CreatePath(monster.PathInfo)

	local Success, Error = pcall(function()
		path:ComputeAsync(rootpart.Position, targetroot.Position)
	end)
	if Error or not Success then return end

	if Success and path.Status == Enum.PathStatus.Success then


		local waypoints = path:GetWaypoints()
		if #waypoints < 2 then
			return
		end
		monster.pathID += 1
		monster.waypoints = waypoints

		if DebugMode then
			VisibleDebugingWaypoints(monster, monster.pathID)
		end
	end 
end

function Monster.Moveing(monster:mytype, myId:number)

	if myId ~= monster.pathID then
		return
	end

	local body:Instance = monster.Body
	local humanoid = body:FindFirstChild("Humanoid") :: Humanoid?
	local rootpart = body:FindFirstChild("HumanoidRootPart") :: BasePart?
	local waypoints = monster.waypoints ::{PathWaypoint}?

	if not humanoid or not rootpart then 
		return 
	end

	if not waypoints or #waypoints < 2 then
		humanoid:Move(Vector3.zero)
		return
	end

	for i = 3, #waypoints do

		if humanoid.Health <= 0  then
			return
		end


		local waypoint = waypoints[i] :: PathWaypoint
		if not waypoint or not rootpart then humanoid:Move(Vector3.zero) continue end

		local distance:number = math.huge

		if waypoint.Action == Enum.PathWaypointAction.Jump then
			humanoid.Jump = true
		end

		local timein = os.clock()

		repeat 

			if myId ~= monster.pathID then
				return
			end


			if not monster.waypoints then humanoid:Move(Vector3.zero) return end

			if os.clock() - timein >= timeout then warn("timeout") humanoid:Move(Vector3.zero) return end

			local targetpos:Vector3 = Vector3.new(waypoint.Position.X, rootpart.Position.Y, waypoint.Position.Z)


			local flottarget: Vector3 = (targetpos - rootpart.Position).Unit
			distance = (targetpos - rootpart.Position).Magnitude
			if distance < targetdist then humanoid:Move(Vector3.zero) break end

			humanoid:Move(flottarget, false)
			task.wait()
		until distance < targetdist or myId ~= monster.pathID or humanoid.Health <= 0 or not monster.waypoints
	end
	humanoid:Move(Vector3.zero)
end

function Monster.SetupStatus(monster:mytype)
	if not monster then return end
	local Health = monster.Health
	local Defense = monster.Defense
	local Speed = monster.Speed
	local body = monster.Body
	if not Health or not Defense or not Speed or not body then warn(" monster nil") return end

	local humanoid = body:FindFirstChild("Humanoid") :: Humanoid?

	if not humanoid then warn("not found: humanoid")
		return
	end
	humanoid.Health = Health + Defense
	humanoid.WalkSpeed = Speed
end	


local waitingtime = 2
function Monster.ManagerNormalMove(monster)
	local currenttime = os.clock()
	local lasttargetsearch:number = monster.lasttargetsearch or -math.huge 

	local needtaregt = not monster.target or (currenttime - lasttargetsearch) > waitingtime
	if needtaregt  then
		monster.lasttargetsearch = currenttime
		local newtarget = FindTarget(monster, Players:GetPlayers())
		if needtaregt then
			monster.target = newtarget ::Model?
		elseif not monster.target then
			return
		end
	end


	local target = monster.target ::Model
	local targethuman 
	local targetroot 
	if target then
		targethuman = target:FindFirstChild("Humanoid") :: Humanoid?
		targetroot = target:FindFirstChild("HumanoidRootPart") :: BasePart?
	end


	if not targethuman or not targetroot or targethuman.Health <= 0 then 
		monster.target = nil
		monster.waypoints = nil :: any
		return
	end

	local needspathupdate = false

	if not monster.waypoints or #monster.waypoints == 0 then
		needspathupdate = true
	else
		local endPoint = monster.waypoints[#monster.waypoints] ::PathWaypoint
		local targetDist:number
		if targetroot then
			targetDist = (targetroot.Position - endPoint.Position).Magnitude
		end


		if targetDist > 5 then
			needspathupdate = true
		end
	end

	if needspathupdate then
		Monster.FindPath(monster, target)
		if monster.waypoints and #monster.waypoints > 0 then
			local pathID = monster.pathID ::number
			task.spawn(Monster.Moveing, monster, pathID)
		end
	end
end

return Monster
