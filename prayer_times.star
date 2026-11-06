"""
Applet: Prayer Times
Summary: Islamic Prayer Time Display
Description: Displays the prayer times for today's date and also shows the remaining time till the next prayer based on the user's location.
Author: EslamMoh

Modified by tmuhamma in 2026 from the Prayer Times app in https://github.com/tidbyt/community,
which is licensed under the Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0).
Changes: added a single page layout, cycle rate, 12 hour clock, Hanafi Asr, time offset and color settings, fixed
crashes at the end of the day and at the exact start of a prayer, and moved requests to HTTPS.
"""

load("animation.star", "animation")
load("encoding/base64.star", "base64")
load("encoding/json.star", "json")
load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

# Adhan prayer API URL
PRAYER_TIME_BASE_URL = "https://api.aladhan.com/v1/timings/"

# Load Moon icon from base64 encoded data
MOON_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAA0AAAANCAYAAABy6+R8AAABhGlDQ1BJQ0MgcHJvZmlsZQ
AAKJF9kT1Iw0AcxV/TiiIVBTuIOGSoThZERR21CkWoEGqFVh1MLv2CJg1Jiouj4Fpw8GOx
6uDirKuDqyAIfoA4OTopukiJ/0sKLWI8OO7Hu3uPu3eAUC8zzQqNAZpum6lEXMxkV8XOVw
QRQgTT6JOZZcxJUhK+4+seAb7exXiW/7k/R4+asxgQEIlnmWHaxBvEU5u2wXmfOMKKskp8
Tjxq0gWJH7muePzGueCywDMjZjo1TxwhFgttrLQxK5oa8SRxVNV0yhcyHquctzhr5Spr3p
O/MJzTV5a5TnMICSxiCRJEKKiihDJsxGjVSbGQov24j3/Q9UvkUshVAiPHAirQILt+8D/4
3a2Vnxj3ksJxoOPFcT6Ggc5doFFznO9jx2mcAMFn4Epv+St1YOaT9FpLix4BvdvAxXVLU/
aAyx1g4MmQTdmVgjSFfB54P6NvygL9t0D3mtdbcx+nD0CaukreAAeHwEiBstd93t3V3tu/
Z5r9/QBe53KfIhP12QAAAAZiS0dEAP8A/wD/oL2nkwAAAAlwSFlzAAALEwAACxMBAJqcGA
AAAAd0SU1FB+QDBBUeOG9t+GkAAAAZdEVYdENvbW1lbnQAQ3JlYXRlZCB3aXRoIEdJTVBX
gQ4XAAAATElEQVQoz2NkYGD4z0AiYGIgA7BgE/z/2hrOZhQ9StgmZA3Y+Bg2EbIBwyZiNZ
AdEJRpQnYSNs8jA0b0yMWmAd2PTIQUYAsURrolIwA2fBgZWqCnTgAAAABJRU5ErkJggg==
""")

# Load Sun icon from base64 encoded data
SUN_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAA0AAAANCAYAAABy6+R8AAABhGlDQ1BJQ0MgcHJvZmlsZQ
AAKJF9kT1Iw0AcxV/TiiIVBTuIOGSoThZERR21CkWoEGqFVh1MLv2CJg1Jiouj4Fpw8GOx
6uDirKuDqyAIfoA4OTopukiJ/0sKLWI8OO7Hu3uPu3eAUC8zzQqNAZpum6lEXMxkV8XOVw
QRQgTT6JOZZcxJUhK+4+seAb7exXiW/7k/R4+asxgQEIlnmWHaxBvEU5u2wXmfOMKKskp8
Tjxq0gWJH7muePzGueCywDMjZjo1TxwhFgttrLQxK5oa8SRxVNV0yhcyHquctzhr5Spr3p
O/MJzTV5a5TnMICSxiCRJEKKiihDJsxGjVSbGQov24j3/Q9UvkUshVAiPHAirQILt+8D/4
3a2Vnxj3ksJxoOPFcT6Ggc5doFFznO9jx2mcAMFn4Epv+St1YOaT9FpLix4BvdvAxXVLU/
aAyx1g4MmQTdmVgjSFfB54P6NvygL9t0D3mtdbcx+nD0CaukreAAeHwEiBstd93t3V3tu/
Z5r9/QBe53KfIhP12QAAAAZiS0dEAP8A/wD/oL2nkwAAAAlwSFlzAAALEwAACxMBAJqcGA
AAAAd0SU1FB+QDBBQ5HxFglVAAAAAZdEVYdENvbW1lbnQAQ3JlYXRlZCB3aXRoIEdJTVBX
gQ4XAAAAYUlEQVQoz2NgYGD4jw3/f239H5ccEwMDA8P/19YMxABkdQRNRpdnhDJwmsgoeh
TDRiZ8GnA5nYmQAmziLDABbM7ApZmFGMXo/mPCJohLMc6AQFeAyyCS44kBlwYCYqSnPQAb
5W9EvIXnIQAAAABJRU5ErkJggg==
""")

