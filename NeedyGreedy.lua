NeedyGreedy = LibStub("AceAddon-3.0"):NewAddon("NeedyGreedy", "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale("NeedyGreedy", true)
local LSM = LibStub("LibSharedMedia-3.0")

local report = {}
local items = {}
local nameList = {}
local NAME_LOG = {}
local NAMELIST_LOG = {}
local EVENT_LOG = {}

-- Set up DataBroker object
local NeedyGreedyLDB = LibStub("LibDataBroker-1.1"):NewDataObject("NeedyGreedy", {
    type = "data source",
    text = "",
    label = "Needy Greedy",
    icon = "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
    OnClick = function(frame, button)
        if button == "RightButton" then
            InterfaceOptionsFrame_OpenToCategory("NeedyGreedy")
        elseif IsShiftKeyDown() then
            NeedyGreedy.db.profile.detachedTooltip = not NeedyGreedy.db.profile.detachedTooltip
            LibStub("AceConfigRegistry-3.0"):NotifyChange("NeedyGreedy")
            NeedyGreedy:HideDBTooltip()
            NeedyGreedy:ShowDBTooltip(frame)
            NeedyGreedy:HideDetachedTooltip()
            if NeedyGreedy.db.profile.detachedTooltip then
                NeedyGreedy.db.profile.displayStatus = true
                NeedyGreedy:RefreshTooltip()
            end
        elseif IsAltKeyDown() then
            NeedyGreedy:ClearItems()
        elseif NeedyGreedy.db.profile.detachedTooltip then
            NeedyGreedy:ToggleDisplay()
        end
    end,
    OnEnter = function(frame)
        NeedyGreedy:ShowDBTooltip(frame)
    end,
    OnLeave = function()
        if NeedyGreedy.db.profile.detachedTooltip then
            NeedyGreedy:HideDBTooltip()
        end
    end,
})
local ngDBIcon = LibStub("LibDBIcon-1.0")

-- Set up configuration window
local options = {
    name = L["NeedyGreedy"],
    desc = L["Displays a table of items and the roll choices players have made on them"],
    handler = NeedyGreedy,
    type = "group",
    args = {
        general = {
            name = L['General'],
            type = 'group',
            childGroups = "tab",
            args = {
                nItems = {
                    name = L["Display Items"],
                    desc = L["Number of item columns in the display window"],
                    type = "range",
                    order = 105,
                    min = 1,
                    max = 10,
                    step = 1,
                    get = "GetNItems",
                    set = "SetNItems"
                },
                maxHeight = {
                    name = L["Maximum Height"],
                    desc = L["Maximum height of the display window"],
                    type = "range",
                    order = 106,
                    min = 200,
                    max = 1200,
                    step = 10,
                    get = "GetMaxHeight",
                    set = "SetMaxHeight",
                },
                expiry = {
                    name = L["Expiry Time"],
                    desc = L["Minutes after item is received before it is removed from display (0 = forever)"],
                    type = "range",
                    order = 120,
                    min = 0,
                    max = 110,
                    step = 1,
                    get = "GetExpiry",
                    set = "SetExpiry"
                },
                quality = {
                    name = L["Minimum Quality"],
                    desc = L["Minimum quality of item to be displayed"],
                    type = "select",
                    order = 130,
                    values = {
                        [ITEM_QUALITY_UNCOMMON] = ITEM_QUALITY2_DESC,
                        [ITEM_QUALITY_RARE] = ITEM_QUALITY3_DESC,
                        [ITEM_QUALITY_EPIC] = ITEM_QUALITY4_DESC
                    },
                    style = "dropdown",
                    get = "GetQuality",
                    set = "SetQuality"
                },
                resetInNewParty = {
                    name = L["Reset on Join Party"],
                    desc = L["Clear the item list when joining a new group"],
                    type = "select",
                    values = {
                        always = "Always",
                        ask = "Ask",
                        never = "Never",
                    },
                    style = "dropdown",
                    order = 100,
                    get = "GetResetInNewParty",
                    set = "SetResetInNewParty",
                },
                resetInNewInstance = {
                    name = L["Reset in Instance"],
                    desc = L["Clear the item list when entering an instance"],
                    type = "select",
                    values = {
                        always = "Always",
                        ask = "Ask",
                        never = "Never",
                    },
                    style = "dropdown",
                    order = 101,
                    get = "GetResetInNewInstance",
                    set = "SetResetInNewInstance",
                },

                displayIcons = {
                    name = L["Graphical Display"],
                    desc = L["Display icons for rolls types instead of text"],
                    type = "toggle",
                    order = 20,
                    get = "GetDisplayIcons",
                    set = "SetDisplayIcons",
                },
                displayTextLink = {
                    name = L["Item Names"],
                    desc = L["Toggle the display of the item name in the header"],
                    order = 30,
                    type = "toggle",
                    get = "GetDisplayTextLink",
                    set = "SetDisplayTextLink",
                },
                hideMinimapIcon = {
                    name = L["Minimap Icon"],
                    desc = L["Toggle the display of the minimap icon"],
                    type = "toggle",
                    order = 99,
                    get = "GetHideMinimapIcon",
                    set = "SetHideMinimapIcon",
                    width = "full"
                },
                showGroupOnly = {
                    name = L["Hide Non-Members"],
                    desc = L["Only display the names of members currently in your party"],
                    type = "toggle",
                    order = 50,
                    get = "GetShowGroupOnly",
                    set = "SetShowGroupOnly",
                },
                showLootMethod = {
                    name = L["Show Loot Method"],
                    desc = L["Display the loot method as a databroker feed"],
                    type = "toggle",
                    order = 50,
                    get = "GetShowLootMethod",
                    set = "SetShowLootMethod",
                },


                chatOptions = {
                    name = L["Chat options"],
                    type = "group",
                    args = {
                        filterLootMsgs = {
                            name = L["Filter Loot Messages"],
                            desc = L["Enable filtering of loot roll messages"],
                            type = "toggle",
                            order = 70,
                            get = "GetFilterLootMsgs",
                            set = "SetFilterLootMsgs",
                        },
                        noSpamMode = {
                            name = L["Loot Summary"],
                            desc = L["Print loot roll summary message to chat frame"],
                            type = "toggle",
                            order =71,
                            get = "GetNoSpamMode",
                            set = "SetNoSpamMode",
                        },
                        highlightSelfChat = {
                            name = L["Highlight Self"],
                            desc = L["Color loot you have won differently. Only works with loot summary enabled"],
                            type = "toggle",
                            order = 75,
                            get = "GetHighlightSelfChat",
                            set = "SetHighlightSelfChat",
                        },
                        highlightSelfColorChat = {
                            name = L["Self Color"],
                            type = "color",
                            order = 76,
                            get = "GetHighlightSelfChatColor",
                            set = "SetHighlightSelfChatColor",
                            hasAlpha = false,
                        },
                        highlightWinnerChat = {
                            name = L["Highlight Winner"],
                            desc = L["Color winning loot rolls differently. Only works with loot summary enabled"],
                            type = "toggle",
                            order = 77,
                            get = "GetHighlightWinnerChat",
                            set = "SetHighlightWinnerChat",
                        },
                        highlightWinnerChatColor = {
                            name = L["Winner Color"],
                            type = "color",
                            order = 78,
                            get = "GetHighlightWinnerChatColor",
                            set = "SetHighlightWinnerChatColor",
                            hasAlpha = false,
                        },
                    },
                },

                UIOptions = {
                    name = L["UI options"],
                    type = "group",
                    args = {
                        highlightSelf = {
                            name = L["Highlight Self"],
                            desc = L["Color loot you have won differently"],
                            type = "toggle",
                            order = 80,
                            get = "GetHighlightSelf",
                            set = "SetHighlightSelf",
                        },
                        highlightSelfColor = {
                            name = L["Self Color"],
                            type = "color",
                            order = 81,
                            get = "GetHighlightSelfColor",
                            set = "SetHighlightSelfColor",
                            hasAlpha = false,
                        },
                        highlightWinner = {
                            name = L["Highlight Winner"],
                            desc = L["Color winning loot rolls differently"],
                            type = "toggle",
                            order = 82,
                            get = "GetHighlightWinner",
                            set = "SetHighlightWinner",
                        },
                        highlightWinnerColor = {
                            name = L["Winner Color"],
                            type = "color",
                            order = 83,
                            get = "GetHighlightWinnerColor",
                            set = "SetHighlightWinnerColor",
                            hasAlpha = false,
                        },

                        playSoundOnAward = {
                            name = L["Play Sound"],
                            desc = L["Play sound when rolling is complete"],
                            type = "toggle",
                            order = 100,
                            get = "GetPlaySoundOnAward",
                            set = "SetPlaySoundOnAward",
                        },

                        soundFile = {
                            name = 'Sound File',
                            desc = 'Sound to play when rolling is complete',
                            type = 'select',
                            dialogControl = 'LSM30_Sound',
                            style = "dropdown",
                            values = LSM:HashTable("sound"),
                            get = "GetSoundFile",
                            set = "SetSoundFile",
                        },
                    },
                },

            },
        },

        detachedTooltipOptions = {
            name = L["Detached Tooltip"],
            type = "group",
            childGroups = "tab",
            args = {
                detachedTooltip = {
                    name = L["Detach Tooltip"],
                    desc = L["Display the roll information in a standalone window"],
                    type = "toggle",
                    order = 10,
                    get = "GetDetachedTooltip",
                    set = "SetDetachedTooltip",
                },
                autoPopUp = {
                    name = L["Popup when rolling"],
                    desc = L["Automatically show the detached tooltip when an item is being rolled on"],
                    type = "toggle",
                    order = 11,
                    get = "GetAutoPopUp",
                    set = "SetAutoPopUp",
                },
                showOnParty = {
                    name = L["Show in party"],
                    desc = L["Display the detached window when joining a party and hide the tooltip when leaving a party"],
                    type = "toggle",
                    order = 12,
                    get = "GetShowOnParty",
                    set = "SetShowOnParty",
                },
                tooltipAutoHideDelay = {
                    name = L["Autohide delay"],
                    desc = L["Time to remain visible after the last item has been received (Popup mode only)"],
                    type = "range",
                    order = 13,
                    min = 0,
                    max = 60,
                    step = 1,
                    get = "GetAutoHideDelay",
                    set = "SetAutoHideDelay",
                },
                hideInCombat = {
                    name = L["Hide in combat"],
                    desc = L["Only display the detached window when not in combat"],
                    type = "toggle",
                    order = 14,
                    get = "GetHideInCombat",
                    set = "SetHideInCombat",
                },
                tooltipScale = {
                    name = L["Scale"],
                    desc = L["Adjust the scale of the detached tooltip"],
                    type = "range",
                    order = 16,
                    min = 0.5,
                    max= 2.0,
                    step = 0.01,
                    get = "GetTooltipScale",
                    set = "SetTooltipScale",
                },
                lockTooltip = {
                    name = L["Lock Tooltip"],
                    desc = L["Adjust the position of the detached tooltip"],
                    type = "toggle",
                    order = 100,
                    get = "GetLockTooltip",
                    set = "SetLockTooltip",
                    width = "full",
                },

                detachedTooltipUIOptions = {
                    name = L["UI options"],
                    type = "group",
                    args = {
                        useTooltipDefaults = {
                            name = L["Default Style"],
                            desc = L["Use the default tooltip background and border style for detached tooltip"],
                            type = "toggle",
                            order = 200,
                            get = "GetUseTooltipDefault",
                            set = "SetUseTooltipDefault",
                            width = "full",
                        },
                        bgColor = {
                            name = L["Background Color"],
                            desc = L["Change the background color of the detached tooltip"],
                            type = "color",
                            order = 210,
                            get = "GetBackgroundColor",
                            set = "SetBackgroundColor",
                            hasAlpha = true,
                            disabled = function() return NeedyGreedy.db.profile.useTooltipDefaults end,
                        },
                        borderColor = {
                            name = L["Border Color"],
                            desc = L["Change the border color of the detached tooltip"],
                            type = "color",
                            order = 220,
                            get = "GetBorderColor",
                            set = "SetBorderColor",
                            hasAlpha = true,
                            disabled = function() return NeedyGreedy.db.profile.useTooltipDefaults end,
                        },
                    }
                }

            },
        },

        dataBrokerOptions = {
            name = L["DataBroker Tooltip"],
            type = "group",
            args = {
                suppressInRaid = {
                    name = L["Hide In Raid"],
                    desc = L["Suppress the display of the LibDataBroker tooltip when in a raid"],
                    type = "toggle",
                    order = 10,
                    get = "GetSuppressInRaid",
                    set = "SetSuppressInRaid",
                },
            },
        },

        debugOptions = {
            name = L["Debug Options"],
            type = "group",
            args = {
                toggleDebug = {
                    name = L["Show Debug Messages"],
                    desc = L["Show Debugging Messages"],
                    type = "toggle",
                    width = "full",
                    order = 110,
                    get = "GetToggleDebug",
                    set = "SetToggleDebug",
                },
                maxEvents = {
                    name = L["Max Debug Messages"],
                    type = "range",
                    order = 111,
                    min = 10,
                    max = 500,
                    step = 10,
                    get = "GetMaxEvents",
                    set = "SetMaxEvents"
                },
                exportDebugLog = {
                    name = L["Debug Log"],
                    type = "input",
                    multiline = 25,
                    width = "full",
                    order = 115,
                    get = "GetDebugLog",
                    set = "SetDebugLog",
                },
                clearDebugLog = {
                    name = L["Clear Debug Log"],
                    type = "execute",
                    order = 120,
                    func = "ClearDebugLog",
                },

            },
        },

    }
}

-- Set profile defaults
local defaults = {
    profile = {
        nItems = 2,
        expiry = 5,
        quality = ITEM_QUALITY_RARE,
        displayIcons = true,
        detachedTooltip = false,
        displayTextLink = false,
        displayStatus = false,
        minimap = { hide = false },
        filterLootMsgs = false,
        showOnParty = false,
        hideInCombat = false,
        showGroupOnly = true,
        autoPopUp = true,
        resetInNewParty = "ask",
        resetInNewInstance = "ask",
        tooltipScale = 1,
        lockTooltip = false,
        suppressInRaid = false,
        autoHideDelay = 0,
        noSpamMode = false,
        highlightSelf = false,
        highlightSelfColor = {1, 0.8, 0, 1},
        highlightWinner = false,
        highlightWinnerColor = {0, 1, 0, 1},
        highlightSelfChat = false,
        highlightSelfChatColor = {1, 0.8, 0, 1},
        highlightWinnerChat = false,
        highlightWinnerChatColor = {0, 1, 0, 1},
        showLootMethod = false,
        useTooltipDefaults = true,
        bgColor = GameTooltip:GetBackdrop(),
        borderColor = {GameTooltip:GetBackdropBorderColor()},
        playSoundOnAward = false,
        soundFile = LSM:Fetch("sound", value),
        soundName = "None",
        debugStatus = false,
        maxDebugEvents = 100,
        maxHeight = 250,
        scrollStep = 20,
    }
}

-- Console commands
local slashTable = {
    handler = NeedyGreedy,
    type = "group",
    args = {
        config = {
            name = L["Open the configuration menu"],
            type = "execute",
            func = function() InterfaceOptionsFrame_OpenToCategory("NeedyGreedy") end,
        },
        hide = {
            name = L["Hide the detached tooltip"],
            type = "execute",
            func = "SlashHide",
        },
        report = {
            name = L["Generate a text summary"],
            type = "execute",
            func = "PrintReport",
        },
        reset = {
            name = L["Reset the item list"],
            type = "execute",
            func = "ClearItems",
        },
        show = {
            name = L["Show the detached tooltip"],
            type = "execute",
            func = "SlashShow",
        },
    },
}

-- Icon textures
local iconSize = 20
local NEEDYGREEDY_CHOICE = {
    ["need"] = {
        ["string"] = "|c00FF0000" .. NEED .. "|r",
        ["icon"] = "|TInterface\\Buttons\\UI-GroupLoot-Dice-Up:" .. iconSize .. "|t",
    },
    ["greed"] = {
        ["string"] = "|c0000FF00" .. GREED .. "|r",
        ["icon"] = "|TInterface\\Buttons\\UI-GroupLoot-Coin-Up:" .. iconSize .. "|t",
    },
    ["pass"] = {
        ["string"] = "|c00CCCCCC" .. PASS .. "|r",
        ["icon"] = "|TInterface\\Buttons\\UI-GroupLoot-Pass-Up:" .. iconSize .. "|t",
    },
    ["disenchant"] = {
        ["string"] = "|c00FF00FF" .. ROLL_DISENCHANT .. "|r",
        ["icon"] = "|TInterface\\Buttons\\UI-GroupLoot-DE-Up:" .. iconSize .. "|t",
    }
}
local BLANK_ICON = "|T:" .. iconSize .. "|t"
iconSize = 27
local CLOSE_ICON = "|TInterface\\Buttons\\UI-Panel-MinimizeButton-Up:" .. iconSize .. "|t"
local PAGER_ICONS = {
    leftUp = "|TInterface\\Buttons\\UI-SpellbookIcon-PrevPage-Up:" .. iconSize .. "|t",
    leftDisabled = "|TInterface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled:" .. iconSize .. "|t",
    rightUp = "|TInterface\\Buttons\\UI-SpellbookIcon-NextPage-Up:" .. iconSize .. "|t",
    rightDisabled = "|TInterface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled:" .. iconSize .. "|t",
}

-- Funky colors for text strings
local yC = "|cffFFCC00" -- Golden
local eC = "|cffEDA55F" -- Orange
local gC = "|cff00FF00" -- Green

-- For tracking original state of detailed loot information
local originalSpamFilterSetting

-- For tracking combat status
local IS_IN_COMBAT

-- We track rolling on items like this to avoid the scenario where you're in
-- combat the window pops up, you leave combat briefly before another add
-- attacks and the window disappears as you're deciding
local WATCH_ITEM_BEING_ROLLED_ON

-- To track if there is a scheduled script
local ROLL_TIMER

-- For tracking grouped status
local IS_IN_PARTY
local IS_IN_RAID

-- For tracking ghost status
local WAS_GHOST

-- For tracking instance changes
local INSTANCE_NAME

-- Needed for chat filter
local FILTER_CHAT_LOOT_MSGS = {}

local ORIG_FILTER_CHAT_LOOT_MSGS = {
    LOOT_ROLL_DISENCHANT,
    LOOT_ROLL_DISENCHANT_SELF,
    LOOT_ROLL_GREED,
    LOOT_ROLL_GREED_SELF,
    LOOT_ROLL_NEED,
    LOOT_ROLL_NEED_SELF,
    LOOT_ROLL_PASSED,
    LOOT_ROLL_PASSED_AUTO,
    LOOT_ROLL_PASSED_AUTO_FEMALE,
    LOOT_ROLL_PASSED_SELF,
    LOOT_ROLL_PASSED_SELF_AUTO,
    LOOT_ROLL_ROLLED_DE,
    LOOT_ROLL_ROLLED_GREED,
    LOOT_ROLL_ROLLED_NEED,
}

local NO_SPAM_FILTER_CHAT_LOOT_MSGS = {
    --LOOT_ROLL_ALL_PASSED,
    LOOT_ROLL_DISENCHANT,
    LOOT_ROLL_DISENCHANT_SELF,
    LOOT_ROLL_GREED,
    LOOT_ROLL_GREED_SELF,
    LOOT_ROLL_NEED,
    LOOT_ROLL_NEED_SELF,
    LOOT_ROLL_PASSED,
    LOOT_ROLL_PASSED_AUTO,
    LOOT_ROLL_PASSED_AUTO_FEMALE,
    LOOT_ROLL_PASSED_SELF,
    LOOT_ROLL_PASSED_SELF_AUTO,
    LOOT_ROLL_ROLLED_DE,
    LOOT_ROLL_ROLLED_GREED,
    LOOT_ROLL_ROLLED_NEED,
    LOOT_ROLL_WON,
    LOOT_ROLL_YOU_WON,
    --LOOT_ITEM,
    --LOOT_ITEM_MULTIPLE,
    --LOOT_ITEM_PUSHED_SELF,
    --LOOT_ITEM_PUSHED_SELF_MULTIPLE,
    --LOOT_ITEM_SELF,
    --LOOT_ITEM_SELF_MULTIPLE,
}

-- Utility functions
local function sanitizePattern(pattern)
    -- Escape potential regexp pattern characters first!
    pattern = string.gsub(pattern, "%+", "%%+")
    pattern = string.gsub(pattern, "%(", "%%(")
    pattern = string.gsub(pattern, "%)", "%%)")
    pattern = string.gsub(pattern, "%-", "%%-")

    -- Now construct regexp patterns
    pattern = string.gsub(pattern, "%%s", "(.+)")
    pattern = string.gsub(pattern, "%%d", "(%%d+)")
    return pattern
end

-- Converts a format string into a pattern and list of capture group indices
-- e.g. %2$s won the %1$s
local function patternFromFormat(format)
    local pattern = ""
    local captureIndices = {}

    local start = 1
    local captureIndex = 0
    repeat
        -- find the next group
        local s, e, group, position = format:find("(%%([%d$]*)[ds])", start)
        if s then
            -- add the text between the last group and this group
            pattern = pattern..sanitizePattern(format:sub(start, s-1))
            -- update the current capture index, using the position bit in the
            -- group if it exists, otherwise just increment
            if #position > 0 then
                -- chop off the $ and convert to a number
                captureIndex = tonumber(position:sub(1, #position-1))
            else
                captureIndex = captureIndex + 1
            end
            -- add the current capture index to our list
            tinsert(captureIndices, captureIndex)
            -- remove the position bit from the group, sanitize the remainder
            -- and add it to the pattern
            pattern = pattern..sanitizePattern(group:gsub("%d%$", "", 1))
            -- start searching again from past the end of the group
            start = e + 1
        else
            -- if no more groups can be found, but there's still more text
            -- remaining in the format string, sanitize the remainder, add it
            -- to the pattern and finish the loop
            if start <= #format then
                pattern = pattern..sanitizePattern(format:sub(start))
            end
            break
        end
    until start > #format

    return pattern, captureIndices
end

-- Like string:find but uses a list of capture indices to re-order the capture
-- groups. For use with converted format strings that use positional args.
-- e.g. %2$s won the %1$s.
local function superFind(text, pattern, captureIndices)
    local results = { text:find(pattern) }
    if #results == 0 then
        return
    end

    local s, e = tremove(results, 1), tremove(results, 1)

    local captures = {}
    for _, index in ipairs(captureIndices) do
        tinsert(captures, results[index])
    end

    return s, e, unpack(captures)
end

-- Strips the item ID out of the item link
-- Needed for items that change their unique identifier
local function itemIdFromLink(itemLink)
    local found, _, itemString = string.find(itemLink, "|H(.+)|h")
    if found then
        local _, itemId = strsplit(":", itemString)
        return tonumber(itemId)
    end
    return nil
end

-- Ye olde pop up box
local function confirmResetDialog()
	StaticPopupDialogs["NeedyGreedyResetDialog"] = {
						text = L["Do you wish to reset NeedyGreedy?"],
						button1 = ACCEPT,
						button2 = CANCEL,
						timeout = 30,
						whileDead = 0,
						hideOnEscape = 1,
						OnAccept = function() NeedyGreedy:ClearItems() end,
					}
	StaticPopup_Show("NeedyGreedyResetDialog")
end



-- Event handling functions
function NeedyGreedy:OnInitialize()

    -- Profile handling
    self.db = LibStub("AceDB-3.0"):New("NeedyGreedyDB", defaults, true)
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshProfile")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshProfile")
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshProfile")
    options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)

    -- Register config options
    LibStub("AceConfig-3.0"):RegisterOptionsTable("NeedyGreedy", options)

    -- Set up GUI configuration
    local ACD = LibStub("AceConfigDialog-3.0")
    ACD:AddToBlizOptions("NeedyGreedy", "NeedyGreedy", nil, "general")
    ACD:AddToBlizOptions("NeedyGreedy", L["Detached Tooltip"], "NeedyGreedy", "detachedTooltipOptions")
    ACD:AddToBlizOptions("NeedyGreedy", L["DataBroker Tooltip"], "NeedyGreedy", "dataBrokerOptions")
    ACD:AddToBlizOptions("NeedyGreedy", L["Debug Options"], "NeedyGreedy", "debugOptions")
    ACD:AddToBlizOptions("NeedyGreedy", L["Profile"], "NeedyGreedy", "profile")

    -- Register slash options table
    LibStub("AceConfig-3.0"):RegisterOptionsTable("NeedyGreedyCmds", slashTable, {"ng", "needygreedy"})

    -- Register the minimap icon
    ngDBIcon:Register("NeedyGreedy", NeedyGreedyLDB, self.db.profile.minimap)

    -- Register some sounds
    LSM:Register("sound", "Bells", [[Sound\Spells\ShaysBell.wav]])
    LSM:Register("sound", "Cheer", [[Sound\Event Sounds\OgreEventCheerUnique.wav]])

end

function NeedyGreedy:OnEnable()
    self:RegisterEvent("PARTY_MEMBERS_CHANGED")
    self:RegisterEvent("START_LOOT_ROLL")
    self:RegisterEvent("CHAT_MSG_LOOT")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("PLAYER_ALIVE")
    self:RegisterEvent("RAID_ROSTER_UPDATE")
    self:RegisterEvent("PARTY_LOOT_METHOD_CHANGED")

    self:ScheduleRepeatingTimer("ExpireItems", 10)

    -- Refresh display when class can be determined
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("UNIT_CLASSIFICATION_CHANGED", "PLAYER_ENTERING_WORLD")

    self:RegisterEvent("PLAYER_LEAVING_WORLD")

    -- Set up chat filters
    if self.db.profile.filterLootMsgs then
        self:EnableChatFilter()
    end

    if self.db.profile.noSpamMode then
        self:EnableNoSpamMode()
    end

    self:SetShowLootSpam()
end

function NeedyGreedy:OnDisable()
    self:HideDetachedTooltip()

    -- Turn off chat filters
    if self.db.profile.filterLootMsgs then
        self:DisableChatFilter()
    end

    self:ResetShowLootSpam()
end

function NeedyGreedy:PLAYER_ENTERING_WORLD()
    local inInstance, instanceType = IsInInstance()
    local newInstanceName = GetInstanceInfo()

    -- PLAYER_ENTERING_WORLD events can trigger without any
    -- discernable change to the instance e.g. during
    -- Prophet Tharonja, CoT:CoS when the dragonkin reveal themselves
    -- Swamp Lord Musalek fight in Underbog
    if newInstanceName == INSTANCE_NAME then
        return
    else
        INSTANCE_NAME = newInstanceName
    end

    wipe(nameList)
    if self.db.profile.detachedTooltip then
        if self:DisplayDetachedTTCheck() then
            self:RefreshTooltip()
        end
    end

    if inInstance and (instanceType == "party" or instanceType == "raid") then
        -- Don't ask when making a graveyard run
        if not WAS_GHOST then
            if self.db.profile.resetInNewInstance == "always" and (#items ~= 0) then
                self:ClearItems()
            elseif self.db.profile.resetInNewInstance == "ask" and (#items ~= 0) then
                confirmResetDialog()
            end
        else
            WAS_GHOST = false
        end
    end

    self:UpdatePartyLootMethodText()

    self:SetShowLootSpam()
end

function NeedyGreedy:PLAYER_LEAVING_WORLD()
    self:ResetShowLootSpam()
end

function NeedyGreedy:PARTY_MEMBERS_CHANGED()
    if (GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0) and not IS_IN_PARTY then
        IS_IN_PARTY = true

        if self.db.profile.resetInNewParty == "always" and (#items ~= 0) then
            self:ClearItems()
        elseif self.db.profile.resetInNewParty == "ask" and (#items ~= 0) then
            confirmResetDialog()
        end

        if self.db.profile.showOnParty and self.db.profile.detachedTooltip and not self.db.profile.displayStatus then
            self.db.profile.displayStatus = true
            self:ShowDetachedTooltip()
        end

    elseif (GetNumPartyMembers() == 0 and GetNumRaidMembers() == 0) then
        IS_IN_PARTY = false
        IS_IN_RAID = false

        if self.db.profile.showOnParty and self.db.profile.detachedTooltip and self.db.profile.displayStatus then
            self.db.profile.displayStatus = false
            self:HideDetachedTooltip()
        end

    end

    self:UpdatePartyLootMethodText()

    wipe(nameList)
    self:RefreshTooltip()
end

function NeedyGreedy:PLAYER_REGEN_DISABLED()
    IS_IN_COMBAT = true
    self:RefreshTooltip()
end

function NeedyGreedy:PLAYER_REGEN_ENABLED()
    IS_IN_COMBAT = false
    self:RefreshTooltip()
end

function NeedyGreedy:PLAYER_ALIVE()
    if UnitIsDeadOrGhost("player") then
        WAS_GHOST = true
    elseif WAS_GHOST then
        WAS_GHOST = false
    end
end

function NeedyGreedy:RAID_ROSTER_UPDATE()
    if GetNumRaidMembers() > 0 then
        IS_IN_RAID = true
    else
        IS_IN_RAID = false
    end
end

function NeedyGreedy:PARTY_LOOT_METHOD_CHANGED()
    self:UpdatePartyLootMethodText()
end

local LOOT_METHOD_STRINGS = {
    ["freeforall"] = LOOT_FREE_FOR_ALL,
    ["roundrobin"] = LOOT_ROUND_ROBIN,
    ["group"] = LOOT_GROUP_LOOT,
    ["master"] = LOOT_MASTER_LOOTER,
    ["needbeforegreed"] = LOOT_NEED_BEFORE_GREED,
}

function NeedyGreedy:UpdatePartyLootMethodText()
    if not self.db.profile.showLootMethod then
        NeedyGreedyLDB.text = ""
        return
    end

    local lootmethod, masterlooterPartyID, masterlooterRaidID = GetLootMethod()
    local nameServer, name

    if (GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0) then
        if lootmethod == "master" then
            if masterlooterRaidID ~= nil then
                nameServer = GetRaidRosterInfo(masterlooterRaidID)
                if nameserver then
                    name = string.match(nameServer, "[^ -]+")
                end
            elseif masterlooterPartyID ~= nil then
                name = UnitName("party" .. masterlooterPartyID)
            end

            if name == nil then
                name = UnitName("player")
            end
            NeedyGreedyLDB.text = LOOT_METHOD_STRINGS[lootmethod] .. " (" .. name .. ")"
        else

            NeedyGreedyLDB.text = LOOT_METHOD_STRINGS[lootmethod]
        end

    else
        NeedyGreedyLDB.text = ""
    end
end


-- Chat scanning and loot recording
function NeedyGreedy:START_LOOT_ROLL(event, rollid, rollTime)
    -- For debugging
    if self.db.profile.debugStatus then
        self:AddEventToLog({event, rollid, rollTime})

        -- Take a snapshot of the current state of the name lists
        table.insert(NAMELIST_LOG, self:GetSortedPlayers())
        table.insert(NAME_LOG, self:GetPlayers())
    end

    local texture, name, count, quality = GetLootRollItemInfo(rollid)
    local link = GetLootRollItemLink(rollid)
    if quality >= self.db.profile.quality then
        table.insert(items, {
            texture = texture,
            link = link,
            itemID = itemIdFromLink(link),
            assigned = "",
            received = 0,
            choices = {},
            rolls = {},
            rollTimeOut = GetTime() + rollTime/1000,
        })

        if self.db.profile.detachedTooltip and self.db.profile.autoPopUp then
            WATCH_ITEM_BEING_ROLLED_ON = true
            self:ShowDetachedTooltip()
            -- Check if a new roll was started before the delayed script was called
            if self.db.profile.autoHideDelay > 0 and ROLL_TIMER then
                self:CancelTimer(ROLL_TIMER, true)
                ROLL_TIMER = nil
            end
        end

        self:UpdateReport()
    end
end

local CHAT_MSG_TABLE = {
    {LOOT_ROLL_YOU_WON, "RecordAwarded", {1, "me", nil, nil}},
    {LOOT_ROLL_WON, "RecordAwarded", {2, 1, nil, nil}},
    {LOOT_ROLL_ALL_PASSED, "RecordAwarded", {1, "---", nil, nil}},
    {LOOT_ROLL_PASSED_AUTO, "RecordChoice", {2, 1, nil, "pass"}},
    {LOOT_ROLL_PASSED_AUTO_FEMALE, "RecordChoice", {2, 1, nil, "pass"}},
    {LOOT_ROLL_NEED_SELF, "RecordChoice", {1, "me", nil, "need"}},
    {LOOT_ROLL_GREED_SELF, "RecordChoice", {1, "me", nil, "greed"}},
    {LOOT_ROLL_PASSED_SELF, "RecordChoice", {1, "me", nil, "pass"}},
    {LOOT_ROLL_PASSED_SELF_AUTO, "RecordChoice", {1, "me", nil, "pass"}},
    {LOOT_ROLL_NEED, "RecordChoice", {2, 1, nil, "need"}},
    {LOOT_ROLL_GREED, "RecordChoice", {2, 1, nil, "greed"}},
    {LOOT_ROLL_PASSED, "RecordChoice", {2, 1, nil, "pass"}},
    {LOOT_ROLL_DISENCHANT_SELF, "RecordChoice", {1, "me", nil, "disenchant"}},
    {LOOT_ROLL_DISENCHANT, "RecordChoice", {2, 1, nil, "disenchant"}},
    {LOOT_ROLL_ROLLED_NEED_ROLE_BONUS, "RecordRoll", {2, 3, 1, nil}},           -- "Need Roll - %d for %s by %s + Role Bonus";
    {LOOT_ROLL_ROLLED_NEED, "RecordRoll", {2, 3, 1, nil}},                      -- "Need Roll - %d for %s by %s"
    {LOOT_ROLL_ROLLED_GREED, "RecordRoll", {2, 3, 1, nil}},
    {LOOT_ROLL_ROLLED_DE, "RecordRoll", {2, 3, 1, nil}},
    {LOOT_ITEM_PUSHED_SELF, "RecordReceived", {1, "me", nil, nil}},
    {LOOT_ITEM_PUSHED_SELF_MULTIPLE, "RecordReceived", {1, "me", nil, nil}},
    {LOOT_ITEM_SELF, "RecordReceived", {1, "me", nil, nil}},
    {LOOT_ITEM_SELF_MULTIPLE, "RecordReceived", {1, "me", nil, nil}},
    {LOOT_ITEM, "RecordReceived", {2, 1, nil, nil}},
    {LOOT_ITEM_MULTIPLE, "RecordReceived", {2, 1, nil, nil}},
}

local CHAT_MSG_NO_SPAM_TABLE = {
    LOOT_ROLL_WON_NO_SPAM_DE, -- = "%1$s won: %3$s |cff818181(Disenchant - %2$d)|r";
    LOOT_ROLL_WON_NO_SPAM_GREED, --  = "%1$s won: %3$s |cff818181(Greed - %2$d)|r";
    LOOT_ROLL_WON_NO_SPAM_NEED, -- = "%1$s won: %3$s |cff818181(Need - %2$d)|r";
    LOOT_ROLL_YOU_WON_NO_SPAM_DE, -- = "You won: %2$s |cff818181(Disenchant - %1$d)|r";
    LOOT_ROLL_YOU_WON_NO_SPAM_GREED, -- = "You won: %2$s |cff818181(Greed - %1$d)|r";
    LOOT_ROLL_YOU_WON_NO_SPAM_NEED, -- = "You won: %2$s |cff818181(Need - %1$d)|r";
}

function NeedyGreedy:NoSpamMessage(link, player)
    local printString
    local me = UnitName("player")
    local item

    for _, record in ipairs(items) do
        if record.assigned == player and record.link == link then
            item = record
            break
        end
    end

    if not item then
        return
    end

    local rollType = item.choices[player]
    local roll = item.rolls[player]

    -- Temporary fix until we determine the cause
    if not roll then
        if self.db.profile.debugStatus then
            print("NoSpamMessage: Roll was nil")
        end
        roll = 0
    end

    if player == me then
        if rollType == "disenchant" then
            printString = LOOT_ROLL_YOU_WON_NO_SPAM_DE:format(roll, link)
        elseif rollType == "greed" then
            printString = LOOT_ROLL_YOU_WON_NO_SPAM_GREED:format(roll, link)
        elseif rollType == "need" then
            printString = LOOT_ROLL_YOU_WON_NO_SPAM_NEED:format(roll, link)
        end
    else
        if rollType == "disenchant" then
            printString = LOOT_ROLL_WON_NO_SPAM_DE:format(player, roll, link)
        elseif rollType == "greed" then
            printString = LOOT_ROLL_WON_NO_SPAM_GREED:format(player, roll, link)
        elseif rollType == "need" then
            printString = LOOT_ROLL_WON_NO_SPAM_NEED:format(player, roll, link)
        end
    end

    -- Default to Blizzard color
    local r, g, b, a = GetMessageTypeColor("CHAT_MSG_LOOT")

    -- Color winner
    if self.db.profile.highlightWinnerChat then
        r, g, b, a = unpack(self.db.profile.highlightWinnerChatColor)
    end

    -- Color self
    if self.db.profile.highlightSelfChat and player == me then
        r, g, b, a = unpack(self.db.profile.highlightSelfChatColor)
    end

    DEFAULT_CHAT_FRAME:AddMessage(printString, r, g, b)
end

function NeedyGreedy:CHAT_MSG_LOOT(event, msg)
    self:ChatMsgLootParser(event, msg)
end

function NeedyGreedy:ChatMsgLootParser(event, msg)
    -- For debugging
    if self.db.profile.debugStatus then
        self:AddEventToLog({event, msg})
    end

    local functionName, link, player, roll, rollType
    local stringValues, inputs

    for _, message in ipairs(CHAT_MSG_TABLE) do
        stringValues = {self:unformat(message[1], msg)}
        if #stringValues > 0 then
            functionName = message[2]
            inputs = message[3]
            link = stringValues[inputs[1]]
            link = self:RemoveItemCountFromLink(link)
            if inputs[2] == "me" then
                player = UnitName("player")
            elseif inputs[2] == "---" then
                player = "---"
            else
                player = stringValues[inputs[2]]
            end
            if inputs[3] then
                roll = stringValues[inputs[3]]
            end
            rollType = inputs[4]
            self:RecordParser(functionName, link, player, roll, rollType)
            break
        end
    end

    return {msg, functionName, link, player, roll, rollType}
end

function NeedyGreedy:RemoveItemCountFromLink(link)
    if link == nil then return link end

    local match = string.match(link, "(.+)x%d+$")
    if match then link = match end
    return link
end

function NeedyGreedy:RecordParser(functionName, link, player, roll, type)
    if functionName == "RecordAwarded" then
        self:RecordAwarded(link, player)

        -- if no spam filter option turned on
        if self.db.profile.noSpamMode then
            self:NoSpamMessage(link, player)
        end

    elseif functionName == "RecordChoice" then
        self:RecordChoice(link, player, type)
    elseif functionName == "RecordRoll" then
        self:RecordRoll(link, player, roll)
    elseif functionName == "RecordReceived" then
        self:RecordReceived(link, player)
    else
        self:Print("Unrecognised function name: " .. tostring(functionName))
    end
end

function NeedyGreedy:RecordChoice(link, player, choice)
    local _, _, quality = GetItemInfo(link)
    if quality < self.db.profile.quality then return end

    for _, record in ipairs(items) do
        if record.assigned == "" and record.link == link then
            record.choices[player] = choice
            break
        end
    end
    self:UpdateReport()
end

function NeedyGreedy:RecordRoll(link, player, number)
    local _, _, quality = GetItemInfo(link)
    if quality < self.db.profile.quality then return end

    -- Temporary fix until we determine the cause
    if not number then
        if self.db.profile.debugStatus then
            print("RecordRoll: Roll was nil")
        end
        number = 0
    end

    for _, record in ipairs(items) do
        if record.assigned == "" and record.link == link then
            record.rolls[player] = number

            -- If we get to this point and there are still players with no choices fill them in with a blank
            for _, name in pairs(nameList) do
                if not record.choices[name] then
                    record.choices[name] = "pass"
                end
            end

            break
        end
    end
    self:UpdateReport()
end

function NeedyGreedy:RecordAwarded(link, player)
    local _, _, quality = GetItemInfo(link)
    if quality < self.db.profile.quality then return end

    for _, record in ipairs(items) do
        if record.assigned == "" and record.link == link then
            record.assigned = player
            break
        end
    end
    self:UpdateReport()
end

function NeedyGreedy:RecordReceived(link, player)
    local _, _, quality = GetItemInfo(link)
    -- Because disenchanted items can be white >_<9
    if quality < ITEM_QUALITY_COMMON then return end

    local match = false
    for _, record in ipairs(items) do
        if record.received == 0 and record.link == link then
            record.received = GetTime()
            match = true
            break
        end
    end

    if not match then
        -- For items with weird unique identifiers
        for _, record in ipairs(items) do
            if record.received == 0 and record.itemID == itemIdFromLink(link) then
                record.received = GetTime()
                match = true
                break
            end
        end
    end

    if not match then
        for _, record in ipairs(items) do
            -- Since players receive the results of the disenchant, we will never be
            -- able to match the link that triggered the received message against
            -- our list. However, we should cross disenchanted items that have been
            -- assigned off the list as we find them on the assumption that they
            -- would have automatically received the item anyway.
            if record.choices[player] == "disenchant" and record.assigned == player and record.received == 0 then
                record.received = GetTime()
                -- It's ok to put in the break since each disenchanted
                -- result will trigger a received message
                break
            end
        end
    end

    -- This could be done in one of the other loops, but since I live with
    -- pedantic man, we will do this as a separate scan
    if WATCH_ITEM_BEING_ROLLED_ON then
        local itemsStillBeingRolledOn = 0
        for _, record in ipairs(items) do
            if record.received == 0 then
                itemsStillBeingRolledOn = itemsStillBeingRolledOn + 1
            end
        end

        if itemsStillBeingRolledOn == 0 then
            local autoHideDelay = self.db.profile.autoHideDelay

            if autoHideDelay == 0 then
                self:RollPostProcessing()
            else
                ROLL_TIMER = self:ScheduleTimer("RollPostProcessing", autoHideDelay)
            end

            if self.db.profile.playSoundOnAward then
                local soundFile = self.db.profile.soundFile
                if soundFile then
                    PlaySoundFile(soundFile, "SFX")
                end
            end

        end
    end

    self:UpdateReport()
end

function NeedyGreedy:RollPostProcessing()
    WATCH_ITEM_BEING_ROLLED_ON = false
    ROLL_TIMER = nil
    self:RefreshTooltip()
end

function NeedyGreedy:ClearItems()
    wipe(items)
    wipe(nameList)
    self:RefreshTooltip()
    self:Print(L["All items have been cleared."])
end



-- Tooltip Information Formatting
function NeedyGreedy:PageLeft()
    report.firstItem = report.firstItem - self.db.profile.nItems
    if report.firstItem < 1 then
        report.firstItem = 1
    end
    self:UpdateReport()
end

function NeedyGreedy:PageRight()
    local count = #items
    report.firstItem = report.firstItem + self.db.profile.nItems
    if count == 0 then
        report.firstItem = 1
    elseif report.firstItem > count then
        report.firstItem = count
    end
    self:UpdateReport()
end

function NeedyGreedy:GetPlayers()
    local names = {}
    local name

    if GetNumRaidMembers() > 0 then
        for i = 1,MAX_RAID_MEMBERS do
            name = GetRaidRosterInfo(i)
            table.insert(names, name)
        end
    else
        for _, unit in ipairs({"player", "party1", "party2", "party3", "party4"}) do
            name = UnitName(unit)
            table.insert(names, name)
        end
    end

    return names
end

function NeedyGreedy:GetSortedPlayers()
    local list = {}
    local nameServer, name

    if GetNumRaidMembers() > 0 then
        for i = 1,MAX_RAID_MEMBERS do
            nameServer = GetRaidRosterInfo(i)
            if nameServer then
                name = string.match(nameServer, "[^ -]+")
                if not (nameList[name]) and (name ~= UNKNKOWN) then nameList[name] = name end
            end
        end
    else
        for _, unit in ipairs({"player", "party1", "party2", "party3", "party4"}) do
            local name = UnitName(unit)
            if name then
                if not (nameList[name]) and (name ~= UNKNKOWN) then nameList[name] = name end
            end
        end
    end

    if not self.db.profile.showGroupOnly then
        for _, item in ipairs(items) do
            for name, _ in pairs(item.choices) do
                if not nameList[name] then nameList[name] = name end
            end
        end
    end

    for name, _ in pairs(nameList) do
        table.insert(list, name)
    end

    table.sort(list)
    return list
end

function NeedyGreedy:GetNumPlayers()
    local nraid = GetNumRaidMembers()
    if nraid > 0 then
        return nraid
    else
        return GetNumPartyMembers() + 1
    end
end

function NeedyGreedy:ColorizeName(name)
    local _, class = UnitClass(name)
    local color

    if class then
        color = RAID_CLASS_COLORS[class]
        color = string.format("\124cff%.2x%.2x%.2x", color.r*255, color.g*255, color.b*255)
    end
    if not color then
        color = GRAY_FONT_COLOR_CODE
    end
    return color .. name .. "|r"
end

function NeedyGreedy:ChoiceText(choice)
    local style = "string"
    if self.db.profile.displayIcons == true then style = "icon" end

    if choice then
          if NEEDYGREEDY_CHOICE[choice][style] then
              return NEEDYGREEDY_CHOICE[choice][style]
          end
    end
    return ""
end

function NeedyGreedy:RollText(number, winner, winnerIsSelf)
    local hexColor = ""
    local r, g, b, a = unpack({1, 1, 1, 1})

    if number then
        number = " - " .. number
        if self.db.profile.highlightWinner and winner then
            r, g, b, a = unpack(self.db.profile.highlightWinnerColor)
            hexColor = string.format("|cff%2X%2X%2X", 255*r, 255*g, 255*b)
        end

        if self.db.profile.highlightSelf and winner and winnerIsSelf then
            r, g, b, a = unpack(self.db.profile.highlightSelfColor)
            hexColor = string.format("|cff%2X%2X%2X", 255*r, 255*g, 255*b)
        end

        number = hexColor .. number .. "|r"

        return number
    else
        return ""
    end
end

function NeedyGreedy:AssignedText(item)
    if item.received == 0 then
        return "|c00FF0000" .. item.assigned .. "|r"
    else
        return "|c0000FF00" .. item.assigned .. "|r"
    end
end

function NeedyGreedy:ExpireItems()
    local now = GetTime()
    local update = false
    local displayTimeOut = true
    local padding = 60

    for rollid, record in ipairs(items) do
        -- Are there any unresolved rolls past expiry time
        if record.rollTimeOut and record.rollTimeOut > 0 and now < record.rollTimeOut + padding and WATCH_ITEM_BEING_ROLLED_ON then
            displayTimeOut = false
        end

        -- Are there items that need to be expired
        if self.db.profile.expiry ~= 0 then
            if record.received > 0 and now - record.received >= self.db.profile.expiry * 60 then
                table.remove(items, rollid)
                wipe(nameList)
                update = true
            end
        end
    end

    if displayTimeOut and WATCH_ITEM_BEING_ROLLED_ON then
        self:RollPostProcessing()
    end

    if update then
        self:UpdateReport()
    end
end

local CONVERTED_FORMATS = {}
function NeedyGreedy:unformat(fmt, msg)
    local pattern, captureIndices
    if CONVERTED_FORMATS[fmt] then
        pattern, captureIndices = unpack(CONVERTED_FORMATS[fmt])
    else
        pattern, captureIndices = patternFromFormat(fmt)
        CONVERTED_FORMATS[fmt] = {pattern, captureIndices}
    end

    local _, _, a1, a2, a3, a4 = superFind(msg, pattern, captureIndices)
    return a1, a2, a3, a4
end



-- Config option getters and setters
function NeedyGreedy:GetNItems(info)
    return self.db.profile.nItems
end

function NeedyGreedy:SetNItems(info, nItems)
    self.db.profile.nItems = nItems
    self:RefreshTooltip()
end

function NeedyGreedy:GetMaxHeight(info)
    return self.db.profile.maxHeight
end

function NeedyGreedy:SetMaxHeight(info, value)
    self.db.profile.maxHeight = value
    self:RefreshTooltip()
end

function NeedyGreedy:GetExpiry(info)
    return self.db.profile.expiry
end

function NeedyGreedy:SetExpiry(info, expiry)
    self.db.profile.expiry = expiry
    self:ExpireItems()
end

function NeedyGreedy:GetQuality(info)
    return self.db.profile.quality
end

function NeedyGreedy:SetQuality(info, quality)
    self.db.profile.quality = quality
end

function NeedyGreedy:GetDisplayIcons(info)
    return self.db.profile.displayIcons
end

function NeedyGreedy:SetDisplayIcons(info, displayIcons)
    self.db.profile.displayIcons = displayIcons
    self:UpdateReport()
end

function NeedyGreedy:GetDetachedTooltip(info)
    return self.db.profile.detachedTooltip
end

function NeedyGreedy:SetDetachedTooltip(info, detachedTooltip)
    self.db.profile.detachedTooltip = detachedTooltip
    self:HideDBTooltip()
    if self.db.profile.detachedTooltip then
        self.db.profile.displayStatus = true
        if self:CheckDisplayOptions() then
            self:ShowDetachedTooltip()
        end
    else
        self.db.profile.displayStatus = false
        self:HideDetachedTooltip()
        -- Return to page one
        report.firstItem = 1
    end
end

function NeedyGreedy:GetDisplayTextLink(info)
    return self.db.profile.displayTextLink
end

function NeedyGreedy:SetDisplayTextLink(info, displayTextLink)
    self.db.profile.displayTextLink = displayTextLink
    self:UpdateReport()
end

function NeedyGreedy:GetHideMinimapIcon(info)
    return not self.db.profile.minimap.hide
end

function NeedyGreedy:SetHideMinimapIcon(info, hideMinimapIcon)
    self.db.profile.minimap.hide = not hideMinimapIcon
    if self.db.profile.minimap.hide then
        ngDBIcon:Hide("NeedyGreedy")
    else
        ngDBIcon:Show("NeedyGreedy")
    end
end

function NeedyGreedy:GetFilterLootMsgs(info)
    return self.db.profile.filterLootMsgs
end

function NeedyGreedy:SetFilterLootMsgs(info, filterLootMsgs)
    self.db.profile.filterLootMsgs = filterLootMsgs
    if self.db.profile.filterLootMsgs then
        self:EnableChatFilter()
    else
        self:DisableChatFilter()
    end
end

function NeedyGreedy:GetShowOnParty(info)
    return self.db.profile.showOnParty
end

function NeedyGreedy:SetShowOnParty(info, showOnParty)
    self.db.profile.showOnParty = showOnParty
end

function NeedyGreedy:GetHideInCombat(info)
    return self.db.profile.hideInCombat
end

function NeedyGreedy:SetHideInCombat(info, hideInCombat)
    self.db.profile.hideInCombat = hideInCombat
    self:RefreshTooltip()
end

function NeedyGreedy:GetShowGroupOnly(info)
    return self.db.profile.showGroupOnly
end

function NeedyGreedy:SetShowGroupOnly(info, showGroupOnly)
    self.db.profile.showGroupOnly = showGroupOnly
    wipe(nameList)
    self:RefreshTooltip()
end

function NeedyGreedy:GetAutoPopUp(info)
    return self.db.profile.autoPopUp
end

function NeedyGreedy:SetAutoPopUp(info, autoPopUp)
    self.db.profile.autoPopUp = autoPopUp
    self:RefreshTooltip()
end

function NeedyGreedy:GetResetInNewParty(info)
    return self.db.profile.resetInNewParty
end

function NeedyGreedy:SetResetInNewParty(info, resetInNewParty)
    self.db.profile.resetInNewParty = resetInNewParty
end

function NeedyGreedy:GetResetInNewInstance(info)
    return self.db.profile.resetInNewInstance
end

function NeedyGreedy:SetResetInNewInstance(info, resetInNewInstance)
    self.db.profile.resetInNewInstance = resetInNewInstance
end

function NeedyGreedy:GetTooltipScale(info)
    return self.db.profile.tooltipScale
end

function NeedyGreedy:SetTooltipScale(info, tooltipScale)
    self.db.profile.tooltipScale = tooltipScale
    self:RefreshTooltip()
end

function NeedyGreedy:GetLockTooltip(info)
    return self.db.profile.lockTooltip
end

function NeedyGreedy:SetLockTooltip(info, lockTooltip)
    self.db.profile.lockTooltip = lockTooltip
    self:RefreshTooltip()
end

function NeedyGreedy:GetSuppressInRaid(info)
    return self.db.profile.suppressInRaid
end

function NeedyGreedy:SetSuppressInRaid(info, suppressInRaid)
    self.db.profile.suppressInRaid = suppressInRaid
    self:RefreshTooltip()
end

function NeedyGreedy:GetAutoHideDelay(info)
    return self.db.profile.autoHideDelay
end

function NeedyGreedy:SetAutoHideDelay(info, autoHideDelay)
    self.db.profile.autoHideDelay = autoHideDelay
    self:RefreshTooltip()
end

function NeedyGreedy:GetShowLootMethod(info)
    return self.db.profile.showLootMethod
end

function NeedyGreedy:SetShowLootMethod(info, showLootMethod)
    self.db.profile.showLootMethod = showLootMethod
    self:UpdatePartyLootMethodText()
end

function NeedyGreedy:GetNoSpamMode(info)
    return self.db.profile.noSpamMode
end

-- Chat config
function NeedyGreedy:SetNoSpamMode(info, noSpamMode)
    self.db.profile.noSpamMode = noSpamMode
    if noSpamMode then
        self:EnableNoSpamMode()
    else
        self:DisableNoSpamMode()
    end
end

function NeedyGreedy:GetHighlightSelfChat(info)
    return self.db.profile.highlightSelfChat
end

function NeedyGreedy:SetHighlightSelfChat(info, highlightSelfChat)
    self.db.profile.highlightSelfChat = highlightSelfChat
    self:RefreshTooltip()
end

function NeedyGreedy:GetHighlightSelfChatColor(info)
    return unpack(self.db.profile.highlightSelfChatColor)
end

function NeedyGreedy:SetHighlightSelfChatColor(info, r, g, b, a)
    self.db.profile.highlightSelfChatColor = {r, g, b, a}
    self:RefreshTooltip()
end

function NeedyGreedy:GetHighlightWinnerChat(info)
    return self.db.profile.highlightWinnerChat
end

function NeedyGreedy:SetHighlightWinnerChat(info, highlightWinnerChat)
    self.db.profile.highlightWinnerChat = highlightWinnerChat
    self:RefreshTooltip()
end

function NeedyGreedy:GetHighlightWinnerChatColor(info)
    return unpack(self.db.profile.highlightWinnerChatColor)
end

function NeedyGreedy:SetHighlightWinnerChatColor(info, r, g, b, a)
    self.db.profile.highlightWinnerChatColor = {r, g, b, a}
    self:RefreshTooltip()
end

-- UI config
function NeedyGreedy:GetHighlightSelf(info)
    return self.db.profile.highlightSelf
end

function NeedyGreedy:SetHighlightSelf(info, highlightSelf)
    self.db.profile.highlightSelf = highlightSelf
    self:RefreshTooltip()
end

function NeedyGreedy:GetHighlightSelfColor(info)
    return unpack(self.db.profile.highlightSelfColor)
end

function NeedyGreedy:SetHighlightSelfColor(info, r, g, b, a)
    self.db.profile.highlightSelfColor = {r, g, b, a}
    self:RefreshTooltip()
end

function NeedyGreedy:GetHighlightWinner(info)
    return self.db.profile.highlightWinner
end

function NeedyGreedy:SetHighlightWinner(info, highlightWinner)
    self.db.profile.highlightWinner = highlightWinner
    self:RefreshTooltip()
end

function NeedyGreedy:GetHighlightWinnerColor(info)
    return unpack(self.db.profile.highlightWinnerColor)
end

function NeedyGreedy:SetHighlightWinnerColor(info, r, g, b, a)
    self.db.profile.highlightWinnerColor = {r, g, b, a}
    self:RefreshTooltip()
end

function NeedyGreedy:GetUseTooltipDefault(info)
    return self.db.profile.useTooltipDefaults
end

function NeedyGreedy:SetUseTooltipDefault(info, useTooltipDefaults)
    self.db.profile.useTooltipDefaults = useTooltipDefaults
    self:RefreshTooltip()
end

function NeedyGreedy:GetBackgroundColor(info)
    return unpack(self.db.profile.bgColor)
end

function NeedyGreedy:SetBackgroundColor(info, r, g, b, a)
    self.db.profile.bgColor = {r, g, b, a}
    self:RefreshTooltip()
end

function NeedyGreedy:GetBorderColor(info)
    return unpack(self.db.profile.borderColor)
end

function NeedyGreedy:SetBorderColor(info, r, g, b, a)
    self.db.profile.borderColor = {r, g, b, a}
    self:RefreshTooltip()
end

function NeedyGreedy:GetPlaySoundOnAward(info)
    return self.db.profile.playSoundOnAward
end

function NeedyGreedy:SetPlaySoundOnAward(info, value)
    self.db.profile.playSoundOnAward = value
end

function NeedyGreedy:GetSoundFile(info)
    return self.db.profile.soundName
end

function NeedyGreedy:SetSoundFile(info, value)
    self.db.profile.soundName = value
    self.db.profile.soundFile = LSM:Fetch("sound", value)
end

-- Debug Config
function NeedyGreedy:GetToggleDebug(info)
    return self.db.profile.debugStatus
end

function NeedyGreedy:SetToggleDebug(info, value)
    self.db.profile.debugStatus = value
end

function NeedyGreedy:GetMaxEvents(info)
    return self.db.profile.maxDebugEvents
end

function NeedyGreedy:SetMaxEvents(info, value)
    self.db.profile.maxDebugEvents = value
end

function NeedyGreedy:GetDebugLog()
    local dumpString = ""

    dumpString = dumpString .. "EventLog = "
    dumpString = dumpString .. "\n" .. self:PrintTable(EVENT_LOG)

    dumpString = dumpString .. "\n\nGetSortedPlayers = "
    dumpString = dumpString .. "\n" .. self:PrintTable(NAMELIST_LOG)

    dumpString = dumpString .. "\n\nGetPlayers = "
    dumpString = dumpString .. "\n" .. self:PrintTable(NAME_LOG)

    return dumpString
end

function NeedyGreedy:SetDebugLog(info, value)
end

function NeedyGreedy:ClearDebugLog()
    EVENT_LOG = {}
    options.args.debugOptions.args.exportDebugLog.disabled = false
end


-- QTip Frames
local LibQTip = LibStub('LibQTip-1.0')
local COL_MIN_WIDTH = 60

-- Special cell provider for displaying item icons
local ItemCell, ItemCell_Prototype = LibQTip:CreateCellProvider()
function ItemCell_Prototype:InitializeCell()
    local ItemCellHeight = 30
    local IconHeight = 25

    self:SetHeight(ItemCellHeight)
    self:SetWidth(COL_MIN_WIDTH)

    if not self.ItemDetailsBorder then
        self.ItemDetailsBorder = self:CreateTexture(nil, 'ARTWORK')
    end

    self.ItemDetailsBorder:SetTexture(nil)
    self.ItemDetailsBorder:SetAlpha(1)
    self.ItemDetailsBorder:SetHeight(ItemCellHeight)
    self.ItemDetailsBorder:SetWidth(ItemCellHeight)
    self.ItemDetailsBorder:SetPoint("CENTER", self, "CENTER")

    if not self.ItemDetails then
        self.ItemDetails = self:CreateTexture(nil,"OVERLAY")
    end

    self.ItemDetails:SetTexture(nil)
    self.ItemDetails:SetHeight(IconHeight)
    self.ItemDetails:SetWidth(IconHeight)
    self.ItemDetails:SetPoint("CENTER", self.ItemDetailsBorder, "CENTER")

end

function ItemCell_Prototype:SetupCell(tooltip, value, justification, font, args)
    local icon, quality = unpack(value)
    self.ItemDetails:SetTexture(icon)

    if quality then
        local color = {r, g, b, hex}
        color.r, color.g, color.b, color.hex = GetItemQualityColor(quality)
        self.ItemDetailsBorder:SetTexture(color.r, color.g, color.b)
    else
        self.ItemDetailsBorder:SetTexture(nil)
    end

    self.ItemDetailsBorder:Show()

    return self:GetWidth(), self:GetHeight()
end

function ItemCell_Prototype:getContentHeight()
    return 30
end

-- Create functions locally to reduce garbage collection
local function Detached_OnMouseDown()
    NeedyGreedy.detachedTooltip:StartMoving()
end

local function Detached_OnMouseUp()
    -- Make it remember
    local tooltip = NeedyGreedy.detachedTooltip
    local pos = NeedyGreedy.db.profile.reportFramePos

    tooltip:StopMovingOrSizing()

    local anchor1, _, anchor2, x, y = tooltip:GetPoint()

    pos.anchor1 = anchor1
    pos.anchor2 = anchor2
    pos.x = x
    pos.y = y
end

-- Detachable tooltip
function NeedyGreedy:ShowDetachedTooltip()

    -- Acquire a tooltip
    if not LibQTip:IsAcquired("NeedyGreedyReport") then
        self.detachedTooltip = LibQTip:Acquire("NeedyGreedyReport", 1, "LEFT")
        self.detachedTooltip:SetScale(self.db.profile.tooltipScale)

        local r, g, b, a
        if self.db.profile.useTooltipDefaults then
            r, g, b, a  = unpack(GameTooltip:GetBackdrop())
            self.detachedTooltip:SetBackdropColor(r, g, b, a)
            r, g, b, a = GameTooltip:GetBackdropBorderColor()
            self.detachedTooltip:SetBackdropBorderColor(r, g, b, a)
        else
            r, g, b, a = unpack(self.db.profile.bgColor)
            self.detachedTooltip:SetBackdropColor(r, g, b, a)
            r, g, b, a = unpack(self.db.profile.borderColor)
            self.detachedTooltip:SetBackdropBorderColor(r, g, b, a)
        end

        -- Add columns here because tooltip:Clear() preserves columns
        for i = 1, self.db.profile.nItems do
            self.detachedTooltip:AddColumn("LEFT")
        end

        -- Add two columns for left and right buttons if detached
        if self.db.profile.detachedTooltip then
            self.detachedTooltip:AddColumn("LEFT")
        end

        -- Fill in the info
        self:BuildDetachedTooltip(self.detachedTooltip)

        if self.db.profile.detachedTooltip then
            -- To make tooltip detached
            self.detachedTooltip:ClearAllPoints()
            self.detachedTooltip:SetFrameStrata("FULLSCREEN")
            self.detachedTooltip:EnableMouse(true)
            self.detachedTooltip:SetResizable(true)
            self.detachedTooltip:SetFrameLevel(1)
            self.detachedTooltip:SetMovable(true)
            self.detachedTooltip:SetClampedToScreen(true)

            if not self.db.profile.reportFramePos then
                self.db.profile.reportFramePos = {
                    anchor1 = "CENTER",
                    anchor2 = "CENTER",
                    x = 0,
                    y = 0
                }
            end
            self.detachedTooltip:SetPoint(self.db.profile.reportFramePos.anchor1, nil, self.db.profile.reportFramePos.anchor2,
                self.db.profile.reportFramePos.x, self.db.profile.reportFramePos.y)

            -- Make it move !
            if not self.db.profile.lockTooltip then
                self.detachedTooltip:SetScript("OnMouseDown", Detached_OnMouseDown)
                self.detachedTooltip:SetScript("OnMouseUp", Detached_OnMouseUp)
            end
        end
    end

    self.detachedTooltip:UpdateScrolling(self.db.profile.maxHeight)
    self.detachedTooltip:SetScrollStep(self.db.profile.scrollStep)

    -- Show it, et voila !
    self.detachedTooltip:Show()
end

function NeedyGreedy:HideDetachedTooltip()
    if self.detachedTooltip then
        self.detachedTooltip:Hide()
        self.detachedTooltip:SetScript("OnMouseDown", nil)
        self.detachedTooltip:SetScript("OnMouseUp", nil)
        self.detachedTooltip:SetScale(1)
        LibQTip:Release(self.detachedTooltip)
        self.detachedTooltip = nil
    end
end

function NeedyGreedy:ShowDBTooltip(frame)
    -- Acquire a tooltip
    if not LibQTip:IsAcquired("NeedyGreedyDBReport") then
        self.dbTooltip = LibQTip:Acquire("NeedyGreedyDBReport", 1, "LEFT")

        if not self.db.profile.detachedTooltip then
            self.dbTooltip:SetAutoHideDelay(0.25, frame)
            -- Add columns here because tooltip:Clear() preserves columns
            for i = 1, self.db.profile.nItems do
                self.dbTooltip:AddColumn("LEFT")
            end

            -- Extra column for the pager arrow
            self.dbTooltip:AddColumn("LEFT")

            -- Fill in the info
            self:BuildDBReportTooltip(self.dbTooltip)
        else

            self:AddHeaderText(self.dbTooltip)
            self:AddInfoText(self.dbTooltip)
        end

        if frame then self.dbTooltip:SmartAnchorTo(frame) end

        self.dbTooltip:SetScript("OnHide", function()
            if self.dbTooltip then
                LibQTip:Release(self.dbTooltip)
                self.dbTooltip = nil
            end
        end)
    end

    self.dbTooltip:UpdateScrolling(self.db.profile.maxHeight)
    self.dbTooltip:SetScrollStep(self.db.profile.scrollStep)

    -- Show it, et voila !
    self.dbTooltip:Show()
end

function NeedyGreedy:HideDBTooltip()
    if self.dbTooltip then
        self.dbTooltip:Hide()
        LibQTip:Release(self.dbTooltip)
        self.dbTooltip = nil
    end
end

function NeedyGreedy:PopulateReportTooltip(tooltip)
    local nItems = self.db.profile.nItems
    local players = self:GetSortedPlayers()

    -- For sizing the columns
    local fontString = tooltip:CreateFontString()
    fontString:SetFontObject(tooltip:GetFont())
    local minWidth = 0
    for _, name in ipairs(players) do
        fontString:SetText(name)
        local fontWidth = fontString:GetStringWidth()
        minWidth = max(fontWidth, minWidth)
    end

    -- Verify that report.firstItem is set reasonably
    local count = #items

    if not(report.firstItem) then report.firstItem = 1 end
    if count == 0 then
        report.firstItem = 1
    elseif report.firstItem > count then
        report.firstItem = count
    end

    -- Create icon headers
    local headerline, _ = tooltip:AddLine("")
    for i = 1, nItems do
        local index = #items - (report.firstItem + i - 2)
        local texture = ""
        local item
        if index >= 1 then
            item = items[index]
        end

        -- Placeholder icons
        tooltip:SetCell(headerline, i + 1, "", nil, nil, nil, nil , nil, nil, nil, minWidth)

        if item then
            -- Color surrounding cell according to item rarity
            local _, _, quality = GetItemInfo(item.itemID)
            tooltip:SetCell(headerline, i + 1, {item.texture, quality}, nil, nil, nil, ItemCell , nil, nil, nil, minWidth)

            tooltip:SetCellScript(headerline, i + 1, "OnEnter", function()
                GameTooltip:SetOwner(tooltip, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(item.link)
            end )
                tooltip:SetCellScript(headerline, i + 1, "OnMouseUp", function()
                    if IsShiftKeyDown() then
                        ChatEdit_InsertLink(item.link)
                    end
                end )
            tooltip:SetCellScript(headerline, i + 1, "OnLeave", function()
                GameTooltip:Hide()
            end )
        end
    end

    -- Now add item link names
    if self.db.profile.displayTextLink then
        headerline, _ = tooltip:AddLine("")
        for i = 1, nItems do
            local index = #items - (report.firstItem + i - 2)
            local text = ""
            local item
            if index >= 1 then
                item = items[index]
                text = item.link
            end
            tooltip:SetCell(headerline, i + 1, text, nil, nil, nil, nil, nil, nil, nil, 60)
            if item then
                tooltip:SetCellScript(headerline, i + 1, "OnEnter", function()
                    GameTooltip:SetOwner(tooltip, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink(item.link)
                end )
                tooltip:SetCellScript(headerline, i + 1, "OnMouseUp", function()
                    if IsShiftKeyDown() then
                        ChatEdit_InsertLink(item.link)
                    end
                end )
                tooltip:SetCellScript(headerline, i + 1, "OnLeave", function()
                    GameTooltip:Hide()
                end )
            end
        end
    end

    tooltip:AddLine("")

    -- Create table with party names and their rolls
    local me = UnitName("player")
    for i, name in ipairs(players) do
        local partyLine = tooltip:AddLine("")
        tooltip:SetCell(partyLine, 1, self:ColorizeName(name) .. " " .. (self.db.profile.displayIcons and BLANK_ICON or ""), nil, "LEFT", nil, nil, nil, nil, nil, minWidth)

        for i = 1, nItems do
            local index = #items - (report.firstItem + i - 2)
            if index >= 1 then
                local item = items[index]
                tooltip:SetCell(partyLine, i + 1, self:ChoiceText(item.choices[name]) .. self:RollText(item.rolls[name], item.assigned == name, item.assigned == me), nil, "LEFT", nil, nil, nil, nil, nil, minWidth)
            end
        end
    end

    tooltip:AddSeparator()

    -- Display winner
    local winnerTable = {yC .. "Winner|r"}
    for i = 1, nItems do
        local index = #items - (report.firstItem + i - 2)
        if index >= 1 then
            local item = items[index]
            table.insert(winnerTable, self:AssignedText(item))
        end
    end
    tooltip:AddLine(unpack(winnerTable))
end

function NeedyGreedy:AddHeaderText(tooltip)
    local headerText = yC .. "NeedyGreedy|r"
    local lineNum = tooltip:AddLine("")
    tooltip:SetCell(lineNum, 1, headerText, tooltip:GetHeaderFont(), tooltip:GetColumnCount() - 1)

    if self.detachedTooltip and tooltip == self.detachedTooltip then
        tooltip:SetCell(lineNum, tooltip:GetColumnCount(), CLOSE_ICON)
        tooltip:SetCellScript(lineNum, tooltip:GetColumnCount(),"OnMouseUp", function() self:ToggleDisplay() end)
    end

    tooltip:AddLine("")
end

function NeedyGreedy:AddPagerArrows(tooltip)
    local nItems = self.db.profile.nItems
    local count = #items

    local lineNum, _ = tooltip:AddLine("")
    local colNum = nItems + 1

    if report.firstItem > 1 then
        tooltip:SetCell(lineNum, colNum, PAGER_ICONS.leftUp, nil, "RIGHT")
        tooltip:SetCellScript(lineNum, colNum, "OnMouseUp", function() self:PageLeft() end)
    else
        tooltip:SetCell(lineNum, colNum, PAGER_ICONS.leftDisabled, nil, "RIGHT")
    end

    if report.firstItem + nItems - 1 < count then
        tooltip:SetCell(lineNum, colNum + 1, PAGER_ICONS.rightUp)
        tooltip:SetCellScript(lineNum, colNum + 1, "OnMouseUp", function() self:PageRight() end)
    else
        tooltip:SetCell(lineNum, colNum + 1, PAGER_ICONS.rightDisabled)
    end

    -- Set the page # text
    local pageText = ""
    if nItems == 1 and count > 0 then
        pageText = tostring(report.firstItem)
    elseif count == 0 then
        pageText = ""
    elseif count == 1 or report.firstItem == count then
        pageText = string.format(L["%d of %d"], report.firstItem, count)
    else
        local lastitem = report.firstItem + nItems - 1
        if (lastitem > count) then
            lastitem = count
        end
        pageText = string.format(L["%d-%d of %d"], report.firstItem, lastitem, count)
    end

    tooltip:SetCell(lineNum, colNum - 1, yC .. pageText, nil, "RIGHT")
end

function NeedyGreedy:AddInfoText(tooltip)
    local lineNum
    local helpText

    tooltip:AddLine("")

    helpText = ""
    if self.db.profile.detachedTooltip then
        helpText = helpText .. eC .. L["Click"] .. "|r " .. gC .. L["to hide/show detached tooltip"] .. "|r\n"
    end
    helpText = helpText .. eC .. L["Shift-Click"] .. "|r " .. gC .. L["to attach/detach tooltip"] .. "|r\n"
    helpText = helpText .. eC .. L["Alt-Click"] .. "|r " .. gC .. L["to clear item list"] .. "|r"
    lineNum = tooltip:AddLine()
    tooltip:SetCell(lineNum, 1, helpText, nil, tooltip:GetColumnCount())
end

function NeedyGreedy:BuildDetachedTooltip(tooltip)
    tooltip:Clear()
    self:AddHeaderText(tooltip)
    self:PopulateReportTooltip(tooltip)
    self:AddPagerArrows(tooltip)
end

function NeedyGreedy:BuildDBReportTooltip(tooltip)
    tooltip:Clear()
    self:AddHeaderText(tooltip)
    if self:DisplayLDBTTCheck() then
        self:PopulateReportTooltip(tooltip)
        self:AddPagerArrows(tooltip)
    end
    self:AddInfoText(tooltip)
end

function NeedyGreedy:UpdateReport()
    local tooltip
    if self.detachedTooltip and self.detachedTooltip:IsShown() then
        self:BuildDetachedTooltip(self.detachedTooltip)
        self.detachedTooltip:UpdateScrolling(self.db.profile.maxHeight)
        self.detachedTooltip:SetScrollStep(self.db.profile.setStep)
    elseif self.dbTooltip and self.dbTooltip:IsShown() and (not self.db.profile.detachedTooltip) then
        self:BuildDBReportTooltip(self.dbTooltip)
        self.dbTooltip:UpdateScrolling(self.db.profile.maxHeight)
        self.dbTooltip:SetScrollStep(self.db.profile.setStep)
    else
        return
    end
end

function NeedyGreedy:RefreshTooltip()
    if self.db.profile.detachedTooltip and self:DisplayDetachedTTCheck() then
        self:HideDetachedTooltip()
        self:ShowDetachedTooltip()
    else
        self:HideDetachedTooltip()
    end
    self:HideDBTooltip()
end

function NeedyGreedy:ToggleDisplay()
    if not self.db.profile.detachedTooltip then return end

    -- Don't toggle display status if we can't see anything to toggle
    if self.detachedTooltip and self.detachedTooltip:IsShown() then
        if WATCH_ITEM_BEING_ROLLED_ON then
            WATCH_ITEM_BEING_ROLLED_ON = false
        end
        self:HideDetachedTooltip()
        self.db.profile.displayStatus = false
    elseif self:CheckDisplayOptions() then
        self:ShowDetachedTooltip()
        self.db.profile.displayStatus = true
    end

end

-- Only use this when not forcing display e.g. RefreshTooltip
function NeedyGreedy:DisplayDetachedTTCheck()
    if self.db.profile.autoPopUp and WATCH_ITEM_BEING_ROLLED_ON then
        return true
    end

    if not self.db.profile.displayStatus then
        return false
    end

    return self:CheckDisplayOptions()
end

-- Use this when forcing display of detached tooltip
function NeedyGreedy:CheckDisplayOptions()
    if self:CheckShowInCombat() then
        return true
    end

    return false
end

function NeedyGreedy:CheckShowInCombat()
    if self.db.profile.hideInCombat and IS_IN_COMBAT then
        return false
    end

    return true
end

function NeedyGreedy:DisplayLDBTTCheck()
    if self:CheckSuppressInRaid() then
        return false
    end

    return true
end

function NeedyGreedy:CheckSuppressInRaid()
    if IS_IN_RAID and self.db.profile.suppressInRaid then
        return true
    end

    return false
end



-- Chat filter functions
local function FilterLootMsg(ChatFrameSelf, event, ...)
    local msg = select(1, ...)
    for _, string in ipairs(FILTER_CHAT_LOOT_MSGS) do
        local match = NeedyGreedy:unformat(string, msg)
        if match then
            return true
        end
    end

    return false, ...
end

function NeedyGreedy:EnableNoSpamMode()
    FILTER_CHAT_LOOT_MSGS = NO_SPAM_FILTER_CHAT_LOOT_MSGS
end

function NeedyGreedy:DisableNoSpamMode()
    FILTER_CHAT_LOOT_MSGS = ORIG_FILTER_CHAT_LOOT_MSGS
end

function NeedyGreedy:EnableChatFilter()
    FILTER_CHAT_LOOT_MSGS = ORIG_FILTER_CHAT_LOOT_MSGS
    if self.db.profile.noSpamMode then
        FILTER_CHAT_LOOT_MSGS = NO_SPAM_FILTER_CHAT_LOOT_MSGS
    end
    ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", FilterLootMsg)
end

function NeedyGreedy:DisableChatFilter()
    ChatFrame_RemoveMessageEventFilter("CHAT_MSG_LOOT", FilterLootMsg)
end



-- Automatic enabling of detailed loot information
function NeedyGreedy:SetShowLootSpam()
    local showLootSpam = GetCVar("showLootSpam") -- 0 for filtered, 1 for details
    if showLootSpam == "0" then
        originalSpamFilterSetting = showLootSpam
        SetCVar("showLootSpam", "1")
    end
end

function NeedyGreedy:ResetShowLootSpam()
    if originalSpamFilterSetting then
        SetCVar("showLootSpam", originalSpamFilterSetting)
        originalSpamFilterSetting = nil
    end
end



-- Slash Commands
function NeedyGreedy:SlashHide()
    self.db.profile.detachedTooltip = true
    self.db.profile.displayStatus = false
    if WATCH_ITEM_BEING_ROLLED_ON then
        WATCH_ITEM_BEING_ROLLED_ON = false
    end
    self:RefreshTooltip()
    LibStub("AceConfigRegistry-3.0"):NotifyChange("NeedyGreedy")
end

function NeedyGreedy:SlashShow()
    self.db.profile.detachedTooltip = true
    self.db.profile.displayStatus = true
    self:RefreshTooltip()
    LibStub("AceConfigRegistry-3.0"):NotifyChange("NeedyGreedy")
end

function NeedyGreedy:PrintReport()
    if #items == 0 then self:Print(L["Nothing to report"]) return end
    local output = {}

    for _, item in ipairs(items) do
        for name, choice in pairs(item.choices) do
            if not output[name] then
                output[name] = {
                    ["name"] = name,
                    ["need"] = 0,
                    ["greed"] = 0,
                    ["disenchant"] = 0,
                    ["pass"] = 0,
                    ["assigned"] = 0,
                }
            end

            for k, v in pairs(output[name]) do
                if choice == k then
                    output[name][k] = v + 1
                end
            end

            if item.assigned == name then
                output[name]["assigned"] = output[name]["assigned"] + 1
            end
        end
    end

    local sorted = {}
    for _, record in pairs(output) do
        table.insert(sorted, record)
    end
    table.sort(sorted, function(a,b) return b.assigned < a.assigned end)

    for _, info in ipairs(sorted) do
        self:Printf("%s N:%d G:%d DE:%d P:%d Wins:%d", info.name, info.need, info.greed, info.disenchant, info.pass, info.assigned)
    end
end



-- Profile Handling
function NeedyGreedy:RefreshProfile()
    if self.db.profile.minimap.hide then
        ngDBIcon:Hide("NeedyGreedy")
    else
        ngDBIcon:Show("NeedyGreedy")
    end

    self:RefreshTooltip()
end


-- Debugging functions
local function cleanvalue(value)
    local valType = type(value)
    if valType == "nil" then
        value = "nil"
    elseif valType == "number" then
        value = value
    elseif valType == "boolean" then
        if value then
            value = "true"
        else
            value = "false"
        end
    elseif valType == "string" then
        local tempString = string.gsub(value, "|", "||")
        tempString = string.format("\"%s\"", tempString)
        value = tempString
    else
        value = tostring(value)
    end

    return value
end

function NeedyGreedy:tableToString(tableObj)
    if tableObj == nil then
        return "nil"
    elseif type(tableObj) ~= "table" then
        return "not a table"
    end

    local dumpString = "{\n"
    for k, v in pairs(tableObj) do
        dumpString = dumpString .. "    [" .. k .. "] = " .. cleanvalue(v) .. ", \n"
    end
    dumpString = dumpString .. "}"

    return dumpString
end

function NeedyGreedy:PrintTable(t, indent)
    if not t then return "nil" end

    if indent == nil then
        indent = ""
    end

    local dumpString = "{\n"
    for key, detail in pairs(t) do
        -- Convert value to a pretty format
        dumpString = dumpString .. indent .. "  [" .. tostring(key) .. "] = "
        if type(detail) == "table" then
            dumpString = dumpString .. self:PrintTable(detail, indent .. "  ")
        else
            dumpString = dumpString .. cleanvalue(detail)
        end

        dumpString = dumpString .. ",\n"
    end

    dumpString = dumpString .. indent .."}"

    return dumpString
end

function NeedyGreedy:AddEventToLog(eventTable)
    if not eventTable then return end

    table.insert(EVENT_LOG, eventTable)
    if #EVENT_LOG > self.db.profile.maxDebugEvents then
        table.remove(EVENT_LOG, 1)
    end
end


-- Unit tests
--[[
function NeedyGreedy:SetItems(itemList)
    items = itemList
    self:UpdateReport()
end

function NeedyGreedy:GetItems()
    return items
end

function NeedyGreedy:TestItemList()
    items = {
        {
            ["received"] = 108626.818,
            ["assigned"] = "Evilplaque",
            ["itemID"] = 36040,
            ["link"] = "|cff1eff00|Hitem:36040:0:0:0:0:0:-36:-2033450911:80|h[Condor Pants of the Sorcerer]|h|r",
            ["choices"] = {
                ["Aneeka"] = "greed",
                ["Lubov"] = "greed",
                ["Evilplaque"] = "greed",
                ["Blizzy"] = "disenchant",
                ["Dkmonkey"] = "disenchant",
            },
            ["rolls"] = {
                ["Aneeka"] = "24",
                ["Lubov"] = "66",
                ["Evilplaque"] = "98",
                ["Blizzy"] = "52",
                ["Dkmonkey"] = "3",
            },
            ["texture"] = "Interface\\Icons\\INV_Pants_Cloth_10",
        }, -- [6]
        {
            ["received"] = 109046.237,
            ["assigned"] = "Lubov",
            ["itemID"] = 50228,
            ["link"] = "|cffa335ee|Hitem:50228:0:0:0:0:0:0:1749772928:80|h[Barbed Ymirheim Choker]|h|r",
            ["choices"] = {
                ["Aneeka"] = "greed",
                ["Blizzy"] = "disenchant",
                ["Evilplaque"] = "disenchant",
                ["Lubov"] = "need",
                ["Dkmonkey"] = "disenchant",
            },
            ["rolls"] = {
                ["Lubov"] = "17",
            },
            ["texture"] = "Interface\\Icons\\INV_Jewelry_Necklace_22",
        }, -- [7]
        {
            ["received"] = 109223.287,
            ["assigned"] = "Lubov",
            ["itemID"] = 36260,
            ["link"] = "|cff1eff00|Hitem:36260:0:0:0:0:0:-40:-1617756088:80|h[Cormorant Footwraps of the Bandit]|h|r",
            ["choices"] = {
                ["Aneeka"] = "greed",
                ["Blizzy"] = "disenchant",
                ["Evilplaque"] = "greed",
                ["Lubov"] = "greed",
                ["Dkmonkey"] = "disenchant",
            },
            ["rolls"] = {
                ["Aneeka"] = "61",
                ["Blizzy"] = "54",
                ["Evilplaque"] = "50",
                ["Lubov"] = "87",
                ["Dkmonkey"] = "1",
            },
            ["texture"] = "Interface\\Icons\\INV_Boots_Chain_07",
        }, -- [8]
        {
            ["received"] = 109267.102,
            ["assigned"] = "Dkmonkey",
            ["itemID"] = 50319,
            ["link"] = "|cffa335ee|Hitem:50319:0:0:0:0:0:0:459549600:80|h[Unsharpened Ice Razor]|h|r",
            ["choices"] = {
                ["Aneeka"] = "disenchant",
                ["Lubov"] = "disenchant",
                ["Evilplaque"] = "disenchant",
                ["Blizzy"] = "disenchant",
                ["Dkmonkey"] = "disenchant",
            },
            ["rolls"] = {
                ["Aneeka"] = "69",
                ["Lubov"] = "28",
                ["Evilplaque"] = "30",
                ["Blizzy"] = "21",
                ["Dkmonkey"] = "80",
            },
            ["texture"] = "Interface\\Icons\\inv_weapon_shortblade_61",
        }, -- [9]
        {
            ["received"] = 109483.031,
            ["assigned"] = "Dkmonkey",
            ["itemID"] = 50262,
            ["link"] = "|cffa335ee|Hitem:50262:0:0:0:0:0:0:305102456:80|h[Felglacier Bolter]|h|r",
            ["choices"] = {
                ["Aneeka"] = "disenchant",
                ["Blizzy"] = "disenchant",
                ["Evilplaque"] = "disenchant",
                ["Lubov"] = "disenchant",
                ["Dkmonkey"] = "disenchant",
            },
            ["rolls"] = {
                ["Aneeka"] = "9",
                ["Lubov"] = "40",
                ["Evilplaque"] = "69",
                ["Blizzy"] = "45",
                ["Dkmonkey"] = "77",
            },
            ["texture"] = "Interface\\Icons\\inv_weapon_crossbow_30",
        }, -- [10]
        {
            ["received"] = 109746.236,
            ["assigned"] = "Blizzy",
            ["itemID"] = 37780,
            ["link"] = "|cff0070dd|Hitem:37780:0:0:0:0:0:0:1986751616:80|h[Condor-Bone Chestguard]|h|r",
            ["choices"] = {
                ["Aneeka"] = "greed",
                ["Blizzy"] = "disenchant",
                ["Evilplaque"] = "greed",
                ["Lubov"] = "greed",
                ["Dkmonkey"] = "greed",
            },
            ["rolls"] = {
                ["Aneeka"] = "14",
                ["Lubov"] = "22",
                ["Evilplaque"] = "72",
                ["Blizzy"] = "77",
                ["Dkmonkey"] = "62",
            },
            ["texture"] = "Interface\\Icons\\INV_Chest_Chain_14",
        }, -- [11]
        {
            ["received"] = 110173.528,
            ["assigned"] = "Lubov",
            ["itemID"] = 50272,
            ["link"] = "|cffa335ee|Hitem:50272:0:0:0:0:0:0:349262944:80|h[Frost Wyrm Ribcage]|h|r",
            ["choices"] = {
                ["Aneeka"] = "greed",
                ["Blizzy"] = "disenchant",
                ["Evilplaque"] = "disenchant",
                ["Lubov"] = "need",
                ["Dkmonkey"] = "disenchant",
            },
            ["rolls"] = {
                ["Lubov"] = "2",
            },
            ["texture"] = "Interface\\Icons\\inv_chest_plate23",
        }, -- [12]
        {
            ["received"] = 110155.978,
            ["assigned"] = "Lubov",
            ["itemID"] = 50285,
            ["link"] = "|cffa335ee|Hitem:50285:0:0:0:0:0:0:617698400:80|h[Icebound Bronze Cuirass]|h|r",
            ["choices"] = {
                ["Aneeka"] = "greed",
                ["Blizzy"] = "disenchant",
                ["Evilplaque"] = "disenchant",
                ["Lubov"] = "need",
                ["Dkmonkey"] = "disenchant",
            },
            ["rolls"] = {
                ["Lubov"] = "25",
            },
            ["texture"] = "Interface\\Icons\\inv_chest_plate23",
        }, -- [13]
        {
            ["received"] = 110154.673,
            ["assigned"] = "Evilplaque",
            ["itemID"] = 43102,
            ["link"] = "|cff0070dd|Hitem:43102:0:0:0:0:0:0:1423004768:80|h[Frozen Orb]|h|r",
            ["choices"] = {
                ["Aneeka"] = "greed",
                ["Lubov"] = "greed",
                ["Evilplaque"] = "greed",
                ["Blizzy"] = "greed",
                ["Dkmonkey"] = "greed",
            },
            ["rolls"] = {
                ["Aneeka"] = "83",
                ["Blizzy"] = "96",
                ["Evilplaque"] = "96",
                ["Lubov"] = "60",
                ["Dkmonkey"] = "15",
            },
            ["texture"] = "Interface\\Icons\\Spell_Frost_FrozenCore",
        }, -- [14]
    }
    self:RefreshTooltip()
end

function NeedyGreedy:TestCleanup()
    WATCH_ITEM_BEING_ROLLED_ON = true
    local link = "|cff0070dd|Hitem:43102:0:0:0:0:0:0:1423004768:80|h[Frozen Orb]|h|r"
    local player = "Lubov"
    self:RecordReceived(link, player)
end
--]]

-- /dump NeedyGreedy:TestSuperFind()
--[[
function NeedyGreedy:TestSuperFind()
    do
        local pattern, captureIndices = patternFromFormat("%s automatically passed on: %s because he cannot loot that item.")
        DevTools_Dump({pattern, captureIndices})
        DevTools_Dump({superFind("bob automatically passed on: [Tuxedo Jacket] because he cannot loot that item.", pattern, captureIndices)})
    end

    do
        local pattern, captureIndices = patternFromFormat("%1$s gewinnt: %3$s |cff818181(Gier - %2$d)|r")
        DevTools_Dump({pattern, captureIndices})
        DevTools_Dump({superFind("bob gewinnt: [Tuxedo Jacket] |cff818181(Gier - 123)|r", pattern, captureIndices)})
    end

    --DevTools_Dump()

end
]]
