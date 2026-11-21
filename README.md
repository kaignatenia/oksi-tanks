# Oksi Tanks

Самостоятельная танковая игра (Godot 4.7, Android), выделенная из Oksi Block.
Package ID: `com.kaignatenia.oksitanks` (до регистрации в Play Console проверить, что свободен).

## Структура
- `scripts/tanks.gd` — бой (перенесён из Oksi Block без изменений, кроме пути к данным).
- `scripts/tank_art.gd` — картинки танков и предметов.
- `scripts/tank_data.gd` — танки, арены, апгрейды, сложности, награды, музыка.
- `scripts/app.gd` — оболочка: меню, гараж (бой / танки / апгрейды / арены), настройки, экономика, музыка, сохранение `user://oksi_tanks_save.cfg`.
- `i18n/*.json` — 13 языков, только танковые тексты.
- `tests/test_run.gd` — тесты оболочки, экономики, сохранения и механики боя.
- `tools/shots.gd` — скриншоты всех экранов для согласования дизайна.

## Запуск
```
godot --headless --path . --import
godot --headless --path . --script res://tests/test_run.gd
xvfb-run -s "-screen 0 720x1280x24" godot --path . --rendering-driver opengl3 --script res://tools/shots.gd
```

## Пока не сделано
Neon/Titan за реальные деньги (нужны товары в Play Console), VIP/напарник, лидерборд Play Games (нужен новый game id),
импорт прогресса из Oksi Block, релизная подпись, собственная иконка (сейчас временно иконка Oksi Block).
