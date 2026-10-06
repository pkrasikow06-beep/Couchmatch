# Couchmatch

Filme und Serien entdecken wie beim Daten-Swipen: nur Titel von deinen Abos, mit echten Covern.

- **links** wischen = nicht interessiert
- **rechts** wischen = Merkliste
- **oben** wischen = schon gesehen und gut (ähnliche Genres kommen dann öfter)

Daten und Cover: [TMDB](https://www.themoviedb.org), Verfügbarkeit in Deutschland: JustWatch.
This product uses the TMDB API but is not endorsed or certified by TMDB.

## Einrichten

1. Neues GitHub-Repository `Couchmatch` (Public) anlegen.
2. **Add file → Upload files**: alle Dateien aus dem ZIP hineinziehen (die `.swift`-Dateien, `Info.plist`, `project.yml`, `icon-1024.png`, `README.md`) und **Commit changes**.
3. **Add file → Create new file**, Name `.github/workflows/build.yml`, Inhalt der Datei `build.yml` aus dem ZIP hineinkopieren und **Commit changes**.
4. **Settings → Secrets and variables → Actions → New repository secret**
   - Name: `TMDB_API_KEY`
   - Secret: dein TMDB-API-Schlüssel
5. **Actions → iPhone-App bauen → Run workflow**. Nach etwa 10–15 Minuten unten bei **Artifacts** die Datei **Couchmatch-ipa** herunterladen und entpacken.
6. `Couchmatch.ipa` wie bei Budget mit **Sideloadly** aufs iPhone spielen. Entwicklermodus und Vertrauen sind schon eingerichtet.

Wie bei Budget gilt mit kostenloser Apple-ID: alle 7 Tage neu mit Sideloadly aufspielen, deine Merkliste bleibt erhalten.
