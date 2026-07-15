local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local beautiful = require("beautiful")

local config = require("modules.config")

local battery = require("widgets.battery")
local volume = require("widgets.volume")
local brightness = require("widgets.brightness")
local keyboard_layout = require("widgets.keyboard")
local date = require("widgets.date")
local time = require("widgets.time")

local module = {}

function module.init(screen)
  screen.padding = {
    top = beautiful.useless_gap * 2,
  }

  awful.tag(config.tag_names, screen, awful.layout.layouts[1])

  screen.tray = wibox.widget.systray()
  screen.tray:set_base_size(beautiful.menu.tray.size)
  screen.tray.forced_height = beautiful.menu.tray.height

  screen.taglist = awful.widget.taglist({
    screen = screen,
    filter = awful.widget.taglist.filter.all,
    buttons = gears.table.join(awful.button({}, 1, function(t)
      t:view_only()
    end)),
    widget_template = {
        {
            widget = wibox.container.margin,
            left = beautiful.taglist.padding,
            right = beautiful.taglist.padding,
            {
                id = "text_role",
                widget = wibox.widget.textbox,
            },
        },
        id = "background_role",
        widget = wibox.container.background,
        shape = gears.shape.circle,
    },
  })

  screen.wibar = awful.wibar({
    position = "top",
    width = screen.geometry.width - beautiful.useless_gap * 800,
    height = beautiful.menu.height,
    screen = screen,
    stretch = false,
    bg = "#0e1014",
    margins = beautiful.useless_gap * 2,
    shape = function(cr, w, h)
        gears.shape.partially_rounded_rect(cr, w, h, false, false, true, true, 16)
    end,
    })

  screen.wibar:setup({
      right = beautiful.menu.padding.riRght,
      left = beautiful.menu.padding.left,
        -- layout = wibox.container.margin,
      layout = wibox.container.place,
      halign = "center",
      valign = "center",
      {
          widget = wibox.container.place,
          halign = "center",
          valign = "center",

          screen.taglist,
      },
  })

  screen.left = wibox({
      screen = screen,
      x = 20,
      y = 2,
      width = 200,
      height = 40,
      visible = true,
      ontop = false,
      bg = "#00000000",
  })

  screen.left:setup({
      layout = wibox.layout.align.horizontal,
      nil,
      {
          layout = wibox.layout.fixed.horizontal,
          spacing = beautiful.menu.spacing,

          -- brightness,
          -- battery,
          keyboard_layout,
          time,
          date,
          -- {
          --     layout = wibox.container.place,
          --     screen.tray,
          --     valign = "center",
          --     halign = "center",
          -- },
      },
    })

  screen.right = wibox({
      screen = screen,
      x = screen.geometry.width - 220,
      y = 2,
      width = 200,
      height = 40,
      visible = true,
      ontop = false,
      bg = "#00000000",
  })

  screen.right:setup({
      widget = wibox.container.place,
      halign = "right",
      {
      layout = wibox.layout.align.horizontal,
      {
        layout = wibox.layout.fixed.horizontal,
        spacing = beautiful.menu.spacing,
          date,
          time,
          keyboard_layout,
       },
    }    })

end

return module
