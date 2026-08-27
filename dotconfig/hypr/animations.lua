-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/

-- Bezier curves
hl.curve("overshot",       { type = "bezier", points = { {0.13, 0.99}, {0.29, 1.1}  } })
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })

-- Springs
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 })

-- Borders
hl.animation({ leaf = "border",        enabled = true,  speed = 5,    bezier = "default" })
hl.animation({ leaf = "borderangle",   enabled = true,  speed = 50,   bezier = "linear",       style = "loop" })

-- Windows
hl.animation({ leaf = "windows",       enabled = true,  speed = 5,    bezier = "overshot" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 6,    bezier = "overshot",     style = "popin 80%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "popin 80%" })

-- Fades
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 5,    bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 4,    bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" })

-- Layers
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "overshot" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "overshot",     style = "slide" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" })

-- Workspaces
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 6,    bezier = "overshot",     style = "slide" })
hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 6,    bezier = "overshot",     style = "slide" })
hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 6,    bezier = "overshot",     style = "slidefade 80%" })

-- Misc
hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick" })
