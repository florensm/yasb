from core.validation.widgets.base_model import CallbacksConfig, CustomBaseModel, KeybindingConfig


class GlazewmOverviewPopupConfig(CustomBaseModel):
    blur: bool = True
    dark_mode: bool = True


class GlazewmOverviewColorsConfig(CustomBaseModel):
    # empty accent = the Windows accent color
    accent: str = ""
    base: str = "#161217"
    bg: str = "#221e24"
    surface: str = "#2d292e"
    text: str = "#e8e0e8"
    subtext: str = "#cdc3ce"
    # search hits
    blue: str = "#89b4fa"
    # the dim behind the cards; the alpha is how dark it gets
    scrim: str = "#99000000"


class GlazewmOverviewCallbacksConfig(CallbacksConfig):
    on_left: str = "toggle_overview"


class GlazewmOverviewConfig(CustomBaseModel):
    label: str = ""
    glazewm_server_uri: str = "ws://localhost:6123"
    monitor_exclusive: bool = True
    # columns in the all-workspaces grid (tab, or the toggle_overview_grid hotkey)
    grid_columns: int = 5
    # ms the overlay stays up after picking a workspace or window, e.g. set it to
    # GlazeWM's workspace_switch duration to hide the switch animation behind it
    close_delay: int = 0
    colors: GlazewmOverviewColorsConfig = GlazewmOverviewColorsConfig()
    popup: GlazewmOverviewPopupConfig = GlazewmOverviewPopupConfig()
    callbacks: GlazewmOverviewCallbacksConfig = GlazewmOverviewCallbacksConfig()
    keybindings: list[KeybindingConfig] = []
