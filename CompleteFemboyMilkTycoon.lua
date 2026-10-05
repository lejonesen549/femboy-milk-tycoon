-- ============================================
-- FEMBOY MILK TYCOON - COMPLETE GAME SCRIPT
-- Place in ServerScriptService
-- ============================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

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
	HasGUI = false,
}

local function getProfile(player)
	local key = tostring(player.UserId)
	if not playerData[key] then
		playerData[key] = {}
		for k, v in pairs(DEFAULT_PROFILE) do
			if type(v) == "table" then
				playerData[key][k] = {}
				for tk, tv in pairs(v) do
					playerData[key][k][tk] = tv
				end
			else
				playerData[key][k] = v
			end
		end
	end
	return playerData[key]
end

local function addMoney(player, amount)
	local profile = getProfile(player)
	profile.Cash = profile.Cash + amount
	profile.TotalCash = profile.TotalCash + amount
end

local function subtractMoney(player, amount)
	local profile = getProfile(player)
	profile.Cash = math.max(0, profile.Cash - amount)
end

local function addMilk(player, amount)
	local profile = getProfile(player)
	profile.Milk = profile.Milk + amount
	profile.TotalMilk = profile.TotalMilk + amount
end

local function subtractMilk(player, amount)
	local profile = getProfile(player)
	profile.Milk = math.max(0, profile.Milk - amount)
end

local function getProductionRate(player)
	local p = getProfile(player)
	local workerProduction = (p.FemboyWorkers * CONFIG.FEMBOY_PRODUCTION) + (p.TomboyWorkers * CONFIG.TOMBOY_PRODUCTION)
	local storeMultiplier = CONFIG.STORE_MULTIPLIER ^ p.StoreLevel
	return math.floor(workerProduction * storeMultiplier * p.PrestigeMultiplier)
end

local function getFemboyCost(player)
	local p = getProfile(player)
	return CONFIG.FEMBOY_BASE_COST + (p.FemboyWorkers * CONFIG.FEMBOY_SCALE)
end

local function getTomboyCost(player)
	local p = getProfile(player)
	return CONFIG.TOMBOY_BASE_COST + (p.TomboyWorkers * CONFIG.TOMBOY_SCALE)
end

local function getRebirthCost(player)
	local p = getProfile(player)
	return CONFIG.REBIRTH_BASE_COST + (p.Rebirths * CONFIG.REBIRTH_SCALE)
end

-- ============================================
-- WORLD GENERATION SYSTEM
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

local function makePart(parent, size, cframe, color, material, transparency, canCollide)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = canCollide ~= false
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
local groundBase = makePart(tycoonModel, Vector3.new(200, 4, 200), CFrame.new(0, -2, 0), Color3.fromRGB(100, 110, 120), Enum.Material.Slate, 0, true)
groundBase.Name = "GroundBase"

-- Grass area
for x = -8, 8 do
	for z = -8, 8 do
		if (x * x + z * z) > 10 then
			local tile = makePart(tycoonModel, Vector3.new(10, 1, 10), CFrame.new(x * 10, 0.5, z * 10), Color3.fromRGB(85, 145, 75), Enum.Material.Grass, 0, false)
		end
	end
end

-- Spawn pad
local spawnPad = makePart(tycoonModel, Vector3.new(40, 1, 40), CFrame.new(0, 1, 70), Color3.fromRGB(80, 90, 110), Enum.Material.Slate, 0, true)
spawnPad.Name = "SpawnPad"
createTextSign(spawnPad, "SPAWN AREA", Vector2.new(400, 100))

-- Main building lot
local mainLot = makePart(tycoonModel, Vector3.new(120, 1, 120), CFrame.new(0, 1, 0), Color3.fromRGB(65, 72, 82), Enum.Material.Pavement, 0, true)
mainLot.CanCollide = true

-- Floor generation
local floorData = {}

