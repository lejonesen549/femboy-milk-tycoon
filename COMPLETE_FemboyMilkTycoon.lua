-- ============================================
-- FEMBOY MILK TYCOON - MULTIPLAYER PLOT EDITION
-- Place in ServerScriptService
-- Each player gets their own private plot with building
-- ============================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- ============================================
-- CONFIGURATION - ALL SETTINGS HERE
-- ============================================

local CONFIG = {
	TOTAL_PLOTS = 8,
	PLOT_SIZE = 50,
	BUILDING_HEIGHT = 18,
	PRODUCTION_TICK = 1,
	
	-- Starting money so players can actually play
	STARTING_CASH = 1000,
	
	-- Costs
	FEMBOY_BASE_COST = 200,
	FEMBOY_SCALE = 120,
	TOMBOY_BASE_COST = 2500,
	TOMBOY_SCALE = 2000,
	REBIRTH_BASE_COST = 50000,
	REBIRTH_SCALE = 30000,
	UPGRADE_BASE_COST = 500,
	
	-- Production rates
	FEMBOY_PRODUCTION = 2,
	TOMBOY_PRODUCTION = 12,
	STORE_MULTIPLIER = 1.2,
	PRESTIGE_MULTIPLIER = 0.35,
	CASH_CONVERSION = 1.45,
	
	-- Decor items with costs
	DECOR_ITEMS = {
		{name = "Pink Neon Light", cost = 500, color = Color3.fromRGB(255, 100, 200)},
		{name = "Gold Statue", cost = 1500, color = Color3.fromRGB(255, 200, 0)},
		{name = "Fountain", cost = 3000, color = Color3.fromRGB(100, 200, 255)},
		{name = "Rainbow Orb", cost = 5000, color = Color3.fromRGB(255, 100, 255)},
		{name = "Diamond Block", cost = 10000, color = Color3.fromRGB(200, 255, 255)},
		{name = "Glowing Cube", cost = 15000, color = Color3.fromRGB(100, 255, 100)},
		{name = "Premium Lamp", cost = 20000, color = Color3.fromRGB(255, 255, 0)},
		{name = "Crystal Ball", cost = 35000, color = Color3.fromRGB(255, 150, 200)},
	},
}

-- ============================================
-- PLAYER DATA SYSTEM
-- ============================================

local playerData = {}
local plotOwnership = {} -- Maps plot number to player userId