# Default location and timezone data for prayer
DEFAULT_LOCATION = """
{
    "timezone": "Asia/Riyadh",
    "lat": "24.7136",
	"lng": "46.6753"
}
"""

# Default method of calculating prayer time
DEFAULT_METHOD = "4"

# Mapping current prayer to the matching icon
PRAYER_ICON = {
    "sunrise": SUN_ICON,
    "duhr": SUN_ICON,
    "asr": SUN_ICON,
    "maghrib": MOON_ICON,
    "isha": MOON_ICON,
    "fajr": MOON_ICON,
}

# Cache prayer times request for one day.
TTL_CACHE = 86400

# Default time each screen is shown, in milliseconds.
DEFAULT_CYCLE_RATE = "4000"

# Default Asr calculation (0 = Shafi'i, Maliki and Hanbali, 1 = Hanafi).
DEFAULT_SCHOOL = "0"

# Largest adjustment, in minutes, that can be applied to a prayer time.
MAX_OFFSET_MINUTES = 30

# Prayers in the order they occur during the day.
PRAYER_ORDER = ["fajr", "sunrise", "duhr", "asr", "maghrib", "isha"]

# Name of each prayer in the API response and in the settings.
PRAYER_NAMES = {
    "fajr": "Fajr",
    "sunrise": "Sunrise",
    "duhr": "Dhuhr",
    "asr": "Asr",
    "maghrib": "Maghrib",
    "isha": "Isha",
}

# Prayers shown in the single page layout. Sunrise is left out so the five rows fit the screen.
SINGLE_PAGE_PRAYERS = ["fajr", "duhr", "asr", "maghrib", "isha"]

# How long a render stays valid, in seconds. A render can be up to a minute old when its turn
# comes, so this leaves room for a full 60 second Time on Screen; a render that would expire while
# on screen makes the display move on early. The app still re-renders every minute, so this only
# matters if a refresh fails, when the countdown would be up to 3 minutes old.
RENDER_MAX_AGE = 180

# Default colors for each part of the display.
DEFAULT_COLORS = {
    "next_prayer_color": "#228B22",
    "countdown_color": "#FFFFFF",
    "separator_color": "#FF0000",
    "label_color": "#FFFFFF",
    "time_color": "#FFFFFF",
    "highlight_color": "#F4C430",
    "highlight_text_color": "#000000",
}

# Fetch location configs
def get_location(config):
    location = config.get("location", DEFAULT_LOCATION)
    return json.decode(location)

# Fetch method of calculation for prayer time config
def get_method(config):
    return config.get("method", DEFAULT_METHOD)

# Fetch how long each screen is shown, in milliseconds.
def get_cycle_rate(config):
    return int(config.get("cycle_rate", DEFAULT_CYCLE_RATE))

# Build the API "tune" value, which adjusts each timing by a number of minutes.
# Its order is Imsak, Fajr, Sunrise, Dhuhr, Asr, Maghrib, Sunset, Isha, Midnight.
def get_tune(config):
    offset = int(config.get("offset", "0"))
    return "0,%d,%d,%d,%d,%d,0,%d,0" % (offset, offset, offset, offset, offset, offset)

