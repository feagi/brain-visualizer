# FEAGI Mode Selection UI - Analysis & Recommendations

**Question:** Should we add a UI choice before loading sequence: "Run with FEAGI or without?"

**Date:** November 5, 2025

---

## Current Loading Sequence

```
App Launch
    ↓
BrainVisualizer._ready()
    ↓
FeagiCore.load_FEAGI_settings()
    ↓
FeagiCore.attempt_connection_to_FEAGI()
    ↓
┌─────────────────────────────────────┐
│  Connection Sequence (automatic)    │
├─────────────────────────────────────┤
│ 1. HTTP health check probe          │
│ 2. WebSocket connection attempt     │
│ 3. Agent registration              │
│ 4. Genome discovery                │
│ 5. Genome download                 │
│ 6. 3D scene initialization         │
└─────────────────────────────────────┘
    ↓
Loading screen shows:
 - "Checking FEAGI health..."
 - "Making WebSocket connection..."
 - "Loading genome..."
    ↓
All checks pass → Hide loading screen → Ready!
```

**Current behavior:** FEAGI connection is **mandatory** - app won't fully load without it.

---

## Proposed: Add Pre-Launch Mode Selection

### Option A: Splash Screen with Choice ⭐ **RECOMMENDED**

```
App Launch
    ↓
┌─────────────────────────────────────────────┐
│        FEAGI Mode Selection Screen          │
│                                             │
│  🦀 Brain Visualizer v2.0                  │
│                                             │
│  How would you like to run?                │
│                                             │
│  ┌────────────────────────────────────┐   │
│  │  ⚡ With FEAGI (Recommended)       │   │
│  │  └─ Neural processing enabled      │   │
│  │  └─ Full functionality             │   │
│  │                                     │   │
│  │  [Auto-detect]  [Embedded]  [Remote]│  │
│  └────────────────────────────────────┘   │
│                                             │
│  ┌────────────────────────────────────┐   │
│  │  📊 Viewer Only Mode               │   │
│  │  └─ 3D visualization only          │   │
│  │  └─ No neural processing           │   │
│  │  └─ Pre-recorded data playback     │   │
│  └────────────────────────────────────┘   │
│                                             │
│  [?] What's the difference?                │
└─────────────────────────────────────────────┘
```

**User Flow:**

**Choice 1: "With FEAGI" (Auto-detect)**
- Desktop with extension → EMBEDDED mode
- Desktop without extension → REMOTE mode (tries localhost, then prompts for URL)
- Web → REMOTE mode (requires cloud FEAGI)
- **Continues with existing loading sequence**

**Choice 2: "With FEAGI" (Force Embedded)**
- Only available if `FeagiEmbedded` extension detected
- Initializes embedded FEAGI
- **Skips network probing** (no health checks needed)
- **Faster startup** (~2 seconds vs ~5-10 seconds)

**Choice 3: "With FEAGI" (Force Remote)**
- Prompts for FEAGI server URL/IP
- Shows connection settings dialog
- **Continues with existing loading sequence**

**Choice 4: "Viewer Only Mode"**
- **NEW mode** - No FEAGI connection at all
- Loads pre-recorded genome data from file
- Plays back recorded neural activity (if available)
- 3D visualization only (no real-time processing)
- Useful for: Demos, screenshots, offline viewing

---

### Option B: Settings-Based (No UI Prompt)

```
App Launch
    ↓
FeagiModeDetector (automatic)
    ↓
[Auto-select mode based on: platform, extension, env vars, settings file]
    ↓
Continue with existing loading sequence
```

**User can change mode via:**
- Settings menu (after first launch)
- Environment variables
- Config file

**Pros:**
- ✅ No interruption to startup
- ✅ Smart defaults (works out of the box)
- ✅ Advanced users can customize

**Cons:**
- ❌ Users may not know they have embedded mode available
- ❌ No obvious way to switch modes for non-technical users

---

### Option C: Hybrid (Smart Default + Optional Override)

