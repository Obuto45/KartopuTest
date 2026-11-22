# KartopuTest: Gemini / Antigravity çalışma kuralları

Yanıtları Türkçe ver. Ayrıntılı proje kuralları `CLAUDE.md` dosyasında; onu da oku.

- Godot 4.7.2, saf GDScript. API'den emin değilsen önce `docs/engine-reference/godot/` oku.
- Godot yolu: `C:\Godot\Godot_v4.7.2-stable_win64_console.exe`.
- `addons/` altına dokunma. Her değişiklik küçük ve tam olsun.
- Godot'u çalıştırmadığın bir değişikliği "test edildi" diye bildirme.

## İşe başlamadan (pull)

Her zaman güncel `main` üzerinden yeni bir dalda çalış; eski dallarda (örn. `hunyuan-bazuka`) asla çalışma:

```sh
git fetch origin
git switch -c <kisa-is-adi> origin/main
```

Çalışma klasöründe commitlenmemiş değişiklik varsa önce kullanıcıya sor.

## Doğrulama

```sh
godot --headless --path . --import
godot --headless --path . -s res://.claude/scripts/godot-parse-check.gd -- res://<degisen>.gd
godot --path . res://tests/world_shots.tscn   # görsel değişiklikte: ekran görüntüleri + fps
```

Testler (`tests/world_test`, `tests/td_test`, `tests/weapons_test`) geçmeli. Godot'un değiştirdiği `.import` dosyalarını commit'e katma.

## Yayınlama (kullanıcı "yayınla" deyince)

1. `project.godot` içindeki `config/version` değerini artır (örn. 1.15 -> 1.16).
2. `docs/surum-notlari/vX.md` dosyasına kısa Türkçe sürüm notu yaz.
3. Yalnızca ilgili dosyaları `git add` et, commit at, push et: `git push -u origin <dal>`
4. PR aç ve birleştir:
   `gh pr create --base main --title "Sürüm X: ..." --body "..."`
   `gh pr merge <dal> --squash --delete-branch=false`
5. Derlemeyi başlat ve bekle: `gh workflow run release.yml --ref main`, ardından `gh run watch <id> --exit-status`
6. `gh release view vX` ile zip'in yüklendiğini doğrula ve indirme linkini kullanıcıya ver.

Yayın sonrası çalışma klasörünü güncel `main`'e al: `git switch main` ve `git pull origin main`.