# Fetch the color for each part of the display.
def get_colors(config):
    return {name: config.get(name) or color for name, color in DEFAULT_COLORS.items()}

def main(config):
    location = get_location(config)
    params = {
        "method": get_method(config),
        "school": config.get("school", DEFAULT_SCHOOL),
        "tune": get_tune(config),
    }
    now = time.now().in_location(location["timezone"])
    date = now.format("2-01-2006")

    # Fetch today prayer times
    prayers = get_prayers(date, location, params)

    # Calculate the next prayer based on the current time
    next_prayer = next_prayer_time(prayers, now, location, params)

    # Get the current prayer name
    current_prayer = current_prayer_name(next_prayer["prayer"])

    colors = get_colors(config)
    display = {
        "prayers": prayers,
        "current_prayer": current_prayer,
        "colors": colors,
        "use_12_hour": config.bool("use_12_hour", True),
    }

    if config.bool("single_page", False):
        # A still image, so Niblet's Time on Screen setting decides how long it stays up.
        return render.Root(
            max_age = RENDER_MAX_AGE,
            child = render_single_page(next_prayer, display),
        )

    meta_data = render_meta_data(PRAYER_ICON[current_prayer], next_prayer, colors)

    return render.Root(
        delay = get_cycle_rate(config),
        max_age = RENDER_MAX_AGE,
        # Slower cycle rates run past the default 15 second limit and would lose the last screens.
        show_full_animation = True,
        child = render.Column(
            children = [
                render.Sequence(children = [
                    render_screen(
                        0,
                        render_prayer("fajr", "FAJR", 7, 17, 15, 5, display) +
                        render_prayer("sunrise", "sunrise", 30, 29, 27, 34, display) +
                        meta_data,
                    ),
                    render_screen(
                        64,
                        render_prayer("duhr", "Duhr", 7, 17, 15, 5, display) +
                        render_prayer("asr", "Asr", 38, 13, 11, 34, display) +
                        meta_data,
                    ),
                    render_screen(
                        64,
                        render_prayer("maghrib", "MAGHRIB", 5, 29, 26, 8, display) +
                        render_prayer("isha", "ISHA", 42, 16, 16, 40, display) +
                        meta_data,
                    ),
                ]),
            ],
        ),
    )

# Render the five daily prayers on one screen. The current prayer is highlighted and
# the next prayer's name is shown in the next prayer color.
def render_single_page(next_prayer, display):
    return render.Padding(
        pad = (0, 1, 0, 0),
        child = render.Column(children = [
            render_single_page_prayer(prayer, next_prayer["prayer"], display)
            for prayer in SINGLE_PAGE_PRAYERS
        ]),
    )

# Render the name and time of one prayer as a row of the single page layout.
def render_single_page_prayer(prayer, next_prayer, display):
    colors = current_prayer_color(prayer, display["current_prayer"], display["colors"])
    if prayer == next_prayer:
        colors["font_color"] = display["colors"]["next_prayer_color"]

    return render.Box(
        width = 64,
        height = 6,
        child = render.Row(
            expanded = True,
            main_align = "space_between",
            children = [
                render.Box(
                    width = 4 * len(PRAYER_NAMES[prayer]) + 1,
                    height = 6,
                    color = colors["box_color"],
                    child = render.Text(
                        content = PRAYER_NAMES[prayer].upper(),
                        font = "CG-pixel-3x5-mono",
                        color = colors["font_color"],
                    ),
                ),
                render.Padding(
                    pad = (0, 0, 1, 0),
                    child = render.Text(
                        content = display_time(display["prayers"][PRAYER_NAMES[prayer]], display["use_12_hour"]),
                        font = "CG-pixel-3x5-mono",
                        color = display["colors"]["time_color"],
                    ),
                ),
            ],
        ),
    )

