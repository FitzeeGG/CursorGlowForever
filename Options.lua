-- Options panel (Esc > Options > AddOns > Cursor Glow Forever, or /cg).
-- Widgets are built from plain textures so they work on any client.
local _, ns = ...

local panel = CreateFrame("Frame")
panel:Hide()
local widgets = {}


local function onChanged()
	ns.updateLayout()
	for _, widget in ipairs(widgets) do
		if widget.refresh then widget:refresh() end
	end
end


local function createLabel(parent, text, template)
	local label = parent:CreateFontString(nil, "ARTWORK", template or "GameFontHighlight")
	label:SetText(text)
	return label
end


local function createCheckbox(key, text, tooltip)
	local check = CreateFrame("CheckButton", nil, panel)
	check:SetSize(26, 26)
	check:SetNormalTexture("Interface/Buttons/UI-CheckBox-Up")
	check:SetPushedTexture("Interface/Buttons/UI-CheckBox-Down")
	check:SetHighlightTexture("Interface/Buttons/UI-CheckBox-Highlight", "ADD")
	check:SetCheckedTexture("Interface/Buttons/UI-CheckBox-Check")
	check:SetDisabledCheckedTexture("Interface/Buttons/UI-CheckBox-Check-Disabled")
	check.label = createLabel(check, text)
	check.label:SetPoint("LEFT", check, "RIGHT", 2, 1)
	check:SetHitRectInsets(0, -check.label:GetStringWidth() - 4, 0, 0)
	check:SetScript("OnClick", function(self)
		ns.db[key] = self:GetChecked() and true or false
		PlaySound(ns.db[key] and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
		if self.onChange then self.onChange(ns.db[key]) end
		onChanged()
	end)
	if tooltip then
		check:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(text, 1, 1, 1)
			GameTooltip:AddLine(tooltip, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		check:SetScript("OnLeave", GameTooltip_Hide)
	end
	function check:refresh() self:SetChecked(ns.db[key]) end
	table.insert(widgets, check)
	return check
end


-- values: list of {value, text} for a slider over fixed choices
local function createSlider(key, text, minValue, maxValue, step, format, values, tooltip, width)
	local slider = CreateFrame("Slider", nil, panel)
	slider:SetOrientation("HORIZONTAL")
	slider:SetSize(width or 220, 16)
	slider:SetHitRectInsets(0, 0, -6, -6)
	slider:SetObeyStepOnDrag(true)
	if values then
		minValue, maxValue, step = 1, #values, 1
	end
	slider:SetMinMaxValues(minValue, maxValue)
	slider:SetValueStep(step)

	local track = slider:CreateTexture(nil, "BACKGROUND")
	track:SetColorTexture(1, 1, 1, .2)
	track:SetPoint("LEFT")
	track:SetPoint("RIGHT")
	track:SetHeight(4)
	slider:SetThumbTexture("Interface/Buttons/UI-SliderBar-Button-Horizontal")

	slider.label = createLabel(slider, text, "GameFontNormal")
	slider.label:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 4)
	slider.value = createLabel(slider, "", "GameFontHighlightSmall")
	slider.value:SetPoint("LEFT", slider, "RIGHT", 10, 0)

	local function toSetting(position)
		if values then return values[position][1] end
		return math.floor(position / step + .5) * step
	end
	local function toPosition(setting)
		if values then
			for i, entry in ipairs(values) do
				if entry[1] == setting then return i end
			end
			return 1
		end
		return setting
	end
	local function showValue(setting)
		if values then
			slider.value:SetText(values[toPosition(setting)][2])
		else
			slider.value:SetText(format:format(setting))
		end
	end

	slider:SetScript("OnValueChanged", function(self, position, userInput)
		local setting = toSetting(position)
		showValue(setting)
		if userInput then
			ns.db[key] = setting
			onChanged()
		end
	end)
	if tooltip then
		slider:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(text, 1, 1, 1)
			GameTooltip:AddLine(tooltip, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		slider:SetScript("OnLeave", GameTooltip_Hide)
	end
	function slider:refresh()
		self:SetValue(toPosition(ns.db[key]))
		showValue(ns.db[key])
	end
	table.insert(widgets, slider)
	return slider
end


-- disabledBy: the checkbox setting that, while ticked, makes this colour unused
local function createColorSwatch(key, text, disabledBy)
	local swatch = CreateFrame("Button", nil, panel)
	swatch:SetSize(22, 22)
	local border = swatch:CreateTexture(nil, "BACKGROUND")
	border:SetColorTexture(1, 1, 1, .8)
	border:SetAllPoints()
	swatch.color = swatch:CreateTexture(nil, "ARTWORK")
	swatch.color:SetPoint("TOPLEFT", 2, -2)
	swatch.color:SetPoint("BOTTOMRIGHT", -2, 2)
	swatch.label = createLabel(swatch, text)
	swatch.label:SetPoint("LEFT", swatch, "RIGHT", 8, 0)

	local function setColor(r, g, b)
		ns.db[key] = {r, g, b}
		onChanged()
	end
	swatch:SetScript("OnClick", function()
		local r, g, b = unpack(ns.db[key])
		ColorPickerFrame:SetupColorPickerAndShow({
			r = r, g = g, b = b,
			swatchFunc = function() setColor(ColorPickerFrame:GetColorRGB()) end,
			cancelFunc = function() setColor(r, g, b) end,
		})
	end)
	function swatch:refresh()
		self.color:SetColorTexture(unpack(ns.db[key]))
		local disabled = disabledBy and ns.db[disabledBy]
		self:SetEnabled(not disabled)
		self:SetAlpha(disabled and .4 or 1)
	end
	table.insert(widgets, swatch)
	return swatch
end


local function build()
	local title = createLabel(panel, ns.TITLE, "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	local subtitle = createLabel(panel, "A glow around your cursor, drawn where your mouse was while turning the camera.", "GameFontHighlightSmall")
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)

	local enabled = createCheckbox("enabled", "Enable")
	enabled:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", -2, -14)
	enabled.onChange = ns.setEnabled

	-- COLOUR
	local classColor = createCheckbox("useClassColor", "Use class colour", "Colour the glow with your class colour. Untick to pick a custom colour.")
	classColor:SetPoint("TOPLEFT", enabled, "BOTTOMLEFT", 0, -16)
	local swatch = createColorSwatch("color", "Custom colour", "useClassColor")
	swatch:SetPoint("LEFT", classColor.label, "RIGHT", 24, 0)

	local glow = createSlider("glowOpacity", "Glow opacity", 0, 1, .05, "%.2f")
	glow:SetPoint("TOPLEFT", classColor, "BOTTOMLEFT", 4, -34)
	local outline = createSlider("outlineOpacity", "Outline opacity", 0, 1, .05, "%.2f")
	outline:SetPoint("TOPLEFT", glow, "BOTTOMLEFT", 0, -34)

	local sizes = {{-1, "Game setting"}}
	for i = 0, #ns.CURSOR_SIZES do
		local size = ns.CURSOR_SIZES[i]
		table.insert(sizes, {i, size.."x"..size})
	end
	local size = createSlider("cursorSize", "Cursor size", nil, nil, nil, nil, sizes,
		"Size of your game cursor. Game setting reads the cursor size option (32x32 if it is on automatic).")
	size:SetPoint("TOPLEFT", outline, "BOTTOMLEFT", 0, -34)

	local prediction = createSlider("prediction", "Movement prediction", 0, 2, .1, "%.1f frames", nil,
		"Places the glow ahead of the cursor by this many frames of its movement, so it keeps up during fast movement. Lower it if the glow overshoots when you stop.")
	prediction:SetPoint("TOPLEFT", size, "BOTTOMLEFT", 0, -34)

	local shakeToFind = createCheckbox("shakeToFind", "Shake to find",
		"Shake the mouse quickly side to side to flash a bright halo around the cursor, so you can find it.")
	shakeToFind:SetPoint("TOPLEFT", prediction, "BOTTOMLEFT", -4, -20)

	local shakeCount = createSlider("shakeCount", "Shakes needed", 2, 10, 1, "%d", nil,
		"How many times in a row the mouse has to change direction to count as a shake. Raise it if the halo shows when you didn't mean it to.")
	shakeCount:SetPoint("TOPLEFT", shakeToFind, "BOTTOMLEFT", 4, -34)

	local combatPulse = createCheckbox("combatPulse", "Pulse in combat",
		"While you're in combat, the glow gently pulses brighter, with a soft halo.")
	combatPulse:SetPoint("TOPLEFT", shakeCount, "BOTTOMLEFT", -4, -20)

	local pulseGlowColor = createCheckbox("pulseUseGlowColor", "Pulse uses glow colour",
		"Pulse in the glow colour. Untick to pick a pulse colour (a red, for example) that the glow takes on as it pulses, to show you're in combat.")
	pulseGlowColor:SetPoint("TOPLEFT", combatPulse, "BOTTOMLEFT", 0, -4)
	local pulseSwatch = createColorSwatch("pulseColor", "Pulse colour", "pulseUseGlowColor")
	pulseSwatch:SetPoint("LEFT", pulseGlowColor.label, "RIGHT", 24, 0)

	-- BEHAVIOUR (right column)
	local showWhen = createSlider("showWhen", "Show the glow", nil, nil, nil, nil,
		{{"always", "Always"}, {"combat", "In combat"}, {"noCombat", "Out of combat"}},
		"Show the glow always, only in combat, or only out of combat. Shake to find still shows it for a moment.", 160)
	showWhen:SetPoint("TOPLEFT", enabled, "TOPLEFT", 344, -20)

	local hover = createCheckbox("hideOnHover", "Hide on hover targets",
		"Hide the glove glow while the cursor has a hover look (mailbox, enemy, NPC...).")
	hover:SetPoint("TOPLEFT", showWhen, "BOTTOMLEFT", -4, -20)

	local outlineHover = createCheckbox("outlineHover", "Outline hover cursors",
		"Outline the hover cursor (loot bag, pickaxe, sword...) when it can be told which one is showing. Unrecognised ones get no outline.")
	outlineHover:SetPoint("TOPLEFT", hover, "BOTTOMLEFT", 0, -4)

	local outlineServices = createCheckbox("outlineServices", "Outline vendors and services",
		"Also outline the cursors of vendors, repairers, bankers, innkeepers, flight masters, stable masters and trainers. An NPC with a quest for you shows the quest cursor instead, which can't always be told in advance.")
	outlineServices:SetPoint("TOPLEFT", outlineHover, "BOTTOMLEFT", 0, -4)

	local dimRange = createCheckbox("dimOutOfRange", "Dim outlines out of range",
		"Weaken the hover outline on NPCs and corpses while they are too far away to interact with, and bring it back to full strength in range.")
	dimRange:SetPoint("TOPLEFT", outlineServices, "BOTTOMLEFT", 0, -4)

	local rangeStrength = createSlider("outOfRangeStrength", "Out of range strength", .1, 1, .05, "%.2f", nil,
		"How strong the hover outline is while out of interaction range, compared with in range.")
	rangeStrength:SetPoint("TOPLEFT", dimRange, "BOTTOMLEFT", 4, -34)

	local glove = createCheckbox("gloveWhileTurning", "Draw the glove while turning",
		"The game hides its cursor while you turn the camera; draw the glove with the glow where the mouse was.")
	glove:SetPoint("TOPLEFT", rangeStrength, "BOTTOMLEFT", -4, -20)

	local gloveGlowColor = createCheckbox("gloveUseGlowColor", "Glove uses glow colour",
		"Tint the drawn glove with the glow colour. Untick to pick a separate glove colour.")
	gloveGlowColor:SetPoint("TOPLEFT", glove, "BOTTOMLEFT", 0, -4)
	local gloveSwatch = createColorSwatch("gloveColor", "Glove colour", "gloveUseGlowColor")
	gloveSwatch:SetPoint("TOPLEFT", gloveGlowColor, "BOTTOMLEFT", 4, -6)

	local tint = createSlider("gloveTint", "Glove tint", 0, 1, .05, "%.2f", nil,
		"How strongly the glove drawn while turning the camera is tinted with its colour.")
	tint:SetPoint("TOPLEFT", gloveSwatch, "BOTTOMLEFT", 0, -30)

	local intensity = createSlider("turningIntensity", "Glow intensity while turning", 1, 2, .05, "%.2fx", nil,
		"How much stronger the glow is around the glove drawn while turning the camera.")
	intensity:SetPoint("TOPLEFT", tint, "BOTTOMLEFT", 0, -34)

	local idlePulse = createCheckbox("idlePulse", "Pulse when idle",
		"After a few seconds without moving the mouse, the glow slowly fades out and back in (the outline stays) until you move it again.")
	idlePulse:SetPoint("TOPLEFT", intensity, "BOTTOMLEFT", -4, -20)

	local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	reset:SetSize(140, 22)
	reset:SetText("Reset to defaults")
	reset:SetPoint("TOPLEFT", pulseGlowColor, "BOTTOMLEFT", 0, -16)
	reset:SetScript("OnClick", function()
		for key, value in pairs(ns.defaults) do
			ns.db[key] = type(value) == "table" and CopyTable(value) or value
		end
		ns.setEnabled(ns.db.enabled)
		onChanged()
	end)
end


panel:SetScript("OnShow", function(self)
	if not self.built then
		build()
		self.built = true
	end
	for _, widget in ipairs(widgets) do widget:refresh() end
end)


local category = Settings.RegisterCanvasLayoutCategory(panel, ns.TITLE)
Settings.RegisterAddOnCategory(category)

SLASH_CURSORGLOWFOREVER1 = "/cg"
SLASH_CURSORGLOWFOREVER2 = "/cursorglow"
SLASH_CURSORGLOWFOREVER3 = "/cursorglowforever"
SlashCmdList.CURSORGLOWFOREVER = function(msg)
	if msg and msg:lower():match("^%s*debug%s*$") then
		ns.debug = not ns.debug
		print("|cff66ccffCursor Glow Forever:|r debug "..(ns.debug and "on" or "off")
			..(ns.worldEvent and "" or " (WORLD_CURSOR_TOOLTIP_UPDATE not available, using tooltips)"))
		return
	end
	Settings.OpenToCategory(category:GetID())
end
