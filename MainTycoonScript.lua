-- ============================================
-- FEMBOY MILK TYCOON - MAIN SERVER SCRIPT
-- Place in ServerScriptService
-- ============================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

-- ============================================
-- CONFIGURATION
-- ============================================

local CONFIG = {
	WORLD_SIZE = 500,
	PLOT_SIZE = 24,
	BUILDING_HEIGHT = 18,
	TOTAL_FLOORS = 5,
	MAX_PLOTS = 4,
	PRODUCTION_TICK = 1,
	
	-- Costs
	FEMBOY_BASE_COST = 200,
	FEMBOY_SCALE = 120,
	TOMBOY_BASE_COST = 2500,
	TOMBOY_SCALE = 2000,
	REBIRTH_BASE_COST = 50000,
	REBIRTH_SCALE = 30000,
	
	-- Production rates
	FEMBOY_PRODUCTION = 2,
	TOMBOY_PRODUCTION = 12,
	STORE_MULTIPLIER = 1.2,
	PRESTIGE_MULTIPLIER = 0.35,
	CASH_CONVERSION = 1.45,
	
	-- Store costs
	STORE_UPGRADE_1 = 2000,
	STORE_UPGRADE_2 = 9000,
	PLOT_UNLOCK = 15000,
}

-- ============================================
-- PLAYER DATA SYSTEM
-- ============================================

local playerData = {}

local DEFAULT_PROFILE = {
	Cash = 0,
	Milk = 0,
	Rebirths = 0,
	Level = 1,
	Floor = 1,
	Production = 0,
	PlotUnlocked = 1,
	FemboyWorkers = 0,
	TomboyWorkers = 0,
	StoreLevel = 1,
	PrestigeMultiplier = 1,
	TotalMilk = 0,
	TotalCash = 0,
	OwnedDecor = {},
	LastCollected = tick(),
}

local function getProfile(player)
	local key = tostring(player.UserId)
	if not playerData[key] then
		playerData[key] = {}
		for k, v in pairs(DEFAULT_PROFILE) do
			playerData[key][k] = v
		end
	end
	return playerData[key]
end

local function addMoney(player, amount)
	local profile = getProfile(player)
	profile.Cash = profile.Cash + amount
	profile.TotalCash = profile.TotalCash + amount
end

local function addMilk(player, amount)
	local profile = getProfile(player)
	profile.Milk = profile.Milk + amount
	profile.TotalMilk = profile.TotalMilk + amount
end

local function getProductionRate(player)
	local p = getProfile(player)
	local workerProduction = (p.FemboyWorkers * CONFIG.FEMBOY_PRODUCTION) + (p.TomboyWorkers * CONFIG.TOMBOY_PRODUCTION)
	local storeMultiplier = CONFIG.STORE_MULTIPLIER ^ p.StoreLevel
	return math.floor(workerProduction * storeMultiplier * p.PrestigeMultiplier)
end

-- ============================================
-- WORLD GENERATION
-- ============================================

local tycoonModel = Instance.new("Model")
tycoonModel.Name = "FemboyMilkTycoon"
tycoonModel.Parent = workspace

local plotFolder = Instance.new("Folder")
plotFolder.Name = "Plots"
plotFolder.Parent = tycoonModel

local decorFolder = Instance.new("Folder")
decorFolder.Name = "Decorations"
decorFolder.Parent = tycoonModel

local machinesFolder = Instance.new("Folder")
machinesFolder.Name = "Machines"
machinesFolder.Parent = tycoonModel

local buildingsFolder = Instance.new("Folder")
buildingsFolder.Name = "Buildings"
buildingsFolder.Parent = tycoonModel

local function makePart(parent, size, cframe, color, material, transparency)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Transparency = transparency or 0
	p.Parent = parent
	return p
end

local function createTextSign(part, text, size)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.CanvasSize = size or Vector2.new(800, 200)
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.5
	label.Parent = gui
	return label
end

-- Ground base
local groundBase = makePart(tycoonModel, Vector3.new(200, 4, 200), CFrame.new(0, -2, 0), Color3.fromRGB(100, 110, 120), Enum.Material.Slate)
groundBase.Name = "GroundBase"

-- Grass area
for x = -8, 8 do
	for z = -8, 8 do
		if (x * x + z * z) > 10 then
			local tile = makePart(tycoonModel, Vector3.new(10, 1, 10), CFrame.new(x * 10, 0.5, z * 10), Color3.fromRGB(85, 145, 75), Enum.Material.Grass)
			tile.CanCollide = false
		end
	end
end