local DEFAULT_PROFILE = {
	Cash = CONFIG.STARTING_CASH,
	Milk = 0,
	Rebirths = 0,
	Level = 1,
	Production = 0,
	OwnedPlot = 0,
	FemboyWorkers = 0,
	TomboyWorkers = 0,
	BuildingLevel = 1,
	PrestigeMultiplier = 1,
	TotalMilk = 0,
	TotalCash = CONFIG.STARTING_CASH,
	OwnedDecor = {},
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
	local storeMultiplier = CONFIG.STORE_MULTIPLIER ^ p.BuildingLevel
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

local pathwayFolder = Instance.new("Folder")
pathwayFolder.Name = "Pathways"
pathwayFolder.Parent = tycoonModel

local decorFolder = Instance.new("Folder")
decorFolder.Name = "Decorations"
decorFolder.Parent = tycoonModel

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
	label.TextStrokeTransparency = 0.3
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.Parent = gui
	return label
end

-- Ground base
local groundBase = makePart(tycoonModel, Vector3.new(400, 2, 400), CFrame.new(0, -1, 0), Color3.fromRGB(60, 70, 60), Enum.Material.Grass, 0, true)
groundBase.Name = "GroundBase"

-- Spawn area in center
local spawnPad = makePart(tycoonModel, Vector3.new(40, 1, 40), CFrame.new(0, 1, 0), Color3.fromRGB(100, 120, 100), Enum.Material.Slate, 0, true)
spawnPad.Name = "SpawnPad"
createTextSign(spawnPad, "HUB - CLAIM YOUR PLOT!", Vector2.new(400, 100))

-- Generate 8 plots in a circle
local plotPositions = {}
local centerX, centerZ = 0, 0
local radius = 120

for i = 1, CONFIG.TOTAL_PLOTS do
	local angle = (i - 1) * (2 * math.pi / CONFIG.TOTAL_PLOTS)
	local x = centerX + radius * math.cos(angle)
	local z = centerZ + radius * math.sin(angle)
	table.insert(plotPositions, Vector3.new(x, 0, z))
end

-- Create pathways connecting plots in a circle
for i = 1, CONFIG.TOTAL_PLOTS do
	local nextI = i == CONFIG.TOTAL_PLOTS and 1 or i + 1
	local startPos = plotPositions[i]
	local endPos = plotPositions[nextI]
	
	-- Create pathway segment
	local midX = (startPos.X + endPos.X) / 2
	local midZ = (startPos.Z + endPos.Z) / 2
	local distance = math.sqrt((endPos.X - startPos.X)^2 + (endPos.Z - startPos.Z)^2)
	
	local pathway = makePart(pathwayFolder, Vector3.new(6, 0.5, distance + 10), CFrame.new(midX, 0.75, midZ), Color3.fromRGB(120, 100, 80), Enum.Material.Concrete, 0, false)
	pathways = pathways or {}
	table.insert(pathways, pathway)
end

-- Create pathway from center to each plot
for i, pos in ipairs(plotPositions) do
	local distance = math.sqrt(pos.X^2 + pos.Z^2)
	local midX = pos.X / 2
	local midZ = pos.Z / 2
	local pathway = makePart(pathwayFolder, Vector3.new(6, 0.5, distance), CFrame.new(midX, 0.75, midZ), Color3.fromRGB(120, 100, 80), Enum.Material.Concrete, 0, false)
end

-- ============================================
-- PLOT CLAIM SYSTEM
-- ============================================

local plots = {}

for i = 1, CONFIG.TOTAL_PLOTS do
	local pos = plotPositions[i]
	
	local plot = Instance.new("Model")
	plot.Name = "Plot" .. i
	plot.Parent = plotFolder

	-- Plot ground pad
	local pad = makePart(plot, Vector3.new(CONFIG.PLOT_SIZE, 1, CONFIG.PLOT_SIZE), CFrame.new(pos.X, 1, pos.Z), Color3.fromRGB(76, 90, 100), Enum.Material.Slate, 0, true)
	pad.Name = "Pad"

	-- Plot claim sign
	local claimSign = makePart(plot, Vector3.new(14, 4, 1), CFrame.new(pos.X, 5, pos.Z - CONFIG.PLOT_SIZE/2 + 2), Color3.fromRGB(100, 200, 255), Enum.Material.Neon, 0, false)
	claimSign.Name = "ClaimSign"
	local claimLabel = createTextSign(claimSign, "PLOT " .. i .. "\n[UNCLAIMED]\nCLICK TO CLAIM", Vector2.new(700, 250))

	-- Storage marker
	local storage = makePart(plot, Vector3.new(8, 3, 8), CFrame.new(pos.X - 15, 2, pos.Z), Color3.fromRGB(120, 100, 80), Enum.Material.Wood, 0, true)
	storage.Name = "StorageMarker"

	plots[i] = {
		model = plot,
		pad = pad,
		claimSign = claimSign,
		claimLabel = claimLabel,
		storage = storage,
		position = Vector3.new(pos.X, 2, pos.Z),
		owner = nil,
		buildingLevel = 1,
	}
end

-- ============================================
-- ENVIRONMENT DECORATION
-- ============================================

-- Trees around the world
local treePositions = {
	Vector3.new(-180, 0, -180), Vector3.new(-180, 0, 180), Vector3.new(180, 0, -180), Vector3.new(180, 0, 180),
	Vector3.new(-140, 0, 0), Vector3.new(140, 0, 0), Vector3.new(0, 0, -140), Vector3.new(0, 0, 140),
}

for _, tpos in ipairs(treePositions) do
	local trunk = makePart(decorFolder, Vector3.new(3, 20, 3), CFrame.new(tpos + Vector3.new(0, 10, 0)), Color3.fromRGB(118, 83, 52), Enum.Material.Wood, 0, false)
	local leaves = makePart(decorFolder, Vector3.new(16, 14, 16), CFrame.new(tpos + Vector3.new(0, 18, 0)), Color3.fromRGB(69, 146, 85), Enum.Material.Grass, 0, false)
	leaves.Shape = Enum.PartType.Ball
end

-- Lampposts at intervals
for i = 1, CONFIG.TOTAL_PLOTS do
	local pos = plotPositions[i]
	local post = makePart(decorFolder, Vector3.new(1.5, 16, 1.5), CFrame.new(pos.X, 8, pos.Z + 25), Color3.fromRGB(60, 60, 60), Enum.Material.Concrete, 0, false)
	local light = makePart(decorFolder, Vector3.new(8, 2, 8), CFrame.new(pos.X, 16, pos.Z + 25), Color3.fromRGB(255, 255, 150), Enum.Material.Neon, 0.2, false)
end

-- ============================================
-- PLAYER BUILDING SYSTEM
-- ============================================

local function buildPlayerBuilding(plotNumber, player)
	local plot = plots[plotNumber]
	local profile = getProfile(player)
	local buildingFolder = Instance.new("Folder")
	buildingFolder.Name = "Building_" .. player.UserId
	buildingFolder.Parent = plot.model
	
	local pos = plot.position
	
	-- Base floor
	local baseFloor = makePart(buildingFolder, Vector3.new(30, 1, 30), CFrame.new(pos.X, pos.Y, pos.Z), Color3.fromRGB(90, 100, 120), Enum.Material.Slate, 0, true)
	baseFloor.Name = "BaseFloor"
	
	-- Main building structure
	for floorIdx = 1, profile.BuildingLevel do
		local yPos = pos.Y + (floorIdx - 1) * CONFIG.BUILDING_HEIGHT
		
		-- Floor
		local floor = makePart(buildingFolder, Vector3.new(28, 1, 28), CFrame.new(pos.X, yPos, pos.Z), Color3.fromRGB(81, 90, 108), Enum.Material.Slate, 0, true)
		floor.Name = "Floor_" .. floorIdx
		
		-- Ceiling
		local ceiling = makePart(buildingFolder, Vector3.new(28, 1, 28), CFrame.new(pos.X, yPos + 8, pos.Z), Color3.fromRGB(112, 122, 138), Enum.Material.SmoothPlastic, 0.1, false)
		
		-- Walls
		makePart(buildingFolder, Vector3.new(26, 8, 1), CFrame.new(pos.X, yPos + 4, pos.Z - 14), Color3.fromRGB(124, 132, 145), Enum.Material.SmoothPlastic, 0, true)
		makePart(buildingFolder, Vector3.new(26, 8, 1), CFrame.new(pos.X, yPos + 4, pos.Z + 14), Color3.fromRGB(124, 132, 145), Enum.Material.SmoothPlastic, 0, true)
		makePart(buildingFolder, Vector3.new(1, 8, 26), CFrame.new(pos.X - 14, yPos + 4, pos.Z), Color3.fromRGB(124, 132, 145), Enum.Material.SmoothPlastic, 0, true)
		makePart(buildingFolder, Vector3.new(1, 8, 26), CFrame.new(pos.X + 14, yPos + 4, pos.Z), Color3.fromRGB(124, 132, 145), Enum.Material.SmoothPlastic, 0, true)
		
		-- Glass window
		local glass = makePart(buildingFolder, Vector3.new(20, 6, 0.5), CFrame.new(pos.X, yPos + 4, pos.Z - 13.75), Color3.fromRGB(153, 206, 255), Enum.Material.Glass, 0.25, false)
		
		-- Floor sign
		local floorColor = Color3.fromRGB(255, 100, 200)
		if floorIdx == 1 then floorColor = Color3.fromRGB(100, 200, 255) end
		if floorIdx == profile.BuildingLevel then floorColor = Color3.fromRGB(255, 150, 100) end
		
		local floorSign = makePart(buildingFolder, Vector3.new(12, 3, 1), CFrame.new(pos.X, yPos + 7, pos.Z - 14), floorColor, Enum.Material.Neon, 0, false)
		createTextSign(floorSign, "FLOOR " .. floorIdx, Vector2.new(600, 150))
		
		-- Production machines on first floor
		if floorIdx == 1 then
			local machine1 = makePart(buildingFolder, Vector3.new(8, 6, 8), CFrame.new(pos.X - 8, yPos + 1, pos.Z + 5), Color3.fromRGB(140, 160, 180), Enum.Material.Metal, 0, true)
			createTextSign(machine1, "PUMP", Vector2.new(400, 150))
			
			local machine2 = makePart(buildingFolder, Vector3.new(8, 6, 8), CFrame.new(pos.X + 8, yPos + 1, pos.Z + 5), Color3.fromRGB(140, 160, 180), Enum.Material.Metal, 0, true)
			createTextSign(machine2, "PUMP", Vector2.new(400, 150))
		end
		
		-- Stairs (if not top floor)
		if floorIdx < profile.BuildingLevel then
			for step = 0, 2 do
				local stair = makePart(buildingFolder, Vector3.new(8, 1, 6), CFrame.new(pos.X - 10 + step * 3, yPos + 1 + (step * 2.5), pos.Z - 8), Color3.fromRGB(170, 170, 180), Enum.Material.SmoothPlastic, 0, true)
			end
		end
	end
	
	plot.buildingFolder = buildingFolder
	return buildingFolder
end

-- ============================================
-- PLAYER SPAWN
-- ============================================

local spawnPoint = CFrame.new(0, 5, 0)

local function teleportToSpawn(character)
	task.wait(0.5)
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart then
		humanoidRootPart.CFrame = spawnPoint
	end
end

-- ============================================
-- ADVANCED GUI SYSTEM
-- ============================================

local function createAdvancedGUI(player)
	local playerGui = player:WaitForChild("PlayerGui")
	
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TycoonGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 100
	screenGui.Parent = playerGui

	-- Main stats frame
	local statsFrame = Instance.new("Frame")
	statsFrame.Name = "StatsFrame"
	statsFrame.Size = UDim2.new(0, 480, 0, 350)
	statsFrame.Position = UDim2.new(1, -500, 0, 20)
	statsFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	statsFrame.BorderSizePixel = 0
	statsFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = statsFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 100, 200)
	stroke.Thickness = 2
	stroke.Parent = statsFrame

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -30, 0, 50)
	title.Position = UDim2.new(0, 15, 0, 10)
	title.BackgroundTransparency = 1
	title.Text = "💎 YOUR PLOT"
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 100, 200)
	title.Parent = statsFrame

	-- Stats display
	local statsLabel = Instance.new("TextLabel")
	statsLabel.Name = "Stats"
	statsLabel.Size = UDim2.new(1, -30, 0, 140)
	statsLabel.Position = UDim2.new(0, 15, 0, 65)
	statsLabel.BackgroundTransparency = 1
	statsLabel.Text = "Loading..."
	statsLabel.Font = Enum.Font.Gotham
	statsLabel.TextSize = 15
	statsLabel.TextWrapped = true
	statsLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.TextYAlignment = Enum.TextYAlignment.Top
	statsLabel.Parent = statsFrame

	-- Buttons frame
	local buttonsFrame = Instance.new("Frame")
	buttonsFrame.Name = "ButtonsFrame"
	buttonsFrame.Size = UDim2.new(1, -30, 0, 140)
	buttonsFrame.Position = UDim2.new(0, 15, 1, -155)
	buttonsFrame.BackgroundTransparency = 1
	buttonsFrame.Parent = statsFrame

	local buttonLayout = Instance.new("UIGridLayout")
	buttonLayout.CellSize = UDim2.new(0.5, -7, 0.33, -7)
	buttonLayout.CellPadding = UDim2.new(0, 14, 0, 14)
	buttonLayout.Parent = buttonsFrame

	local function createButton(name, text, color, parent)
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.Size = UDim2.new(1, 0, 1, 0)
		btn.Text = text
		btn.BackgroundColor3 = color
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 14
		btn.TextWrapped = true
		btn.AutoButtonColor = true
		btn.Parent = parent

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 10)
		btnCorner.Parent = btn

		return btn
	end

	local hireBtn = createButton("HireFemboy", "👗 Hire Femboy\n$0", Color3.fromRGB(93, 166, 255), buttonsFrame)
	local tomboyBtn = createButton("HireTomboy", "💪 Hire Tomboy\n$0", Color3.fromRGB(255, 107, 198), buttonsFrame)
	local collectBtn = createButton("Collect", "🥛 Collect\n+0", Color3.fromRGB(56, 208, 117), buttonsFrame)
	local upgradeBtn = createButton("Upgrade", "🏢 Upgrade\nBuilding", Color3.fromRGB(200, 150, 100), buttonsFrame)
	local shopBtn = createButton("Shop", "🛍️ Decor", Color3.fromRGB(255, 180, 0), buttonsFrame)
	local rebirthBtn = createButton("Rebirth", "🔥 Rebirth\n[0]", Color3.fromRGB(255, 190, 75), buttonsFrame)

	-- Prestige frame
	local prestigeFrame = Instance.new("Frame")
	prestigeFrame.Name = "PrestigeFrame"
	prestigeFrame.Size = UDim2.new(0, 480, 0, 60)
	prestigeFrame.Position = UDim2.new(1, -500, 0, 375)
	prestigeFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	prestigeFrame.BorderSizePixel = 0
	prestigeFrame.Parent = screenGui

	local prestigeCorner = Instance.new("UICorner")
	prestigeCorner.CornerRadius = UDim.new(0, 16)
	prestigeCorner.Parent = prestigeFrame

	local prestigeStroke = Instance.new("UIStroke")
	prestigeStroke.Color = Color3.fromRGB(255, 190, 75)
	prestigeStroke.Thickness = 2
	prestigeStroke.Parent = prestigeFrame

	local prestigeLabel = Instance.new("TextLabel")
	prestigeLabel.Name = "Label"
	prestigeLabel.Size = UDim2.new(1, -30, 1, 0)
	prestigeLabel.Position = UDim2.new(0, 15, 0, 0)
	prestigeLabel.BackgroundTransparency = 1
	prestigeLabel.Text = "⭐ Prestige: 1.00x | Rebirths: 0"
	prestigeLabel.Font = Enum.Font.GothamBold
	prestigeLabel.TextSize = 16
	prestigeLabel.TextColor3 = Color3.fromRGB(255, 190, 75)
	prestigeLabel.Parent = prestigeFrame

	-- ============================================
	-- GUI UPDATE LOGIC
	-- ============================================

	local function updateStats()
		local profile = getProfile(player)
		local production = getProductionRate(player)
		local femboyC = getFemboyCost(player)
		local tomboyC = getTomboyCost(player)
		local collectValue = math.floor(profile.Milk * CONFIG.CASH_CONVERSION)
		local upgradeCost = CONFIG.UPGRADE_BASE_COST * profile.BuildingLevel

		if profile.OwnedPlot == 0 then
			statsLabel.Text = "❌ NO PLOT CLAIMED\n\nGo back to the HUB and claim a plot to get started!"
			title.Text = "📍 UNCLAIMED"
		else
			statsLabel.Text = string.format(
				"💰 Cash: $%d\n🥛 Milk: %d\n⚡ Production: %d/sec\n👗 Femboys: %d | 💪 Tomboys: %d\n🏢 Building Lv: %d",
				profile.Cash,
				profile.Milk,
				production,
				profile.FemboyWorkers,
				profile.TomboyWorkers,
				profile.BuildingLevel
			)
			title.Text = "📍 PLOT " .. profile.OwnedPlot
		end

		hireBtn.Text = "👗 Hire\n$" .. femboyC
		tomboyBtn.Text = "💪 Hire\n$" .. tomboyC
		collectBtn.Text = "🥛 Collect\n+" .. collectValue
		upgradeBtn.Text = "🏢 Upgrade\n$" .. upgradeCost
		rebirthBtn.Text = "🔥 Rebirth\n[" .. getRebirthCost(player) .. "]"

		-- Update button colors
		hireBtn.BackgroundColor3 = profile.Cash >= femboyC and Color3.fromRGB(120, 190, 255) or Color3.fromRGB(93, 166, 255)
		tomboyBtn.BackgroundColor3 = profile.Cash >= tomboyC and Color3.fromRGB(255, 130, 215) or Color3.fromRGB(255, 107, 198)
		collectBtn.BackgroundColor3 = profile.Milk > 0 and Color3.fromRGB(80, 230, 140) or Color3.fromRGB(56, 208, 117)
		upgradeBtn.BackgroundColor3 = profile.Cash >= upgradeCost and Color3.fromRGB(220, 170, 120) or Color3.fromRGB(200, 150, 100)
		rebirthBtn.BackgroundColor3 = profile.Milk >= getRebirthCost(player) and Color3.fromRGB(255, 220, 100) or Color3.fromRGB(255, 190, 75)

		prestigeLabel.Text = string.format("⭐ Prestige: %.2fx | Rebirths: %d", profile.PrestigeMultiplier, profile.Rebirths)
	end

	-- Hire Femboy
	hireBtn.MouseButton1Click:Connect(function()
		local profile = getProfile(player)
		if profile.OwnedPlot == 0 then return end
		local cost = getFemboyCost(player)
		if profile.Cash >= cost then
			subtractMoney(player, cost)
			profile.FemboyWorkers = profile.FemboyWorkers + 1
			profile.Level = profile.Level + 1
			updateStats()
		end
	end)

	-- Hire Tomboy
	tomboyBtn.MouseButton1Click:Connect(function()
		local profile = getProfile(player)
		if profile.OwnedPlot == 0 then return end
		local cost = getTomboyCost(player)
		if profile.Cash >= cost then
			subtractMoney(player, cost)
			profile.TomboyWorkers = profile.TomboyWorkers + 1
			profile.Level = profile.Level + 2
			updateStats()
		end
	end)

	-- Collect
	collectBtn.MouseButton1Click:Connect(function()
		local profile = getProfile(player)
		if profile.Milk > 0 then
			local value = math.floor(profile.Milk * CONFIG.CASH_CONVERSION)
			addMoney(player, value)
			subtractMilk(player, profile.Milk)
		end
		updateStats()
	end)

	-- Upgrade building
	upgradeBtn.MouseButton1Click:Connect(function()
		local profile = getProfile(player)
		if profile.OwnedPlot == 0 then return end
		local cost = CONFIG.UPGRADE_BASE_COST * profile.BuildingLevel
		if profile.Cash >= cost then
			subtractMoney(player, cost)
			profile.BuildingLevel = profile.BuildingLevel + 1
			
			-- Rebuild player's building
			local plot = plots[profile.OwnedPlot]
			if plot.buildingFolder then
				plot.buildingFolder:Destroy()
			end
			buildPlayerBuilding(profile.OwnedPlot, player)
			updateStats()
		end
	end)

	-- Rebirth
	rebirthBtn.MouseButton1Click:Connect(function()
		local profile = getProfile(player)
		local cost = getRebirthCost(player)
		if profile.Milk >= cost then
			subtractMilk(player, cost)
			profile.Rebirths = profile.Rebirths + 1
			profile.PrestigeMultiplier = 1 + (profile.Rebirths * CONFIG.PRESTIGE_MULTIPLIER)
			profile.BuildingLevel = 1
			profile.FemboyWorkers = 0
			profile.TomboyWorkers = 0
			profile.Cash = CONFIG.STARTING_CASH
			profile.Level = 1
			
			-- Rebuild with level 1
			local plot = plots[profile.OwnedPlot]
			if plot.buildingFolder then
				plot.buildingFolder:Destroy()
			end
			buildPlayerBuilding(profile.OwnedPlot, player)
			updateStats()
		end
	end)

	-- ============================================
	-- SHOP SYSTEM
	-- ============================================

	local shopGui = Instance.new("ScreenGui")
	shopGui.Name = "ShopGui"
	shopGui.ResetOnSpawn = false
	shopGui.DisplayOrder = 101
	shopGui.Enabled = false
	shopGui.Parent = playerGui

	local shopFrame = Instance.new("Frame")
	shopFrame.Name = "ShopFrame"
	shopFrame.Size = UDim2.new(0, 600, 0, 700)
	shopFrame.Position = UDim2.new(0.5, -300, 0.5, -350)
	shopFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	shopFrame.BorderSizePixel = 0
	shopFrame.Parent = shopGui

	local shopCorner = Instance.new("UICorner")
	shopCorner.CornerRadius = UDim.new(0, 20)
	shopCorner.Parent = shopFrame

	local shopStroke = Instance.new("UIStroke")
	shopStroke.Color = Color3.fromRGB(255, 200, 0)
	shopStroke.Thickness = 3
	shopStroke.Parent = shopFrame

	local shopTitle = Instance.new("TextLabel")
	shopTitle.Size = UDim2.new(1, -30, 0, 50)
	shopTitle.Position = UDim2.new(0, 15, 0, 10)
	shopTitle.BackgroundTransparency = 1
	shopTitle.Text = "🛍️ DECOR SHOP"
	shopTitle.Font = Enum.Font.GothamBlack
	shopTitle.TextScaled = true
	shopTitle.TextColor3 = Color3.fromRGB(255, 200, 0)
	shopTitle.Parent = shopFrame

	local closeShop = Instance.new("TextButton")
	closeShop.Size = UDim2.new(0, 40, 0, 40)
	closeShop.Position = UDim2.new(1, -55, 0, 10)
	closeShop.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
	closeShop.Text = "✕"
	closeShop.Font = Enum.Font.GothamBold
	closeShop.TextSize = 20
	closeShop.Parent = shopFrame

	local itemsContainer = Instance.new("Frame")
	itemsContainer.Size = UDim2.new(1, -30, 1, -80)
	itemsContainer.Position = UDim2.new(0, 15, 0, 65)
	itemsContainer.BackgroundTransparency = 1
	itemsContainer.Parent = shopFrame

	local itemsScroll = Instance.new("UIListLayout")
	itemsScroll.Padding = UDim.new(0, 12)
	itemsScroll.Parent = itemsContainer

	-- Create shop items
	for idx, item in ipairs(CONFIG.DECOR_ITEMS) do
		local itemFrame = Instance.new("Frame")
		itemFrame.Size = UDim2.new(1, 0, 0, 60)
		itemFrame.BackgroundColor3 = Color3.fromRGB(40, 45, 55)
		itemFrame.Parent = itemsContainer

		local itemCorner = Instance.new("UICorner")
		itemCorner.CornerRadius = UDim.new(0, 12)
		itemCorner.Parent = itemFrame

		local itemStroke = Instance.new("UIStroke")
		itemStroke.Color = item.color
		itemStroke.Thickness = 2
		itemStroke.Parent = itemFrame

		local itemLabel = Instance.new("TextLabel")
		itemLabel.Size = UDim2.new(0.6, 0, 1, 0)
		itemLabel.BackgroundTransparency = 1
		itemLabel.Text = item.name .. "\n$" .. item.cost
		itemLabel.Font = Enum.Font.GothamBold
		itemLabel.TextSize = 14
		itemLabel.TextColor3 = item.color
		itemLabel.TextXAlignment = Enum.TextXAlignment.Left
		itemLabel.TextWrapped = true
		itemLabel.Parent = itemFrame

		local buyBtn = Instance.new("TextButton")
		buyBtn.Size = UDim2.new(0.35, -6, 1, -10)
		buyBtn.Position = UDim2.new(0.65, 6, 0, 5)
		buyBtn.BackgroundColor3 = item.color
		buyBtn.Text = "BUY"
		buyBtn.Font = Enum.Font.GothamBold
		buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		buyBtn.Parent = itemFrame

		local buyCorner = Instance.new("UICorner")
		buyCorner.CornerRadius = UDim.new(0, 8)
		buyCorner.Parent = buyBtn

		buyBtn.MouseButton1Click:Connect(function()
			local profile = getProfile(player)
			if profile.Cash >= item.cost then
				subtractMoney(player, item.cost)
				table.insert(profile.OwnedDecor, item.name)
				updateStats()
			end
		end)
	end

	closeShop.MouseButton1Click:Connect(function()
		shopGui.Enabled = false
	end)

	shopBtn.MouseButton1Click:Connect(function()
		shopGui.Enabled = true
	end)

	-- Auto refresh stats
	task.spawn(function()
		while screenGui and screenGui.Parent do
			task.wait(1)
			updateStats()
		end
	end)

	updateStats()
	return screenGui
