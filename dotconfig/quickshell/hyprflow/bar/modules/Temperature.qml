// A hwmon sensor (`path`, a glob is fine); past `critical` °C it turns red.
import QtQuick
import qs
import qs.bar

Module {
    property int celsius: 0
    icon: "\u{F050F}"
    iconColor: celsius >= (settings.critical ?? 80) ? "#f7768e" : Colors.foreground
    tooltip: "Temperature"
    poll: ["sh", "-c", "cat " + (settings.path ?? "/sys/class/thermal/thermal_zone0/temp")]
    interval: settings.interval ?? 10
    onPolled: out => {
        celsius = Math.round(Number(out.trim().split("\n")[0]) / 1000);
        text = celsius + "°C";
    }
}
