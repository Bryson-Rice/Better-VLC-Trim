-- ffmpeg_trim.lua

-- TODO: Add millisecond support?
function descriptor()
    return {
        title = "FFmpeg Trim Video",
        version = "1.2",
        author = "Sen",
        shortdesc = "Trim video using FFmpeg",
        description = "Trim current video using start and end times",
        capabilities = {"input-listener"}
    }
end

local dlg
local start_input
local end_input
local status_label

function activate()
    dlg = vlc.dialog("FFmpeg Trim Video")

    dlg:add_label("Start Time (HH:MM:SS):", 1, 1, 1, 1)
    start_input = dlg:add_text_input("00:00:00", 2, 1, 2, 1)

    dlg:add_label("End Time (HH:MM:SS):", 1, 2, 1, 1)
    end_input = dlg:add_text_input("00:00:10", 2, 2, 2, 1)

    dlg:add_button("Trim Video", trim_video, 1, 3, 3, 1)
    status_label = dlg:add_label("", 1, 4, 3, 1)

    set_default_times()
end

function deactivate()
    dlg = nil
end

function close()
    vlc.deactivate()
end

-- Start = 00:00:00, End = full video length (if a video is loaded)
function set_default_times()
    start_input:set_text("00:00:00")

    local duration = get_video_duration_seconds()
    if duration then
        end_input:set_text(seconds_to_hms(duration))
    end
end

function set_status(msg)
    status_label:set_text(msg)
end

-- Returns an error message if the range is invalid, otherwise nil
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

-- Returns the playing file's path, or nil if nothing is playing
function get_input_path()
    local item = vlc.input.item()
    if not item then return nil end

    local path = vlc.strings.decode_uri(item:uri())
    path = path:gsub("^file:///", "")
    return path
end

function trim_video()
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
        'ffmpeg -y -i "%s" -ss %s -to %s -c copy "%s"',
        input_path, seconds_to_hms(start_seconds),
        seconds_to_hms(end_seconds), output_path
    )

    set_status("Running ffmpeg...")
    vlc.msg.info("Running: " .. cmd)
    os.execute(cmd)
    set_status("Done! Saved as: " .. output_path)
end

function get_video_duration_seconds()
    local input = vlc.object.input()
    if not input then return nil end

    local length_micro = vlc.var.get(input, "length")
    if not length_micro or length_micro <= 0 then
        return nil
    end

    return math.floor(length_micro / 1000000)
end


-- allows overflow
function parse_time(t)
    local h, m, s = string.match(t, "^(%d+):(%d+):(%d+)$")
    if not h then return nil end
    return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s)
end

-- Convert seconds -> normalized HH:MM:SS
function seconds_to_hms(total)
    local h = math.floor(total / 3600)
    local m = math.floor((total % 3600) / 60)
    local s = total % 60
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