.pragma library

// Reads an iCalendar feed (.ics), such as Google Calendar's "Secret address in iCal format" or an Outlook published
// calendar, and lists its events on days. Plain JavaScript, no network or files: the Clock widget fetches the text.
//
// Covers what calendar apps publish in practice: single and all-day events, events over several days, repeats by
// day, week, month or year (INTERVAL, COUNT, UNTIL, BYDAY, BYMONTHDAY), skipped dates (EXDATE), moved or cancelled
// single repeats (RECURRENCE-ID) and cancelled events. A time with a TZID is read as local time.

function unescapeText(value) {
    return value.replace(/\\([nN,;\\])/g, (match, char) => char === "n" || char === "N" ? "\n" : char)
}

// One content line: its name, its parameters and its value
function readLine(line) {
    let quoted = false
    let colon = -1
    for (let i = 0; i < line.length; i++) {
        const char = line[i]
        if (char === '"')
            quoted = !quoted
        else if (char === ":" && !quoted) {
            colon = i
            break
        }
    }
    if (colon < 0)
        return null
    const head = line.slice(0, colon).split(";")
    const params = {}
    for (let i = 1; i < head.length; i++) {
        const equals = head[i].indexOf("=")
        if (equals > 0)
            params[head[i].slice(0, equals).toUpperCase()] = head[i].slice(equals + 1).replace(/"/g, "")
    }
    return { name: head[0].toUpperCase(), params: params, value: line.slice(colon + 1) }
}

// A DATE or DATE-TIME value: { date, allDay }, or null
function readDate(value, params) {
    const day = /^(\d{4})(\d{2})(\d{2})$/.exec(value)
    if (day || params.VALUE === "DATE") {
        const parts = day ?? /^(\d{4})(\d{2})(\d{2})/.exec(value)
        if (!parts)
            return null
        return { date: new Date(+parts[1], +parts[2] - 1, +parts[3]), allDay: true }
    }
    const time = /^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z?)$/.exec(value)
    if (!time)
        return null
    const [, y, mo, d, h, mi, s, utc] = time
    const date = utc ? new Date(Date.UTC(+y, +mo - 1, +d, +h, +mi, +s)) : new Date(+y, +mo - 1, +d, +h, +mi, +s)
    return { date: date, allDay: false }
}

