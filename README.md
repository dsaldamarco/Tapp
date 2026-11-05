# Tapp

**Usa il tuo iPhone come tastiera e trackpad per il Mac.**

Tapp è una coppia di app native (iOS + macOS) scritte in SwiftUI. L'iPhone si collega al Mac in modalità wireless e diventa un trackpad multi-touch con tastiera: puoi muovere il puntatore, cliccare, scorrere, trascinare e scrivere senza toccare il Mac. È pensata per il divano, per le presentazioni o per un Mac collegato alla TV.

<p align="center">
  <img src="docs/screenshots/keyboard.png" width="250" alt="Modalità Tastiera: trackpad, tasti speciali e tastiera dell'iPhone">
  &nbsp;&nbsp;
  <img src="docs/screenshots/spacebar.png" width="250" alt="Modalità Spacebar: barra spaziatrice gigante e trackpad">
  &nbsp;&nbsp;
  <img src="docs/screenshots/connect.png" width="250" alt="Schermata di ricerca del Mac">
</p>

<p align="center"><sub>Modalità Tastiera · Modalità Spacebar · Ricerca del Mac</sub></p>

---

## Funzionalità

### 🖱️ Trackpad multi-touch
I gesti sono gli stessi del trackpad del Mac:

| Gesto | Azione |
|---|---|
| Muovi 1 dito | Sposta il puntatore (con accelerazione) |
| Tap | Click sinistro (due tap rapidi = doppio click) |
| **Tap con 2 dita** | **Click destro** |
| **Trascina con 2 dita** | **Scroll** verticale e orizzontale, con inerzia |
| Tieni premuto, poi muovi | Click e trascina (selezionare testo, spostare finestre e file) |

Ogni gesto dà un feedback aptico. Nelle impostazioni (⚙️) puoi regolare la velocità del puntatore e dello scroll e attivare o disattivare lo scorrimento naturale.

### ⌨️ Modalità Tastiera
Usa la **tastiera di sistema dell'iPhone**, con tasti grandi, accenti, emoji e dettatura. Il testo arriva al Mac così com'è, qualunque sia il layout di tastiera impostato sul Mac. Sopra la tastiera c'è una barra con i tasti che sull'iPhone mancano:

- `esc`, `⇥` (tab), frecce `← ↑ ↓ →` (tenendole premute il tasto si ripete)
- i modificatori `⌘ ⌥ ⌃ ⇧`: tocchi il modificatore, poi il tasto. Per esempio `⌘` e poi `c` copia, `⌘` e poi `⇥` cambia app, `⌥` e poi `⌫` cancella una parola

Il pulsante ⌨️ in alto nasconde la tastiera e lascia tutto lo schermo al trackpad.

### ␣ Modalità Spacebar
Una barra spaziatrice gigante e il trackpad. Va bene per mettere in pausa i video, scorrere le slide o giocare.

### 💻 App per Mac
Gira nella barra dei menu, accetta la connessione dell'iPhone da sola e trasforma i comandi ricevuti in eventi reali di tastiera e mouse. Supporta più monitor.

---

## Come funziona

```
┌──────────────┐   MultipeerConnectivity    ┌──────────────────┐
│   iPhone     │  (Wi-Fi / Bluetooth / P2P) │       Mac        │
│              │ ─────────────────────────▶ │                  │
│ touch, tasti │   pacchetti JSON           │ CGEvent → macOS  │
└──────────────┘                            └──────────────────┘
```

1. **Scoperta e connessione.** L'app Mac si annuncia sulla rete con **MultipeerConnectivity** (servizio `tapp-remote`). L'iPhone la trova e si collega da solo. Funziona via Wi-Fi, Bluetooth o Wi-Fi peer-to-peer e non serve configurare nulla.
2. **Protocollo.** Ogni azione (movimento, click, scroll, tasto, testo) diventa un piccolo `TappPacket` in JSON (vedi [`TappCore.swift`](Tapp/Tapp/TappCore.swift)). Movimento e scroll viaggiano in modalità *unreliable* per avere la latenza più bassa. Click e tasti usano la modalità *reliable*, così arrivano sempre e nell'ordine giusto.
3. **Iniezione sul Mac.** [`EventInjector`](Tapp/Tapp/TappMacOS/Services/EventInjector.swift) crea eventi `CGEvent` di sistema: movimento del mouse, click con *click state* (per i doppi click), scroll continuo a pixel come un trackpad vero e testo Unicode. Per farlo serve il permesso di **Accessibilità**.
4. **Riconnessione.** Se la connessione cade, l'iPhone si ricollega da solo. Mentre l'app è aperta lo schermo resta acceso.

### Struttura del progetto

```
Tapp/Tapp/
├── TappApp.swift              # @main unico per iOS e macOS
├── TappCore.swift             # Protocollo condiviso + mappa dei keycode Mac
├── TappIOS/
│   ├── Managers/              # ConnectionManager (MultipeerConnectivity), InputSender
│   └── Views/
│       ├── TrackpadView.swift     # Trackpad multi-touch in UIKit (gesti, scroll con inerzia)
│       ├── KeyboardView.swift     # Cattura della tastiera di sistema + barra dei tasti speciali
│       ├── SpacebarModeView.swift
│       ├── ControllerView.swift   # Layout, selettore della modalità, impostazioni
│       └── ConnectionView.swift
└── TappMacOS/
    ├── Services/              # NetworkServer, EventInjector, PermissionManager
    └── *View.swift            # Finestra di stato + menu nella barra dei menu
```

---

## Installazione

**Requisiti:** Xcode 26 o successivo, macOS 26 o successivo, iOS 26 o successivo, un Apple ID (basta quello gratuito) per firmare l'app.

1. Clona il repository e apri `Tapp/Tapp.xcodeproj`.
2. In **Signing & Capabilities** scegli il tuo *Team*. Se serve, cambia il *Bundle Identifier*.
3. **Mac:** seleziona la destinazione *My Mac* e premi ▶︎. Al primo avvio macOS chiede il permesso di **Accessibilità**: apri *Impostazioni di Sistema → Privacy e sicurezza → Accessibilità* e attiva **Tapp**.
4. **iPhone:** collega l'iPhone, selezionalo come destinazione e premi ▶︎. Quando l'app chiede di accedere alla **rete locale**, consenti.
5. Apri Tapp sull'iPhone: trova il Mac e si collega da solo. 🎉

> **Nota:** l'App Sandbox del Mac è disattivata (`ENABLE_APP_SANDBOX = NO`). È necessario, perché un'app in sandbox non può generare eventi di input di sistema.

### Problemi comuni

- **Il Mac non viene trovato:** controlla che Tapp sia aperto sul Mac (icona ⌨️ nella barra dei menu), che l'iPhone abbia il permesso *Rete locale* (Impostazioni → Privacy → Rete locale) e che Wi-Fi o Bluetooth siano attivi su entrambi.
- **Il puntatore si muove ma i click e i tasti non fanno nulla:** manca il permesso di Accessibilità. Dopo ogni nuova build, macOS può chiederlo di nuovo: in *Accessibilità* rimuovi Tapp con **–**, aggiungilo di nuovo e riavvia l'app.

---

## Sviluppo

Per vedere l'interfaccia iOS nel simulatore senza un Mac collegato, avvia l'app (build Debug) con l'argomento `-TappDemo`. L'app si comporta come se fosse già connessa. Gli screenshot qui sopra sono stati fatti così.

```bash
xcrun simctl launch booted <bundle-id> -TappDemo
```
