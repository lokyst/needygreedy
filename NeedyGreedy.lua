NeedyGreedy = LibStub("AceAddon-3.0"):NewAddon("NeedyGreedy", "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale("NeedyGreedy", true)

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

local report = {}
local items = {}

-- Set up configuration window
local options = {
    name = L["NeedyGreedy"],
    desc = L["Displays a table of items and the roll choices players have made on them"],
    handler = NeedyGreedy,
    type = "group",
    args = {
        nItems = {
            name = L["Display Items"],
            desc = L["Number of item columns in the display window"],
            type = "range",
            order = 50,
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
            order = 60,
            min = 0,
            max = 60,
            step = 1,
            get = "GetExpiry",
            set = "SetExpiry"
        },
        quality = {
            name = L["Minimum Quality"],
            desc = L["Minimum quality of item to be displayed"],
            type = "select",
            order = 70,
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
            order = 40,
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
    }
}

-- Set profile defaults
local defaults = {
    profile = {
        nItems = 2,
        expiry = 5,
        quality = ITEM_QUALITY_EPIC,
        displayIcons = true,
        detachedTooltip = false,
        displayTextLink = false,
        displayDetached = false,
        minimap = { hide = false },
        filterLootMsgs = false,
    }
}

-- Icon textures for Need/Greed/Pass/DE
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
        ["icon"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:16|t",
    },
    ["disenchant"] = {
        ["string"] = "|c00FF00FF" .. ROLL_DISENCHANT .. "|r",
        ["icon"] = "|TInterface\\Buttons\\UI-GroupLoot-DE-Up:" .. iconSize .. "|t",
    }
}

-- Funky colors for text strings
local yC = "|cffFFCC00" -- Golden
local eC = "|cffEDA55F" -- Orange
local gC = "|cff00FF00" -- Green

-- For tracking original state of detailed loot information
local originalSpamFilterSetting = nil

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



-- Event handling functions
function NeedyGreedy:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("NeedyGreedyDB", defaults, true)
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshTooltip")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshTooltip")
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshTooltip")
    options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
    LibStub("AceConfig-3.0"):RegisterOptionsTable("NeedyGreedy", options)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions("NeedyGreedy")
    self:RegisterChatCommand("needygreedy", function() InterfaceOptionsFrame_OpenToCategory("NeedyGreedy") end)
    -- self:RegisterChatCommand("ngt", "TestItemList")
    -- self.items = items

    -- Register the minimap icon
    ngDBIcon:Register("NeedyGreedy", NeedyGreedyLDB, self.db.profile.minimap)
end

function NeedyGreedy:OnEnable()
    self:RegisterEvent("PARTY_MEMBERS_CHANGED")
    self:RegisterEvent("START_LOOT_ROLL")
    self:RegisterEvent("CHAT_MSG_LOOT")
    self:ScheduleRepeatingTimer("ExpireItems", 1)

    -- Delay frame display so that player does not show as offline
    self:RegisterEvent("PLAYER_ENTERING_WORLD")

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
    for rollid, record in pairs(items) do
        if record.assigned == "" and record.link == link then
            record.choices[player] = choice
            break
        end
    end
    self:UpdateReport()
end

function NeedyGreedy:RecordRoll(link, player, number)
    for rollid, record in pairs(items) do
        if record.assigned == "" and record.link == link then
            record.rolls[player] = number
            break
        end
    end
    self:UpdateReport()
end

function NeedyGreedy:RecordAwarded(link, player)
    for rollid, record in pairs(items) do
        if record.assigned == "" and record.link == link then
            record.assigned = player
            break
        end
    end
    self:UpdateReport()
end

function NeedyGreedy:RecordReceived(link, player)
    for rollid, record in pairs(items) do
        if record.received == 0 and record.link == link then
            record.received = GetTime()
            break
        end
        -- Since players receive disenchanted items not link
        if record.choices[player] == "disenchant" and record.assigned == player and record.received == 0 then
            record.received = GetTime()
        end
    end
    self:UpdateReport()
end

function NeedyGreedy:ClearItems()
    items = {}
    self:UpdateReport()
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
                table.insert(list, name)
            end
        end
    else
        for _, unit in ipairs({"player", "party1", "party2", "party3", "party4"}) do
            local name = UnitName(unit)
            if name then
                table.insert(list, name)
            end
        end
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



-- Detachable QTip Frames
local LibQTip = LibStub('LibQTip-1.0')

