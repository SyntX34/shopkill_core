# ShopKill Core

A SourceMod plugin that rewards players with Shop credits for kills, headshots, knife eliminations, and infections with VIP multiplier support and player-customizable notifications.

## Features

- **Action-Based Rewards**: Configurable credit payouts for individual weapons, headshots, knife kills, and zombie infections.
- **Death Penalty Support**: Deduct credits on death if configured.
- **VIP Integration**: Optional VIP multipliers via SourceMod admin flags or `vip_core`.
- **Customizable Notifications**: Players can configure their credit notification delivery via `!settings`, ClientPrefs cookies menu, or `!skchat`:
  - **Chat**: Rich colored chat notifications.
  - **Console**: Clean, uncolored console messages.
  - **Custom HUD**: Synchronized HUD text appearing at random screen coordinates with rich color customization.
  - **Disabled**: Silent operation.
- **50 HUD Color Presets + Custom Color**:
  - **Custom Color Option**: At the very top of the color menu, players can type their own custom color into chat:
    - Hex format: `#RRGGBB` or `#RRGGBBAA` (e.g. `#00ffcc` or `#ff007f`)
    - RGB/RGBA format: `R G B` or `R G B A` (e.g. `255 128 0` or `0, 255, 128, 255`)
    - Type `!cancel` to abort custom color input anytime.
  - **50 Named Color Presets**: From Red, Coral, Lime, Gold, Aqua, Teal, Dodger Blue, Violet, Hot Pink, to Deep Pink, and more.
  - **Random Vibrant Colors**: Dynamically cycles through vibrant colors.
- **Game Mode Integration**: Supports Zombie:Reloaded and Zombie:Riot events.

## Directory Structure

```
shopkill_core/
├── .github/
│   └── workflows/
│       └── release.yml
├── .vscode/
│   └── settings.json
├── configs/
│   └── shopkill.cfg
├── plugins/
│   └── shopkill_core.smx
├── scripting/
│   └── shopkill_core.sp
├── translations/
│   └── shopkill_css.txt
├── CONTRIBUTING.md
├── LICENSE
└── README.md
```

## Installation

1. Place `plugins/shopkill_core.smx` into your server's `addons/sourcemod/plugins/` directory.
2. Place `configs/shopkill.cfg` into `addons/sourcemod/configs/`.
3. Place `translations/shopkill_css.txt` into `addons/sourcemod/translations/`.
4. Restart your server or run `sm plugins load shopkill_core`.

## Commands

| Command | Description |
|---|---|
| `!settings` / `sm_settings` | Core ClientPrefs settings menu listing plugin options (including ShopKill Settings). |
| `!skchat` / `!shopkillchat` | Cycles through notification modes (Chat -> Console -> HUD -> Off). |
| `!shopkillprefs` | Displays active reward preferences, HUD color, and VIP status. |

## ConVars

- `sm_shopkill_enabled` (default `1`): Enable/disable the plugin.
- `sm_shopkill_vip_multiplier` (default `2.0`): Multiplier applied to VIP players.
- `sm_shopkill_access_method` (default `1`): Access check method (`1` = Flags, `2` = VIP Core, `3` = Both).
- `sm_shopkill_access_flags` (default `o`): Admin flag required for VIP status when using flags.
- `sm_shopkill_vipcore_required` (default `1`): Require VIP Core when using VIP Core access.
- `sm_shopkill_advert_interval` (default `180.0`): Interval in seconds to broadcast the notification settings advertisement in chat (`0.0` = disabled).

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