for floorIdx = 1, CONFIG.TOTAL_FLOORS do
	local yPos = (floorIdx - 1) * CONFIG.BUILDING_HEIGHT + 1
	
	-- Floor base
	local floorBase = makePart(buildingsFolder, Vector3.new(80, 1, 80), CFrame.new(0, yPos, 0), Color3.fromRGB(81, 90, 108), Enum.Material.Slate, 0, true)
	floorBase.Name = "FloorBase_" .. floorIdx
	
	-- Ceiling
	local ceiling = makePart(buildingsFolder, Vector3.new(80, 1, 80), CFrame.new(0, yPos + 9, 0), Color3.fromRGB(112, 122, 138), Enum.Material.SmoothPlastic, 0.15, false)
	ceiling.Name = "FloorCeiling_" .. floorIdx
	
	-- Walls
	makePart(buildingsFolder, Vector3.new(70, 9, 1), CFrame.new(0, yPos + 4.5, -40), Color3.fromRGB(124, 132, 145), Enum.Material.SmoothPlastic, 0, false)
	makePart(buildingsFolder, Vector3.new(70, 9, 1), CFrame.new(0, yPos + 4.5, 40), Color3.fromRGB(124, 132, 145), Enum.Material.SmoothPlastic, 0, false)
	makePart(buildingsFolder, Vector3.new(1, 9, 70), CFrame.new(-40, yPos + 4.5, 0), Color3.fromRGB(124, 132, 145), Enum.Material.SmoothPlastic, 0, false)
	makePart(buildingsFolder, Vector3.new(1, 9, 70), CFrame.new(40, yPos + 4.5, 0), Color3.fromRGB(124, 132, 145), Enum.Material.SmoothPlastic, 0, false)
	
	-- Glass windows
	local glassFront = makePart(buildingsFolder, Vector3.new(50, 8, 0.5), CFrame.new(0, yPos + 4.5, -39.75), Color3.fromRGB(153, 206, 255), Enum.Material.Glass, 0.3, false)
	local glassBack = makePart(buildingsFolder, Vector3.new(50, 8, 0.5), CFrame.new(0, yPos + 4.5, 39.75), Color3.fromRGB(153, 206, 255), Enum.Material.Glass, 0.3, false)
	
	-- Floor sign
	local floorSign = makePart(buildingsFolder, Vector3.new(16, 4, 1), CFrame.new(0, yPos + 8, -39.5), Color3.fromRGB(255, 88, 186), Enum.Material.Neon, 0, false)
	local floorName = "FLOOR " .. floorIdx
	if floorIdx == 1 then floorName = "MAIN HQ" end
	if floorIdx == 5 then floorName = "TOMBOY LAB - SUPER PRODUCERS!" end
	createTextSign(floorSign, floorName, Vector2.new(800, 200))
	
	-- Corner pillars
	makePart(buildingsFolder, Vector3.new(4, 10, 4), CFrame.new(-35, yPos + 4.5, -35), Color3.fromRGB(160, 170, 180), Enum.Material.Concrete, 0, false)
	makePart(buildingsFolder, Vector3.new(4, 10, 4), CFrame.new(35, yPos + 4.5, -35), Color3.fromRGB(160, 170, 180), Enum.Material.Concrete, 0, false)
	makePart(buildingsFolder, Vector3.new(4, 10, 4), CFrame.new(-35, yPos + 4.5, 35), Color3.fromRGB(160, 170, 180), Enum.Material.Concrete, 0, false)
	makePart(buildingsFolder, Vector3.new(4, 10, 4), CFrame.new(35, yPos + 4.5, 35), Color3.fromRGB(160, 170, 180), Enum.Material.Concrete, 0, false)
	
	-- Floor-specific decorations
	if floorIdx == 1 then
		-- Main floor: milk storage tanks
		local tank1 = makePart(decorFolder, Vector3.new(15, 8, 15), CFrame.new(-25, yPos + 2, -20), Color3.fromRGB(220, 240, 255), Enum.Material.SmoothPlastic, 0.2, false)
		createTextSign(tank1, "MILK TANK", Vector2.new(600, 200))
		
		local tank2 = makePart(decorFolder, Vector3.new(15, 8, 15), CFrame.new(25, yPos + 2, -20), Color3.fromRGB(220, 240, 255), Enum.Material.SmoothPlastic, 0.2, false)
		createTextSign(tank2, "MILK TANK", Vector2.new(600, 200))
		
		local control = makePart(decorFolder, Vector3.new(8, 6, 8), CFrame.new(0, yPos + 1, 25), Color3.fromRGB(100, 100, 100), Enum.Material.Metal, 0, false)
		createTextSign(control, "CONTROL", Vector2.new(400, 150))
		
	elseif floorIdx == 2 then
		-- Floor 2: production machines
		local pump1 = makePart(decorFolder, Vector3.new(10, 8, 10), CFrame.new(-20, yPos + 2, 0), Color3.fromRGB(140, 160, 180), Enum.Material.Metal, 0, false)
		createTextSign(pump1, "PUMP 1", Vector2.new(400, 150))
		
		local pump2 = makePart(decorFolder, Vector3.new(10, 8, 10), CFrame.new(20, yPos + 2, 0), Color3.fromRGB(140, 160, 180), Enum.Material.Metal, 0, false)
		createTextSign(pump2, "PUMP 2", Vector2.new(400, 150))
		
		local pump3 = makePart(decorFolder, Vector3.new(10, 8, 10), CFrame.new(0, yPos + 2, 20), Color3.fromRGB(140, 160, 180), Enum.Material.Metal, 0, false)
		createTextSign(pump3, "PUMP 3", Vector2.new(400, 150))
		
	elseif floorIdx == 3 then
		-- Floor 3: processing units
		local unit1 = makePart(decorFolder, Vector3.new(12, 7, 12), CFrame.new(-18, yPos + 2, 10), Color3.fromRGB(180, 120, 100), Enum.Material.SmoothPlastic, 0, false)
		createTextSign(unit1, "PROCESSOR", Vector2.new(500, 150))
		
		local unit2 = makePart(decorFolder, Vector3.new(12, 7, 12), CFrame.new(18, yPos + 2, 10), Color3.fromRGB(180, 120, 100), Enum.Material.SmoothPlastic, 0, false)
		createTextSign(unit2, "PROCESSOR", Vector2.new(500, 150))
		
		local unit3 = makePart(decorFolder, Vector3.new(12, 7, 12), CFrame.new(0, yPos + 2, -15), Color3.fromRGB(180, 120, 100), Enum.Material.SmoothPlastic, 0, false)
		createTextSign(unit3, "PROCESSOR", Vector2.new(500, 150))
		
	elseif floorIdx == 4 then
		-- Floor 4: quality assurance
		local qa1 = makePart(decorFolder, Vector3.new(14, 6, 14), CFrame.new(-15, yPos + 2, -15), Color3.fromRGB(100, 180, 200), Enum.Material.SmoothPlastic, 0, false)
		createTextSign(qa1, "QUALITY", Vector2.new(500, 150))
		
		local qa2 = makePart(decorFolder, Vector3.new(14, 6, 14), CFrame.new(15, yPos + 2, -15), Color3.fromRGB(100, 180, 200), Enum.Material.SmoothPlastic, 0, false)
		createTextSign(qa2, "QUALITY", Vector2.new(500, 150))
		
		local qa3 = makePart(decorFolder, Vector3.new(14, 6, 14), CFrame.new(0, yPos + 2, 20), Color3.fromRGB(100, 180, 200), Enum.Material.SmoothPlastic, 0, false)
		createTextSign(qa3, "QUALITY", Vector2.new(500, 150))
		
	elseif floorIdx == 5 then
		-- Floor 5: tomboy lab - ultra powerful
		local lab1 = makePart(decorFolder, Vector3.new(16, 7, 16), CFrame.new(-20, yPos + 2, 5), Color3.fromRGB(255, 150, 100), Enum.Material.Neon, 0.1, false)
		createTextSign(lab1, "TOMBOY 🔥", Vector2.new(600, 200))
		
		local lab2 = makePart(decorFolder, Vector3.new(16, 7, 16), CFrame.new(20, yPos + 2, 5), Color3.fromRGB(255, 150, 100), Enum.Material.Neon, 0.1, false)
		createTextSign(lab2, "TOMBOY 🔥", Vector2.new(600, 200))
		
		local lab3 = makePart(decorFolder, Vector3.new(16, 7, 16), CFrame.new(0, yPos + 2, -20), Color3.fromRGB(255, 150, 100), Enum.Material.Neon, 0.1, false)
		createTextSign(lab3, "TOMBOY 🔥", Vector2.new(600, 200))
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
		makePart(buildingsFolder, Vector3.new(12, 1, 8), CFrame.new(-25 + step * 3, stairY, 35), Color3.fromRGB(170, 170, 180), Enum.Material.SmoothPlastic, 0, true)
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

	local pad = makePart(plot, Vector3.new(CONFIG.PLOT_SIZE, 1, CONFIG.PLOT_SIZE), CFrame.new(plotPositions[i]), Color3.fromRGB(76, 80, 90), Enum.Material.SmoothPlastic, i > 1 and 0.4 or 0, i == 1)
	pad.Name = "Pad"

	-- Counter
	local counter = makePart(plot, Vector3.new(16, 2, 8), CFrame.new(plotPositions[i] + Vector3.new(0, 1.5, 10)), Color3.fromRGB(58, 62, 68), Enum.Material.SmoothPlastic, 0, true)

	-- Plot sign
	local sign = makePart(plot, Vector3.new(12, 3, 1), CFrame.new(plotPositions[i] + Vector3.new(0, 5, 12)), Color3.fromRGB(88, 162, 255), Enum.Material.Neon, 0, false)
	local label = createTextSign(sign, "PLOT " .. i, Vector2.new(600, 200))
	if i > 1 then
		label.Text = "PLOT " .. i .. "\n[LOCKED]"
	end
	
	-- Storage area
	local storage = makePart(plot, Vector3.new(8, 3, 8), CFrame.new(plotPositions[i] + Vector3.new(-10, 2, -8)), Color3.fromRGB(120, 100, 80), Enum.Material.Wood, 0, false)
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
	local trunk = makePart(decorFolder, Vector3.new(2, 15, 2), CFrame.new(pos + Vector3.new(0, 7, 0)), Color3.fromRGB(118, 83, 52), Enum.Material.Wood, 0, false)
	local leaves = makePart(decorFolder, Vector3.new(12, 10, 12), CFrame.new(pos + Vector3.new(0, 14, 0)), Color3.fromRGB(69, 146, 85), Enum.Material.Grass, 0, false)
	leaves.Shape = Enum.PartType.Ball