# Render one screen of prayer times.
def render_screen(x, children):
    return animation.Transformation(
        child = render.Row(children = [
            render.Stack(children = children),
        ]),
        duration = 1,
        keyframes = keyframes(x),
    )

# Render the name and time of one prayer.
def render_prayer(prayer, label, label_x, label_box_width, label_text_width, time_x, display):
    colors = current_prayer_color(prayer, display["current_prayer"], display["colors"])

    return [
        render.Padding(
            pad = (label_x, 17, 0, 0),
            child = render.Box(
                width = label_box_width,
                height = 7,
                color = colors["box_color"],
                child = render.WrappedText(
                    content = label,
                    font = "CG-pixel-3x5-mono",
                    align = "left",
                    width = label_text_width,
                    color = colors["font_color"],
                ),
            ),
        ),
        render.Padding(
            pad = (time_x, 24, 0, 0),
            child = render.Box(
                width = 22,
                height = 8,
                child = render.WrappedText(
                    content = display_time(display["prayers"][PRAYER_NAMES[prayer]], display["use_12_hour"]),
                    # Times without a leading zero are narrower, so keep them under their label.
                    align = "center" if display["use_12_hour"] else "left",
                    width = 22,
                    color = display["colors"]["time_color"],
                ),
            ),
        ),
    ]

# Format an API "HH:MM" time for display, in either 12 or 24 hour format.
def display_time(prayer, use_12_hour):
    if not use_12_hour:
        return prayer

    p = prayer.partition(":")
    return "%d:%s" % (int(p[0]) % 12 or 12, p[2])

def render_time_icon(icon):
    return render.Padding(
        pad = (0, 0, 0, 0),
        child = render.Image(
            src = icon,
        ),
    )

def render_line_separator(colors):
    return render.Padding(
        pad = (0, 16, 0, 0),
        child = render.Box(
            width = 64,
            height = 1,
            color = colors["separator_color"],
        ),
    )

def render_next_prayer_time(next_prayer, colors):
    return {
        "name": render.Padding(
            pad = (20, 1, 0, 0),
            child = render.Box(
                width = 28,
                height = 7,
                child = render.WrappedText(
                    content = next_prayer["prayer"],
                    font = "CG-pixel-3x5-mono",
                    color = colors["next_prayer_color"],
                    align = "left",
                ),
            ),
        ),
        "time": render.Padding(
            pad = (12, 5, 0, 0),
            child = render.Box(
                width = 50,
                height = 15,
                child = render.WrappedText(
                    content = "%dhrs %dmins" % next_prayer["remaining"],
                    font = "CG-pixel-3x5-mono",
                    linespacing = 1,
                    align = "left",
                    color = colors["countdown_color"],
                ),
            ),
        ),
    }

# Format prayer times in DateTime format
def formatted_prayer_times(prayers, now, timezone):
    return {prayer: format_time(prayers[PRAYER_NAMES[prayer]], now, timezone) for prayer in PRAYER_ORDER}

# Format time from "HH:MM" to DateTime format
def format_time(prayer, now, timezone):
    p = prayer.partition(":")

    return time.time(year = now.year, month = now.month, day = now.day, hour = int(p[0]), minute = int(p[2]), second = 0o0, location = timezone)

# Calculate next prayer time based on the current time.
def next_prayer_time(prayers, now, location, params):
    pt = formatted_prayer_times(prayers, now, location["timezone"])

    for prayer in PRAYER_ORDER:
        if now < pt[prayer]:
            return {"prayer": prayer, "remaining": time_till_next_prayer(now, pt[prayer])}

    # All of today's prayers have passed, so the next one is tomorrow's Fajr.
    tomorrow_fajr = get_tomorrow_fajr(now, location, params)

    return {"prayer": "fajr", "remaining": time_till_next_prayer(now, tomorrow_fajr)}

# Get Fajr prayer time for tomorrow date.
def get_tomorrow_fajr(now, location, params):
    tomorrow = now + 24 * time.hour
    tomorrow_date = tomorrow.format("2-01-2006")
    tomorrow_prayers = get_prayers(tomorrow_date, location, params)
    return format_time(tomorrow_prayers["Fajr"], tomorrow, location["timezone"])

