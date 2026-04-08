local PackDefs = {}

local DEFS = {
    startup = {
        id = "startup",
        displayName = "The Startup",
        topText = "The",
        bottomText = "Startup",
        iconPath = "assets/handdrawn/cardIcons/star.png",
        iconCirclePath = "assets/handdrawn/ui/circleBig.png",
        uses = 4,
        sequence = {
            "junior_dev",
            "junior_tester",
            "software",
            "mini_requirement",
        },
        backgroundColor = { 0.78, 0.91, 1.0, 1.0 },
        borderColor = { 0.10, 0.16, 0.23, 1.0 },
        textColor = { 0.10, 0.16, 0.23, 1.0 },
        iconColor = { 0.10, 0.16, 0.23, 1.0 },
        iconCircleColor = { 0.58, 0.76, 0.95, 1.0 },
    },
}

function PackDefs.get(defId)
    return DEFS[defId]
end

function PackDefs.all()
    return DEFS
end

return PackDefs