-- Spawn pad
local spawnPad = makePart(tycoonModel, Vector3.new(40, 1, 40), CFrame.new(0, 1, 70), Color3.fromRGB(80, 90, 110), Enum.Material.Slate)
spawnPad.Name = "SpawnPad"
spawnPad.CanCollide = true

createTextSign(spawnPad, "SPAWN", Vector2.new(400, 100))

-- Main building
local mainLot = makePart(tycoonModel, Vector3.new(120, 1, 120), CFrame.new(0, 1, 0), Color3.fromRGB(65, 72, 82), Enum.Material.Pavement)
mainLot.CanCollide = true

local floorData = {}

for floorIdx = 1, CONFIG.TOTAL_FLOORS do
	local yPos = (floorIdx - 1) * CONFIG.BUILDING_HEIGHT + 1
	
	-- Floor base
	local floorBase = makePart(buildingsFolder, Vector3.new(80, 1, 80), CFrame.new(0, yPos, 0), Color3.fromRGB(81, 90, 108), Enum.Material.Slate)
	floorBase.Name = "FloorBase_" .. floorIdx
	
	-- Ceiling
	local ceiling = makePart(buildingsFolder, Vector3.new(80, 1, 80), CFrame.new(0, yPos + 9, 0), Color3.fromRGB(112, 122, 138), Enum.Material.SmoothPlastic)
	ceiling.Transparency = 0.15
	ceiling.Name = "FloorCeiling_" .. floorIdx
	
	-- Walls
	local wallFront = makePart(buildingsFolder, Vector3.new(70, 9, 1), CFrame.new(0, yPos + 4.5, -40), Color3.fromRGB(124, 132, 145), Enum.Material.SmoothPlastic)
	local wallBack = makePart(buildingsFolder, Vector3.new(70, 9, 1), CFrame.new(0, yPos + 4.5, 40), Color3.fromRGB(124, 132, 145), Enum.Material.SmoothPlastic)
	local wallLeft = makePart(buildingsFolder, Vector3.new(1, 9, 70), CFrame.new(-40, yPos + 4.5, 0), Color3.fromRGB(124, 132, 145), Enum.Material.SmoothPlastic)
	local wallRight = makePart(buildingsFolder, Vector3.new(1, 9, 70), CFrame.new(40, yPos + 4.5, 0), Color3.fromRGB(124, 132, 145), Enum.Material.SmoothPlastic)
	
	-- Glass windows
	local glassFront = makePart(buildingsFolder, Vector3.new(50, 8, 0.5), CFrame.new(0, yPos + 4.5, -39.75), Color3.fromRGB(153, 206, 255), Enum.Material.Glass)
	glassFront.Transparency = 0.3
	
	local glassBack = makePart(buildingsFolder, Vector3.new(50, 8, 0.5), CFrame.new(0, yPos + 4.5, 39.75), Color3.fromRGB(153, 206, 255), Enum.Material.Glass)
	glassBack.Transparency = 0.3
	
	-- Floor sign
	local floorSign = makePart(buildingsFolder, Vector3.new(16, 4, 1), CFrame.new(0, yPos + 8, -39.5), Color3.fromRGB(255, 88, 186), Enum.Material.Neon)
	local floorName = "FLOOR " .. floorIdx
	if floorIdx == 1 then floorName = "MAIN HQ" end
	if floorIdx == 5 then floorName = "TOMBOY LAB" end
	createTextSign(floorSign, floorName, Vector2.new(800, 200))
	
	-- Corner pillars
	local pillarA = makePart(buildingsFolder, Vector3.new(4, 10, 4), CFrame.new(-35, yPos + 4.5, -35), Color3.fromRGB(160, 170, 180), Enum.Material.Concrete)
	local pillarB = makePart(buildingsFolder, Vector3.new(4, 10, 4), CFrame.new(35, yPos + 4.5, -35), Color3.fromRGB(160, 170, 180), Enum.Material.Concrete)
	local pillarC = makePart(buildingsFolder, Vector3.new(4, 10, 4), CFrame.new(-35, yPos + 4.5, 35), Color3.fromRGB(160, 170, 180), Enum.Material.Concrete)
	local pillarD = makePart(buildingsFolder, Vector3.new(4, 10, 4), CFrame.new(35, yPos + 4.5, 35), Color3.fromRGB(160, 170, 180), Enum.Material.Concrete)
	
	-- Floor-specific decorations
	if floorIdx == 1 then
		-- Main floor: milk storage tanks
		local tank1 = makePart(decorFolder, Vector3.new(15, 8, 15), CFrame.new(-25, yPos + 2, -20), Color3.fromRGB(220, 240, 255), Enum.Material.SmoothPlastic)
		tank1.Transparency = 0.2
		createTextSign(tank1, "MILK TANK", Vector2.new(600, 200))
		
		local tank2 = makePart(decorFolder, Vector3.new(15, 8, 15), CFrame.new(25, yPos + 2, -20), Color3.fromRGB(220, 240, 255), Enum.Material.SmoothPlastic)
		tank2.Transparency = 0.2
		createTextSign(tank2, "MILK TANK", Vector2.new(600, 200))
		
	elseif floorIdx == 2 then
		-- Floor 2: production machines
		local pump1 = makePart(decorFolder, Vector3.new(10, 8, 10), CFrame.new(-20, yPos + 2, 0), Color3.fromRGB(140, 160, 180), Enum.Material.Metal)
		createTextSign(pump1, "PUMP 1", Vector2.new(400, 150))
		
		local pump2 = makePart(decorFolder, Vector3.new(10, 8, 10), CFrame.new(20, yPos + 2, 0), Color3.fromRGB(140, 160, 180), Enum.Material.Metal)
		createTextSign(pump2, "PUMP 2", Vector2.new(400, 150))
		
	elseif floorIdx == 3 then
		-- Floor 3: processing units
		local unit1 = makePart(decorFolder, Vector3.new(12, 7, 12), CFrame.new(-18, yPos + 2, 10), Color3.fromRGB(180, 120, 100), Enum.Material.SmoothPlastic)
		createTextSign(unit1, "PROCESS", Vector2.new(500, 150))
		
		local unit2 = makePart(decorFolder, Vector3.new(12, 7, 12), CFrame.new(18, yPos + 2, 10), Color3.fromRGB(180, 120, 100), Enum.Material.SmoothPlastic)
		createTextSign(unit2, "PROCESS", Vector2.new(500, 150))
		
	elseif floorIdx == 4 then
		-- Floor 4: quality assurance
		local qa1 = makePart(decorFolder, Vector3.new(14, 6, 14), CFrame.new(-15, yPos + 2, -15), Color3.fromRGB(100, 180, 200), Enum.Material.SmoothPlastic)
		createTextSign(qa1, "QUALITY", Vector2.new(500, 150))
		
		local qa2 = makePart(decorFolder, Vector3.new(14, 6, 14), CFrame.new(15, yPos + 2, -15), Color3.fromRGB(100, 180, 200), Enum.Material.SmoothPlastic)
		createTextSign(qa2, "QUALITY", Vector2.new(500, 150))
		
	elseif floorIdx == 5 then
		-- Floor 5: tomboy lab
		local lab1 = makePart(decorFolder, Vector3.new(16, 7, 16), CFrame.new(-20, yPos + 2, 5), Color3.fromRGB(255, 150, 100), Enum.Material.Neon)
		lab1.Transparency = 0.1
		createTextSign(lab1, "TOMBOY", Vector2.new(600, 200))
		
		local lab2 = makePart(decorFolder, Vector3.new(16, 7, 16), CFrame.new(20, yPos + 2, 5), Color3.fromRGB(255, 150, 100), Enum.Material.Neon)
		lab2.Transparency = 0.1
		createTextSign(lab2, "TOMBOY", Vector2.new(600, 200))
	end
	
	floorData[floorIdx] = {
		yPos = yPos,
		floorBase = floorBase,
	}
