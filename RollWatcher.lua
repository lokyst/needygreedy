RollWatcher = LibStub("AceAddon-3.0"):NewAddon("RollWatcher", "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")

LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject("RollWatcher", {
          type = "launcher",
          icon = "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
          OnClick = function(clickedframe, button)
                     RollWatcher:ToggleDisplay()
          end,
})

local fontsize = 12
local iconheight = 40
local report = nil
local items = {}

local options = {
    name = "RollWatcher",
    desc = "Displays a table of items and the roll choices players have made on them",
    handler = RollWatcher,
    type = "group",
    args = {
        nitems = {
            name = "Display Items",
            desc = "Number of item columns in the display window",
            type = "range",
            min = 1,
            max = 10,
            step = 1,
            get = "GetNItems",
            set = "SetNItems"
        },
        width = {
            name = "Namelist Width",
            desc = "Pixel width of columns containing names (increase if your raid has very long names)",
            type = "range",
            min = 80,
            max = 250,
            step = 1,
            get = "GetNameListWidth",
            set = "SetNameListWidth"
        },
        scale = {
            name = "Window Scale",
            desc = "Overall scaling of the display window",
            type = "range",
            min = 0.1,
            max = 2,
            step = 0.01,
            isPercent = true,
            get = "GetWindowScale",
            set = "SetWindowScale"
        },
        expiry = {
            name = "Expiry Time",
            desc = "Minutes after item is received before it is removed from display (0 = forever)",
            type = "range",
            min = 0,
            max = 60,
            step = 1,
            get = "GetExpiry",
            set = "SetExpiry"
        },
        quality = {
            name = "Minimum Quality",
            desc = "Minimum quality of item to be displayed",
            type = "select",
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
            name = "Display Icons",
            desc = "Display icons for rolls types instead of text strings",
            type = "toggle",
            get = "GetDisplayIcons",
            set = "SetDisplayIcons",
        }
    }
}

local defaults = {
    profile = {
        nitems = 2,
        namelistwidth = 100,
        scale = 1,
        expiry = 5,
        quality = ITEM_QUALITY_EPIC,
        displayIcons = false,
    }
}

