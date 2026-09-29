-- Options panel (Esc > Options > AddOns > Cursor Glow Forever, or /cg).
-- Widgets are built from plain textures so they work on any client. Text is
-- translated in Locales.lua.
local _, ns = ...
local L = ns.L

local panel = CreateFrame("Frame")
panel:Hide()
local widgets = {}
-- the settings scroll under a fixed header holding the live preview
local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
local content = CreateFrame("Frame", nil, scroll)
scroll:SetScrollChild(content)
local PREVIEW_MAX = 40 -- largest sample cursor, so its glow fits the preview


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
	local check = CreateFrame("CheckButton", nil, content)
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
	local slider = CreateFrame("Slider", nil, content)
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
	local swatch = CreateFrame("Button", nil, content)
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


-- Live preview: the cursor and the glove drawn while turning the camera, with
-- the current colour, glow, outline, size and glove settings.
local function createPreview()
	local box = CreateFrame("Frame", nil, panel)
	box:SetSize(240, 118)
	box:SetClipsChildren(true)
	local background = box:CreateTexture(nil, "BACKGROUND", nil, -8)
	background:SetColorTexture(.05, .05, .06, 1)
	background:SetAllPoints()
	box.samples = {}
	for i, turning in ipairs({false, true}) do
		local sample = CreateFrame("Frame", nil, box)
		sample.turning = turning
		sample.glow = sample:CreateTexture(nil, "BACKGROUND")
		sample.glow:SetPoint("CENTER", sample, "CENTER")
		sample.outline = sample:CreateTexture(nil, "BORDER")
		sample.outline:SetTexture(ns.TEXTURES.."point-outline")
		sample.outline:SetPoint("CENTER", sample, "CENTER")
		sample.glove = sample:CreateTexture(nil, "ARTWORK")
		sample.glove:SetTexture(ns.CURSORS.."Point")
		sample.glove:SetAllPoints(sample)
		local caption = createLabel(box, turning and L["Turning the camera"] or L["Cursor"], "GameFontDisableSmall")
		caption:SetPoint("BOTTOM", box, "BOTTOMLEFT", 120 * (i - .5), 6)
		box.samples[i] = sample
	end

	function box:refresh()
		local db = ns.db
		local r, g, b = ns.getColor()
		-- the cursor's real size on screen, within what fits the box
		local size = ns.cursor.size or 32
		local scale = (UIParent:GetEffectiveScale() or 1) / (self:GetEffectiveScale() or 1)
		size = math.min(size * scale, PREVIEW_MAX)
		for i, sample in ipairs(self.samples) do
			local intensity = sample.turning and db.turningIntensity or 1
			sample:SetSize(size, size)
			sample:ClearAllPoints()
			sample:SetPoint("CENTER", self, "TOPLEFT", 120 * (i - .5), -52)
			sample.glow:SetTexture(ns.getGlowTexture())
			sample.glow:SetSize(size * 4, size * 4)
			sample.glow:SetVertexColor(r, g, b)
			sample.glow:SetAlpha(math.min(db.glowOpacity * intensity, 1))
			sample.outline:SetSize(size * 2, size * 2)
			sample.outline:SetVertexColor(r, g, b)
			sample.outline:SetAlpha(math.min(db.outlineOpacity * intensity, 1))
			if sample.turning then
				sample.glove:SetVertexColor(ns.getGloveColor())
			else
				sample.glove:SetVertexColor(1, 1, 1)
			end
			-- the game draws no glove while turning without the option
			sample:SetShown(not sample.turning or db.gloveWhileTurning)
		end
		self:SetAlpha(db.enabled and 1 or .4)
	end
	table.insert(widgets, box)
	return box
end


