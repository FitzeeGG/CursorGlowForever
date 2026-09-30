-- Options panel (Esc > Options > AddOns > Cursor Glow Forever, or /cg).
-- Widgets are built from plain textures so they work on any client. Text is
-- translated in Locales.lua.
local _, ns = ...
local L = ns.L

local panel = CreateFrame("Frame")
panel:Hide()
local widgets = {}
-- the settings scroll under a fixed header holding the live preview and the
-- tabs; each tab is a page in the scroll area
local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
local content = CreateFrame("Frame", nil, scroll)
scroll:SetScrollChild(content)
local pages, tabs = {}, {}
local parent = content -- the page widgets are being built on
local PREVIEW_MAX = 40 -- largest sample cursor, so its glow fits the preview
local RIGHT_COLUMN = 344


local function onChanged()
	ns.updateLayout()
	for _, widget in ipairs(widgets) do
		if widget.refresh then widget:refresh() end
	end
end


local function createLabel(owner, text, template)
	local label = owner:CreateFontString(nil, "ARTWORK", template or "GameFontHighlight")
	label:SetText(text)
	return label
end


local function setTooltip(frame, title, tooltip)
	frame:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(title, 1, 1, 1)
		GameTooltip:AddLine(tooltip, nil, nil, nil, true)
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", GameTooltip_Hide)
end


local function createCheckbox(key, text, tooltip)
	local check = CreateFrame("CheckButton", nil, parent)
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
	if tooltip then setTooltip(check, text, tooltip) end
	function check:refresh() self:SetChecked(ns.db[key]) end
	table.insert(widgets, check)
	return check
end


-- values: list of {value, text} for a slider over fixed choices
local function createSlider(key, text, minValue, maxValue, step, format, values, tooltip, width)
	local slider = CreateFrame("Slider", nil, parent)
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
	if tooltip then setTooltip(slider, text, tooltip) end
	function slider:refresh()
		self:SetValue(toPosition(ns.db[key]))
		showValue(ns.db[key])
	end
	table.insert(widgets, slider)
	return slider
end


-- disabledBy: the checkbox setting that, while ticked, makes this colour unused
local function createColorSwatch(key, text, disabledBy)
	local swatch = CreateFrame("Button", nil, parent)
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


local function createButton(owner, text, width, tooltip)
	local button = CreateFrame("Button", nil, owner, "UIPanelButtonTemplate")
	button:SetSize(width, 22)
	button:SetText(text)
	if tooltip then setTooltip(button, text, tooltip) end
	return button
end