# Send API request to get prayer times according to location and date.
def get_prayers(date, location, params):
    url = PRAYER_TIME_BASE_URL + date + "?latitude=%s" % (location["lat"]) + "&longitude=%s" % (location["lng"]) + "&method=%s" % (params["method"]) + "&school=%s" % (params["school"]) + "&tune=%s" % (params["tune"])
    rep = http.get(url, ttl_seconds = TTL_CACHE)

    if rep.status_code != 200:
        fail("Prayer Time request failed with status %d" % rep.status_code)

    if rep.headers.get("Tidbyt-Cache-Status") == "HIT":
        print("Hit! Displaying cached data.")
    else:
        print("Miss! Calling Prayer Times API.")

    return rep.json()["data"]["timings"]

# Render time icon, next prayer times data and separation line.
def render_meta_data(icon, next_prayer, colors):
    next_prayer_time_widgets = render_next_prayer_time(next_prayer, colors)

    return [
        render_time_icon(icon),
        render_line_separator(colors),
        next_prayer_time_widgets["name"],
        next_prayer_time_widgets["time"],
    ]

# Animate prayers frames based on x axis input.
def keyframes(x):
    return [
        animation.Keyframe(
            percentage = 0.0,
            transforms = [animation.Translate(x, 0)],
            curve = "linear",
        ),
        animation.Keyframe(
            percentage = 1.0,
            transforms = [animation.Translate(-64, 0)],
            curve = "linear",
        ),
    ]

# Pick the highlight color for the current prayer.
def current_prayer_color(prayer_name, current_prayer, colors):
    if current_prayer == prayer_name:
        return {"box_color": colors["highlight_color"], "font_color": colors["highlight_text_color"]}
    else:
        return {"box_color": "#000000", "font_color": colors["label_color"]}

# Calculate the hours and minutes remaining till the next prayer time.
def time_till_next_prayer(now, nxt_pryr_time):
    remaining_time = nxt_pryr_time - now
    hours = int(remaining_time.hours)
    mins = int(remaining_time.minutes) % 60

    return (hours, mins)

# Get the current prayer time based on the next prayer time name.
def current_prayer_name(next_prayer):
    return {
        "sunrise": "fajr",
        "duhr": "sunrise",
        "asr": "duhr",
        "maghrib": "asr",
        "isha": "maghrib",
        "fajr": "isha",
    }[next_prayer]

# List the minutes that can be added to or removed from a prayer time.
def offset_options():
    options = []
    for minutes in range(-MAX_OFFSET_MINUTES, MAX_OFFSET_MINUTES + 1):
        options.append(schema.Option(
            display = "%s%d min" % ("+" if minutes > 0 else "", minutes),
            value = str(minutes),
        ))
    return options