end

-- Stairs connecting floors
for i = 1, CONFIG.TOTAL_FLOORS - 1 do
	for step = 0, 3 do
		local stairY = (i - 1) * CONFIG.BUILDING_HEIGHT + 1 + (step * 2)
		local stair = makePart(buildingsFolder, Vector3.new(12, 1, 8), CFrame.new(-25 + step * 3, stairY, 35), Color3.fromRGB(170, 170, 180), Enum.Material.SmoothPlastic)
		stair.CanCollide = true
	end
end

-- ============================================
-- PLOT SYSTEM
-- ============================================

local plotPositions = {
	Vector3.new(-50, 1.5, -50),
	Vector3.new(50, 1.5, -50),
	Vector3.new(-50, 1.5, 50),
	Vector3.new(50, 1.5, 50),
}

local plots = {}

for i = 1, CONFIG.MAX_PLOTS do
	local plot = Instance.new("Model")
	plot.Name = "Plot" .. i
	plot.Parent = plotFolder

	local pad = makePart(plot, Vector3.new(CONFIG.PLOT_SIZE, 1, CONFIG.PLOT_SIZE), CFrame.new(plotPositions[i]), Color3.fromRGB(76, 80, 90), Enum.Material.SmoothPlastic)
	pad.Name = "Pad"
	
	if i > 1 then
		pad.Transparency = 0.4
		pad.CanCollide = false
	end

	-- Counter
	local counter = makePart(plot, Vector3.new(16, 2, 8), CFrame.new(plotPositions[i] + Vector3.new(0, 1.5, 10)), Color3.fromRGB(58, 62, 68), Enum.Material.SmoothPlastic)
	counter.CanCollide = true

	-- Plot sign
	local sign = makePart(plot, Vector3.new(12, 3, 1), CFrame.new(plotPositions[i] + Vector3.new(0, 5, 12)), Color3.fromRGB(88, 162, 255), Enum.Material.Neon)
	sign.CanCollide = false
	
	local label = createTextSign(sign, "PLOT " .. i, Vector2.new(600, 200))
	if i > 1 then
		label.Text = "PLOT " .. i .. "\n[LOCKED]"
	end
	
	-- Storage area
	local storage = makePart(plot, Vector3.new(8, 3, 8), CFrame.new(plotPositions[i] + Vector3.new(-10, 2, -8)), Color3.fromRGB(120, 100, 80), Enum.Material.Wood)
	storage.CanCollide = true
	createTextSign(storage, "STORAGE", Vector2.new(400, 150))

	plots[i] = {
		model = plot,
		pad = pad,
		counter = counter,
		sign = sign,
		storage = storage,
		position = plotPositions[i],
		locked = i > 1,
	}
