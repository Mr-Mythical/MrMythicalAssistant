local addonName = ...
---@class MrMythicalAssistant
local MrMythicalAssistant = _G[addonName] or {}

--- Default position configuration for the display frame
local DEFAULT_POSITION = { anchor = "BOTTOMRIGHT", x = -120, y = 120 }
--- Duration for the fade-in animation
local FADE_IN_DURATION = 0.25
--- Duration for the fade-out animation
local FADE_OUT_DURATION = 0.35
--- Minimum seconds between showing messages for the same event
local MIN_REPEAT_SECONDS = 3 -- throttle to avoid spamming the same event

--- Table containing all available messages for different events
---@type table<string, string[]>
local messages = {
    PLAYER_DEAD = {
        "Ah. Yes. That mechanic.",
        "Fascinating decision-making, really.",
        "One does not simply ignore swirlies.",
        "Shall we pretend that pull didn’t happen?",
        "Gravity is a harsh mistress, isn't it?",
        "A tactical reset, I presume?",
        "Brilliant performance. Truly."
    },
    CHALLENGE_MODE_START = {
        "Another dungeon? Do try to be entertaining.",
        "A +%s? How ambitious.",
        "Time starts now. Don't disappoint me.",
        "Do try to keep up, darling.",
        "Oh good, cardio."
    },
    CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN = {
        "Window shopping? You don't have this key.",
        "You opened the slot. Marvelous. Now where is the key?",
        "Planning to insert your imagination? You have no keystone for this dungeon.",
        "Do you enjoy staring at empty sockets?"
    },
    KEY_INSERTED = {
        "The key is set. Do try not to break it.",
        "Are you sure you're ready for this?",
        "A bold choice."
    },
    TEST_BUTTON = {
        "Do not poke the unicorn.",
        "I am working, can't you see?",
        "Yes, yes, I'm here. Sophisticated as always."
    },
    CHALLENGE_MODE_COMPLETED = {
        "Finally. I was getting bored.",
        "It is done. Adequately.",
        "Not terrible. I've seen worse.",
        "Timed? Barely.",
        "Next time, try to be faster."
    },
    REPAIR_BILL_SELF = {
        "Repaired for %s. Expensive hobby, isn't it?",
        "Swirlies are not for standing in. That will be %s.",
        "Your armor is made of paper. %s deducted.",
        "%s? I suppose durability is optional for you."
    },
    REPAIR_BILL_GUILD = {
        "%s repair bill? Your guild master must hate you.",
        "Draining the guild bank of %s. How very altruistic.",
        "The guild pays %s for your incompetence. Charming.",
        "%s from the guild funds. Do you enjoy being a liability?"
    }
}

-- Display frame for avatar and text
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

---Saves the current frame position to the database
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

---Selects a random message for a given event
---@param event string The event key to look up in the messages table
---@return string|nil message The selected message string or nil if not found
local function pickMessage(event)
    local list = messages[event]
    if not list or #list == 0 then
        return nil
    end
    local index = math.random(#list)
    return list[index]
end

---Cancels the current active hide timer and animation
local function cancelHideTimer()
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
    if UIFrameFadeRemoveFrame then
        UIFrameFadeRemoveFrame(frame)
    end
end

---Fades out the frame
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

    local msg = pickMessage(event)
    if not msg then
        return
    end

    -- Format message if args provided
    if ... then
        -- Handle potential formatting errors gracefully
        local success, formatted = pcall(string.format, msg, ...)
        if success then 
            msg = formatted 
        end
    end

    lastEventShown[event] = now
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
---Handle slash commands
---@param msg string The message passed to the slash command
SlashCmdList["MRMYTHICALASSISTANT"] = function(msg)
    msg = msg:lower():trim()
    if msg == "test" then
        showMessage("TEST_BUTTON", true)
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

local lastRepairCost = 0
local playerMoney = 0

---Main event handler script
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            -- Initialize Options first which handles DB defaults
            if MrMythicalAssistant.Options and MrMythicalAssistant.Options.initializeSettings then
                MrMythicalAssistant.Options.initializeSettings()
            end
            
            MrMythicalAssistantDB = MrMythicalAssistantDB or {}
            applyPosition()
        end
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
                     showMessage("REPAIR_BILL_SELF", true, costString)
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
        showMessage(event, false, level or "?", mapName)

    elseif event == "CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN" then
        -- Auto insert keystone logic
        if MrMythicalAssistantDB.ENABLE_KEY_AUTO_INSERT then
            local validKeyFound = false
            for bag = 0, 4 do
                local numSlots = C_Container.GetContainerNumSlots(bag)
                for slot = 1, numSlots do
                    local link = C_Container.GetContainerItemLink(bag, slot)
                    if link and string.find(link, "Keystone") then
                        local itemLocation = ItemLocation:CreateFromBagAndSlot(bag, slot)
                        if itemLocation and C_ChallengeMode.CanUseKeystoneInCurrentMap(itemLocation) then
                            C_Container.PickupContainerItem(bag, slot)
                            if CursorHasItem() then
                                 C_ChallengeMode.SlotKeystone()
                                 validKeyFound = true
                            end
                            break 
                        end
                    end
                end
                if validKeyFound then break end
            end
    
            if not validKeyFound then
                showMessage(event)
            end
        else
            showMessage(event)
        end

    elseif event == "CHALLENGE_MODE_KEYSTONE_SLOTTED" then
        showMessage("KEY_INSERTED", true)
        
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        local info = C_ChallengeMode.GetChallengeCompletionInfo()
        
        if info and info.onTime then
             showMessage(event, true)
        else
             showMessage(event, true) 
        end
    end
end)

---Hook repair function to catch when user repairs
---@param useGuild boolean Whether the repair is paid by the guild
hooksecurefunc("RepairAllItems", function(useGuild)
    if not MrMythicalAssistantDB.ENABLE_REPAIR_TRACKING then return end

    if lastRepairCost > 0 then
        local costString = C_CurrencyInfo.GetCoinTextureString(lastRepairCost)
        if useGuild then
            showMessage("REPAIR_BILL_GUILD", true, costString)
        else
            showMessage("REPAIR_BILL_SELF", true, costString)
        end
        lastRepairCost = 0 -- Reset so we don't show it again via auto-detect
    end
end)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("CHALLENGE_MODE_START")