function NeedyGreedy:ShowDetachedTooltip()
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
    self:PopulateReportTooltip(self.detachedTooltip)

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
        -- Add columns here because tooltip:Clear() preserves columns
        for i = 1, self.db.profile.nItems do
            self.dbTooltip:AddColumn("LEFT")
        end

        -- Fill in the info
        self:PopulateReportTooltip(self.dbTooltip)

    else
        -- Fill in the info
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
    tooltip:Clear()

    self:AddHeaderText(tooltip)

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

    -- Create table with party names and their rolls
    for i, name in ipairs(players) do
        local rollTable = {}
        table.insert(rollTable, self:ColorizeName(name))

        for i = 1, nItems do
            local index = report.firstItem + i - 1
            if index <= count then
                local rollID = sorted[index]
                local item = items[rollID]
                table.insert(rollTable, self:ChoiceText(item.choices[name]) .. self:RollText(item.rolls[name]))
            end
        end

        tooltip:AddLine(unpack(rollTable))
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

    -- Display left and right arrows if frame is detached
    if self.db.profile.detachedTooltip then
        self:AddPagerArrows(tooltip)
    else
        self:AddInfoText(tooltip)
    end
end

function NeedyGreedy:AddHeaderText(tooltip)
    tooltip:AddHeader(yC .. "NeedyGreedy|r")
    tooltip:AddLine("")
end

function NeedyGreedy:AddPagerArrows(tooltip)
    local nItems = self.db.profile.nItems
    local count = self:CountItems()

    local lineNum, _ = tooltip:AddLine("")
    local colNum = nItems + 2

    if report.firstItem > 1 then
        tooltip:SetCell(lineNum, colNum, "|TInterface\\Buttons\\UI-SpellbookIcon-PrevPage-Up:" .. iconSize .. "|t")
        tooltip:SetCellScript(lineNum, colNum, "OnMouseUp", function() self:PageLeft() end)
    else
        tooltip:SetCell(lineNum, colNum, "|TInterface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled:" .. iconSize .. "|t")
    end

    if report.firstItem + nItems - 1 < count then
        tooltip:SetCell(lineNum, colNum + 1, "|TInterface\\Buttons\\UI-SpellbookIcon-NextPage-Up:" .. iconSize .. "|t")
        tooltip:SetCellScript(lineNum, colNum + 1, "OnMouseUp", function() self:PageRight() end)
    else
        tooltip:SetCell(lineNum, colNum + 1, "|TInterface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled:" .. iconSize .. "|t")
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
    local helpText = ""
    if self.db.profile.detachedTooltip then
        helpText = helpText .. eC .. L["Click"] .. "|r " .. gC .. L["to hide/show detached tooltip"] .. "|r"
    end
    helpText = helpText .. "\n" .. eC .. L["Shift-Click"] .. "|r " .. gC .. L["to attach/detach tooltip"] .. "|r"
    helpText = helpText .. "\n" .. eC .. L["Alt-Click"] .. "|r " .. gC .. L["to clear item list"] .. "|r"
    tooltip:AddLine("")
    local lineNum = tooltip:AddLine()
    tooltip:SetCell(lineNum, 1, helpText, nil, tooltip:GetColumnCount())
end

function NeedyGreedy:UpdateReport()
    local tooltip = nil
    if self.detachedTooltip and self.detachedTooltip:IsShown() then
        tooltip = self.detachedTooltip
    elseif self.dbTooltip and self.dbTooltip:IsShown() then
        tooltip = self.dbTooltip
    else
        return
    end
    self:PopulateReportTooltip(tooltip)
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



-- Chat filter functions
local filter = function() return true end
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



-- Unit tests
--[[
function NeedyGreedy:TestItemList()
    items[1] = {
        texture = "Interface\\Icons\\INV_Weapon_ShortBlade_04",
        link = "|cff0070dd|Hitem:2169:0:0:0:0:0:0:1016630800:80|h[Buzzer Blade]|h|r",
        assigned = "",
        received = 0,
        choices = {},
        rolls = {}
    }
    items[2] = {
        texture = "Interface\\Icons\\INV_Weapon_ShortBlade_05",
        link = "|cff0070dd|Hitem:2169:0:0:0:0:0:0:1016630800:80|h[Buzzer Blade]|h|r",
        assigned = "",
        received = 0,
        choices = {Matsuri = "disenchant", Lubov = "greed"},
        rolls = {Matsuri = "- 61", Lubov = "- 98"}
    }
    items[3] = {
        texture = "Interface\\Icons\\INV_Weapon_ShortBlade_06",
        link = "|cff0070dd|Hitem:2169:0:0:0:0:0:0:1016630800:80|h[Buzzer Blade]|h|r",
        assigned = "Matsuri",
        received = GetTime(),
        choices = {Shalii = "pass", Matsuri = "need"},
        rolls = {Shalii = "", Matsuri = " - 42"}
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
