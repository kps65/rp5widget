--{{{
--	RP5.RU weather informer for awesome version >= 3.5
--
--	parses HTML informer code for text forecasts
--	uses static images for wibox and tooltip
--	shows forecast in naughty notifications
--
--	customizable through rp5 parameters
--
--	default mouse bindings:
--		left = show complete set of forecast notifications
--		ctrl+left = open rp5.ru in brower for the location
--		right = force forecast refresh
--
--	TODO: (?) common button in the case of several locations
--
-- Licensed under GNU General Public License v2
--	(c) 2015 Konstantin Savov
--

--{ environment
local awful = require("awful")
local wibox = require("wibox")
local naughty = require("naughty")
--
-- to get printlog require("error_handlers") in rc.lua
if not printlog then printlog = print end
--}

--{{ module
--
local rp5 = {}
--
-- image cache
rp5.img = config.."/widgets/rp5/img/"
rp5.logo = rp5.img.."logo_48.png"

--{ rp5 api templates
-- forecast url template (html informer)
rp5.url = "'http://rp5.ru/htmla.php?id=%s&sc=%s'"
-- small icon url template (for wibox)
rp5.url_wibox = "'http://rp5.ru/informer/88x31x2.php?id=%s'"
-- 100x100 icon url template (nearest forecast)
rp5.url_tooltip = "'http://rp5.ru/informer/100x100x2.php?id=%s'"
-- open url in browser (template)
rp5.open_url = "firefox 'http://rp5.ru/%s/ru'"
--}

-- notification preset (naughty parameters)
rp5.preset = {
	timeout = 10,
	screen = awful.tag.getscreen(awful.tag.selected()),
	position = "bottom_left",
	font = beautiful.monofont or 'Droid Sans Mono 8',
	fg = beautiful.fg_widget or "#AECF96",
	bg = beautiful.bg_focus,
}

-- locations 
-- 	location = {id, name, forenum}
-- 	where
-- 		id - rp5 location id
-- 		name - location text name
-- 		forenum - number of forecast timesteps (up to 4)
--
-- 	the following parameters can be explicitely defined:
-- 		url - url to retrieve forecast
-- 		wibox_image - filename for wibox image
-- 		tooltip_image - filename for tooltip image
--
rp5.loc = { {}, }
--
--}}

--{ private data
--
-- download command
local cmd = "curl --connect-timeout 1 -fsm 3 "
-- current forecasts (up to 4 for every location)
local forecast = { } 
-- default number of forecasts
local forenum = 4
-- forecasts for widget tooltip (for every location)
local forecast_tt = {}
-- active notifications
local curnot, tip = {}, false
-- refresh timer
local rp5timer
-- destroy timer (clean notifications data when timeout > 0)
local dtimer
--
--}

--{{ helper functions
--
-- get rp5 forecast icon (stored in icons cache)
--
local get_icon = function(img)
	local imgfile

	-- get filename
	_,_,imgfile = string.find(img,'.+/(.-png)$')
	if imgfile then imgfile = rp5.img..imgfile
	else return false end

	-- download image
	if not awful.util.file_readable(imgfile) then
		os.execute(cmd.." -o "..imgfile.." '"..img.."'")
	end
	if not awful.util.file_readable(imgfile) then return false end

	return imgfile
end

-- close active forecast notifications
--
local destroy_all = function()
	-- clean current notifications
	if curnot then
		for ii = 1, #curnot do naughty.destroy(curnot[ii]) end
		curnot = {}
	end
	-- clean tooltip
	if tip then
		naughty.destroy(tip)
		tip = false
	end
	-- stop destroy timer
	if dtimer.started then dtimer:stop() end
end

-- get notification width
--
local get_width = function(ntf)
	local nn = naughty.notify(ntf)
	local width = nn.width
	naughty.destroy(nn)
	return width
end
--
--}}

--{{ location private functions
--
-- parse forecast html
--
local parse_data = function(loc,_data)
	local forecast = {}
	local fnum = 1

	-- title with logo
	forecast[fnum] = {
		preset = rp5.preset,
		icon = rp5.logo,
		title = loc.name,
		run = destroy_all,
	}
	-- get width
	local width = get_width(forecast[fnum])

	-- parse rp5 html forecast
	for time, img, txt in string.gmatch(_data,
	'<tr><td.->(.-)</td><td.-(http.-)%"><br>.-</td><td.->(.-)</td></tr>')
	do
		fnum = fnum + 1
		-- init forecast unit
		forecast[fnum] = {
			preset = rp5.preset,
			icon = nil,
			title = tostring(fnum),
			text = "",
			run = destroy_all,
		}
		-- get icon file
		local imgfile = get_icon(img)
		if imgfile then forecast[fnum].icon = imgfile end
		-- set forecast time
		time = string.gsub(time,"<b.->",", ")
		if time then forecast[fnum].title = time end
		-- set forecast text
		txt = string.gsub(txt,"<b.->","; ")
		if txt then forecast[fnum].text = txt end
		-- look for max width
		width = math.max(width,get_width(forecast[fnum]))
	end

	-- assign max width to all notifications
	for ii = 1, #forecast do forecast[ii].width = width end

	return forecast
end

-- refresh location forecast
--
local refresh_loc = function(loc)
	-- get image for widget
	if not os.execute(cmd.." -o "..loc.wibox_image.." "..
		string.format(rp5.url_wibox,loc.id))
	then printlog ("rp5: cannot get image 31") end
	if awful.util.file_readable(loc.wibox_image)
	then loc.widget:set_image(awesome.load_image(loc.wibox_image))
	else loc.widget:set_image(rp5.logo) end

	-- get image for notification
	if not os.execute(cmd.." -o "..loc.tooltip_image.." "..
		string.format(rp5.url_tooltip,loc.id))
	then printlog ("rp5: cannot get image 100") end

	-- get forecast data
	local _data = awful.util.pread(cmd..loc.url)
	if not _data then printlog ("rp5: cannot get data") end
	forecast[loc.id] = parse_data(loc,_data)

	printlog("rp5: refreshed id = "..loc.id)
end

-- init location data and widget
--
local init_widget = function(loc)
	-- forecast name
	if not loc.name then loc.name = "id = "..loc.id end
	-- forecast steps
	if not loc.forenum then loc.forenum = forenum end
	-- url for location
	if not loc.url then
		loc.url = rp5.url:format(loc.id,loc.forenum)
	end
	-- image names for location
	if not loc.wibox_image then
		loc.wibox_image = rp5.img..loc.id.."_31.png"
	end
	if not loc.tooltip_image then
		loc.tooltip_image = rp5.img..loc.id.."_100.png"
	end

	-- init imagebox
	loc.widget = wibox.widget.imagebox()
	if awful.util.file_readable(loc.wibox_image) then
		loc.widget:set_image(loc.wibox_image)
	else 
		loc.widget:set_image(rp5.logo)
	end

	-- forecast tooltip
	forecast_tt[loc.id] = {
		preset = rp5.preset,
		icon = loc.tooltip_image,
		title = loc.name,
	}

	-- show|hide tooltip on mouse events
	loc.widget:connect_signal("mouse::enter", function()
		if curnot[1] then return end
		tip = naughty.notify(forecast_tt[loc.id])
	end)
	loc.widget:connect_signal("mouse::leave", function() 
		naughty.destroy(tip)
		tip = false
	end)

	-- widget buttons
	loc.widget:buttons(awful.util.table.join(
		-- show complete set of forecast notifications
		awful.button({""}, 1, function() rp5.notify(loc.id) end),
		-- open url in browser
		awful.button({"Control"}, 1, function()
			os.execute(string.format(rp5.open_url,loc.id))
		end),
		-- force refresh
		awful.button({""}, 3, function() refresh_loc(loc) end)
	))

	return loc
end
--
--}}

--{{ public API
--
-- show forecast as naughty notifications
--
rp5.notify = function(id)
	if not id then id = 1 end
	local fc = forecast[id]
	if not fc then return false end

	-- close forecast shown
	destroy_all()
	-- show forecast notifications ordered from top to bottom
	local _spacing = naughty.config.spacing
	naughty.config.spacing = 0
	if string.match(rp5.preset.position,"bottom") then
		for ii = #fc, 1, -1 do
			curnot[ii] = naughty.notify(fc[ii])
		end
	else 
		for ii = 1, #fc do 
			curnot[ii] = naughty.notify(fc[ii])
		end
	end
	naughty.config.spacing = _spacing

	-- activate destroy timer, if needed
	if rp5.preset.timeout > 0 then dtimer:start() end
end

-- refresh all locations
--
rp5.refresh = function()
	rp5timer:stop()

	-- refresh all locations
	for ii = 1, #rp5.loc do refresh_loc(rp5.loc[ii]) end

	-- calculate timeout
	local cur = os.date("*t")
	local time = 0
	if cur.hour < 3 then
		time = (3 - cur.hour) * 3600
	elseif cur.hour >= 3 and cur.hour < 9 then
		time = (9 - cur.hour) * 3600
	elseif cur.hour >= 9 and cur.hour < 15 then
		time = (15 - cur.hour) * 3600
	elseif cur.hour >= 15 and cur.hour < 21 then
		time = (21 - cur.hour) * 3600
	else
		time = (27 - cur.hour) * 3600
	end
	-- some delay may be useful
	time = time - cur.min * 60 + 30
	printlog("rp5 timeout = "..time)

	-- set timeout
	rp5timer.timeout = time
	rp5timer:start()
end

-- init rp5 
--
rp5.widgets = function()
	if not rp5.loc then return end

	-- widgetset
	local widgets = wibox.layout.fixed.horizontal()
	-- spacer
	local space = wibox.widget.textbox()
	space:set_text(" ")

	-- init widgets
	for ii = 1, #rp5.loc do
		rp5.loc[ii] = init_widget(rp5.loc[ii])
		if ii > 1 then widgets:add(space) end
		widgets:add(rp5.loc[ii].widget)
	end

	-- set destroy timer
	if rp5.preset.timeout > 0 then
		dtimer = timer({timeout = rp5.preset.timeout})
		dtimer:connect_signal("timeout", destroy_all)
	else dtimer = {} end

	-- set refresh timer
	rp5timer = timer({})
	rp5timer:connect_signal("timeout", rp5.refresh)
	rp5timer:emit_signal("timeout")

	return widgets
end
--
--}}

return rp5
--
--}}}
