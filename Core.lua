local addonName = ...
---@class MrMythicalAssistant
local MrMythicalAssistant = _G[addonName] or {}

local DEFAULT_POSITION = { anchor = "BOTTOMRIGHT", x = -120, y = 120 }
local FADE_IN_DURATION = 0.25
local FADE_OUT_DURATION = 0.35
local MIN_REPEAT_SECONDS = 3

---@type Frame
local frame = CreateFrame("Frame", addonName .. "Frame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
frame:SetSize(260, 170)
frame:SetPoint(DEFAULT_POSITION.anchor, UIParent, DEFAULT_POSITION.anchor, DEFAULT_POSITION.x, DEFAULT_POSITION.y)
frame:SetClampedToScreen(true)
frame:SetFrameStrata("DIALOG")
frame:SetAlpha(0)
frame:Hide()

---@type Texture
local avatar = frame:CreateTexture(nil, "ARTWORK")
avatar:SetSize(96, 96)
avatar:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -12)
avatar:SetTexture("Interface/AddOns/MrMythicalAssistant/Logo.png")
avatar:SetTexCoord(0, 1, 0, 1)

---@type FontString
local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
text:SetPoint("TOP", avatar, "BOTTOM", 0, -10)
text:SetWidth(236)
text:SetWordWrap(true)
text:SetJustifyH("CENTER")
text:SetSpacing(2)
text:SetShadowOffset(1, -1)
text:SetShadowColor(0, 0, 0, 0.9)
text:SetTextColor(1, 1, 1, 1)
text:SetText("Mr. Mythical says hi!")

local hideTimer
---@type table<string, number>
local lastEventShown = {}
local moveMode = false
local lastStartedDungeon
local repeatCount = 0
local lastShownTemplate
local cachedKeystoneBag
local cachedKeystoneSlot

local function savePosition()
    local point, _, _, x, y = frame:GetPoint()
    MrMythicalAssistantDB = MrMythicalAssistantDB or {}
    MrMythicalAssistantDB.position = { point = point, x = x, y = y }
end

---Restores the frame position from the database
local function applyPosition()
    local pos = MrMythicalAssistantDB and MrMythicalAssistantDB.position
    frame:ClearAllPoints()
    if pos and pos.point and pos.x and pos.y then
        frame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    else
        frame:SetPoint(DEFAULT_POSITION.anchor, UIParent, DEFAULT_POSITION.anchor, DEFAULT_POSITION.x, DEFAULT_POSITION.y)
    end
end

local function resetPosition()
    MrMythicalAssistantDB = MrMythicalAssistantDB or {}
    MrMythicalAssistantDB.position = { point = "CENTER", x = 0, y = 0 }
    applyPosition()
end