end

-- Lampposts
for x = -80, 80, 40 do
	for z = -80, 80, 40 do
		if math.abs(x) > 20 or math.abs(z) > 20 then
			local post = makePart(decorFolder, Vector3.new(1, 12, 1), CFrame.new(x, 6, z), Color3.fromRGB(60, 60, 60), Enum.Material.Concrete, 0, false)
			local light = makePart(decorFolder, Vector3.new(8, 2, 8), CFrame.new(x, 12, z), Color3.fromRGB(255, 255, 150), Enum.Material.Neon, 0.3, false)
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
	local bench = makePart(decorFolder, Vector3.new(16, 2, 6), CFrame.new(pos), Color3.fromRGB(100, 80, 60), Enum.Material.Wood, 0, false)
end

-- ============================================
-- PLAYER SPAWN HANDLING
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
-- GUI SYSTEM
-- ============================================

local function createPlayerGUI(player)
	local playerGui = player:WaitForChild("PlayerGui")
	
	-- Main Screen GUI
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TycoonGui"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	-- Main stats frame
	local statsFrame = Instance.new("Frame")
	statsFrame.Name = "StatsFrame"
	statsFrame.Size = UDim2.new(0, 450, 0, 280)
	statsFrame.Position = UDim2.new(1, -470, 0, 20)
	statsFrame.BackgroundColor3 = Color3.fromRGB(24, 27, 33)
	statsFrame.BorderSizePixel = 0
	statsFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = statsFrame

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 15)
	padding.PaddingRight = UDim.new(0, 15)
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.Parent = statsFrame

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Text = "FEMBOY MILK TYCOON"
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 100, 200)
	title.Parent = statsFrame

	-- Stats text
	local statsLabel = Instance.new("TextLabel")
	statsLabel.Name = "Stats"
	statsLabel.Size = UDim2.new(1, 0, 0, 120)
	statsLabel.Position = UDim2.new(0, 0, 0, 45)
	statsLabel.BackgroundTransparency = 1
	statsLabel.Text = "Loading..."
	statsLabel.Font = Enum.Font.Gotham
	statsLabel.TextSize = 16
	statsLabel.TextWrapped = true
	statsLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.TextYAlignment = Enum.TextYAlignment.Top
	statsLabel.Parent = statsFrame

	-- Buttons frame
	local buttonsFrame = Instance.new("Frame")
	buttonsFrame.Name = "ButtonsFrame"
	buttonsFrame.Size = UDim2.new(1, 0, 0, 95)
	buttonsFrame.Position = UDim2.new(0, 0, 1, -95)
	buttonsFrame.BackgroundTransparency = 1
	buttonsFrame.Parent = statsFrame

	local buttonLayout = Instance.new("UIGridLayout")
	buttonLayout.CellSize = UDim2.new(0.5, -5, 0.5, -5)
	buttonLayout.CellPadding = UDim2.new(0, 10, 0, 10)
	buttonLayout.FillDirection = Enum.FillDirection.Horizontal
	buttonLayout.FillDirectionMaxCells = 2
	buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	buttonLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	buttonLayout.Parent = buttonsFrame

	-- Hire Femboy Button
	local hireBtn = Instance.new("TextButton")
	hireBtn.Name = "HireFemboy"
	hireBtn.Size = UDim2.new(1, 0, 1, 0)
	hireBtn.Text = "Hire Femboy\n$0"
	hireBtn.BackgroundColor3 = Color3.fromRGB(93, 166, 255)
	hireBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	hireBtn.Font = Enum.Font.GothamBold
	hireBtn.TextSize = 14
	hireBtn.Parent = buttonsFrame

	local btnCorner1 = Instance.new("UICorner")
	btnCorner1.CornerRadius = UDim.new(0, 8)
	btnCorner1.Parent = hireBtn

	-- Hire Tomboy Button
	local tomboyBtn = Instance.new("TextButton")
	tomboyBtn.Name = "HireTomboy"
	tomboyBtn.Size = UDim2.new(1, 0, 1, 0)
	tomboyBtn.Text = "Hire Tomboy\n$0"
	tomboyBtn.BackgroundColor3 = Color3.fromRGB(255, 107, 198)
	tomboyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	tomboyBtn.Font = Enum.Font.GothamBold
	tomboyBtn.TextSize = 14
	tomboyBtn.Parent = buttonsFrame

	local btnCorner2 = Instance.new("UICorner")
	btnCorner2.CornerRadius = UDim.new(0, 8)
	btnCorner2.Parent = tomboyBtn

	-- Collect Button
	local collectBtn = Instance.new("TextButton")
	collectBtn.Name = "Collect"
	collectBtn.Size = UDim2.new(1, 0, 0, 40)
	collectBtn.Position = UDim2.new(0, 0, 1, -40)
	collectBtn.BackgroundColor3 = Color3.fromRGB(56, 208, 117)
	collectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	collectBtn.Font = Enum.Font.GothamBold
	collectBtn.Text = "Collect Milk to Cash"
	collectBtn.TextSize = 14
	collectBtn.Parent = statsFrame

	local collectCorner = Instance.new("UICorner")
	collectCorner.CornerRadius = UDim.new(0, 8)
	collectCorner.Parent = collectBtn

	-- Rebirth Button (separate frame)
	local rebirthFrame = Instance.new("Frame")
	rebirthFrame.Name = "RebirthFrame"
	rebirthFrame.Size = UDim2.new(0, 450, 0, 80)
	rebirthFrame.Position = UDim2.new(1, -470, 0, 310)
	rebirthFrame.BackgroundColor3 = Color3.fromRGB(24, 27, 33)
	rebirthFrame.BorderSizePixel = 0
	rebirthFrame.Parent = screenGui

	local rebirthCorner = Instance.new("UICorner")
	rebirthCorner.CornerRadius = UDim.new(0, 14)
	rebirthCorner.Parent = rebirthFrame

	local rebirthLabel = Instance.new("TextLabel")
	rebirthLabel.Name = "Label"
	rebirthLabel.Size = UDim2.new(1, -30, 0, 25)
	rebirthLabel.Position = UDim2.new(0, 15, 0, 8)
	rebirthLabel.BackgroundTransparency = 1
	rebirthLabel.Text = "Prestige: 0x Multiplier"
	rebirthLabel.Font = Enum.Font.GothamBold
	rebirthLabel.TextSize = 14
	rebirthLabel.TextColor3 = Color3.fromRGB(255, 190, 75)
	rebirthLabel.Parent = rebirthFrame

	local rebirthBtn = Instance.new("TextButton")
	rebirthBtn.Name = "Rebirth"
	rebirthBtn.Size = UDim2.new(1, -30, 0, 40)
	rebirthBtn.Position = UDim2.new(0, 15, 0, 35)
	rebirthBtn.BackgroundColor3 = Color3.fromRGB(255, 190, 75)
	rebirthBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	rebirthBtn.Font = Enum.Font.GothamBold
	rebirthBtn.Text = "Rebirth / Prestige (Requires Milk)"
	rebirthBtn.TextSize = 14
	rebirthBtn.Parent = rebirthFrame

	local rebirthBtnCorner = Instance.new("UICorner")
	rebirthBtnCorner.CornerRadius = UDim.new(0, 8)
	rebirthBtnCorner.Parent = rebirthBtn

	-- ============================================
	-- GUI UPDATE FUNCTIONS
	-- ============================================

	local function updateStats()
		local profile = getProfile(player)
		local production = getProductionRate(player)
		local femboyC = getFemboyCost(player)
		local tomboyC = getTomboyCost(player)

		statsLabel.Text = string.format(
			"💰 Cash: $%d\n🥛 Milk: %d\n⚡ Production: %d/sec\n👗 Femboys: %d | 🧥 Tomboys: %d\n📊 Store Level: %d",
			profile.Cash,
			profile.Milk,
			production,
			profile.FemboyWorkers,
			profile.TomboyWorkers,
			profile.StoreLevel
		)

		hireBtn.Text = "Hire Femboy\n$" .. femboyC
		tomboyBtn.Text = "Hire Tomboy\n$" .. tomboyC

		rebirthLabel.Text = string.format("Prestige: %.1fx Multiplier | Rebirths: %d", profile.PrestigeMultiplier, profile.Rebirths)

		if profile.Cash >= femboyC then
			hireBtn.BackgroundColor3 = Color3.fromRGB(120, 190, 255)
		else
			hireBtn.BackgroundColor3 = Color3.fromRGB(93, 166, 255)
		end

		if profile.Cash >= tomboyC then
			tomboyBtn.BackgroundColor3 = Color3.fromRGB(255, 130, 215)
		else
			tomboyBtn.BackgroundColor3 = Color3.fromRGB(255, 107, 198)
		end
	end

	local function hireFemboy()
		local profile = getProfile(player)
		local cost = getFemboyCost(player)
		if profile.Cash >= cost then
			subtractMoney(player, cost)
			profile.FemboyWorkers = profile.FemboyWorkers + 1
			profile.Level = profile.Level + 1
			updateStats()
		end
	end

	local function hireTomboy()
		local profile = getProfile(player)
		local cost = getTomboyCost(player)
		if profile.Cash >= cost then
			subtractMoney(player, cost)
			profile.TomboyWorkers = profile.TomboyWorkers + 1
			profile.Level = profile.Level + 2
			updateStats()
		end
	end

	local function collect()
		local profile = getProfile(player)
		if profile.Milk > 0 then
			local value = math.floor(profile.Milk * CONFIG.CASH_CONVERSION)
			addMoney(player, value)
			subtractMilk(player, profile.Milk)
		end
		updateStats()
	end

	local function rebirth()
		local profile = getProfile(player)
		local cost = getRebirthCost(player)
		if profile.Milk >= cost then
			subtractMilk(player, cost)
			profile.Rebirths = profile.Rebirths + 1
			profile.PrestigeMultiplier = 1 + (profile.Rebirths * CONFIG.PRESTIGE_MULTIPLIER)
			profile.StoreLevel = profile.StoreLevel + 1
			profile.FemboyWorkers = 0
			profile.TomboyWorkers = 0
			profile.Cash = 0
			profile.Level = 1
			updateStats()
		end
	end

	hireBtn.MouseButton1Click:Connect(hireFemboy)
	tomboyBtn.MouseButton1Click:Connect(hireTomboy)
	collectBtn.MouseButton1Click:Connect(collect)
	rebirthBtn.MouseButton1Click:Connect(rebirth)

	updateStats()

	-- Auto refresh
	task.spawn(function()
		while screenGui and screenGui.Parent do
			task.wait(1)
			updateStats()
		end
	end)

	return screenGui
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

-- ============================================
-- PLAYER MANAGEMENT
-- ============================================

Players.PlayerAdded:Connect(function(player)
	task.wait(0.5)
	getProfile(player)
	
	player.CharacterAdded:Connect(function(character)
		teleportToSpawn(character)
	end)

	task.wait(1)
	createPlayerGUI(player)
end)

Players.PlayerRemoving:Connect(function(player)
	-- Save data (optional - implement database here)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.wait(0.3)
	getProfile(player)
	createPlayerGUI(player)
	
	if player.Character then
		teleportToSpawn(player.Character)
	end
end

print("✅ Femboy Milk Tycoon - COMPLETE SCRIPT LOADED")
print("✅ World: 5 Floors | 4 Plots | Full Production System")
print("✅ Players can now join and start their tycoon!")