-- Live preview: the cursor and the glove drawn while turning the camera, with
-- the current colour, glow, outline, size and glove settings, and the cast and
-- global cooldown rings (when on) running through a pretend cast.
local DEMO_CAST, DEMO_GCD, DEMO_EVERY = 1.6, 1.5, 2.4 -- seconds

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
		sample.rings = ns.createRings(sample)
		local caption = createLabel(box, turning and L["Turning the camera"] or L["Cursor"], "GameFontDisableSmall")
		caption:SetPoint("BOTTOM", box, "BOTTOMLEFT", 120 * (i - .5), 6)
		box.samples[i] = sample
	end

	-- a custom ring position is placed on the preview's cursor
	box.hint = createLabel(box, L["Drag to place the ring"], "GameFontHighlightSmall")
	box.hint:SetPoint("TOP", box, "TOP", 0, -5)
	box:SetScript("OnMouseDown", function(self, button)
		if ns.db.ringPosition ~= "custom" then return end
		if button == "RightButton" then
			ns.setRingOffset(0, 0)
			onChanged()
		else
			self.dragging = true
		end
	end)
	box:SetScript("OnMouseUp", function(self)
		if not self.dragging then return end
		self.dragging = false
		onChanged()
	end)

	local function layoutRings(sample)
		ns.layoutRings(sample.rings, sample.size)
		-- while placing them, the rings show clearly even without a cast
		if ns.db.ringPosition == "custom" then
			for _, ring in pairs(sample.rings) do ring.track:SetAlpha(.6) end
			sample.rings.cast.track:Show()
		end
	end
	box.layoutRings = layoutRings

	-- the demo cast restarts every few seconds while the preview shows
	box.lastDemo = -DEMO_EVERY
	box:SetScript("OnUpdate", function(self)
		local now, db = GetTime(), ns.db
		if self.dragging then
			local sample = self.samples[1]
			local x, y = sample:GetCenter()
			local scale = self:GetEffectiveScale()
			local mouseX, mouseY = GetCursorPosition()
			if x and sample.size and sample.size > 0 then
				ns.setRingOffset((mouseX / scale - x) / sample.size, (mouseY / scale - y) / sample.size)
				ns.updateRings()
				for _, each in ipairs(self.samples) do layoutRings(each) end
			end
		end
		if now - self.lastDemo >= DEMO_EVERY then
			self.lastDemo = now
			for _, sample in ipairs(self.samples) do
				if db.castRing then ns.startRing(sample.rings.cast, now, DEMO_CAST, false) else ns.stopRing(sample.rings.cast) end
				if db.gcdRing then ns.startRing(sample.rings.gcd, now, DEMO_GCD, false) else ns.stopRing(sample.rings.gcd) end
				layoutRings(sample)
			end
		end
	end)

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
			sample.size = size
			layoutRings(sample)
			-- the game draws no glove while turning without the option
			sample:SetShown(not sample.turning or db.gloveWhileTurning)
		end
		-- restart the demo so a ring just switched on shows straight away
		self.lastDemo = -DEMO_EVERY
		local placing = db.ringPosition == "custom"
		self:EnableMouse(placing)
		self.hint:SetShown(placing)
		self:SetAlpha(db.enabled and 1 or .4)
	end
	table.insert(widgets, box)
	return box
end


-- PROFILES
local function getProfileLabel(name)
	return name == ns.DEFAULT_PROFILE and L["Default"] or name
end


local function printMessage(text)
	print("|cff66ccff"..ns.TITLE..":|r "..text)
end


-- the edit box of a StaticPopup, across client versions
local function getPopupEditBox(popup)
	return popup.editBox or popup.EditBox or (popup.GetEditBox and popup:GetEditBox())
end


local function createNewProfile(name)
	if ns.newProfile(name) then
		onChanged()
	elseif (name or ""):match("%S") then
		printMessage(L["A profile with that name already exists."])
	end
end