end

-- ============================================
-- PLOT CLAIMING
-- ============================================

local function claimPlot(plotNumber, player)
	local profile = getProfile(player)
	local plot = plots[plotNumber]
	
	if plot.owner then
		return false
	end
	
	profile.OwnedPlot = plotNumber
	plot.owner = player.UserId
	plotOwnership[plotNumber] = player.UserId
	
	-- Update plot sign
	plot.claimLabel.Text = "PLOT " .. plotNumber .. "\n[" .. player.Name .. "]"
	plot.claimSign.Color = Color3.fromRGB(100, 200, 0)
	
	-- Build player's building
	buildPlayerBuilding(plotNumber, player)
	
	-- Teleport player to their plot
	local char = player.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		task.wait(0.3)
		char.HumanoidRootPart.CFrame = CFrame.new(plot.position + Vector3.new(0, 5, 0))
	end
	
	return true
end

-- ============================================
-- PLOT DETECTION
-- ============================================

task.spawn(function()
	while true do
		task.wait(0.5)
		for _, player in ipairs(Players:GetPlayers()) do
			if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
				local hrp = player.Character.HumanoidRootPart
				for i, plot in ipairs(plots) do
					local distance = (hrp.Position - Vector3.new(plot.position.X, hrp.Position.Y, plot.position.Z)).Magnitude
					if distance < 20 and not plot.owner then
						-- Near unclaimed plot
						local profile = getProfile(player)
						if profile.OwnedPlot == 0 then
							-- Show claim prompt
							plot.claimLabel.Text = "PLOT " .. i .. "\n[UNCLAIMED]\n✓ CLICK SIGN TO CLAIM"
						end
					elseif distance > 25 and not plot.owner then
						plot.claimLabel.Text = "PLOT " .. i .. "\n[UNCLAIMED]\nCLICK TO CLAIM"
					end
				end
			end
		end
	end
end)

