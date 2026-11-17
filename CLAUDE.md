# KartopuTest: Claude çalışma kuralları

Kullanıcının kalıcı isteği: **her işte gereken araç, skill ve ajanı kendiliğinden kullan, izin sorma.** Gereksiz olanı da kullanma: bir iş için tek skill, alt ajan yalnızca büyük işte ya da ayrı uzmanlık gerektiğinde.

Proje: Godot 4.7.2, saf GDScript, GodotSteam 4.24 (Steam lobisi + `SteamMultiplayerPeer`, `net.gd`). Godot 4.7, model bilgisinden yeni: API konusunda şüphen varsa önce `docs/engine-reference/godot/` oku. Bulut oturumunda Godot kurulu değil; Godot komutlarını kullanıcıya ver.

## Hangi iş, hangi araç

| İş | Kullan |
|---|---|
| Kodu anlamak, sembol bulmak, çağıranları izlemek | codebase-memory MCP (`search_graph`, `trace_path`, `get_code_snippet`); düz metin için Grep |
| GDScript yazmak / düzeltmek | `godot-gdscript-specialist` ajanı veya `godot-gdscript-patterns` skill |
| Sahne, düğüm mimarisi, sinyaller | `godot-specialist` ajanı; `.tscn`/`.tres` için `.claude/rules/scene-files.md` |
| Shader, materyal, efekt | `godot-shader-specialist` ajanı |
| Yeni özellik (örn. `TASKS.md`'deki tower defense) | `game-design` → `planning-and-task-breakdown` → `incremental-implementation` |
| Hata, çökme, beklenmeyen davranış | `debugging-and-error-recovery` |
| Davranış değiştiren kod | Testi `tests/` altında yaz (`test-driven-development`) |
| Her kod değişikliği | ponytail + `karpathy-guidelines`: en küçük tam değişiklik |
| Menü, HUD, arayüz tasarımı | `ui-ux-pro-max` (yalnızca tasarım ilkeleri; Godot `Control` düğümleriyle uygula, web kodu üretme) |
| Steam mağaza görselleri | `ui-ux-pro-max:banner-design` |
| Ses ve müzik | `game-audio`; 3D render ve kamera için `3d-games` |
| Kod incelemesi | `/code-review` veya `agent-skills:code-reviewer`; güvenlik için `/security-review` |
| Commit, push, PR | `commit-commands:commit` / `commit-push-pr` |
| Mimari diyagram | `diagram-design` |
| Tanıtım videosu | `brag` |
| Tekrarlayan hata ya da istenmeyen davranış | `hookify` ile kural öner |

## Kullanma

- Web'e özel skill'ler: `frontend-ui-engineering`, `browser-testing-with-devtools`, `web-performance-auditor`, `ui-styling`, `slides`.
- `unity-developer`, ve ponytail varken ayrıca `code-simplification`.
- `addons/` altındaki üçüncü taraf kodunu düzenleme. netfox ve PankuConsole kapalı; açmak oyuna autoload ekler, önce kullanıcıya sor.

## Doğrulama (kullanıcının bilgisayarında)

```sh
godot --headless --path . --import
godot --headless --path . -s res://.claude/scripts/godot-parse-check.gd -- res://player.gd res://net.gd
godot --headless res://tests/autotest.tscn -- host   # ikinci süreçte: -- join
```

Godot'u çalıştıramadığın bir değişikliği "test edildi" diye bildirme; neyin denenmediğini söyle.
