-- ffmpeg_trim.lua

function descriptor()
    return {
        title = "FFmpeg Trim Video",
        version = "2.0",
        author = "Sen",
        shortdesc = "Trim video using FFmpeg",
        description = "Trim current video with a timeline bar and nudge buttons",
        capabilities = {"input-listener"}
    }
end

local MICROSECONDS_PER_SECOND = 1000000
local SECONDS_PER_MINUTE = 60
local SECONDS_PER_HOUR = 3600
local BAR_WIDTH = 48

local dlg
local start_input
local end_input
local status_label
local bar_label
local info_label
local cached_path
local cached_duration
local pending_seek

function activate()
    dlg = vlc.dialog("FFmpeg Trim Video")

    bar_label = dlg:add_label("", 1, 1, 6, 1)
    info_label = dlg:add_label("", 1, 2, 6, 1)

    dlg:add_label("Start:", 1, 3, 1, 1)
    start_input = dlg:add_text_input("00:00:00", 2, 3, 1, 1)
    dlg:add_button("-10s", function() nudge("start", -10) end, 3, 3, 1, 1)
    dlg:add_button("-1s",  function() nudge("start", -1)  end, 4, 3, 1, 1)
    dlg:add_button("+1s",  function() nudge("start", 1)   end, 5, 3, 1, 1)
    dlg:add_button("+10s", function() nudge("start", 10)  end, 6, 3, 1, 1)

    dlg:add_label("End:", 1, 4, 1, 1)
    end_input = dlg:add_text_input("00:00:10", 2, 4, 1, 1)
    dlg:add_button("-10s", function() nudge("end", -10) end, 3, 4, 1, 1)
    dlg:add_button("-1s",  function() nudge("end", -1)  end, 4, 4, 1, 1)
    dlg:add_button("+1s",  function() nudge("end", 1)   end, 5, 4, 1, 1)
    dlg:add_button("+10s", function() nudge("end", 10)  end, 6, 4, 1, 1)

    dlg:add_button("Go to start", function() seek_to("start") end, 1, 5, 3, 1)
    dlg:add_button("Go to end",   function() seek_to("end")   end, 4, 5, 3, 1)

    dlg:add_button("Trim Video", trim_video, 1, 6, 6, 1)
    status_label = dlg:add_label("", 1, 7, 6, 1)

    set_default_times()
end

function deactivate()
    dlg = nil
end

function close()
    vlc.deactivate()
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function read_range()
    local duration = get_video_duration_seconds() or 0
    local s = parse_time(start_input:get_text()) or 0
    local e = parse_time(end_input:get_text()) or duration
    return s, e, duration
end

function write_range(s, e)
    start_input:set_text(seconds_to_hms(s))
    end_input:set_text(seconds_to_hms(e))
end