---Selects a random message for a given event
---@param event string The event key to look up in the messages table
---@param avoidMessage string|nil Optional message to avoid when alternatives exist
---@return string|nil message The selected message string or nil if not found
local function pickMessage(event, avoidMessage)
    local list = MrMythicalAssistant.messages[event]
    if not list or #list == 0 then
        return nil
    end
    if #list == 1 then
        return list[1]
    end
    local filtered = {}
    for i = 1, #list do
        if list[i] ~= avoidMessage then
            filtered[#filtered + 1] = list[i]
        end
    end
    if #filtered == 0 then
        filtered = list
    end
    local index = math.random(#filtered)
    return filtered[index]
end

-- Helper to get repair message bracket
local function getRepairBracket(cost)
    if cost < 1000000 then -- less than 1g
        return "LOW"
    elseif cost < 5000000 then -- 1g to 4g99s
        return "MED"
    elseif cost < 7500000 then -- 5g to 7g49s
        return "HIGH"
    else -- 7g50s+
        return "ULTRA"
    end
end

-- Returns true when the keystone socket already contains a key.
local function hasSlottedKeystone()
    if not C_ChallengeMode or not C_ChallengeMode.GetSlottedKeystoneInfo then
        return false
    end

    local ok, mapID, level = pcall(C_ChallengeMode.GetSlottedKeystoneInfo)
    if not ok then
        return false
    end

    return (type(level) == "number" and level > 0) or (type(mapID) == "number" and mapID > 0)
end

local function clearKeystoneCache()
    cachedKeystoneBag = nil
    cachedKeystoneSlot = nil
end

local function trySlotCachedKeystone()
    if cachedKeystoneBag == nil or cachedKeystoneSlot == nil then
        return false
    end

    local itemLocation = ItemLocation:CreateFromBagAndSlot(cachedKeystoneBag, cachedKeystoneSlot)
    if not itemLocation or not C_ChallengeMode.CanUseKeystoneInCurrentMap(itemLocation) then
        clearKeystoneCache()
        return false
    end

    C_Container.PickupContainerItem(cachedKeystoneBag, cachedKeystoneSlot)
    if CursorHasItem() then
        C_ChallengeMode.SlotKeystone()
        return true
    end

    clearKeystoneCache()
    return false
end

local function refreshKeystoneCache()
    clearKeystoneCache()
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local link = C_Container.GetContainerItemLink(bag, slot)
            if link and string.find(link, "Keystone") then
                local itemLocation = ItemLocation:CreateFromBagAndSlot(bag, slot)
                if itemLocation and C_ChallengeMode.CanUseKeystoneInCurrentMap(itemLocation) then
                    cachedKeystoneBag = bag
                    cachedKeystoneSlot = slot
                    return true
                end
            end
        end
    end

    return false
end

local function cancelHideTimer()
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
    if UIFrameFadeRemoveFrame then
        UIFrameFadeRemoveFrame(frame)
    end
end

local function fadeOut()
    if UIFrameFadeOut then
        UIFrameFadeOut(frame, FADE_OUT_DURATION, frame:GetAlpha(), 0)
        hideTimer = C_Timer.NewTimer(FADE_OUT_DURATION, function()
            frame:Hide()
        end)
    else
        frame:SetAlpha(0)
        frame:Hide()
    end
end

---Displays a message for a specific event
---@param event string The event identifier
---@param force boolean? Whether to force show the message ignoring delay throttle
---@param ... any Optional arguments for string formatting in the message
local function showMessage(event, force, ...)
    if not MrMythicalAssistantDB.ENABLE_CHAT_MESSAGES and (event ~= "TEST_BUTTON" and force ~= true) then return end
    
    local now = GetTime()
    local last = lastEventShown[event]
    if not force and last and (now - last) < MIN_REPEAT_SECONDS then
        return -- prevent spam from rapid repeats
    end

    local msgTemplate = pickMessage(event, lastShownTemplate)
    if not msgTemplate then
        return
    end
    local msg = msgTemplate

    -- Format message if args provided
    if ... then
        -- Handle potential formatting errors gracefully
        local success, formatted = pcall(string.format, msg, ...)
        if success then 
            msg = formatted 
        end
    end

    lastEventShown[event] = now
    lastShownTemplate = msgTemplate
    cancelHideTimer()

    text:SetText(msg)
    frame:Show()
    frame:SetAlpha(1)
    if UIFrameFadeIn then
        UIFrameFadeIn(frame, FADE_IN_DURATION, 0, 1)
    end

    local displayTime = MrMythicalAssistantDB.MESSAGE_DURATION or 5
    hideTimer = C_Timer.NewTimer(displayTime, fadeOut)
end

---Toggles the movement mode for the frame
---@param enable boolean Whether to enable or disable move mode
local function setMoveMode(enable)
    moveMode = enable
    cancelHideTimer()

    if enable then
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            savePosition()
        end)
        frame:Show()
        frame:SetAlpha(1)
        avatar:Show()
        text:Show()
        text:SetText("Drag to move Mr. Mythical\nType /mma move to lock")
    else
        frame:SetMovable(false)
        frame:EnableMouse(false)
        frame:RegisterForDrag()
        frame:SetScript("OnDragStart", nil)
        frame:SetScript("OnDragStop", nil)
        frame:Hide()
    end
end

-- Export for Options
MrMythicalAssistant.SetMoveMode = setMoveMode
MrMythicalAssistant.ShowMessage = showMessage

SLASH_MRMYTHICALASSISTANT1 = "/mma"
---Handles slash commands
---@param msg string The message passed to the slash command
SlashCmdList["MRMYTHICALASSISTANT"] = function(msg)
    msg = msg:lower():trim()
    if msg == "test" then
        showMessage("TEST_BUTTON", true)
    elseif msg == "reset" or msg == "resetpos" then
        resetPosition()
        print("|cff00ff00MrMythicalAssistant:|r Position reset to 0, 0.")
    elseif msg == "move" or msg == "unlock" or msg == "lock" then
        if moveMode then
            setMoveMode(false)
            print("|cff00ff00MrMythicalAssistant:|r Position Locked.")
        else
            setMoveMode(true)
            print("|cff00ff00MrMythicalAssistant:|r Position Unlocked. Drag to move.")
        end
    else
        print("|cff00ff00MrMythicalAssistant Commands:|r")
        print("  /mma test   - Show a test message")
        print("  /mma reset  - Reset position to screen center")
        print("  /mma move   - Unlock/Lock the frame position")
    end
end

frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("CHALLENGE_MODE_START")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN")
frame:RegisterEvent("CHALLENGE_MODE_KEYSTONE_SLOTTED")
frame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("MERCHANT_CLOSED")
frame:RegisterEvent("PLAYER_MONEY")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("BAG_UPDATE_DELAYED")

local lastRepairCost = 0
local playerMoney = 0

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            if MrMythicalAssistant.Options and MrMythicalAssistant.Options.initializeSettings then
                MrMythicalAssistant.Options.initializeSettings()
            end
            
            MrMythicalAssistantDB = MrMythicalAssistantDB or {}
            applyPosition()
            refreshKeystoneCache()
        end
        return
    end

    if event == "BAG_UPDATE_DELAYED" then
        refreshKeystoneCache()
        return
    end

    if event == "MERCHANT_SHOW" then
        local cost, canRepair = GetRepairAllCost()
        if canRepair then
            lastRepairCost = cost
        end
        playerMoney = GetMoney()
        return -- Don't show a message just for opening the merchant
    elseif event == "MERCHANT_CLOSED" then
        lastRepairCost = 0
        return
    end

    if event == "PLAYER_MONEY" then
        if not MrMythicalAssistantDB.ENABLE_REPAIR_TRACKING then return end
        
        if MerchantFrame:IsShown() then
            local currentMoney = GetMoney()
            local moneyDiff = playerMoney - currentMoney
            local currentRepairCost = GetRepairAllCost()
            
            -- If money went down (~cost) and repair cost is now 0
            if lastRepairCost > 0 and currentRepairCost == 0 and moneyDiff > 0 then
                 if math.abs(moneyDiff - lastRepairCost) < 100 then
                     local costString = C_CurrencyInfo.GetCoinTextureString(lastRepairCost)
                     local bracket = getRepairBracket(lastRepairCost)
                     showMessage("REPAIR_BILL_SELF_" .. bracket, true, costString)
                     lastRepairCost = 0
                 end
            end
            playerMoney = currentMoney
        end
        return
    end

    if event == "PLAYER_DEAD" then
        showMessage(event)

    elseif event == "CHALLENGE_MODE_START" then
        local mapID = C_ChallengeMode.GetActiveChallengeMapID()
        local level = C_ChallengeMode.GetActiveKeystoneInfo()
        local mapName = mapID and C_ChallengeMode.GetMapUIInfo(mapID) or "Unknown Dungeon"

        if lastStartedDungeon and mapName == lastStartedDungeon then
            repeatCount = repeatCount + 1
            showMessage("CHALLENGE_MODE_START_REPEAT", false, mapName, tostring(repeatCount + 1))
        else
            if lastStartedDungeon and repeatCount > 0 then
                showMessage("CHALLENGE_MODE_START_SWITCH_AFTER_REPEAT", false, lastStartedDungeon, tostring(repeatCount), mapName)
            else
                showMessage(event, false, level or "?", mapName)
            end
            lastStartedDungeon = mapName
            repeatCount = 0
        end

    elseif event == "CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN" then
        if hasSlottedKeystone() then
            return
        end

        if MrMythicalAssistantDB.ENABLE_KEY_AUTO_INSERT then
            local validKeyFound = trySlotCachedKeystone()
            if not validKeyFound and refreshKeystoneCache() then
                validKeyFound = trySlotCachedKeystone()
            end
    
            if not validKeyFound then
                showMessage(event)
            end
        else
            showMessage(event)
        end

    elseif event == "CHALLENGE_MODE_KEYSTONE_SLOTTED" then
        clearKeystoneCache()
        showMessage("KEY_INSERTED", true)
        
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        showMessage(event, true)
    
    elseif event == "PLAYER_LEVEL_UP" then
        local level = UnitLevel("player")
        showMessage("PLAYER_LEVEL_UP", false, level)
    end
end)

---Hook repair function to catch when user repairs
---@param useGuild boolean Whether the repair is paid by the guild
hooksecurefunc("RepairAllItems", function(useGuild)
    if not MrMythicalAssistantDB.ENABLE_REPAIR_TRACKING then return end

    if lastRepairCost > 0 then
        local costString = C_CurrencyInfo.GetCoinTextureString(lastRepairCost)
        local bracket = getRepairBracket(lastRepairCost)
        if useGuild then
            showMessage("REPAIR_BILL_GUILD_" .. bracket, true, costString)
        else
            showMessage("REPAIR_BILL_SELF_" .. bracket, true, costString)
        end
        lastRepairCost = 0 -- Reset so we don't show it again via auto-detect
    end
end)