```
App Launch
    ↓
Auto-detect mode (silent)
    ↓
IF (first launch OR hold Shift key):
    Show mode selection screen
ELSE:
    Use detected mode
    ↓
Continue with loading sequence
```

**Pros:**
- ✅ Fast startup for repeat users
- ✅ Choice available when needed
- ✅ Power user friendly (Shift to override)

**Cons:**
- ❌ Shift key behavior might be confusing
- ❌ First-time users see extra screen

---

## "Without FEAGI" Mode - What Does It Mean?

### Interpretation 1: Offline Viewer Mode

**Use case:** View pre-recorded brain activity without FEAGI server

**Features:**
- Load genome from .brain.json file (static structure)
- Load recorded neural activity from .recording file
- Playback recorded bursts in 3D
- Scrub timeline, pause/play
- No real-time processing

**UX:**
```
Viewer Only Mode
    ↓
File → Open Genome (.brain.json)
    ↓
File → Open Recording (.recording.json) [optional]
    ↓
If recording loaded:
    Play/pause timeline
    Scrub to see activity at different times
Else:
    Show static brain structure only
```

**Technical:**
- No FeagiCore connection needed
- No HTTP or WebSocket
- Just load static JSON data
- Render 3D structure
- Optionally play back recorded activity

---

### Interpretation 2: Structure-Only Mode

**Use case:** View brain structure without any activity

**Features:**
- Load genome structure only
- 3D visualization of regions and areas
- No neural activity
- No FEAGI connection
- Useful for: Architecture review, screenshots, documentation

---

### Interpretation 3: Skip FEAGI Entirely

**Use case:** Testing BV UI without FEAGI dependency

**Features:**
- Mock/stub FEAGI responses
- UI testing and development
- No actual neural processing

---

## Recommendations

### For Your Use Case: Option A (Splash Screen) + Viewer Mode

**Why:**

1. **Clear choice for users**
   - "I want neural processing" → With FEAGI
   - "I just want to view" → Viewer Only

2. **Embedded mode discovery**
   - Users learn they have embedded option
   - Can choose embedded vs remote explicitly

3. **Offline capability**
   - Viewer mode doesn't need FEAGI
   - Good for demos, screenshots

4. **Doesn't break existing flow**
   - "With FEAGI" continues current loading sequence
   - All existing code works

### UI Design Proposal

**Splash screen** (1-2 seconds, skippable):

```
┌─────────────────────────────────────────────┐
│  FEAGI Brain Visualizer v2.0                │
├─────────────────────────────────────────────┤
│                                             │
│  How would you like to use Brain Visualizer?│
│                                             │
│  ┌──────────────────────────────────────┐  │
│  │ ⚡ WITH FEAGI (Neural Processing)   │  │
│  │                                      │  │
│  │ Real-time brain simulation           │  │
│  │                                      │  │
│  │ 🦀 Embedded  🌐 Remote  🤖 Auto     │  │
│  └──────────────────────────────────────┘  │
│          [Click or press Enter]             │
│                                             │
│  ┌──────────────────────────────────────┐  │
│  │ 📊 VIEWER ONLY (No Processing)      │  │
│  │                                      │  │
│  │ View genome structure & recordings   │  │
│  │ No FEAGI server required             │  │
│  └──────────────────────────────────────┘  │
│          [Click or press V]                 │
│                                             │
│  ☑ Remember my choice (skip this screen)   │
│                                             │
│  Auto-selecting in 5 seconds... [Skip →]   │
└─────────────────────────────────────────────┘
```

**Features:**
- Auto-select default after 5 seconds (no wait)
- Checkbox to remember choice
- Keyboard shortcuts (Enter, V)
- Skip button (continues immediately)

**After selection:**
- **With FEAGI** → Current loading sequence (unchanged)
- **Viewer Only** → Skip to file picker for genome/recording

---

## Implementation Approach

### 1. Create Splash Scene