StaticPopupDialogs.CURSORGLOWFOREVER_NEW_PROFILE = {
	text = L["Name for the new profile (a copy of the current settings):"],
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = true,
	maxLetters = 40,
	OnShow = function(self)
		local editBox = getPopupEditBox(self)
		editBox:SetText(ns.getCharacterName())
		editBox:HighlightText()
	end,
	OnAccept = function(self) createNewProfile(getPopupEditBox(self):GetText()) end,
	EditBoxOnEnterPressed = function(self)
		createNewProfile(self:GetText())
		self:GetParent():Hide()
	end,
	EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

StaticPopupDialogs.CURSORGLOWFOREVER_DELETE_PROFILE = {
	text = L["Delete the profile %s? Characters using it go back to Default."],
	button1 = YES,
	button2 = NO,
	OnAccept = function(_, name)
		ns.deleteProfile(name)
		onChanged()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}


StaticPopupDialogs.CURSORGLOWFOREVER_RESET = {
	text = L["Reset all settings in the profile %s to their defaults?"],
	button1 = YES,
	button2 = NO,
	OnAccept = function()
		for key, value in pairs(ns.defaults) do
			ns.db[key] = type(value) == "table" and CopyTable(value) or value
		end
		ns.setEnabled(ns.db.enabled)
		onChanged()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}


-- a list of profiles under a button; onPick(name) for the one clicked
local menu
local function showProfileMenu(anchor, names, onPick)
	if not menu then
		menu = CreateFrame("Frame", nil, panel)
		menu:SetFrameStrata("FULLSCREEN_DIALOG")
		menu:SetClampedToScreen(true)
		local background = menu:CreateTexture(nil, "BACKGROUND")
		background:SetColorTexture(.08, .08, .09, .97)
		background:SetAllPoints()
		menu.items = {}
		panel:HookScript("OnHide", function() menu:Hide() end)
	end
	if menu:IsShown() and menu.anchor == anchor then
		menu:Hide()
		return
	end
	menu.anchor = anchor
	for i, name in ipairs(names) do
		local item = menu.items[i]
		if not item then
			item = CreateFrame("Button", nil, menu)
			item:SetSize(200, 20)
			item:SetPoint("TOPLEFT", 4, -4 - 20 * (i - 1))
			item:SetHighlightTexture("Interface/QuestFrame/UI-QuestTitleHighlight", "ADD")
			item.text = createLabel(item, "")
			item.text:SetPoint("LEFT", 6, 0)
			menu.items[i] = item
		end
		item.text:SetText(getProfileLabel(name))
		item:SetScript("OnClick", function()
			menu:Hide()
			onPick(name)
		end)
		item:Show()
	end
	for i = #names + 1, #menu.items do menu.items[i]:Hide() end
	menu:SetSize(208, 8 + 20 * #names)
	menu:ClearAllPoints()
	menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
	menu:Show()
end


-- Profile [current v] [New] [Copy from] [Delete]
local function createProfileRow()
	local label = createLabel(parent, L["Profile"], "GameFontNormal")
	local current = createButton(parent, "", 180,
		L["Profiles are shared by all your characters; each character remembers which one it uses."])
	current:SetPoint("LEFT", label, "RIGHT", 10, 0)
	current:GetFontString():SetPoint("LEFT", 10, 0)
	current:GetFontString():SetPoint("RIGHT", -22, 0)
	current:GetFontString():SetJustifyH("LEFT")
	local arrow = current:CreateTexture(nil, "OVERLAY")
	arrow:SetTexture("Interface/ChatFrame/UI-ChatIcon-ScrollDown-Up")
	arrow:SetSize(20, 20)
	arrow:SetPoint("RIGHT", -2, 0)
	current:SetScript("OnClick", function(self)
		showProfileMenu(self, ns.getProfileNames(), function(name)
			ns.setProfile(name)
			onChanged()
		end)
	end)

	local new = createButton(parent, L["New"], 70, L["Start a new profile from a copy of the current settings."])
	new:SetPoint("LEFT", current, "RIGHT", 6, 0)
	new:SetScript("OnClick", function() StaticPopup_Show("CURSORGLOWFOREVER_NEW_PROFILE") end)

	local copy = createButton(parent, L["Copy from"], 100, L["Copy another profile's settings into this one."])
	copy:SetPoint("LEFT", new, "RIGHT", 4, 0)
	copy:SetScript("OnClick", function(self)
		local others = {}
		for _, name in ipairs(ns.getProfileNames()) do
			if name ~= ns.getProfileName() then table.insert(others, name) end
		end
		showProfileMenu(self, others, function(name)
			ns.copyProfile(name)
			onChanged()
		end)
	end)

	local delete = createButton(parent, L["Delete"], 70, L["Delete this profile. Characters using it go back to Default."])
	delete:SetPoint("LEFT", copy, "RIGHT", 4, 0)
	delete:SetScript("OnClick", function()
		local name = ns.getProfileName()
		StaticPopup_Show("CURSORGLOWFOREVER_DELETE_PROFILE", getProfileLabel(name), nil, name)
	end)

	function label:refresh()
		current:SetText(getProfileLabel(ns.getProfileName()))
		copy:SetEnabled(#ns.getProfileNames() > 1)
		delete:SetEnabled(ns.getProfileName() ~= ns.DEFAULT_PROFILE)
	end
	table.insert(widgets, label)
	return label
end


-- CURSOR TAB: profile, look, visibility, hover outlines, turning the camera
local function buildCursorPage(page)
	local enabled = createCheckbox("enabled", L["Enable"])
	enabled:SetPoint("TOPLEFT", page, "TOPLEFT", 14, -4)
	enabled.onChange = ns.setEnabled

	local profile = createProfileRow()
	profile:SetPoint("TOPLEFT", enabled, "BOTTOMLEFT", 4, -14)

	-- left column
	local showWhen = createSlider("showWhen", L["Show the glow"], nil, nil, nil, nil,
		{{"always", L["Always"]}, {"combat", L["In combat"]}, {"noCombat", L["Out of combat"]}},
		L["Show the glow always, only in combat, or only out of combat. Shake to find still shows it for a moment."])
	showWhen:SetPoint("TOPLEFT", profile, "BOTTOMLEFT", 0, -40)

	local classColor = createCheckbox("useClassColor", L["Use class colour"], L["Colour the glow with your class colour. Untick to pick a custom colour."])
	classColor:SetPoint("TOPLEFT", showWhen, "BOTTOMLEFT", -4, -20)
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

	-- right column, level with the top of the left one
	local hover = createCheckbox("hideOnHover", L["Hide on hover targets"],
		L["Hide the glove glow while the cursor has a hover look (mailbox, enemy, NPC...)."])
	hover:SetPoint("TOPLEFT", showWhen, "TOPLEFT", RIGHT_COLUMN - 8, 20)

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

	page.lowest = {prediction, intensity}
end


-- EFFECTS TAB: finding the cursor, pulses, rings and clicks
local function buildEffectsPage(page)
	-- left column
	local shakeToFind = createCheckbox("shakeToFind", L["Shake to find"],
		L["Shake the mouse quickly side to side to flash a bright halo around the cursor, so you can find it."])
	shakeToFind:SetPoint("TOPLEFT", page, "TOPLEFT", 14, -4)

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

	local idlePulse = createCheckbox("idlePulse", L["Pulse when idle"],
		L["After a few seconds without moving the mouse, the glow slowly fades out and back in (the outline stays) until you move it again."])
	idlePulse:SetPoint("TOPLEFT", pulseSwatch, "BOTTOMLEFT", -4, -16)

	-- right column
	local clickRipple = createCheckbox("clickRipple", L["Click ripple"],
		L["A ring spreads out and fades where you click, so you can see each click land."])
	clickRipple:SetPoint("TOPLEFT", shakeToFind, "TOPLEFT", RIGHT_COLUMN, 0)

	local castRing = createCheckbox("castRing", L["Cast ring"],
		L["A ring around the cursor fills up while you cast, and drains while you channel."])
	castRing:SetPoint("TOPLEFT", clickRipple, "BOTTOMLEFT", 0, -16)

	local gcdRing = createCheckbox("gcdRing", L["Global cooldown ring"],
		L["A second, smaller ring fills up over the global cooldown."])
	gcdRing:SetPoint("TOPLEFT", castRing, "BOTTOMLEFT", 0, -4)

	local ringGlowColor = createCheckbox("ringUseGlowColor", L["Rings use glow colour"],
		L["Colour the rings with the glow colour. Untick to pick a ring colour."])
	ringGlowColor:SetPoint("TOPLEFT", gcdRing, "BOTTOMLEFT", 0, -4)
	local ringSwatch = createColorSwatch("ringColor", L["Ring colour"], "ringUseGlowColor")
	ringSwatch:SetPoint("TOPLEFT", ringGlowColor, "BOTTOMLEFT", 4, -6)

	-- where the rings sit and how big they are
	local ringPosition = createSlider("ringPosition", L["Ring position"], nil, nil, nil, nil,
		{{"default", L["Default"]}, {"fingertip", L["Finger tip"]}, {"custom", L["Custom"]}},
		L["Where the rings sit: around the cursor, on its finger tip, or wherever you place them."])
	ringPosition:SetPoint("TOPLEFT", ringSwatch, "BOTTOMLEFT", 0, -38)

	local placeHint = createLabel(parent, L["Click or drag in the preview at the top to place the ring. Right-click the preview to centre it again."], "GameFontHighlightSmall")
	placeHint:SetPoint("TOPLEFT", ringPosition, "BOTTOMLEFT", 0, -12)
	placeHint:SetWidth(250)
	placeHint:SetJustifyH("LEFT")

	local ringSize = createSlider("ringSize", L["Ring size"], nil, nil, nil, nil,
		{{"default", L["Default"]}, {"small", L["Small"]}, {"medium", L["Medium"]}, {"large", L["Large"]}, {"custom", L["Custom"]}},
		L["How big the rings are: sized around the cursor by default, or smaller or larger."])

	local ringScale = createSlider("ringScale", L["Custom ring size"], .4, 3, .05, "%.2fx", nil,
		L["How big the rings are, compared with the default size."])
	ringScale:SetPoint("TOPLEFT", ringSize, "BOTTOMLEFT", 0, -34)

	-- the placing hint and the custom size slider only show when they apply
	function placeHint:refresh()
		local custom = ns.db.ringPosition == "custom"
		self:SetShown(custom)
		ringSize:ClearAllPoints()
		if custom then
			ringSize:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -30)
		else
			ringSize:SetPoint("TOPLEFT", ringPosition, "BOTTOMLEFT", 0, -34)
		end
		ringScale:SetShown(ns.db.ringSize == "custom")
	end
	table.insert(widgets, placeHint)

	page.lowest = {idlePulse, ringScale}
end


-- the scroll area ends just below the lowest setting on the page shown
local function fitContent()
	local page = pages[panel.page or 1]
	local top = page and page:GetTop()
	if not top then return end
	local bottom = top
	for _, widget in ipairs(page.lowest) do
		bottom = math.min(bottom, widget:GetBottom() or bottom)
	end
	content:SetHeight(top - bottom + 16)
end


local function showPage(index)
	panel.page = index
	for i, page in ipairs(pages) do page:SetShown(i == index) end
	for i, tab in ipairs(tabs) do
		if i == index then tab:LockHighlight() else tab:UnlockHighlight() end
	end
	if menu then menu:Hide() end
	scroll:SetVerticalScroll(0)
	fitContent()
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

	for i, name in ipairs({L["Cursor"], L["Effects"]}) do
		local tab = createButton(panel, name, 110)
		tab:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 16 + 114 * (i - 1), -128)
		tab:SetScript("OnClick", function() showPage(i) end)
		tabs[i] = tab
	end
	local reset = createButton(panel, L["Reset to defaults"], 140)
	reset:SetPoint("LEFT", tabs[#tabs], "RIGHT", 12, 0)
	reset:SetScript("OnClick", function()
		StaticPopup_Show("CURSORGLOWFOREVER_RESET", getProfileLabel(ns.getProfileName()))
	end)

	local line = panel:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(1, 1, 1, .15)
	line:SetHeight(1)
	line:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -130)
	line:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -130)

	scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -136)
	scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 8)
	scroll:SetScript("OnSizeChanged", function(_, width) content:SetWidth(width) end)
	content:SetSize(640, 700)

	for i, buildPage in ipairs({buildCursorPage, buildEffectsPage}) do
		local page = CreateFrame("Frame", nil, content)
		page:SetPoint("TOPLEFT")
		page:SetPoint("TOPRIGHT")
		page:SetHeight(1)
		parent = page
		buildPage(page)
		pages[i] = page
	end
	parent = content
end


panel:SetScript("OnShow", function(self)
	if not self.built then
		build()
		self.built = true
	end
	for _, widget in ipairs(widgets) do widget:refresh() end
	showPage(self.page or 1)
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
	if msg and msg:lower():match("^%s*test%s*$") then
		-- both rings on the real cursor, whatever the settings, to see that they draw
		local now = GetTime()
		ns.startRing(ns.rings.cast, now, 3, false)
		ns.startRing(ns.rings.gcd, now, 1.5, false)
		print("|cff66ccffCursor Glow Forever:|r test rings: a 3 second cast ring and a 1.5 second global cooldown ring")
		return
	end
	Settings.OpenToCategory(category:GetID())
end
