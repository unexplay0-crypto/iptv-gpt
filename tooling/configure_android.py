#!/usr/bin/env python3
"""Apply Android TV and network compatibility settings to Flutter's generated manifest."""
from pathlib import Path
import sys
import re
import xml.etree.ElementTree as ET

ANDROID_NS = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", ANDROID_NS)


def attr(name: str) -> str:
    return f"{{{ANDROID_NS}}}{name}"


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("Uso: configure_android.py caminho/AndroidManifest.xml")
    path = Path(sys.argv[1])
    if not path.is_file():
        raise SystemExit(f"Manifest não encontrado: {path}")

    tree = ET.parse(path)
    root = tree.getroot()
    app = root.find("application")
    if app is None:
        raise SystemExit("O Manifest não contém a tag <application>.")

    app.set(attr("label"), "UNEX Vision")
    app.set(attr("allowBackup"), "false")
    # Compatibility for older IPTV endpoints; HTTPS should still be preferred.
    app.set(attr("usesCleartextTraffic"), "true")

    # Network permissions are required by IPTV, XMLTV, metadata and release checks.
    internet_permission = next(
        (node for node in root.findall("uses-permission") if node.get(attr("name")) == "android.permission.INTERNET"),
        None,
    )
    if internet_permission is None:
        internet_permission = ET.Element("uses-permission")
        internet_permission.set(attr("name"), "android.permission.INTERNET")
        root.insert(0, internet_permission)

    required_features = {
        "android.software.leanback": "false",
        "android.hardware.touchscreen": "false",
    }
    for feature_name, required in required_features.items():
        found = next(
            (node for node in root.findall("uses-feature") if node.get(attr("name")) == feature_name),
            None,
        )
        if found is None:
            found = ET.Element("uses-feature")
            found.set(attr("name"), feature_name)
            root.insert(list(root).index(app), found)
        found.set(attr("required"), required)

    launch_filters = []
    for intent_filter in app.findall("activity/intent-filter"):
        actions = {node.get(attr("name")) for node in intent_filter.findall("action")}
        categories = {node.get(attr("name")) for node in intent_filter.findall("category")}
        if "android.intent.action.MAIN" in actions and "android.intent.category.LAUNCHER" in categories:
            launch_filters.append(intent_filter)

    if not launch_filters:
        # This handles alternative Flutter templates that separate categories.
        for activity in app.findall("activity"):
            has_main = any(node.get(attr("name")) == "android.intent.action.MAIN" for node in activity.findall("intent-filter/action"))
            if has_main:
                launch_filters = activity.findall("intent-filter")[:1]
                break

    if not launch_filters:
        raise SystemExit("Não foi encontrado um intent-filter de inicialização no Manifest.")

    for intent_filter in launch_filters:
        categories = {node.get(attr("name")) for node in intent_filter.findall("category")}
        if "android.intent.category.LEANBACK_LAUNCHER" not in categories:
            node = ET.SubElement(intent_filter, "category")
            node.set(attr("name"), "android.intent.category.LEANBACK_LAUNCHER")

    tree.write(path, encoding="utf-8", xml_declaration=True)

    # Current shared_preferences Android implementation requires Android API 24+. Keep the generated
    # native project aligned with that dependency instead of the template minimum.
    app_dir = path.parents[2]
    gradle_files = [app_dir / "build.gradle.kts", app_dir / "build.gradle"]
    for gradle_path in gradle_files:
        if not gradle_path.is_file():
            continue
        source = gradle_path.read_text(encoding="utf-8")
        if gradle_path.name.endswith(".kts"):
            source = re.sub(r"minSdk\s*=\s*(?:flutter\.minSdkVersion|\d+)", "minSdk = 24", source)
        else:
            source = re.sub(r"minSdkVersion\s+(?:flutter\.minSdkVersion|\d+)", "minSdkVersion 24", source)
        gradle_path.write_text(source, encoding="utf-8")
        break

    print(f"Manifest Android configurado: {path}")


if __name__ == "__main__":
    main()
