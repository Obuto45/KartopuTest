# KartopuTest: Qwen çalışma kuralları

Asıl kurallar `CLAUDE.md` dosyasında; onu oku ve uygula. Yanıtları Türkçe ver.

- Proje: Godot 4.7.2, saf GDScript, GodotSteam 4.24. Godot 4.7 API'sinde şüphen varsa önce `docs/engine-reference/godot/` oku.
- `addons/` altındaki üçüncü taraf koduna dokunma.
- Her değişiklik en küçük tam değişiklik olsun; davranış değiştiren kod için `tests/` altında test yaz.
- Godot'u çalıştıramadığın bir değişikliği "test edildi" diye bildirme.
- Alt ajanlar: `.qwen/agents/` (godot-specialist, godot-gdscript-specialist, godot-shader-specialist).
- MCP sunucuları: `.qwen/settings.json` (godot, chrome-devtools, playwright, context7). Godot yolu farklıysa `GODOT_PATH`'i düzelt.

Doğrulama:

```sh
godot --headless --path . --import
godot --headless --path . -s res://.claude/scripts/godot-parse-check.gd -- res://player.gd res://net.gd
godot --headless res://tests/autotest.tscn -- host   # ikinci süreçte: -- join
```