local iconSize = 27
local ROLLWATCHER_CHOICE = {
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

function RollWatcher:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("RollWatcherDB", defaults, true)
    self.db.RegisterCallback(self, "OnProfileChanged", "ResizeFrames")
    self.db.RegisterCallback(self, "OnProfileCopied", "ResizeFrames")
    self.db.RegisterCallback(self, "OnProfileReset", "ResizeFrames")
    options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
    LibStub("AceConfig-3.0"):RegisterOptionsTable("RollWatcher", options)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions("RollWatcher")
    self:RegisterChatCommand("rwt", "TestItemList")
    self:RegisterChatCommand("rollwatcher", function() InterfaceOptionsFrame_OpenToCategory("RollWatcher") end)
    self:SetupFrames()
end

function RollWatcher:OnEnable()
    self:RegisterEvent("PARTY_MEMBERS_CHANGED")
    self:RegisterEvent("START_LOOT_ROLL")
    self:RegisterEvent("CHAT_MSG_LOOT")
    self:ScheduleRepeatingTimer("ExpireItems", 1)
    self:UpdateReport()
end

function RollWatcher:OnDisable()
    report:hide()
end

function RollWatcher:ToggleDisplay()
    if self.tooltip then
        self:HideReportFrame()
    else
        self:ShowReportFrame()
    end
end

function RollWatcher:PARTY_MEMBERS_CHANGED()
    self:ResizeFrames()
end

function RollWatcher:START_LOOT_ROLL(event, rollid)
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

function RollWatcher:CHAT_MSG_LOOT(event, msg)
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
        self:RecordReceived(link)
        return
    end

    link, number = self:unformat(LOOT_ITEM_PUSHED_SELF_MULTIPLE, msg)
    if link then
        self:RecordReceived(link)
        return
    end

    link = self:unformat(LOOT_ITEM_SELF, msg)
    if link then
        self:RecordReceived(link)
        return
    end

    link, number = self:unformat(LOOT_ITEM_SELF_MULTIPLE, msg)
    if link then
        self:RecordReceived(link)
        return
    end

    player, link = self:unformat(LOOT_ITEM, msg)
    if player then
        self:RecordReceived(link)
        return
    end

    player, link, number = self:unformat(LOOT_ITEM_MULTIPLE, msg)
    if player then
        self:RecordReceived(link)
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

function RollWatcher:RecordChoice(link, player, choice)
    for rollid, record in pairs(items) do
        if record.assigned == "" and record.link == link then
            record.choices[player] = choice
            break
        end
    end
    self:UpdateReport()
end

function RollWatcher:RecordRoll(link, player, number)
    for rollid, record in pairs(items) do
        if record.assigned == "" and record.link == link then
            record.rolls[player] = number
            break
        end
    end
    self:UpdateReport()
end

function RollWatcher:RecordAwarded(link, player)
    for rollid, record in pairs(items) do
        if record.assigned == "" and record.link == link then
            record.assigned = player
            break
        end
    end
    self:UpdateReport()
end

function RollWatcher:RecordReceived(link)
    for rollid, record in pairs(items) do
        if record.received == 0 and record.link == link then
            record.received = GetTime()
            break
        end
    end
    self:UpdateReport()
end

function RollWatcher:SetupFrames()
    local f = GameFontNormal:GetFont()
    local spacing = 5

    -- Create outer frame with backdrop
    report = CreateFrame("Frame", "RollWatcherFrame", UIParent)
    report:Hide()
    self:SetupSizes()
    report:SetToplevel(true)
    report:SetWidth(report.totalwidth)
    report:SetHeight(report.totalheight)
    report:SetScale(self.db.profile.scale)
    report:EnableMouse(true)
    report:SetMovable(true)
    report:RegisterForDrag("LeftButton")
    report:SetScript("OnDragStart", function() this:StartMoving() end)
    report:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

    -- QTip Shiz
    report:SetScript('OnEnter', anchor_OnEnter)
    report:SetScript('OnLeave', anchor_OnLeave)

    report:SetBackdrop({
                                 bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", tile = true, tileSize = 16,
                                 edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,
                                 insets = {left = 4, right = 4, top = 4, bottom = 4},
                             })
    report:SetBackdropBorderColor(.5, .5, .5)
    report:SetBackdropColor(0,0,0)
    report:ClearAllPoints()
    report:SetPoint("CENTER")

    -- Create player namelist, anchored to outer frame with room at top for icons
    local namelist = report:CreateFontString(nil, "OVERLAY")
    namelist:SetFont(f, fontsize)
    namelist:SetWidth(self.db.profile.namelistwidth)
    namelist:SetHeight(report.namelistheight)
    namelist:SetJustifyV("TOP")
    namelist:SetJustifyH("LEFT")
    namelist:SetText("")
    namelist:ClearAllPoints()
    namelist:SetPoint("TOPLEFT", report, "TOPLEFT", report.spacing, -(report.spacing * 2 + iconheight))
    report.namelist = namelist

    -- Create invisible frame around choice lists, for anchoring purposes
    local itemgroup = CreateFrame("Frame", nil, report)
    itemgroup:SetWidth(self.db.profile.nitems * (self.db.profile.namelistwidth + report.spacing) - report.spacing)
    itemgroup:SetHeight(report.namelistheight)
    itemgroup:ClearAllPoints()
    itemgroup:SetPoint("TOPLEFT", namelist, "TOPRIGHT", report.spacing, 0)
    report.itemgroup = itemgroup

    -- Create icons and choice lists for each item column
    report.choices = {}
    report.icons = {}
    for i = 1,self.db.profile.nitems do
        self:SetupItemFrames(i)
    end

    -- Create text at bottom and page buttons
    local bottomtext = report:CreateFontString(nil, "OVERLAY")
    bottomtext:SetFont(f, fontsize)
    bottomtext:SetWidth(report.bottomtextwidth)
    bottomtext:SetText("")
    bottomtext:ClearAllPoints()
    bottomtext:SetPoint("TOP", itemgroup, "BOTTOM", 0, -report.spacing)
    report.bottomtext = bottomtext

    local leftbutton = CreateFrame("Button", nil, report)
    leftbutton:SetWidth(32)
    leftbutton:SetHeight(32)
    leftbutton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    leftbutton:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    leftbutton:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled")
    leftbutton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    leftbutton:ClearAllPoints()
    leftbutton:SetPoint("RIGHT", bottomtext, "LEFT", -report.spacing, 0)
    leftbutton:SetScript("OnClick", function() self:PageLeft() end)
    report.leftbutton = leftbutton

    local rightbutton = CreateFrame("Button", nil, report)
    rightbutton:SetWidth(32)
    rightbutton:SetHeight(32)
    rightbutton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    rightbutton:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    rightbutton:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled")
    rightbutton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    rightbutton:ClearAllPoints()
    rightbutton:SetPoint("LEFT", bottomtext, "RIGHT", report.spacing, 0)
    rightbutton:SetScript("OnClick", function() self:PageRight() end)
    report.rightbutton = rightbutton

    report.firstitem = 1
end

function RollWatcher:ResizeFrames()
    self:SetupSizes()
    report:SetWidth(report.totalwidth)
    report:SetHeight(report.totalheight)
    report.namelist:SetWidth(self.db.profile.namelistwidth)
    report.namelist:SetHeight(report.namelistheight)
    report.itemgroup:SetWidth(self.db.profile.nitems * (self.db.profile.namelistwidth + report.spacing) - report.spacing)
    report.itemgroup:SetHeight(report.namelistheight)
    report.bottomtext:SetWidth(report.bottomtextwidth)
    for i = 1, self.db.profile.nitems do
        if not report.choices[i] then
            self:SetupItemFrames(i)
        else
            local choices = report.choices[i]
            choices:SetWidth(self.db.profile.namelistwidth)
            choices:SetHeight(report.namelistheight)
            choices:ClearAllPoints()
            choices:SetPoint("TOPLEFT", report.itemgroup, "TOPLEFT", (i - 1) * (self.db.profile.namelistwidth + report.spacing), 0)
        end
    end
    -- Hide any extra item frames we might have
    for i = self.db.profile.nitems + 1, table.maxn(report.choices) do
        report.choices[i]:Hide()
        report.icons[i]:Hide()
    end
    self:UpdateReport()
end

function RollWatcher:SetupItemFrames(i)
    local f = GameFontNormal:GetFont()
    local choices = report.itemgroup:CreateFontString(nil, "OVERLAY")

    choices:SetFont(f, fontsize)
    choices:SetWidth(self.db.profile.namelistwidth)
    choices:SetHeight(report.namelistheight)
    choices:SetJustifyV("TOP")
    choices:SetJustifyH("LEFT")
    choices:SetText("")
    choices:ClearAllPoints()
    choices:SetPoint("TOPLEFT", report.itemgroup, "TOPLEFT", (i - 1) * (self.db.profile.namelistwidth + report.spacing), 0)
    report.choices[i] = choices

    local icon = CreateFrame("Button", "RollWatcherIcon" .. i, report.itemgroup, "ItemButtonTemplate")
    icon:ClearAllPoints()
    icon:SetPoint("BOTTOMLEFT", choices, "TOPLEFT", 0, report.spacing)
    icon:Hide()
    icon:SetScript("OnEnter", function() self:IconEntered(i) end)
    icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    icon:SetScript("OnClick", function() self:IconClicked(i) end)
    report.icons[i] = icon
end

function RollWatcher:IconEntered(i)
    local sorted = self:SortRollids()
    local count = self:CountItems()
    local ind = report.firstitem + i - 1

    if ind <= count then
        local rollid = sorted[ind]
        GameTooltip:SetOwner(report.icons[i], "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(items[rollid].link)
    end
end

function RollWatcher:IconClicked(i)
    local sorted = self:SortRollids()
    local count = self:CountItems()
    local ind = report.firstitem + i - 1

    if ind <= count then
        local rollid = sorted[ind]
        if (IsControlKeyDown()) then
            items[rollid] = nil
            self:UpdateReport()
            self:IconEntered(i)
        else
            HandleModifiedItemClick(items[rollid].link)
        end
    end
end

-- Compute sizes based on the number of players in the party/raid
function RollWatcher:SetupSizes()
    local nplayers = self:GetNumPlayers()

    report.namelistheight = (nplayers + 2) * fontsize + 5 -- font sizes aren't quite integers; leave some wiggle room
    report.spacing = 10
    report.totalwidth = report.spacing + (self.db.profile.nitems + 1) * (self.db.profile.namelistwidth + report.spacing)
    report.totalheight = report.spacing * 4 + iconheight + report.namelistheight + fontsize
    if self.db.profile.nitems == 1 then
        report.bottomtextwidth = 10
    else
        report.bottomtextwidth = self.db.profile.namelistwidth
    end
end

function RollWatcher:PageLeft()
    report.firstitem = report.firstitem - self.db.profile.nitems
    if report.firstitem < 1 then
        report.firstitem = 1
    end
    self:UpdateReport()
end

function RollWatcher:PageRight()
    local count = RollWatcher:CountItems()
    report.firstitem = report.firstitem + self.db.profile.nitems
    if count == 0 then
        report.firstitem = 1
    elseif report.firstitem > count then
        report.firstitem = count
    end
    self:UpdateReport()
end

function RollWatcher:GetSortedPlayers()
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

function RollWatcher:GetNumPlayers()
    local nraid = GetNumRaidMembers()
    if nraid > 0 then
        return nraid
    else
        return GetNumPartyMembers() + 1
    end
end

function RollWatcher:ColorizeName(name)
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

function RollWatcher:ChoiceText(choice)
    local style = "string"
    if self.db.profile.displayIcons == true then style = "icon" end

    if choice then
          if ROLLWATCHER_CHOICE[choice][style] then
              return ROLLWATCHER_CHOICE[choice][style]
          end
    end
    return ""
end

function RollWatcher:RollText(number)
    if number then
        return " " .. number
    else
        return ""
    end
end

function RollWatcher:AssignedText(item)
    if item.received == 0 then
        return "|c00FF0000" .. item.assigned .. "|r"
    else
        return "|c0000FF00" .. item.assigned .. "|r"
    end
end

-- Return a list of rollids ordered from most recent to least recent
function RollWatcher:SortRollids()
    local rollids = {}
    for rollid, _ in pairs(items) do
        table.insert(rollids, rollid)
    end
    table.sort(rollids, function(a, b) return a > b end)
    return rollids
end

function RollWatcher:CountItems()
    local i = 0
    for _, _ in pairs(items) do
        i = i + 1
    end
    return i
end

function RollWatcher:UpdateReport()
    if self.tooltip and self.tooltip:IsShown() then
        self:PopulateReportTooltip()
    end

    local players = self:GetSortedPlayers()

    -- Place name list into report.namelist
    local text = ""
    for _, name in ipairs(players) do
        text = text .. self:ColorizeName(name) .. "\n"
    end
    text = text .. "\nWinner"
    report.namelist:SetText(text)

    -- Verify that report.firstitem is set reasonably
    local sorted = self:SortRollids()
    local count = self:CountItems()
    if count == 0 then
        report.firstitem = 1
    elseif report.firstitem > count then
        report.firstitem = count
    end

    -- Fill in each item frame
    for i = 1, self.db.profile.nitems do
        local ind = report.firstitem + i - 1
        if ind <= count then
            local rollid = sorted[ind]
            local item = items[rollid]

            SetItemButtonTexture(report.icons[i], item.texture)
            report.icons[i]:Show()
            text = ""
            for _, name in ipairs(players) do
                text = text .. self:ChoiceText(item.choices[name]) .. self:RollText(item.rolls[name]) .. "\n"
            end
            text = text .. "\n" .. self:AssignedText(item)
            report.choices[i]:SetText(text)
        else
            report.icons[i]:Hide()
            report.choices[i]:SetText("")
        end
    end

    -- Set the text at the bottom
    if self.db.profile.nitems == 1 then
        report.bottomtext:SetText(tostring(report.firstitem))
    elseif count == 0 then
        report.bottomtext:SetText("None")
    elseif count == 1 or report.firstitem == count then
        report.bottomtext:SetText(string.format("%d of %d", report.firstitem, count))
    else
        local lastitem = report.firstitem + self.db.profile.nitems - 1
        if (lastitem > count) then
            lastitem = count
        end
        report.bottomtext:SetText(string.format("%d-%d of %d", report.firstitem, lastitem, count))
    end

    -- Enable or disable the page buttons
    if report.firstitem > 1 then
        report.leftbutton:Enable()
    else
        report.leftbutton:Disable()
    end
    if report.firstitem + self.db.profile.nitems - 1 < count then
        report.rightbutton:Enable()
    else
        report.rightbutton:Disable()
    end
end

function RollWatcher:ExpireItems()
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

function RollWatcher:unformat(fmt, msg)
    local pattern = string.gsub(string.gsub(fmt, "(%%s)", "(.+)"), "(%%d)", "(.+)")
    local _, _, a1, a2, a3, a4 = string.find(msg, pattern)
    return a1, a2, a3, a4
end

-- Config option getters and setters

function RollWatcher:GetNItems(info)
    return self.db.profile.nitems
end

function RollWatcher:SetNItems(info, nitems)
    self.db.profile.nitems = nitems
    self:ResizeFrames()
end

function RollWatcher:GetNameListWidth(info)
    return self.db.profile.namelistwidth
end

function RollWatcher:SetNameListWidth(info, width)
    self.db.profile.namelistwidth = width
    self:ResizeFrames()
end

function RollWatcher:GetWindowScale(info)
    return self.db.profile.scale
end

function RollWatcher:SetWindowScale(info, scale)
    self.db.profile.scale = scale
    report:SetScale(scale)
end

function RollWatcher:GetExpiry(info)
    return self.db.profile.expiry
end

function RollWatcher:SetExpiry(info, expiry)
    self.db.profile.expiry = expiry
    self:ExpireItems()
end

function RollWatcher:GetQuality(info)
    return self.db.profile.quality
end

function RollWatcher:SetQuality(info, quality)
    self.db.profile.quality = quality
end

function RollWatcher:GetDisplayIcons(info)
    return self.db.profile.displayIcons
end

function RollWatcher:SetDisplayIcons(info, displayIcons)
    self.db.profile.displayIcons = displayIcons
    self:UpdateReport()
end


-- Detachable QTip Frames
local LibQTip = LibStub('LibQTip-1.0')

function RollWatcher:ShowReportFrame()
    -- Acquire a tooltip
    self.tooltip = LibQTip:Acquire("RollWatcherReport", 1, "LEFT")

    -- Add columns here because tooltip:Clear() preserves columns
    for i = 1, self.db.profile.nitems do
        self.tooltip:AddColumn("LEFT")
    end

    RollWatcher:PopulateReportTooltip()

    -- To make tooltip detached
    self.tooltip:ClearAllPoints()
    self.tooltip:SetFrameStrata("FULLSCREEN")
    self.tooltip:EnableMouse(true)
    self.tooltip:SetResizable(true)
    self.tooltip:SetFrameLevel(1)
    self.tooltip:SetMovable(true)
    self.tooltip:SetClampedToScreen(true)

    if not self.db.profile.reportFramePos then
        self.db.profile.reportFramePos = {
            anchor1 = "CENTER",
            anchor2 = "CENTER",
            x = 0,
            y = 0
        }
    end
    self.tooltip:SetPoint(self.db.profile.reportFramePos.anchor1, nil, self.db.profile.reportFramePos.anchor2, self.db.profile.reportFramePos.x, self.db.profile.reportFramePos.y)

    -- Make it move !
    self.tooltip:SetScript("OnMouseDown", function() self.tooltip:StartMoving() end)
    self.tooltip:SetScript("OnMouseUp", function()
        -- Make it remember
        self.tooltip:StopMovingOrSizing()
        local anchor1, _, anchor2, x, y = self.tooltip:GetPoint()
        self.db.profile.reportFramePos.anchor1 = anchor1
        self.db.profile.reportFramePos.anchor2 = anchor2
        self.db.profile.reportFramePos.x = x
        self.db.profile.reportFramePos.y = y
    end)

    -- Show it, et voilà !
    self.tooltip:Show()
end

function RollWatcher:HideReportFrame()
    self.tooltip:Hide()
    LibQTip:Release(self.tooltip)
    self.tooltip = nil
end

function RollWatcher:PopulateReportTooltip()
    self.tooltip:Clear()

    local players = self:GetSortedPlayers()

    -- Verify that report.firstitem is set reasonably
    local sorted = self:SortRollids()
    local count = self:CountItems()
    local firstItem = 0

    if firstItem > count then
        firstItem = count
    elseif firstItem == 0 then
        firstItem = 1
    else
        firstItem = 0
    end

    -- Create header table
    local itemHeaders = {"Party"}
    local itemSpacer = {""}
    for i = 1, self.db.profile.nitems do
        local index = firstItem + i - 1
        if index <= count then
            local rollID = sorted[index]
            local item = items[rollID]
            table.insert(itemHeaders, "|T" .. item.texture .. ":40|t")
            table.insert(itemSpacer, "")
        end
    end

    -- Set column width and add headers
    local lineNum, colNum
    lineNum, colNum = self.tooltip:AddHeader(unpack(itemSpacer))
    for i = 1, self.db.profile.nitems + 1  do
        self.tooltip:SetCell(lineNum, i, "", nil, nil, nil, nil, nil, nil, nil, 60)
    end
    self.tooltip:AddHeader(unpack(itemHeaders))

    self.tooltip:AddSeparator()

    -- Create table with party names and their rolls
    for i, name in ipairs(players) do
        local rollTable = {}
        table.insert(rollTable, self:ColorizeName(name))

        for i = 1, self.db.profile.nitems do
            local index = firstItem + i - 1
            if index <= count then
                local rollID = sorted[index]
                local item = items[rollID]
                table.insert(rollTable, self:ChoiceText(item.choices[name]) .. self:RollText(item.rolls[name]))
            end
        end

        self.tooltip:AddLine(unpack(rollTable))
    end

    self.tooltip:AddSeparator()
    --
    local winnerTable = {"Winner"}
    for i = 1, self.db.profile.nitems do
        local index = firstItem + i - 1
        if index <= count then
            local rollID = sorted[index]
            local item = items[rollID]
            table.insert(winnerTable, self:AssignedText(item))
        end
    end
    self.tooltip:AddLine(unpack(winnerTable))
end

function RollWatcher:TestItemList()
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
        choices = {Matsuri = "need", Lubov = "greed"},
        rolls = {Matsuri = "- 61", Lubov = "- 98"}
    }
    items[3] = {
        texture = "Interface\\Icons\\INV_Weapon_ShortBlade_06",
        link = "|cff0070dd|Hitem:2169:0:0:0:0:0:0:1016630800:80|h[Buzzer Blade]|h|r",
        assigned = "Matsuri",
        received = 15130,
        choices = {Emberly = "pass", Matsuri = "need"},
        rolls = {Emberly = "---", Matsuri = " - 42"}
    }
    self:UpdateReport()
end