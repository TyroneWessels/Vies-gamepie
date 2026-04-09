# AutoDash - Code Toelichting

## Overzicht
AutoDash is een endless runner game gebouwd met LÖVE2D (Lua). De speler bestuurt een auto die obstakels moet ontwijken door te springen of te boosten.

## Architectuur

```
┌─────────────────────────────────────────────────────────────┐
│                        main.lua                             │
│  - Game loop (load, update, draw)                          │
│  - State management (MENU, PLAYING, GAMEOVER, ENTER_NAME)  │
│  - Responsieve schaling                                     │
└─────────────────────────┬───────────────────────────────────┘
                          │
    ┌─────────────────────┼─────────────────────┐
    │                     │                     │
    ▼                     ▼                     ▼
┌────────────┐     ┌─────────────┐      ┌────────────┐
│ player.lua │     │obstacle.lua │      │ score.lua  │
│ - Beweging │     │ - Spawning  │      │ - Scoring  │
│ - Jump/Boost│    │ - Collision │      │ - Leaderb. │
│ - Rendering │    │ - Thema's   │      │ - Opslag   │
└────────────┘     └─────────────┘      └────────────┘
                          │
                          ▼
                   ┌─────────────┐
                   │ levels.lua  │
                   │ - 6 thema's │
                   │ - Progressie│
                   └─────────────┘
```

## Modules

### main.lua
- **Game loop**: `love.load()`, `love.update(dt)`, `love.draw()`
- **Responsieve UI**: Automatische schaling van 1920x1080 naar elk schermformaat
- **State machine**: Menu → Playing → GameOver → Enter Name
- **Input handling**: Touch, muis en toetsenbord ondersteuning

### player.lua
- **Fysica**: Zwaartekracht (2400), springkracht (-980), snelheid (480/860)
- **Mechanica**: Jump, Boost met cooldown
- **6 auto types**: Verschillende kleuren en stijlen (sedan/sports)

### obstacle.lua
- **Obstakel types**: 18+ verschillende obstakels per thema
- **Animaties**: Rolling, hopping, floating, wobbling
- **Spawning**: Configureerbare spawn-intervallen per level

### levels.lua
- **6 Thema's**: Stad, Woestijn, Bos, Sneeuw, Ruimte, Vulkaan
- **Progressie**: Random volgorde, stijgende moeilijkheid
- **Visueel**: Unieke kleurenschema's per level

### score.lua
- **Score systeem**: 100 punten/seconde
- **Leaderboard**: Top 10 met namen, lokale opslag

### conf.lua
- **Venster configuratie**: Resizable, vsync, minimale grootte

## Belangrijke Constanten

| Constante | Waarde | Beschrijving |
|-----------|--------|--------------|
| BASE_WIDTH | 1920 | Virtuele breedte |
| BASE_HEIGHT | 1080 | Virtuele hoogte |
| GROUND_Y | 660 | Bovenkant asfalt |
| BASE_SPEED | 480 | Normale snelheid |
| BOOST_SPEED | 860 | Boost snelheid |
| JUMP_VELOCITY | -980 | Springkracht |
| GRAVITY | 2400 | Zwaartekracht |

## Game Flow

```
1. Menu
   └─> Selecteer level (1-6)
   └─> Selecteer auto (1-6)
   └─> Klik om te starten

2. Playing
   └─> Auto rijdt automatisch
   └─> SPRING knop = springen
   └─> BOOST knop = versnellen
   └─> Ontwijken obstakels
   └─> Levels wisselen automatisch

3. Game Over
   └─> Bij botsing met obstakel
   └─> Score wordt berekend

4. Enter Name
   └─> Naam invoeren voor leaderboard
   └─> Score opslaan
   └─> Terug naar menu
```