local function build()
	local title = createLabel(panel, ns.TITLE, "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	local subtitle = createLabel(panel, L["A glow around your cursor, drawn where your mouse was while turning the camera."], "GameFontHighlightSmall")
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	subtitle:SetWidth(300)
	subtitle:SetJustifyH("LEFT")

	local preview = createPreview()
	preview:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -8)
	scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -132)
	scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 8)
	scroll:SetScript("OnSizeChanged", function(self, width) content:SetWidth(width) end)
	content:SetSize(640, 700)

	local enabled = createCheckbox("enabled", L["Enable"])
	enabled:SetPoint("TOPLEFT", content, "TOPLEFT", 14, -4)
	enabled.onChange = ns.setEnabled

	local perCharacter = createCheckbox(nil, L["Settings for this character only"],
		L["Give this character its own settings, starting from the account-wide ones. Untick to go back to the account-wide settings (this character's are kept for next time)."])
	perCharacter:SetPoint("TOPLEFT", enabled, "BOTTOMLEFT", 0, -4)
	perCharacter:SetScript("OnClick", function(self)
		ns.setCharacterSettings(self:GetChecked())
		PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
		onChanged()
	end)
	function perCharacter:refresh() self:SetChecked(ns.charDB.useCharacterSettings) end

	-- COLOUR
	local classColor = createCheckbox("useClassColor", L["Use class colour"], L["Colour the glow with your class colour. Untick to pick a custom colour."])
	classColor:SetPoint("TOPLEFT", perCharacter, "BOTTOMLEFT", 0, -16)
	local swatch = createColorSwatch("color", L["Custom colour"], "useClassColor")
	swatch:SetPoint("TOPLEFT", classColor, "BOTTOMLEFT", 4, -6)

	local glow = createSlider("glowOpacity", L["Glow opacity"], 0, 1, .05, "%.2f")
	glow:SetPoint("TOPLEFT", swatch, "BOTTOMLEFT", 0, -30)
	local glowSize = createSlider("glowSize", L["Glow size"], nil, nil, nil, nil,
		{{.5, "50%"}, {.75, "75%"}, {1, "100%"}, {1.25, "125%"}, {1.5, "150%"}, {1.75, "175%"}, {2, "200%"}},
		L["How far the soft glow reaches around the cursor, whatever the cursor size. The outline stays the same."])
	glowSize:SetPoint("TOPLEFT", glow, "BOTTOMLEFT", 0, -34)
	local outline = createSlider("outlineOpacity", L["Outline opacity"], 0, 1, .05, "%.2f")
	outline:SetPoint("TOPLEFT", glowSize, "BOTTOMLEFT", 0, -34)

	local sizes = {{-1, L["Game setting"]}}
	for i = 0, #ns.CURSOR_SIZES do
		local size = ns.CURSOR_SIZES[i]
		table.insert(sizes, {i, size.."x"..size})
	end
	local size = createSlider("cursorSize", L["Cursor size"], nil, nil, nil, nil, sizes,
		L["Size of your game cursor. Game setting reads the cursor size option (32x32 if it is on automatic)."])
	size:SetPoint("TOPLEFT", outline, "BOTTOMLEFT", 0, -34)

	local prediction = createSlider("prediction", L["Movement prediction"], 0, 2, .1, L["%.1f frames"], nil,
		L["Places the glow ahead of the cursor by this many frames of its movement, so it keeps up during fast movement. Lower it if the glow overshoots when you stop."])
	prediction:SetPoint("TOPLEFT", size, "BOTTOMLEFT", 0, -34)

	local shakeToFind = createCheckbox("shakeToFind", L["Shake to find"],
		L["Shake the mouse quickly side to side to flash a bright halo around the cursor, so you can find it."])
	shakeToFind:SetPoint("TOPLEFT", prediction, "BOTTOMLEFT", -4, -20)

	local shakeCount = createSlider("shakeCount", L["Shakes needed"], 2, 10, 1, "%d", nil,
		L["How many times in a row the mouse has to change direction to count as a shake. Raise it if the halo shows when you didn't mean it to."])
	shakeCount:SetPoint("TOPLEFT", shakeToFind, "BOTTOMLEFT", 4, -34)

	local combatPulse = createCheckbox("combatPulse", L["Pulse in combat"],
		L["While you're in combat, the glow gently pulses brighter, with a soft halo."])
	combatPulse:SetPoint("TOPLEFT", shakeCount, "BOTTOMLEFT", -4, -20)

	local pulseGlowColor = createCheckbox("pulseUseGlowColor", L["Pulse uses glow colour"],
		L["Pulse in the glow colour. Untick to pick a pulse colour (a red, for example) that the glow takes on as it pulses, to show you're in combat."])
	pulseGlowColor:SetPoint("TOPLEFT", combatPulse, "BOTTOMLEFT", 0, -4)
	local pulseSwatch = createColorSwatch("pulseColor", L["Pulse colour"], "pulseUseGlowColor")
	pulseSwatch:SetPoint("TOPLEFT", pulseGlowColor, "BOTTOMLEFT", 4, -6)

	-- BEHAVIOUR (right column)
	local showWhen = createSlider("showWhen", L["Show the glow"], nil, nil, nil, nil,
		{{"always", L["Always"]}, {"combat", L["In combat"]}, {"noCombat", L["Out of combat"]}},
		L["Show the glow always, only in combat, or only out of combat. Shake to find still shows it for a moment."], 130)
	showWhen:SetPoint("TOPLEFT", enabled, "TOPLEFT", 344, -20)

	local hover = createCheckbox("hideOnHover", L["Hide on hover targets"],
		L["Hide the glove glow while the cursor has a hover look (mailbox, enemy, NPC...)."])
	hover:SetPoint("TOPLEFT", showWhen, "BOTTOMLEFT", -4, -20)

	local outlineHover = createCheckbox("outlineHover", L["Outline hover cursors"],
		L["Outline the hover cursor (loot bag, pickaxe, sword...) when it can be told which one is showing. Unrecognised ones get no outline."])
	outlineHover:SetPoint("TOPLEFT", hover, "BOTTOMLEFT", 0, -4)

	local outlineServices = createCheckbox("outlineServices", L["Outline vendors and services"],
		L["Also outline the cursors of vendors, repairers, bankers, innkeepers, flight masters, stable masters and trainers. An NPC with a quest for you shows the quest cursor instead, which can't always be told in advance."])
	outlineServices:SetPoint("TOPLEFT", outlineHover, "BOTTOMLEFT", 0, -4)

	local dimRange = createCheckbox("dimOutOfRange", L["Dim outlines out of range"],
		L["Weaken the hover outline on NPCs and corpses while they are too far away to interact with, and bring it back to full strength in range."])
	dimRange:SetPoint("TOPLEFT", outlineServices, "BOTTOMLEFT", 0, -4)

	local rangeStrength = createSlider("outOfRangeStrength", L["Out of range strength"], .1, 1, .05, "%.2f", nil,
		L["How strong the hover outline is while out of interaction range, compared with in range."])
	rangeStrength:SetPoint("TOPLEFT", dimRange, "BOTTOMLEFT", 4, -34)

	local glove = createCheckbox("gloveWhileTurning", L["Draw the glove while turning"],
		L["The game hides its cursor while you turn the camera; draw the glove with the glow where the mouse was."])
	glove:SetPoint("TOPLEFT", rangeStrength, "BOTTOMLEFT", -4, -20)

	local gloveGlowColor = createCheckbox("gloveUseGlowColor", L["Glove uses glow colour"],
		L["Tint the drawn glove with the glow colour. Untick to pick a separate glove colour."])
	gloveGlowColor:SetPoint("TOPLEFT", glove, "BOTTOMLEFT", 0, -4)
	local gloveSwatch = createColorSwatch("gloveColor", L["Glove colour"], "gloveUseGlowColor")
	gloveSwatch:SetPoint("TOPLEFT", gloveGlowColor, "BOTTOMLEFT", 4, -6)

	local tint = createSlider("gloveTint", L["Glove tint"], 0, 1, .05, "%.2f", nil,
		L["How strongly the glove drawn while turning the camera is tinted with its colour."])
	tint:SetPoint("TOPLEFT", gloveSwatch, "BOTTOMLEFT", 0, -30)

	local intensity = createSlider("turningIntensity", L["Glow intensity while turning"], 1, 2, .05, "%.2fx", nil,
		L["How much stronger the glow is around the glove drawn while turning the camera."])
	intensity:SetPoint("TOPLEFT", tint, "BOTTOMLEFT", 0, -34)

	local idlePulse = createCheckbox("idlePulse", L["Pulse when idle"],
		L["After a few seconds without moving the mouse, the glow slowly fades out and back in (the outline stays) until you move it again."])
	idlePulse:SetPoint("TOPLEFT", intensity, "BOTTOMLEFT", -4, -20)

	local reset = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
	reset:SetSize(140, 22)
	reset:SetText(L["Reset to defaults"])
	reset:SetPoint("TOPLEFT", pulseSwatch, "BOTTOMLEFT", -4, -16)
	reset:SetScript("OnClick", function()
		for key, value in pairs(ns.defaults) do
			ns.db[key] = type(value) == "table" and CopyTable(value) or value
		end
		ns.setEnabled(ns.db.enabled)
		onChanged()
	end)
	content.lowest = {reset, idlePulse}
end


-- the scroll area ends just below the lowest setting
local function fitContent()
	local top = content:GetTop()
	if not top then return end
	local bottom = top
	for _, widget in ipairs(content.lowest) do
		bottom = math.min(bottom, widget:GetBottom() or bottom)
	end
	content:SetHeight(top - bottom + 16)
end


panel:SetScript("OnShow", function(self)
	if not self.built then
		build()
		self.built = true
	end
	for _, widget in ipairs(widgets) do widget:refresh() end
	fitContent()
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
