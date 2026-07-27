.pragma library

function stringValue(value) {
    return value === undefined || value === null ? "" : String(value);
}

function domainProvenance(bodyText) {
    const lines = stringValue(bodyText).split(/\r?\n/);
    if (lines.length === 0)
        return { body: stringValue(bodyText), source: "" };

    const domainPattern = /^(?:https?:\/\/)?(?:www\.)?([a-z0-9][a-z0-9.-]*\.[a-z]{2,})(?:\/[^ \t]*)?$/i;
    let candidateIndex = -1;
    let match = domainPattern.exec(lines[0].trim());
    if (match)
        candidateIndex = 0;
    else {
        match = domainPattern.exec(lines[lines.length - 1].trim());
        if (match)
            candidateIndex = lines.length - 1;
    }

    if (candidateIndex < 0)
        return { body: stringValue(bodyText), source: "" };

    lines.splice(candidateIndex, 1);
    while (lines.length > 0 && lines[0] === "")
        lines.shift();
    while (lines.length > 0 && lines[lines.length - 1] === "")
        lines.pop();
    return { body: lines.join("\n"), source: match[1] };
}

function findIndex(model, notificationId) {
    for (let index = 0; index < model.count; ++index) {
        if (Number(model.get(index).notificationId) === Number(notificationId))
            return index;
    }
    return -1;
}

function upsertSnapshots(entries, snapshot, historyLimit) {
    const result = [];
    for (let index = 0; index < entries.length; ++index) {
        if (Number(entries[index].notificationId) !== Number(snapshot.notificationId))
            result.push(entries[index]);
    }
    result.unshift(snapshot);

    let historyCount = 0;
    const bounded = [];
    const limit = historyLimit === undefined ? 50 : historyLimit;
    for (let index = 0; index < result.length; ++index) {
        const entry = result[index];
        if (entry.inHistory) {
            if (historyCount >= limit)
                continue;
            ++historyCount;
        }
        bounded.push(entry);
    }
    return bounded;
}

function effectiveExpirationInterval(expireTimeout, urgencyName) {
    const requested = Number(expireTimeout);
    if (requested > 0)
        return Math.max(1, requested);
    if (requested === 0 || urgencyName === "critical")
        return 0;
    return 7000;
}

function popupDisplayTimeout(expireTimeout, urgencyName) {
    const requested = Number(expireTimeout);
    if (urgencyName === "critical" && requested <= 0)
        return 0;
    return requested > 0 ? Math.min(4200, Math.max(1, requested)) : 4200;
}

function shouldShowPopup(doNotDisturb) {
    return !doNotDisturb;
}