**File:** `godot_source/SplashScreen/ModeSelectionSplash.tscn`

**Components:**
- Background (themed)
- Title label
- Two choice buttons
- Sub-options (embedded/remote/auto)
- Remember checkbox
- Skip/countdown timer
- Help/info button

### 2. Modify Startup Flow

**File:** `BrainVisualizer.gd`

**Before:**
```gdscript
func _ready():
    # Immediately connect to FEAGI
    FeagiCore.attempt_connection_to_FEAGI(...)
```

**After:**
```gdscript
func _ready():
    # Check if user has saved preference
    var saved_mode = _load_saved_mode_preference()
    
    if saved_mode:
        # Skip splash, use saved preference
        _initialize_with_mode(saved_mode)
    else:
        # Show splash screen
        _show_mode_selection_splash()

func _show_mode_selection_splash():
    var splash = preload("res://SplashScreen/ModeSelectionSplash.tscn").instantiate()
    add_child(splash)
    splash.mode_selected.connect(_on_mode_selected)

func _on_mode_selected(mode: String):
    # mode = "feagi_auto", "feagi_embedded", "feagi_remote", or "viewer_only"
    _initialize_with_mode(mode)

func _initialize_with_mode(mode: String):
    match mode:
        "feagi_auto", "feagi_embedded", "feagi_remote":
            # Existing flow (unchanged)
            FeagiCore.attempt_connection_to_FEAGI(...)
        "viewer_only":
            # New: Skip FEAGI, show file picker
            _show_genome_file_picker()
```

### 3. Add Viewer-Only Mode

**File:** `godot_source/ViewerOnlyMode.gd` (NEW)

```gdscript
## Viewer-only mode - loads genome structure without FEAGI
func load_genome_structure_only(genome_path: String):
    # Parse .brain.json
    # Build 3D structure
    # Show static brain
    # No neural activity (unless recording loaded)

func load_recording(recording_path: String):
    # Load pre-recorded neural activity
    # Provide playback controls
    # Scrub timeline
```

---

## When to Show the Splash

### First Launch
- ✅ Show splash (no saved preference)
- User makes choice
- Save preference if "remember" checked

### Subsequent Launches
- ❌ Skip splash (use saved preference)
- User can change via Settings menu
- Or hold Shift key to force splash

### Web Builds
- ❌ Skip splash (only REMOTE mode possible)
- Or show simplified version (just connection settings)

---

## User Experience Scenarios

### Scenario 1: New User (Desktop, Embedded Available)

```
Launch BV → Splash appears
    ↓
User clicks "With FEAGI - Auto"
    ↓
BV detects embedded extension
    ↓
Shows "Initializing FEAGI..." (2-3 seconds)
    ↓
Ready! (no external FEAGI needed)
```

### Scenario 2: Developer (Desktop, Remote Preferred)

```
Launch BV → Splash appears
    ↓
User clicks "With FEAGI - Remote"
    ↓
Dialog: "Enter FEAGI server address"
User enters: "192.168.1.100:8000"
    ↓
BV connects to remote FEAGI
    ↓
Existing health check sequence
    ↓
Ready!
```

### Scenario 3: Presenter (No FEAGI Available)

```
Launch BV → Splash appears
    ↓
User clicks "Viewer Only"
    ↓
File picker: "Select genome file"
User selects: "demo_brain.json"
    ↓
Optionally: "Load recording?" → "demo_activity.recording"
    ↓
Ready! (static or playback mode)
```

### Scenario 4: Repeat User (Desktop)

```
Launch BV → No splash (remembered choice)
    ↓
Automatically uses saved mode (e.g., embedded)
    ↓
Ready!
```

---

## Technical Considerations

### 1. Embedded Mode (With FEAGI - Auto/Embedded)

**Advantages of splash screen:**
- ✅ User explicitly chooses embedded
- ✅ Can show "initializing FEAGI..." progress
- ✅ Sets expectations (FEAGI is starting)

