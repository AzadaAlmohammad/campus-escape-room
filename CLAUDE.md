# Campus Escape Room — Arbeitsanweisungen

## Projektbeschreibung

Multiplayer-Escape-Room-Spiel auf einem Hochschul-Campus. 8-16+ Spieler in Teams (max 4 Teams à 4 Spieler) lösen Rätsel in verschiedenen Campus-Gebäuden (Cafeteria, Mensa, Raum T002, Exterior). LAN-only, Third-Person, reiner Puzzle-Fokus.

**Engine**: Godot 4.6 mit GDScript und Jolt Physics.

## Projektstruktur

```
scripts/autoload/     → Singletons (NetworkManager, GameManager, TeamManager)
scripts/player/       → Player Controller, Third-Person Camera
scripts/interaction/  → Interactable Base, Door, PickupItem, RayCast
scripts/inventory/    → Inventory System, ItemData Resource
scripts/puzzles/      → PuzzleBase und konkrete Puzzle-Typen
scripts/rooms/        → RoomBase Script
scripts/timer/        → GameTimer mit Netzwerk-Sync
scripts/ui/           → HUD, Lobby, TeamChat
scenes/               → .tscn Szenen-Dateien
resources/            → .tres Ressourcen (Items, Puzzle-Configs)
assets/               → 3D-Modelle (.glb), Texturen, Materialien
```

## Architektur-Regeln

1. **Server-autoritativ**: Alle Spielzustand-Änderungen laufen über den Host (peer_id=1). Clients senden Requests per RPC, Server validiert und broadcastet.
2. **Autoload-Singletons**: `NetworkManager`, `GameManager`, `TeamManager` sind in `project.godot` als Autoloads registriert. Direkt per Name zugreifen (z.B. `NetworkManager.players`).
3. **Interactable-Pattern**: Alle interaktiven Objekte erben von `Interactable` (extends StaticBody3D). Neue Typen als eigene Klasse erstellen.
4. **Puzzle-Pattern**: Alle Rätsel erben von `PuzzleBase` (extends Node3D). `_validate_solution(data)` überschreiben für die Lösungslogik.
5. **Physics-Layer**: Layer 1 = Environment, Layer 2 = Interactables, Layer 3 = Players.
6. **MultiplayerSynchronizer** für Position/Rotation-Sync. **RPCs** für Spielzustand (Puzzles, Inventar, Türen).

## Code-Konventionen

- GDScript mit statischer Typisierung wo möglich
- `class_name` für alle wiederverwendbaren Klassen
- Keine Comments außer bei nicht-offensichtlichem Verhalten
- Signals für lose Kopplung zwischen Systemen
- Alle RPCs mit expliziter `authority`/`any_peer` Annotation
- Szenen-Dateien (.tscn) in `scenes/`, Scripts in `scripts/`

## Workflow für Issues

1. `gh issue view <NR>` lesen
2. Branch erstellen: `git checkout -b issue-<NR>-<kurzbeschreibung>`
3. Implementieren wie im Issue beschrieben
4. Testen: `find . -name "*.gd" -exec grep -l "syntax" {} \;` (Syntax-Check via grep ist begrenzt — stelle sicher, dass der Code syntaktisch korrekt ist)
5. Committen mit aussagekräftiger Message
6. `git push -u origin <branch>`
7. PR erstellen mit `gh pr create --title "..." --body "..."`
8. Labels aktualisieren: `claude-task` entfernen, `pr-created` setzen

## Wichtige Abhängigkeiten zwischen Systemen

- `GameManager` hängt von `NetworkManager` und `TeamManager` ab
- `RoomBase` verbindet sich mit `TeamManager` und `GameManager`
- `InteractionRaycast` braucht `Interactable`-Objekte auf Physics Layer 2
- `Inventory` wird als Child-Node am Player-CharacterBody3D angehängt
- `PuzzleBase.attempt_solve()` nutzt RPCs zum Server

## Szenen-Erstellung (.tscn)

Godot .tscn Dateien sind Textdateien. Format:
```
[gd_scene load_steps=X format=3 uid="uid://..."]
[ext_resource type="Script" path="res://scripts/..." id="1"]
[node name="Root" type="NodeType"]
script = ExtResource("1")
[node name="Child" type="ChildType" parent="."]
```

Beim Erstellen von .tscn Dateien:
- `uid://` Werte mit `uid://` + zufälligem alphanumerischem String generieren
- `ext_resource` für externe Scripts/Ressourcen
- `sub_resource` für inline-Ressourcen (Shapes, Materials)
- Parent-Pfade: `"."` = direkt unter Root, `"Parent/Child"` für tiefere Verschachtelung