end

-- ============================================
-- ENVIRONMENT DECORATION
-- ============================================

-- Trees
local treePositions = {
	Vector3.new(-100, 0.5, -80),
	Vector3.new(-100, 0.5, 80),
	Vector3.new(100, 0.5, -80),
	Vector3.new(100, 0.5, 80),
	Vector3.new(-80, 0.5, -100),
	Vector3.new(80, 0.5, -100),
	Vector3.new(-80, 0.5, 100),
	Vector3.new(80, 0.5, 100),
}

for _, pos in ipairs(treePositions) do
	local trunk = makePart(decorFolder, Vector3.new(2, 15, 2), CFrame.new(pos + Vector3.new(0, 7, 0)), Color3.fromRGB(118, 83, 52), Enum.Material.Wood)
	trunk.CanCollide = false
	
	local leaves = makePart(decorFolder, Vector3.new(12, 10, 12), CFrame.new(pos + Vector3.new(0, 14, 0)), Color3.fromRGB(69, 146, 85), Enum.Material.Grass)
	leaves.CanCollide = false
	leaves.Shape = Enum.PartType.Ball
end

-- Lampposts
for x = -80, 80, 40 do
	for z = -80, 80, 40 do
		if math.abs(x) > 20 or math.abs(z) > 20 then
			local post = makePart(decorFolder, Vector3.new(1, 12, 1), CFrame.new(x, 6, z), Color3.fromRGB(60, 60, 60), Enum.Material.Concrete)
			post.CanCollide = false
			
			local light = makePart(decorFolder, Vector3.new(8, 2, 8), CFrame.new(x, 12, z), Color3.fromRGB(255, 255, 150), Enum.Material.Neon)
			light.Transparency = 0.3
			light.CanCollide = false
		end
	end
end

-- Benches
local benchPositions = {
	Vector3.new(-70, 1, -70),
	Vector3.new(70, 1, 70),
	Vector3.new(-70, 1, 70),
	Vector3.new(70, 1, -70),
}

for _, pos in ipairs(benchPositions) do
	local bench = makePart(decorFolder, Vector3.new(16, 2, 6), CFrame.new(pos), Color3.fromRGB(100, 80, 60), Enum.Material.Wood)
	bench.CanCollide = false
end

-- ============================================
-- PLAYER SPAWN
-- ============================================

local spawnPoint = CFrame.new(0, 7, 70)

local function teleportToSpawn(character)
	task.wait(0.3)
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart then
		humanoidRootPart.CFrame = spawnPoint
	end
end

-- ============================================
-- PRODUCTION LOOP
-- ============================================

local function productionTick()
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = getProfile(player)
		local production = getProductionRate(player)
		if production > 0 then
			addMilk(player, production)
		end
	end
end

task.spawn(function()
	while true do
		task.wait(CONFIG.PRODUCTION_TICK)
		productionTick()
	end
end)

print("✓ Femboy Milk Tycoon - Main Script Loaded")
print("✓ World generated with " .. CONFIG.TOTAL_FLOORS .. " floors and " .. CONFIG.MAX_PLOTS .. " plots")