def get_schema():
    method_options = [
        schema.Option(
            display = "Shia Ithna-Ansari",
            value = "0",
        ),
        schema.Option(
            display = "University of Islamic Sciences, Karachi",
            value = "1",
        ),
        schema.Option(
            display = "Islamic Society of North America",
            value = "2",
        ),
        schema.Option(
            display = "Muslim World League",
            value = "3",
        ),
        schema.Option(
            display = "Umm Al-Qura University, Makkah",
            value = "4",
        ),
        schema.Option(
            display = "Egyptian General Authority of Survey",
            value = "5",
        ),
        schema.Option(
            display = "Institute of Geophysics, University of Tehran",
            value = "7",
        ),
        schema.Option(
            display = "Gulf Region",
            value = "8",
        ),
        schema.Option(
            display = "Kuwait",
            value = "9",
        ),
        schema.Option(
            display = "Qatar",
            value = "10",
        ),
        schema.Option(
            display = "Majlis Ugama Islam Singapura, Singapore",
            value = "11",
        ),
        schema.Option(
            display = "Union Organization islamic de France",
            value = "12",
        ),
        schema.Option(
            display = "Diyanet İşleri Başkanlığı, Turkey",
            value = "13",
        ),
        schema.Option(
            display = "Spiritual Administration of Muslims of Russia",
            value = "14",
        ),
        schema.Option(
            display = "Moonsighting Committee Worldwide (also requires shafaq parameter)",
            value = "15",
        ),
        schema.Option(
            display = "Dubai (unofficial)",
            value = "16",
        ),
    ]

    cycle_rate_options = [
        schema.Option(display = "%d seconds" % seconds, value = str(seconds * 1000))
        for seconds in range(2, 11)
    ]

    school_options = [
        schema.Option(display = "Standard (Shafi'i, Maliki, Hanbali)", value = "0"),
        schema.Option(display = "Hanafi", value = "1"),
    ]

    color_fields = [
        schema.Color(
            id = "next_prayer_color",
            name = "Next Prayer Color",
            desc = "Color of the next prayer's name.",
            icon = "palette",
            default = DEFAULT_COLORS["next_prayer_color"],
        ),
        schema.Color(
            id = "countdown_color",
            name = "Countdown Color",
            desc = "Color of the time remaining until the next prayer.",
            icon = "palette",
            default = DEFAULT_COLORS["countdown_color"],
        ),
        schema.Color(
            id = "separator_color",
            name = "Separator Color",
            desc = "Color of the line across the middle of the screen.",
            icon = "palette",
            default = DEFAULT_COLORS["separator_color"],
        ),
        schema.Color(
            id = "label_color",
            name = "Prayer Name Color",
            desc = "Color of the prayer names.",
            icon = "palette",
            default = DEFAULT_COLORS["label_color"],
        ),
        schema.Color(
            id = "time_color",
            name = "Prayer Time Color",
            desc = "Color of the prayer times.",
            icon = "palette",
            default = DEFAULT_COLORS["time_color"],
        ),
        schema.Color(
            id = "highlight_color",
            name = "Current Prayer Highlight",
            desc = "Background color behind the current prayer's name.",
            icon = "palette",
            default = DEFAULT_COLORS["highlight_color"],
        ),
        schema.Color(
            id = "highlight_text_color",
            name = "Current Prayer Text Color",
            desc = "Color of the current prayer's name.",
            icon = "palette",
            default = DEFAULT_COLORS["highlight_text_color"],
        ),
    ]

    return schema.Schema(
        version = "1",
        fields = [
            schema.Location(
                id = "location",
                name = "Location",
                desc = "Location for which to display prayer times",
                icon = "locationDot",
            ),
            schema.Dropdown(
                id = "method",
                name = "Prayer Calculation Method",
                desc = "A prayer times calculation method. Methods identify various schools of thought about how to compute the timings. If not specified, it defaults to Umm Al-Qura University, Makkah",
                icon = "mosque",
                default = "4",
                options = method_options,
            ),
            schema.Dropdown(
                id = "school",
                name = "Asr Calculation",
                desc = "The school of thought used to calculate Asr. Hanafi gives a later Asr time.",
                icon = "mosque",
                default = DEFAULT_SCHOOL,
                options = school_options,
            ),
            schema.Toggle(
                id = "single_page",
                name = "Single Page",
                desc = "Show the five daily prayers in a list on one screen, instead of cycling through screens.",
                icon = "tableCells",
                default = False,
            ),
            schema.Dropdown(
                id = "cycle_rate",
                name = "Cycle Rate",
                desc = "How long each screen of prayer times is shown.",
                icon = "gaugeHigh",
                default = DEFAULT_CYCLE_RATE,
                options = cycle_rate_options,
            ),
            schema.Toggle(
                id = "use_12_hour",
                name = "12 Hour Clock",
                desc = "Show prayer times in 12 hour format instead of 24 hour format.",
                icon = "clock",
                default = True,
            ),
            schema.Dropdown(
                id = "offset",
                name = "Time Offset",
                desc = "Minutes to add to or remove from all prayer times, for example to match a local mosque.",
                icon = "sliders",
                default = "0",
                options = offset_options(),
            ),
        ] + color_fields,
    )