-- ============================================
-- PLOT SIGN CLICK DETECTION
-- ============================================

local UserInputService = game:GetService("UserInputService")
local mouse = Players.LocalPlayer:GetMouse() if Players.LocalPlayer else nil

for _, player in ipairs(Players:GetPlayers()) do
	local playerMouse = nil
	player.CharacterAdded:Connect(function(character)
		task.wait(0.5)
		if player:FindFirstChild("Mouse") then
			playerMouse = player:GetMouse()
		end
	end)
end

-- Server-side detection using touched events
for i, plot in ipairs(plots) do
	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 30
	clickDetector.Parent = plot.claimSign
	
	clickDetector.MouseClick:Connect(function(player)
		local profile = getProfile(player)
		if profile.OwnedPlot == 0 and not plot.owner then
			claimPlot(i, player)
		end
	end)
end

-- ============================================
-- PRODUCTION LOOP
-- ============================================

local function productionTick()
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = getProfile(player)
		if profile.OwnedPlot > 0 then
			local production = getProductionRate(player)
			if production > 0 then
				addMilk(player, production)
			end
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
	createAdvancedGUI(player)
end)

Players.PlayerRemoving:Connect(function(player)
	local key = tostring(player.UserId)
	local profile = playerData[key]
	if profile and profile.OwnedPlot > 0 then
		-- Plot becomes available again
		local plot = plots[profile.OwnedPlot]
		plot.owner = nil
		plot.claimLabel.Text = "PLOT " .. profile.OwnedPlot .. "\n[UNCLAIMED]\nCLICK TO CLAIM"
		plot.claimSign.Color = Color3.fromRGB(100, 200, 255)
		if plot.buildingFolder then
			plot.buildingFolder:Destroy()
		end
	end
	playerData[key] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.wait(0.3)
	getProfile(player)
	createAdvancedGUI(player)
	
	if player.Character then
		teleportToSpawn(player.Character)
	end
end

print("✅ FEMBOY MILK TYCOON - MULTIPLAYER PLOT EDITION LOADED")
print("✅ Features: 8 Private Plots | Per-Player Buildings | Full Production")
print("✅ Players claim plots and build their own tycoons!")
print("✅ Starting Cash: $" .. CONFIG.STARTING_CASH)
print("✅ Ready for multiplayer deployment!")