function readDuration(value) {
    const parts = /^([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/.exec(value)
    if (!parts)
        return 0
    const ms = ((+(parts[2] ?? 0) * 7 + +(parts[3] ?? 0)) * 86400 + +(parts[4] ?? 0) * 3600 + +(parts[5] ?? 0) * 60
        + +(parts[6] ?? 0)) * 1000
    return parts[1] === "-" ? -ms : ms
}

function readRule(value) {
    const rule = {}
    for (const part of value.split(";")) {
        const [key, val] = part.split("=")
        if (key && val !== undefined)
            rule[key.toUpperCase()] = val
    }
    return {
        freq: rule.FREQ ?? "",
        interval: Math.max(1, +(rule.INTERVAL ?? 1) || 1),
        count: rule.COUNT ? +rule.COUNT : 0,
        until: rule.UNTIL ? readDate(rule.UNTIL, {})?.date ?? null : null,
        byDay: rule.BYDAY ? rule.BYDAY.split(",") : [],
        byMonthDay: rule.BYMONTHDAY ? rule.BYMONTHDAY.split(",").map(Number) : []
    }
}

// The events in a feed's text
function parse(text) {
    const lines = text.replace(/\r\n?/g, "\n").replace(/\n[ \t]/g, "").split("\n")
    const events = []
    let event = null
    let depth = 0
    for (const raw of lines) {
        if (raw === "BEGIN:VEVENT") {
            event = { uid: "", summary: "", location: "", start: null, end: null, allDay: false, duration: null,
                      rule: null, exdates: [], recurrenceId: null, cancelled: false }
            depth = 0
            continue
        }
        if (!event)
            continue
        if (raw.startsWith("BEGIN:")) {
            depth++   // an alarm inside the event
            continue
        }
        if (raw.startsWith("END:")) {
            if (depth > 0) {
                depth--
                continue
            }
            if (raw === "END:VEVENT") {
                if (event.start) {
                    if (!event.end)
                        event.end = event.duration !== null ? new Date(event.start.getTime() + event.duration)
                            : event.allDay ? new Date(event.start.getFullYear(), event.start.getMonth(),
                                                      event.start.getDate() + 1)
                            : event.start
                    events.push(event)
                }
                event = null
            }
            continue
        }
        if (depth > 0)
            continue
        const line = readLine(raw)
        if (!line)
            continue
        switch (line.name) {
        case "UID": event.uid = line.value; break
        case "SUMMARY": event.summary = unescapeText(line.value); break
        case "LOCATION": event.location = unescapeText(line.value); break
        case "STATUS": event.cancelled = line.value.toUpperCase() === "CANCELLED"; break
        case "DTSTART": {
            const read = readDate(line.value, line.params)
            if (read) {
                event.start = read.date
                event.allDay = read.allDay
            }
            break
        }
        case "DTEND": event.end = readDate(line.value, line.params)?.date ?? null; break
        case "DURATION": event.duration = readDuration(line.value); break
        case "RRULE": event.rule = readRule(line.value); break
        case "EXDATE":
            for (const value of line.value.split(",")) {
                const read = readDate(value, line.params)
                if (read)
                    event.exdates.push(read.date.getTime())
            }
            break
        case "RECURRENCE-ID": event.recurrenceId = readDate(line.value, line.params)?.date.getTime() ?? null; break
        }
    }
    return events
}

const weekdays = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]

// The days of `month` (in `year`) a BYDAY entry such as "TU", "2TU" or "-1FR" names
function monthDaysFor(entry, year, month) {
    const parts = /^([+-]?\d+)?([A-Z]{2})$/.exec(entry)
    if (!parts)
        return []
    const weekday = weekdays.indexOf(parts[2])
    const length = new Date(year, month + 1, 0).getDate()
    const days = []
    for (let day = 1; day <= length; day++) {
        if (new Date(year, month, day).getDay() === weekday)
            days.push(day)
    }
    if (!parts[1])
        return days
    const nth = +parts[1]
    const pick = nth > 0 ? days[nth - 1] : days[days.length + nth]
    return pick ? [pick] : []
}

// The starts of a repeating event, from its first up to `to`, in order. Each keeps the first's time of day
function starts(event, to) {
    const rule = event.rule
    const first = event.start
    const at = (y, m, d) => new Date(y, m, d, first.getHours(), first.getMinutes(), first.getSeconds())
    const limit = rule.until && rule.until < to ? rule.until : to
    const found = []
    let seen = 0
    const take = date => {
        if (date < first)
            return true
        if (date > limit || (rule.count && seen >= rule.count))
            return false
        seen++
        found.push(date)
        return true
    }
    for (let step = 0; step < 5000; step++) {
        let batch = []
        if (rule.freq === "DAILY") {
            batch = [at(first.getFullYear(), first.getMonth(), first.getDate() + step * rule.interval)]
        } else if (rule.freq === "WEEKLY") {
            const monday = first.getDate() - ((first.getDay() + 6) % 7) + step * 7 * rule.interval
            const days = rule.byDay.length ? rule.byDay.map(day => weekdays.indexOf(day.slice(-2)))
                : [first.getDay()]
            batch = days.filter(day => day >= 0).sort((a, b) => ((a + 6) % 7) - ((b + 6) % 7))
                .map(day => at(first.getFullYear(), first.getMonth(), monday + (day + 6) % 7))
        } else if (rule.freq === "MONTHLY") {
            const shown = new Date(first.getFullYear(), first.getMonth() + step * rule.interval, 1)
            const y = shown.getFullYear()
            const m = shown.getMonth()
            const length = new Date(y, m + 1, 0).getDate()
            let days = rule.byDay.length ? rule.byDay.flatMap(entry => monthDaysFor(entry, y, m))
                : rule.byMonthDay.length ? rule.byMonthDay.map(day => day < 0 ? length + day + 1 : day)
                : [first.getDate()]
            days = days.filter(day => day >= 1 && day <= length).sort((a, b) => a - b)
            batch = days.map(day => at(y, m, day))
        } else if (rule.freq === "YEARLY") {
            const y = first.getFullYear() + step * rule.interval
            if (new Date(y, first.getMonth(), first.getDate()).getMonth() === first.getMonth())
                batch = [at(y, first.getMonth(), first.getDate())]
        } else {
            return [first]
        }
        for (const date of batch) {
            if (!take(date))
                return found
        }
        if (batch.length && batch[0] > limit)
            return found
    }
    return found
}

function dayKey(date) {
    return date.getFullYear() + "-" + (date.getMonth() + 1) + "-" + date.getDate()
}

// The events of every feed that fall between `from` and `to`, listed by day ("2026-11-20"). `feeds` is a list of
// { events, color, name }. Each entry: { summary, location, start, end, allDay, color, calendar }, sorted with
// all-day events first, then by start
function byDay(feeds, from, to) {
    const days = {}
    const add = (event, start, end, feed) => {
        if ((end > start ? end <= from : start < from) || start >= to)
            return
        const entry = { summary: event.summary || "(No title)", location: event.location, start: start, end: end,
                        allDay: event.allDay, color: feed.color, calendar: feed.name }
        // The last day an event shows on: an all-day end is the next day, a timed one ending at midnight too
        const last = new Date(end.getTime() - (end > start ? 1 : 0))
        let day = new Date(start.getFullYear(), start.getMonth(), start.getDate())
        for (let i = 0; day <= last && i < 62; i++) {
            if (day >= new Date(from.getFullYear(), from.getMonth(), from.getDate()) && day < to)
                (days[dayKey(day)] = days[dayKey(day)] ?? []).push(entry)
            day = new Date(day.getFullYear(), day.getMonth(), day.getDate() + 1)
        }
    }
    for (const feed of feeds) {
        const moved = {}
        for (const event of feed.events) {
            if (event.recurrenceId !== null)
                moved[event.uid + "@" + event.recurrenceId] = true
        }
        for (const event of feed.events) {
            if (event.cancelled)
                continue
            const length = event.end.getTime() - event.start.getTime()
            if (!event.rule || event.recurrenceId !== null) {
                add(event, event.start, event.end, feed)
                continue
            }
            for (const start of starts(event, to)) {
                const time = start.getTime()
                if (event.exdates.includes(time) || moved[event.uid + "@" + time])
                    continue
                add(event, start, new Date(time + length), feed)
            }
        }
    }
    for (const key in days)
        days[key].sort((a, b) => (b.allDay - a.allDay) || (a.start - b.start))
    return days
}