**Could skip splash:**
- If embedded extension available → just start it automatically
- Show brief notification: "Starting embedded FEAGI..."
- Faster UX (no user interaction needed)

### 2. Remote Mode (With FEAGI - Remote)

**Advantages of splash screen:**
- ✅ User can enter custom FEAGI URL
- ✅ Choice between local/remote FEAGI
- ✅ Save multiple FEAGI servers

**Could skip splash:**
- Try localhost first (existing behavior)
- If fails, then prompt for URL
- Existing retry logic works

### 3. Viewer-Only Mode

**Requires splash screen:**
- ❌ Can't auto-detect (user must choose)
- ❌ Needs file picker for genome
- ✅ Useful feature for offline/demo

---

## My Recommendations

### Recommendation 1: Smart Default + Quick Access (Best UX)

**Default behavior (no splash):**
```
Desktop + Embedded extension
→ Auto-start embedded FEAGI (show brief toast: "Starting embedded FEAGI...")
→ Skip health checks (in-process, guaranteed available)
→ Fastest startup

Desktop + No extension
→ Try localhost:8000
→ If fails, show connection dialog
→ Existing flow

Web
→ Connect to URL param or default
→ Existing flow
```

**Quick access (optional):**
- Hold **Shift** during launch → Show full mode selection splash
- Settings menu → "Connection Settings" → Can switch modes
- First launch → Show brief tooltip: "Hold Shift for connection options"

**Why this is best:**
- ✅ Zero-click startup for embedded mode (optimal UX)
- ✅ Existing flow preserved for remote mode
- ✅ Advanced options available (Shift key)
- ✅ No unnecessary prompts for 90% of users
- ✅ Professional UX (like holding Option on Mac for boot menu)

---

### Recommendation 2: Always Show Splash (More Discoverable)

**Every launch:**
```
Show splash with 3-second auto-select countdown
User can click choice immediately (skip countdown)
Or wait 3 seconds → auto-selects default
```

**Why this might be good:**
- ✅ Users always know mode options exist
- ✅ Easy to switch modes
- ✅ Clear what's happening

**Why this might be annoying:**
- ❌ 3-second wait every launch (unless clicked)
- ❌ Repetitive for users who always use same mode
- ❌ Extra click/wait on every startup

---

### Recommendation 3: Hybrid (Context-Sensitive)

**Show splash ONLY when:**
1. First launch (no saved preference)
2. Embedded extension newly available (user might not know)
3. Connection to saved FEAGI fails (prompt for new server)
4. User holds Shift key
5. User explicitly opens Settings → Connection

**Otherwise:** Use saved/detected mode silently

**Why this is smart:**
- ✅ Best of both worlds
- ✅ No interruption for repeat users
- ✅ Guidance when needed
- ✅ Discoverable but not annoying

---

## Alternative: In-App Mode Switcher

**Instead of splash screen, add to main UI:**

```
Top Bar:
  FEAGI Status: [🟢 Embedded Mode ▼]
                  ├─ Switch to Remote Mode
                  ├─ Switch to Viewer Only
                  └─ Connection Settings...
```

**Advantages:**
- ✅ No startup interruption
- ✅ Always visible and accessible
- ✅ Can switch modes without restart
- ✅ Status indicator (users know current mode)

**Implementation:**
```gdscript
# TopBar.gd
func _on_feagi_mode_button_pressed():
    var popup = PopupMenu.new()
    popup.add_item("🦀 Embedded Mode", 0)
    popup.add_item("🌐 Remote Mode", 1)
    popup.add_item("📊 Viewer Only", 2)
    popup.add_separator()
    popup.add_item("⚙️ Connection Settings...", 3)
    
    popup.id_pressed.connect(_on_mode_selected)
    popup.popup()
```

---

## My Final Recommendation

**Combine Recommendation 1 + Alternative:**

### **A. Smart Auto-Detection (Default)**

