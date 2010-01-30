NeedyGreedy = LibStub("AceAddon-3.0"):NewAddon("NeedyGreedy", "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale("NeedyGreedy", true)

local report = {}
local items = {}
local nameList = {}

-- Set up DataBroker object
local NeedyGreedyLDB = LibStub("LibDataBroker-1.1"):NewDataObject("NeedyGreedy", {
    type = "launcher",
    label = "Needy Greedy",
    icon = "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
    OnClick = function(frame, button)
        if button == "RightButton" then
            InterfaceOptionsFrame_OpenToCategory("NeedyGreedy")
        elseif IsShiftKeyDown() then
            NeedyGreedy.db.profile.detachedTooltip = not NeedyGreedy.db.profile.detachedTooltip
            LibStub("AceConfigRegistry-3.0"):NotifyChange("NeedyGreedy")
            report.firstItem = 1
            NeedyGreedy:HideDBTooltip()
            NeedyGreedy:ShowDBTooltip(frame)
            NeedyGreedy:HideDetachedTooltip()
            if NeedyGreedy.db.profile.detachedTooltip then
                NeedyGreedy.db.profile.displayDetached = true
                NeedyGreedy:ShowDetachedTooltip()
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
        NeedyGreedy:HideDBTooltip()
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
            args = {
                nItems = {
                    name = L["Display Items"],
                    desc = L["Number of item columns in the display window"],
                    type = "range",
                    order = 100,
                    min = 1,
                    max = 10,
                    step = 1,
                    get = "GetNItems",
                    set = "SetNItems"
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
                displayIcons = {
                    name = L["Graphical Display"],
                    desc = L["Display icons for rolls types instead of text"],
                    type = "toggle",
                    order = 20,
                    get = "GetDisplayIcons",
                    set = "SetDisplayIcons",
                },
                detachedTooltip = {
                    name = L["Detach Tooltip"],
                    desc = L["Display the roll information in a standalone window"],
                    type = "toggle",
                    order = 10,
                    get = "GetDetachedTooltip",
                    set = "SetDetachedTooltip",
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
                },
                filterLootMsgs = {
                    name = L["Filter Loot Messages"],
                    desc = L["Enable filtering of loot roll messages"],
                    type = "toggle",
                    order = 35,
                    get = "GetFilterLootMsgs",
                    set = "SetFilterLootMsgs",
                },
                onlyShowInParty = {
                    name = L["Show only in party"],
                    desc = L["Only display the roll window when in a party"],
                    type = "toggle",
                    order = 50,
                    get = "GetOnlyShowInParty",
                    set = "SetOnlyShowInParty",
                },
                hideInCombat = {
                    name = L["Hide in combat"],
                    desc = L["Only display the roll window when not in combat"],
                    type = "toggle",
                    order = 60,
                    get = "GetHideInCombat",
                    set = "SetHideInCombat",
                },
                showGroupOnly = {
                    name = L["Hide Non-Members"],
                    desc = L["Only display the names of members currently in your party"],
                    type = "toggle",
                    order = 40,
                    get = "GetShowGroupOnly",
                    set = "SetShowGroupOnly",
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
        displayDetached = false,
        minimap = { hide = false },
        filterLootMsgs = false,
        onlyShowInParty = false,
        hideInCombat = false,
        showGroupOnly = true,
    }
}

-- Icon textures
local iconSize = 27
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
local BLANK_ICON = "|T:27|t"
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
local originalSpamFilterSetting = nil

-- For tracking combat status
local IS_IN_COMBAT = nil

-- Utility functions
local function sanitizePattern(pattern)
    pattern = string.gsub(pattern, "%(", "%%(")
    pattern = string.gsub(pattern, "%)", "%%)")
    pattern = string.gsub(pattern, "%%s", "(.+)")
    pattern = string.gsub(pattern, "%%d", "(%%d+)")
    pattern = string.gsub(pattern, "%-", "%%-")
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



-- Event handling functions
function NeedyGreedy:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("NeedyGreedyDB", defaults, true)
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshTooltip")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshTooltip")
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshTooltip")
    options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
    LibStub("AceConfig-3.0"):RegisterOptionsTable("NeedyGreedy", options)
    local ACD = LibStub("AceConfigDialog-3.0")
    ACD:AddToBlizOptions("NeedyGreedy", "NeedyGreedy", nil, "general")
    ACD:AddToBlizOptions("NeedyGreedy", L["Profile"], "NeedyGreedy", "profile")
    self:RegisterChatCommand("needygreedy", "ProcessSlashCommands")
    self:RegisterChatCommand("ng", "ProcessSlashCommands")
    self.items = items

    -- Register the minimap icon
    ngDBIcon:Register("NeedyGreedy", NeedyGreedyLDB, self.db.profile.minimap)
end

function NeedyGreedy:OnEnable()
    self:RegisterEvent("PARTY_MEMBERS_CHANGED")
    self:RegisterEvent("START_LOOT_ROLL")
    self:RegisterEvent("CHAT_MSG_LOOT")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")

    self:ScheduleRepeatingTimer("ExpireItems", 10)

    -- Refresh display when class can be determined
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("UNIT_CLASSIFICATION_CHANGED", "PLAYER_ENTERING_WORLD")

    self:RegisterEvent("PLAYER_LEAVING_WORLD")

    -- Set up chat filters
    if self.db.profile.filterLootMsgs then
        self:EnableChatFilter()
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
    if self.db.profile.displayDetached and self.db.profile.detachedTooltip then
        self:ShowDetachedTooltip()
    end

    self:SetShowLootSpam()
end

function NeedyGreedy:PLAYER_LEAVING_WORLD()
    self:ResetShowLootSpam()
end

function NeedyGreedy:PARTY_MEMBERS_CHANGED()
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



-- Chat scanning and loot recording
function NeedyGreedy:START_LOOT_ROLL(event, rollid)
    local texture, name, count, quality = GetLootRollItemInfo(rollid)
    local link = GetLootRollItemLink(rollid)
    if quality >= self.db.profile.quality then
        items[rollid] = {
            texture = texture,
            link = link,
            itemID = itemIdFromLink(link),
            assigned = "",
            received = 0,
            choices = {},
            rolls = {}
        }
        self:UpdateReport()
    end
end

function NeedyGreedy:CHAT_MSG_LOOT(event, msg)
    local me = UnitName("player")
    local player, link, number

    link = self:unformat(LOOT_ROLL_YOU_WON, msg)
    if link then
        self:RecordAwarded(link, me)
        return
    end

    player, link = self:unformat(LOOT_ROLL_WON, msg)
    if player then
        self:RecordAwarded(link, player)
        return
    end

    link = self:unformat(LOOT_ROLL_ALL_PASSED, msg)
    if link then
        self:RecordAwarded(link, "---")
        return
    end

    player, link = self:unformat(LOOT_ROLL_PASSED_AUTO, msg)
    if player then
        self:RecordChoice(link, player, "pass")
        return
    end

    player, link = self:unformat(LOOT_ROLL_PASSED_AUTO_FEMALE, msg)
    if player then
        self:RecordChoice(link, player, "pass")
        return
    end

    link = self:unformat(LOOT_ROLL_NEED_SELF, msg)
    if link then
        self:RecordChoice(link, me, "need")
        return
    end

    link = self:unformat(LOOT_ROLL_GREED_SELF, msg)
    if link then
        self:RecordChoice(link, me, "greed")
        return
    end

    link = self:unformat(LOOT_ROLL_PASSED_SELF, msg)
    if link then
        self:RecordChoice(link, me, "pass")
        return
    end

    link = self:unformat(LOOT_ROLL_PASSED_SELF_AUTO, msg)
    if link then
        self:RecordChoice(link, me, "pass")
        return
    end

    player, link = self:unformat(LOOT_ROLL_NEED, msg)
    if player then
        self:RecordChoice(link, player, "need")
        return
    end

    player, link = self:unformat(LOOT_ROLL_GREED, msg)
    if player then
        self:RecordChoice(link, player, "greed")
        return
    end

    player, link = self:unformat(LOOT_ROLL_PASSED, msg)
    if player then
        self:RecordChoice(link, player, "pass")
        return
    end

    number, link, player = self:unformat(LOOT_ROLL_ROLLED_NEED, msg)
    if number then
        self:RecordRoll(link, player, number)
        return
    end

    number, link, player = self:unformat(LOOT_ROLL_ROLLED_GREED, msg)
    if number then
        self:RecordRoll(link, player, number)
        return
    end

    link = self:unformat(LOOT_ITEM_PUSHED_SELF, msg)
    if link then
        self:RecordReceived(link, me)
        return
    end

    link, number = self:unformat(LOOT_ITEM_PUSHED_SELF_MULTIPLE, msg)
    if link then
        self:RecordReceived(link, me)
        return
    end

    link = self:unformat(LOOT_ITEM_SELF, msg)
    if link then
        self:RecordReceived(link, me)
        return
    end

    link, number = self:unformat(LOOT_ITEM_SELF_MULTIPLE, msg)
    if link then
        self:RecordReceived(link, me)
        return
    end

    player, link = self:unformat(LOOT_ITEM, msg)
    if player then
        self:RecordReceived(link, player)
        return
    end

    player, link, number = self:unformat(LOOT_ITEM_MULTIPLE, msg)
    if player then
        self:RecordReceived(link, player)
        return
    end

    -- To handle new disenchant rules
    link = self:unformat(LOOT_ROLL_DISENCHANT_SELF, msg)
    if link then
        self:RecordChoice(link, me, "disenchant")
        return
    end

    player, link = self:unformat(LOOT_ROLL_DISENCHANT, msg)
    if link then
        self:RecordChoice(link, player, "disenchant")
        return
    end

    player, link = self:unformat(LOOT_ROLL_DISENCHANT, msg)
    if link then
        self:RecordChoice(link, player, "disenchant")
        return
    end

    number, link, player = self:unformat(LOOT_ROLL_ROLLED_DE, msg)
    if number then
        self:RecordRoll(link, player, number)
        return
    end
end

function NeedyGreedy:RecordChoice(link, player, choice)
    local _, _, quality = GetItemInfo(link)
    if quality < self.db.profile.quality then return end

    for rollid, record in pairs(items) do
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

    for rollid, record in pairs(items) do
        if record.assigned == "" and record.link == link then
            record.rolls[player] = number
            break
        end
    end
    self:UpdateReport()
end

function NeedyGreedy:RecordAwarded(link, player)
    local _, _, quality = GetItemInfo(link)
    if quality < self.db.profile.quality then return end

    for rollid, record in pairs(items) do
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
    for rollid, record in pairs(items) do
        if record.received == 0 and record.link == link then
            record.received = GetTime()
            match = true
            break
        end
    end

    if not match then
        -- For items with weird unique identifiers
        for rollid, record in pairs(items) do
            if record.received == 0 and record.itemID == itemIdFromLink(link) then
                record.received = GetTime()
                match = true
                break
            end
        end
    end

    if not match then
        for rollid, record in pairs(items) do
            -- Since players receive the results of the disenchant, we will never be
            -- able to match the link that triggered the received message against
            -- our list. However, we should cross disenchanted items that have been
            -- assigned off the list as we find them on the assumption that they
            -- would have automatically received the item anyway.
            if record.choices[player] == "disenchant" and record.assigned == player and record.received == 0 then
                record.received = GetTime()
            end
        end
    end

    self:UpdateReport()
end

function NeedyGreedy:ClearItems()
    wipe(items)
    wipe(nameList)
    self:RefreshTooltip()
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
    local count = NeedyGreedy:CountItems()
    report.firstItem = report.firstItem + self.db.profile.nItems
    if count == 0 then
        report.firstItem = 1
    elseif report.firstItem > count then
        report.firstItem = count
    end
    self:UpdateReport()
end

function NeedyGreedy:GetSortedPlayers()
    local list = {}

    if GetNumRaidMembers() > 0 then
        for i = 1,MAX_RAID_MEMBERS do
            name = GetRaidRosterInfo(i)
            if name then
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
        for _, item in pairs(items) do
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
    -- Derived by hand from RAID_CLASS_COLORS because deriving it in lua seemed tricky
    -- Might not be that hard: str_format("%02x%02x%02x", r * 255, g * 255, b * 255)
    local map = {
        HUNTER = "|c00ABD473",
        WARLOCK = "|c009482C9",
        PRIEST = "|c00FFFFFF",
        PALADIN = "|c00F58CBA",
        MAGE = "|c0069CCF0",
        ROGUE = "|c00FFF569",
        DRUID = "|c00FF7D0A",
        SHAMAN = "|c002459FF",
        WARRIOR = "|c00C79C6E",
        DEATHKNIGHT = "|c00C41F3A"
    }
    local _, class = UnitClass(name)
    local color

    if class then
        color = map[class]
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

function NeedyGreedy:RollText(number)
    if number then
        return " - " .. number
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

-- Return a list of rollids ordered from most recent to least recent
function NeedyGreedy:SortRollids()
    local rollids = {}
    for rollid, _ in pairs(items) do
        table.insert(rollids, rollid)
    end
    table.sort(rollids, function(a, b) return a > b end)
    return rollids
end

function NeedyGreedy:CountItems()
    local i = 0
    for _, _ in pairs(items) do
        i = i + 1
    end
    return i
end

function NeedyGreedy:ExpireItems()
    local now = GetTime()
    local update = false

    if self.db.profile.expiry == 0 then
        return
    end
    for rollid, record in pairs(items) do
        if record.received > 0 and now - record.received >= self.db.profile.expiry * 60 then
            items[rollid] = nil
            wipe(nameList)
            update = true
        end
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
    if detachedTooltip then
        self.db.profile.displayDetached = true
        self:ShowDetachedTooltip()
    else
        self.db.profile.displayDetached = false
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

function NeedyGreedy:GetOnlyShowInParty(info)
    return self.db.profile.onlyShowInParty
end

function NeedyGreedy:SetOnlyShowInParty(info, onlyShowInParty)
    self.db.profile.onlyShowInParty = onlyShowInParty
    self:RefreshTooltip()
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



-- Detachable QTip Frames
local LibQTip = LibStub('LibQTip-1.0')

function NeedyGreedy:ShowDetachedTooltip()
    if not self:DisplayRollTableCheck() then return end

    -- Acquire a tooltip
    self.detachedTooltip = LibQTip:Acquire("NeedyGreedyReport", 1, "LEFT")

    -- Add columns here because tooltip:Clear() preserves columns
    for i = 1, self.db.profile.nItems do
        self.detachedTooltip:AddColumn("LEFT")
    end

    -- Add two columns for left and right buttons if detached
    if self.db.profile.detachedTooltip then
        self.detachedTooltip:AddColumn("RIGHT")
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
        self.detachedTooltip:SetScript("OnMouseDown", function() self.detachedTooltip:StartMoving() end)
        self.detachedTooltip:SetScript("OnMouseUp", function()
            -- Make it remember
            self.detachedTooltip:StopMovingOrSizing()
            local anchor1, _, anchor2, x, y = self.detachedTooltip:GetPoint()
            self.db.profile.reportFramePos.anchor1 = anchor1
            self.db.profile.reportFramePos.anchor2 = anchor2
            self.db.profile.reportFramePos.x = x
            self.db.profile.reportFramePos.y = y
        end)
    end

    -- Show it, et voilà !
    self.detachedTooltip:Show()
end

function NeedyGreedy:HideDetachedTooltip()
    if self.detachedTooltip then
        self.detachedTooltip:Hide()
        LibQTip:Release(self.detachedTooltip)
        self.detachedTooltip = nil
    end
end

function NeedyGreedy:ShowDBTooltip(frame)
    -- Acquire a tooltip
    self.dbTooltip = LibQTip:Acquire("NeedyGreedyDBReport", 1, "LEFT")

    if not self.db.profile.detachedTooltip then
        if self:DisplayRollTableCheck() then
            -- Add columns here because tooltip:Clear() preserves columns
            for i = 1, self.db.profile.nItems do
                self.dbTooltip:AddColumn("LEFT")
            end

            -- Fill in the info
            self:BuildDBReportTooltip(self.dbTooltip)
        end
    else

        self:AddHeaderText(self.dbTooltip)
        self:AddInfoText(self.dbTooltip)
    end

    if frame then self.dbTooltip:SmartAnchorTo(frame) end

    -- Show it, et voilà !
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

    -- Verify that report.firstItem is set reasonably
    local sorted = self:SortRollids()
    local count = self:CountItems()

    if not(report.firstItem) then report.firstItem = 1 end
    if count == 0 then
        report.firstItem = 1
    elseif report.firstItem > count then
        report.firstItem = count
    end

    -- Create icon headers
    local headerline, _ = tooltip:AddLine("")
    for i = 1, nItems do
        local index = report.firstItem + i - 1
        local texture = ""
        local item = nil
        if index <= count then
            local rollID = sorted[index]
            item = items[rollID]
            texture = "|T" .. item.texture .. ":40|t"
        end
        tooltip:SetCell(headerline, i + 1, texture, nil, "CENTER", nil, nil, nil, nil, nil, 60)
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

    -- Now add item link names
    if self.db.profile.displayTextLink then
        headerline, _ = tooltip:AddLine("")
        for i = 1, nItems do
            local index = report.firstItem + i - 1
            local text = ""
            local item = nil
            if index <= count then
                local rollID = sorted[index]
                item = items[rollID]
                text= item.link
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
    for i, name in ipairs(players) do
        local partyLine = tooltip:AddLine("")
        tooltip:SetCell(partyLine, 1, self:ColorizeName(name) .. " " .. (self.db.profile.displayIcons and BLANK_ICON or ""), nil, "LEFT", nil, nil, nil, nil, nil, 100)

        for i = 1, nItems do
            local index = report.firstItem + i - 1
            if index <= count then
                local rollID = sorted[index]
                local item = items[rollID]
                tooltip:SetCell(partyLine, i + 1, self:ChoiceText(item.choices[name]) .. self:RollText(item.rolls[name]), nil, "LEFT", nil, nil, nil, nil, nil, 60)
            end
        end
    end

    tooltip:AddSeparator()

    -- Display winner
    local winnerTable = {yC .. "Winner|r"}
    for i = 1, nItems do
        local index = report.firstItem + i - 1
        if index <= count then
            local rollID = sorted[index]
            local item = items[rollID]
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
    local count = self:CountItems()

    local lineNum, _ = tooltip:AddLine("")
    local colNum = nItems + 2

    if report.firstItem > 1 then
        tooltip:SetCell(lineNum, colNum, PAGER_ICONS.leftUp)
        tooltip:SetCellScript(lineNum, colNum, "OnMouseUp", function() self:PageLeft() end)
    else
        tooltip:SetCell(lineNum, colNum, PAGER_ICONS.leftDisabled)
    end

    if report.firstItem + nItems - 1 < count then
        tooltip:SetCell(lineNum, colNum + 1, PAGER_ICONS.rightUp)
        tooltip:SetCellScript(lineNum, colNum + 1, "OnMouseUp", function() self:PageRight() end)
    else
        tooltip:SetCell(lineNum, colNum + 1, PAGER_ICONS.rightDisabled)
    end

    -- Set the page # text
    local pageText = ""
    if nItems == 1 then
        pageText = tostring(report.firstItem)
    elseif count == 0 then
        pageText = L["None"]
    elseif count == 1 or report.firstItem == count then
        pageText = string.format(L["%d of %d"], report.firstItem, count)
    else
        local lastitem = report.firstItem + nItems - 1
        if (lastitem > count) then
            lastitem = count
        end
        pageText = string.format(L["%d-%d of %d"], report.firstItem, lastitem, count)
    end

    tooltip:SetCell(lineNum, colNum - 1, yC .. pageText)
end

function NeedyGreedy:AddInfoText(tooltip)
    local lineNum
    local helpText

    if self.db.profile.onlyShowInParty and not self:CheckOnlyShowInParty() then
        lineNum = tooltip:AddLine()
        tooltip:SetCell(lineNum, 1, L["You are not in a party"], nil, tooltip:GetColumnCount())
    end

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
    self:PopulateReportTooltip(tooltip)
    self:AddInfoText(tooltip)
end

function NeedyGreedy:UpdateReport()
    local tooltip = nil
    if self.detachedTooltip and self.detachedTooltip:IsShown() then
        self:BuildDetachedTooltip(self.detachedTooltip)
    elseif self.dbTooltip and self.dbTooltip:IsShown() and (not self.db.profile.detachedTooltip) then
        self:BuildDBReportTooltip(self.dbTooltip)
    else
        return
    end
end

function NeedyGreedy:RefreshTooltip()
    if self.db.profile.detachedTooltip and self.db.profile.displayDetached then
        self:HideDetachedTooltip()
        self:ShowDetachedTooltip()
    end
    self:HideDBTooltip()
end

function NeedyGreedy:ToggleDisplay()
    if not self.db.profile.detachedTooltip then return end

    if self.db.profile.displayDetached then
        self:HideDetachedTooltip()
    else
        self:ShowDetachedTooltip()
    end

    self.db.profile.displayDetached = not self.db.profile.displayDetached
end

function NeedyGreedy:DisplayRollTableCheck()
    if self:CheckOnlyShowInParty() and self:CheckShowInCombat() then
        return true
    end

    return false
end

function NeedyGreedy:CheckOnlyShowInParty()
    if self.db.profile.onlyShowInParty and (GetNumPartyMembers() == 0) then
        return false
    end

    return true
end

function NeedyGreedy:CheckShowInCombat()
    if self.db.profile.hideInCombat and IS_IN_COMBAT then
        return false
    end

    return true
end



-- Chat filter functions
local FILTER_CHAT_LOOT_MSGS = {
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
    --LOOT_ROLL_WON,
    --LOOT_ROLL_YOU_WON,
    --LOOT_ITEM,
    --LOOT_ITEM_MULTIPLE,
    --LOOT_ITEM_PUSHED_SELF,
    --LOOT_ITEM_PUSHED_SELF_MULTIPLE,
    --LOOT_ITEM_SELF,
    --LOOT_ITEM_SELF_MULTIPLE,
}

local function FilterLootMsg(ChatFrameSelf, event, ...)
    local msg = arg1
    for _, string in ipairs(FILTER_CHAT_LOOT_MSGS) do
        local match = NeedyGreedy:unformat(string, msg)
        if match then
            return true
        end
    end

    return false, msg, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11
end

function NeedyGreedy:EnableChatFilter()
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



-- Console commands
function NeedyGreedy:ProcessSlashCommands(input)
    if input == "report" then
        self:PrintReport()
    elseif input == "config" then
        InterfaceOptionsFrame_OpenToCategory("NeedyGreedy")
    else
        self:Print(L["Valid commands are: config, report"])
    end
end

function NeedyGreedy:PrintReport()
    if #items == 0 then self:Print(L["Nothing to report"]) return end
    local output = {}

    for rollID, item in pairs(items) do
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



-- Unit tests
--[[
function NeedyGreedy:SetItems(itemList)
    items = itemList
    self:UpdateReport()
end

function NeedyGreedy:TestItemList()
    items = {
        nil, -- [1]
        nil, -- [2]
        nil, -- [3]
        nil, -- [4]
        nil, -- [5]
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
    self:UpdateReport()
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
