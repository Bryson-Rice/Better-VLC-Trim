-- ffmpeg_trim.lua

-- TODO: Add millisecond support?
function descriptor()
    return {
        title = "FFmpeg Trim Video",
        version = "1.1",
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
end

function deactivate()
    dlg = nil
end

function close()
    vlc.deactivate()
end

-- TODO: I should simplify this function
function trim_video()
    local start_raw = start_input:get_text()
    local end_raw   = end_input:get_text()

    local start_seconds = parse_time(start_raw)
    local end_seconds   = parse_time(end_raw)

    if not start_seconds or not end_seconds then
        status_label:set_text("Invalid time format. Use HH:MM:SS")
        return
    end

    local duration = get_video_duration_seconds()
    if not duration then
        status_label:set_text("Unable to determine video length")
        return
    end

    if start_seconds >= duration then
        status_label:set_text("Start time exceeds video length")
        return
    end

    if end_seconds > duration then
        status_label:set_text("End time exceeds video length")
        return
    end

    if start_seconds == end_seconds then
        status_label:set_text("Start and end times cannot be the same")
        return
    end

    if start_seconds > end_seconds then
        status_label:set_text("Start time must be before end time")
        return
    end


    local start_time = seconds_to_hms(start_seconds)
    local end_time   = seconds_to_hms(end_seconds)

    local item = vlc.input.item()
    if not item then
        status_label:set_text("No video currently playing")
        return
    end

    local input_path = vlc.strings.decode_uri(item:uri())
    input_path = input_path:gsub("^file:///", "")

    local output_path = make_unique_output_name(input_path)

    local cmd = string.format(
        'ffmpeg -y -i "%s" -ss %s -to %s -c copy "%s"',
        input_path, start_time, end_time, output_path
    )

    status_label:set_text("Running ffmpeg...")
    vlc.msg.info("Running: " .. cmd)

    os.execute(cmd)

    status_label:set_text("Done! Saved as: " .. output_path)
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