```
App Launch
    ↓
Auto-detect and use best mode (silent)
    ↓
Show brief notification (2 sec):
 "Using Embedded FEAGI" or
 "Connecting to Remote FEAGI" or
 "Viewer Only Mode"
    ↓
Continue loading
```

### **B. Mode Indicator + Switcher in UI**

```
Top Bar (always visible):
  [🟢 FEAGI: Embedded ▼]
  
Click dropdown:
  • Embedded Mode (current)
  • Remote Mode
  • Viewer Only
  ─────────────
  ⚙️ Connection Settings...
```

### **C. Settings Menu for Advanced Options**

```
Settings → Connection
  
  FEAGI Mode:
    ○ Auto-detect (recommended)
    ○ Always use embedded
    ○ Always use remote
    ○ Viewer only (no FEAGI)
  
  [If Remote selected:]
    Server URL: [http://127.0.0.1:8000    ]
    WebSocket:  [ws://127.0.0.1:9050      ]
    [Test Connection]
```

---

## Benefits of This Approach

| Aspect | Benefit |
|--------|---------|
| **First launch** | Zero clicks - works immediately |
| **Embedded users** | Instant startup (no health checks needed) |
| **Remote users** | Existing flow preserved |
| **Discovery** | Mode indicator visible in UI |
| **Switching** | One click dropdown, no restart needed |
| **Advanced** | Settings for custom servers |
| **Professional** | No annoying splash screen every time |

---

## Comparison Table

| Approach | Startup Speed | Discoverability | Flexibility | Complexity |
|----------|---------------|-----------------|-------------|------------|
| **Option A (Splash)** | Slow (-3 sec) | ⭐⭐⭐ High | ⭐⭐ Medium | Low |
| **Option B (Settings)** | Fast | ⭐ Low | ⭐⭐⭐ High | Low |
| **Option C (Hybrid)** | Medium | ⭐⭐ Medium | ⭐⭐⭐ High | Medium |
| **My Rec (Smart+UI)** | ⭐⭐⭐ Fast | ⭐⭐⭐ High | ⭐⭐⭐ High | Medium |

---

## Questions for You

Before I implement, please clarify:

### 1. What does "without FEAGI" mean for your use case?
   - A) Viewer-only mode (static genome + optional recordings)?
   - B) Skip FEAGI entirely (for UI testing)?
   - C) Something else?

### 2. What's more important?
   - A) Fast startup (auto-detect, no prompts)
   - B) User control (always show choice)
   - C) Balance (smart defaults + easy switching)

### 3. Should mode be switchable without restart?
   - A) Yes - add UI switcher in top bar
   - B) No - require app restart to change modes
   - C) Depends on mode (embedded → remote = restart, remote → viewer = no restart)

### 4. For embedded mode specifically:
   - A) Auto-start if extension available (fast, zero-click)
   - B) Always ask user (confirm they want embedded)
   - C) Show brief notification but no interaction needed

---

## My Personal Recommendation

**Go with "Smart Auto + UI Switcher" because:**

1. **Best user experience:**
   - Embedded users: Instant startup, no clicks
   - Remote users: Existing flow works
   - All users: Can see and switch modes easily

2. **Professional:**
   - No annoying splash every time
   - Mode visible but not intrusive
   - Advanced options in settings

3. **Flexible:**
   - Can add viewer-only mode later
   - Can switch modes on the fly (if FEAGI supports hot-swap)
   - Environment overrides for power users

**Startup flow:**
```
0.0s: App launches
0.1s: Auto-detect mode (background)
0.2s: Show brief toast: "🦀 Starting Embedded FEAGI..."
2.0s: FEAGI ready
2.5s: Connection established
3.0s: Genome loaded
5.0s: Ready to use!

Total: 5 seconds (no user interaction needed)
```

---

**What do you think?** Should we go with:
- **A)** Smart auto-detection (my recommendation)
- **B)** Always show splash
- **C)** Something else

And what should "without FEAGI" mode do? 🤔