function refresh()
    local s, e, duration = read_range()
    if duration <= 0 then
        bar_label:set_text("[ load a video to see the timeline ]")
        info_label:set_text("")
        return
    end

    s = clamp(s, 0, duration)
    e = clamp(e, 0, duration)

    local start_index = math.floor(s / duration * BAR_WIDTH)
    local end_index = math.floor(e / duration * BAR_WIDTH)

    local chars = {}
    for i = 0, BAR_WIDTH do
        if i >= start_index and i <= end_index then
            chars[#chars + 1] = "█"
        else
            chars[#chars + 1] = "░"
        end
    end
    bar_label:set_text(table.concat(chars))

    info_label:set_text(string.format(
        "In %s  ->  Out %s   |   Clip %s   |   Video %s",
        seconds_to_hms(s), seconds_to_hms(e),
        seconds_to_hms(math.max(0, e - s)), seconds_to_hms(duration)
    ))
end

function set_default_times()
    local duration = get_video_duration_seconds()
    start_input:set_text("00:00:00")
    if duration then
        end_input:set_text(seconds_to_hms(duration))
    end
    refresh()
end

function nudge(which, delta)
    local s, e, duration = read_range()
    if duration <= 0 then return set_status("No video currently playing") end

    if which == "start" then
        s = clamp(s + delta, 0, math.max(0, e - 1))
    else
        e = clamp(e + delta, math.min(duration, s + 1), duration)
    end
    write_range(s, e)
    refresh()

    seek_to(which)
end

function seek_to(which)
    local s, e = read_range()
    seek_player((which == "start") and s or e)
end

function set_status(msg)
    status_label:set_text(msg)
end

function validate_range(start_seconds, end_seconds, duration)
    if start_seconds >= duration then
        return "Start time exceeds video length"
    end
    if end_seconds > duration then
        return "End time exceeds video length"
    end
    if start_seconds == end_seconds then
        return "Start and end times cannot be the same"
    end
    if start_seconds > end_seconds then
        return "Start time must be before end time"
    end
    return nil
end

local function uri_to_path(uri)
    local path = vlc.strings.decode_uri(uri)
    if path:match("^file:///%a:") then
        path = path:gsub("^file:///", "")
    else
        path = path:gsub("^file://", "")
    end
    return path
end

local function remember_current_video()
    local item = vlc.input.item()
    if not item then return end

    local path = uri_to_path(item:uri())
    if path ~= cached_path then
        cached_path = path
        cached_duration = nil
        if start_input then start_input:set_text("00:00:00") end
    end

    if cached_duration then return end

    local input = vlc.object.input()
    local length_micro = input and vlc.var.get(input, "length")
    if length_micro and length_micro > 0 then
        cached_duration = math.floor(length_micro / MICROSECONDS_PER_SECOND)
        if end_input then end_input:set_text(seconds_to_hms(cached_duration)) end
    end
end

function seek_player(seconds)
    local input = vlc.object.input()
    if not input then
        pending_seek = seconds
        vlc.playlist.play()
        return
    end

    vlc.var.set(input, "time", seconds * MICROSECONDS_PER_SECOND)
end

function input_changed()
    remember_current_video()

    if pending_seek then
        local seconds = pending_seek
        pending_seek = nil
        seek_player(seconds)
    end

    if dlg then refresh() end
end

function get_input_path()
    remember_current_video()
    return cached_path
end

function trim_video()
    refresh()

    local start_seconds = parse_time(start_input:get_text())
    local end_seconds   = parse_time(end_input:get_text())
    if not start_seconds or not end_seconds then
        return set_status("Invalid time format. Use HH:MM:SS")
    end

    local duration = get_video_duration_seconds()
    if not duration then
        return set_status("Unable to determine video length")
    end

    local err = validate_range(start_seconds, end_seconds, duration)
    if err then
        return set_status(err)
    end

    local input_path = get_input_path()
    if not input_path then
        return set_status("No video currently playing")
    end

    local output_path = make_unique_output_name(input_path)
    local cmd = string.format(
        'ffmpeg -y -ss %s -to %s -i "%s" -c copy "%s"',
        seconds_to_hms(start_seconds), seconds_to_hms(end_seconds),
        input_path, output_path
    )

    set_status("Running ffmpeg...")
    vlc.msg.info("Running: " .. cmd)
    os.execute(cmd)
    set_status("Done! Saved as: " .. output_path)
end

function get_video_duration_seconds()
    remember_current_video()
    return cached_duration
end

function parse_time(t)
    local h, m, s = string.match(t, "^(%d+):(%d+):(%d+)$")
    if not h then return nil end
    return tonumber(h) * SECONDS_PER_HOUR + tonumber(m) * SECONDS_PER_MINUTE + tonumber(s)
end

function seconds_to_hms(total)
    local h = math.floor(total / SECONDS_PER_HOUR)
    local m = math.floor((total % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE)
    local s = total % SECONDS_PER_MINUTE
    return string.format("%02d:%02d:%02d", h, m, s)
end

function make_unique_output_name(input_path)
    local base, ext = input_path:match("^(.*)%.([^%.]+)$")
    local output = base .. "_trimmed." .. ext

    local i = 2
    while file_exists(output) do
        output = string.format("%s_trimmed(%d).%s", base, i, ext)
        i = i + 1
    end

    return output
end

function file_exists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end