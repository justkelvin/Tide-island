.pragma library

function hasUsefulMediaMetadata(title, metadataUrl) {
    // A URL or MPRIS track ID by itself commonly survives in stale browser
    // players and would only render "Unknown" in Tide's media surface.
    return String(title || "").trim() !== "";
}

function hasPresentableMedia(hasPlayer, playbackSupported, hasUsefulMetadata) {
    return Boolean(hasPlayer && playbackSupported && hasUsefulMetadata);
}

function hoverTarget(currentState, legacyHoverAction, dashboardEnabled, idleHoverContent, presentableMedia) {
    const resting = currentState === "normal" || currentState === "custom" || currentState === "lyrics";
    if (!resting || Number(legacyHoverAction) <= 0)
        return "none";
    if (Number(legacyHoverAction) === 2)
        return "controlCenter";
    if (presentableMedia)
        return "media";
    if (dashboardEnabled && idleHoverContent === "informationDashboard")
        return "dashboard";
    return "none";
}

function shouldPollSystemStats(dashboardActive, customSwipeActive, customSwipeUsesStats) {
    return Boolean(dashboardActive || (customSwipeActive && customSwipeUsesStats));
}

function shouldPollStorage(customSwipeActive, customSwipeUsesStorage) {
    return Boolean(customSwipeActive && customSwipeUsesStorage);
}
