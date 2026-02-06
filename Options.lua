--[[
Options.lua - Mr. Mythical Assistant Options Panel

Purpose: Manages settings panel and global registry for Mr. Mythical addons
Author: Braunerr
--]]

local addonName = ...
local MrMythicalAssistant = _G.MrMythicalAssistant or {}
_G.MrMythicalAssistant = MrMythicalAssistant

local Options = {}
MrMythicalAssistant.Options = Options

local DEFAULTS = {
    POSITION = { anchor = "BOTTOMRIGHT", x = -120, y = 120 },
    ENABLE_CHAT_MESSAGES = true,
    ENABLE_SOUND_EFFECTS = true, -- Future proofing
    ENABLE_REPAIR_TRACKING = true,
    ENABLE_KEY_AUTO_INSERT = true,
    VERBOSE_MODE = false,
    MESSAGE_DURATION = 5 -- Default 5 seconds
}

local TOOLTIPS = {
    ENABLE_KEY_AUTO_INSERT = "Allow Mr. Mythical to automatically attempt to insert your keystone when you open the receptacle.",
    MESSAGE_DURATION = "How long the message stays on screen."
}

local MessageDurationOptions = {
    { text = "Short (3s)", value = 3 },
    { text = "Normal (5s)", value = 5 },
    { text = "Long (8s)",  value = 8 },
    { text = "Very Long (12s)", value = 12 }
}

--- Creates a setting with appropriate UI element
local function createSetting(category, name, key, settingType, tooltip, options)
    local defaultValue = DEFAULTS[key]
    -- Note: MrMythicalAssistantDB is global, defined in main file
    local setting = Settings.RegisterAddOnSetting(category, name, key, MrMythicalAssistantDB, settingType, name, defaultValue)
    
    setting:SetValueChangedCallback(function(_, value)
        MrMythicalAssistantDB[key] = value
        -- Trigger update in main addon if needed
        if MrMythicalAssistant.OnSettingChanged then
            MrMythicalAssistant.OnSettingChanged(key, value)
        end
    end)

    local initializer
    if settingType == "boolean" then
        initializer = Settings.CreateCheckbox(category, setting, tooltip)
    else 
        -- Dropdown logic if needed later
        local function getOptions()
            local dropdownOptions = {}
            local menuRadio = (_G.MenuButtonType and _G.MenuButtonType.Radio)
                or (_G.Enum and Enum.MenuItemType and Enum.MenuItemType.Radio)
                or 1 
            for _, option in ipairs(options) do
                table.insert(dropdownOptions, {
                    text = option.text,
                    label = option.text,
                    value = option.value,
                    controlType = menuRadio,
                    checked = function() return setting:GetValue() == option.value end,
                    func = function() setting:SetValue(option.value) end,
                })
            end
            return dropdownOptions
        end
        initializer = Settings.CreateDropdown(category, setting, getOptions, tooltip)
    end

    initializer:SetSetting(setting)
    return { setting = setting, initializer = initializer }
end

--- Initializes saved variables
function Options.initializeSettings()
    MrMythicalAssistantDB = MrMythicalAssistantDB or {}
    
    -- Set defaults
    for key, default in pairs(DEFAULTS) do
        if MrMythicalAssistantDB[key] == nil then
            MrMythicalAssistantDB[key] = default
        end
    end
    
    -- Create panel
    local success = pcall(Options.createSettingsPanel)
    if not success then
        C_Timer.After(0.1, function()
            pcall(Options.createSettingsPanel)
        end)
    end
end

--- Creates the settings structure
function Options.createSettingsPanel()
    -- Use global registry to share parent category
    if not _G.MrMythicalSettingsRegistry then
        _G.MrMythicalSettingsRegistry = {}
    end

    local registry = _G.MrMythicalSettingsRegistry
    local parentCategory = nil

    if registry.parentCategory then
        parentCategory = registry.parentCategory
    else
        -- Create shared parent category
        local success, result = pcall(function()
            return Settings.RegisterVerticalLayoutCategory("Mr. Mythical")
        end)
        
        if success and result then
            parentCategory = result
            registry.parentCategory = parentCategory
            registry.createdBy = "MrMythicalAssistant"
            Settings.RegisterAddOnCategory(parentCategory)
        end
    end

    -- Create subcategory for Assistant
    local category
    local subcategorySuccess, subcategoryResult = pcall(function()
        return Settings.RegisterVerticalLayoutSubcategory(parentCategory, "Assistant")
    end)

    if subcategorySuccess and subcategoryResult then
        category = subcategoryResult
        registry.subCategories = registry.subCategories or {}
        registry.subCategories["Assistant"] = category
    else
        -- Fallback
        local altSuccess, altResult = pcall(function()
            local subCat = Settings.RegisterVerticalLayoutCategory("Assistant")
            subCat:SetParentCategory(parentCategory)
            return subCat
        end)
        
        if altSuccess and altResult then
            category = altResult
            registry.subCategories = registry.subCategories or {}
            registry.subCategories["Assistant"] = category
        end
    end

    if category then
        Options.createSettingsInCategory(category)
    end
end

function Options.createSettingsInCategory(category)
    local layout = SettingsPanel:GetLayout(category)
    
    local function addHeader(name, tooltip)
        local headerData = { name = name, tooltip = tooltip }
        local headerInitializer = Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", headerData)
        layout:AddInitializer(headerInitializer)
    end

    local settingsConfig = {
        {
            header = { name = "Display Options", tooltip = "Configure appearance" },
            settings = {
                {
                    name = "Message Duration",
                    key = "MESSAGE_DURATION",
                    type = "number",
                    tooltip = TOOLTIPS.MESSAGE_DURATION,
                    options = MessageDurationOptions
                }
            }
        },
        {
            header = { name = "Automation Features", tooltip = "Configure automated actions" },
            settings = {
                {
                    name = "Auto Insert Keystone",
                    key = "ENABLE_KEY_AUTO_INSERT",
                    type = "boolean",
                    tooltip = TOOLTIPS.ENABLE_KEY_AUTO_INSERT
                }
            }
        }
    }

    for _, section in ipairs(settingsConfig) do
        if section.header then
            addHeader(section.header.name, section.header.tooltip)
        end
        for _, setting in ipairs(section.settings) do
            createSetting(category, setting.name, setting.key, setting.type, setting.tooltip, setting.options)
        end
    end
end
