#!/bin/bash
# karin-shell: без hyprshutdown — сразу выключаем/перезагружаем/выходим.
# (VS Code и большинство редакторов сами восстанавливают несохранённое при следующем запуске.)

case "$1" in
    shutdown)
        (setsid systemctl poweroff &>/dev/null &);;
    reboot)
        (setsid systemctl reboot &>/dev/null &);;
    logout)
        (setsid bash -c "hyprctl dispatch 'hl.dsp.exit()' || hyprctl dispatch exit" &>/dev/null &);;
    *)
        exit 1
        ;;
esac
