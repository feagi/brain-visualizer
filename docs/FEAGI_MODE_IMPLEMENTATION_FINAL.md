# FEAGI Mode Selection - Final Implementation Plan

**Based on user requirements - November 5, 2025**

---

## Requirements (Confirmed)

### 3 Runtime Modes

1. **Desktop + Embedded FEAGI** (default for desktop)
   - FEAGI runs in-process
   - Auto-starts on desktop launch
   - No user prompt needed
   - Can switch to remote via Settings

2. **Desktop + Remote FEAGI** (opt-in)
   - User manually selects in Settings
   - Connects via WebSocket to external FEAGI
   - Same as current desktop behavior

3. **HTML5 + Remote FEAGI** (only option for web)
   - Automatic (no embedded option for web)
   - Uses existing WebSocket flow
   - URL parameters work (unchanged)

---

## Implementation

### 1. Early Platform Detection (FeagiModeDetector)

**File:** `godot_source/Autoload/FeagiModeDetector.gd` (ALREADY CREATED ✅)

**Logic:**
```gdscript
func _enter_tree():
    if OS.has_feature("web"):
        mode = REMOTE_WEB
        # Use existing WebSocket + URL param behavior
    
    elif OS.has_feature("desktop"):
        # Check user preference in settings
        var user_pref = load_settings()
        
        if user_pref == "remote":
            mode = REMOTE_DESKTOP
            # User explicitly chose remote
        
        elif ClassDB.class_exists("FeagiEmbedded"):
            mode = EMBEDDED
            # Default to embedded if available
        
        else:
            mode = REMOTE_DESKTOP
            # Fallback to remote if no extension
```

**No splash screen, no prompts - just smart detection!**

---

### 2. Desktop: Auto-Launch Embedded FEAGI

**File:** `BrainVisualizer.gd`

**Current:**
```gdscript
func _ready():
    FeagiCore.load_FEAGI_settings(FEAGI_configuration)
    FeagiCore.attempt_connection_to_FEAGI(default_FEAGI_network_settings)
```

**New:**
```gdscript
func _ready():
    FeagiCore.load_FEAGI_settings(FEAGI_configuration)
    
    # Check detected mode
    if FeagiModeDetector.is_embedded():
        # Desktop with embedded FEAGI
        _initialize_embedded_feagi()
    else:
        # HTML5 or desktop remote mode
        FeagiCore.attempt_connection_to_FEAGI(default_FEAGI_network_settings)

func _initialize_embedded_feagi():
    print("🦀 Initializing embedded FEAGI (desktop mode)...")
    
    # Create embedded FEAGI instance
    var feagi_embedded = ClassDB.instantiate("FeagiEmbedded")
    add_child(feagi_embedded)
    feagi_embedded.name = "FeagiEmbedded"
    
    # Initialize
    if feagi_embedded.initialize_default():
        print("✅ Embedded FEAGI initialized")
        feagi_embedded.start()
        
        # Wire to FeagiCore
        FeagiCore.set_embedded_feagi(feagi_embedded)
        
        # Skip health checks - FEAGI is guaranteed available
        # Continue with existing flow (genome loading, etc.)
    else:
        push_error("Failed to initialize embedded FEAGI - falling back to remote")
        # Fallback: Try remote mode
        FeagiCore.attempt_connection_to_FEAGI(default_FEAGI_network_settings)
```

---

### 3. HTML5: Use Existing WebSocket Flow (Unchanged)

**No changes needed!**

**Current behavior preserved:**
```gdscript
# In FeagiCore.gd or BrainVisualizer.gd
if OS.has_feature("web"):
    # Read URL parameters via JavaScript
    var feagi_url = JavaScriptIntegrations.get_url_param("feagi_url")
    
    # Connect via WebSocket (existing code)
    attempt_connection_to_FEAGI(endpoint_details)
```

**URL parameters continue to work:**
```
https://bv.example.com/?feagi_url=wss://feagi-server.com:9050
```

---

### 4. Settings Menu: Allow Switching to Remote

**File:** `godot_source/BrainVisualizer/UI/Settings/ConnectionSettings.gd` (NEW)

**UI:**
```
┌─────────────────────────────────────────┐
│  Connection Settings                    │
├─────────────────────────────────────────┤
│                                         │
│  FEAGI Mode:                            │
│    ○ Embedded (in-process, recommended) │
│    ● Remote (external server)           │
│                                         │
│  [If Remote selected:]                  │
│                                         │
│  Server Configuration:                  │
│    HTTP API:  [http://127.0.0.1:8000  ]│
│    WebSocket: [ws://127.0.0.1:9050    ]│
│                                         │
│    [Test Connection]  [Save]           │
│                                         │
│  ⚠️ Changing modes requires restart    │
└─────────────────────────────────────────┘
```

**Implementation:**
```gdscript
extends Control

func _on_mode_changed(mode: String):
    # Save to user://feagi_connection_settings.json
    var settings = {
        "mode": mode,  # "embedded" or "remote"
        "api_url": $APIUrlInput.text,
        "ws_host": $WSHostInput.text,
        "ws_port": int($WSPortInput.text)
    }
    
    # Save
    FeagiModeDetector.save_user_preference(settings)
    
    # Show restart prompt
    $RestartPrompt.popup()
```

---

## Startup Flow

### Desktop (Embedded Extension Available)

```
0.0s: Launch BV
0.1s: FeagiModeDetector._enter_tree()
      → Detects: desktop + FeagiEmbedded class exists
      → Mode: EMBEDDED

0.2s: BrainVisualizer._ready()
      → Checks: FeagiModeDetector.is_embedded() → true
      → Creates FeagiEmbedded instance
      → Calls: feagi_embedded.initialize_default()

2.0s: FEAGI initialized (in-process)
2.1s: Calls: feagi_embedded.start()
2.2s: Burst engine running

2.3s: FeagiCore continues normal flow
      → Skip network health checks (FEAGI is in-process)
      → Query genome via HTTP localhost
      → Load genome
      → Initialize 3D scene

5.0s: Ready! (loading screen hidden)

USER SAW: Brief loading screen, no prompts
```

---

### Desktop (No Extension OR User Selected Remote in Settings)

```
0.0s: Launch BV
0.1s: FeagiModeDetector._enter_tree()
      → Detects: desktop, no extension OR user pref = "remote"
      → Mode: REMOTE_DESKTOP

0.2s: BrainVisualizer._ready()
      → Checks: FeagiModeDetector.is_embedded() → false
      → Uses existing flow:
         FeagiCore.attempt_connection_to_FEAGI(...)

0.3s: HTTP health check to localhost:8000
1.0s: WebSocket connection to localhost:9050
2.0s: Agent registration
3.0s: Genome discovery and download
5.0s: Ready!

USER SAW: Existing loading sequence (unchanged)
```

---

### HTML5

```
0.0s: Launch BV (in browser)
0.1s: FeagiModeDetector._enter_tree()
      → Detects: OS.has_feature("web") → true
      → Mode: REMOTE_WEB

0.2s: BrainVisualizer._ready()
      → Checks: FeagiModeDetector.is_embedded() → false
      → Uses existing flow:
         JavaScriptIntegrations.get_url_params()
         FeagiCore.attempt_connection_to_FEAGI(...)

0.5s: WebSocket connection to cloud FEAGI
2.0s: Agent registration
3.0s: Genome download
6.0s: Ready!

USER SAW: Existing web loading sequence (unchanged)
```

---

## Code Changes Required

### Minimal Changes (3 files)

1. **FeagiModeDetector.gd** ✅ (already done)
2. **BrainVisualizer.gd** - Add mode check + embedded initialization (~30 lines)
3. **Settings UI** - Add connection settings panel (~100 lines, optional)

**No changes to:**
- ❌ FeagiCore.gd (works with both modes)
- ❌ FEAGINetworking.gd (remote mode uses this unchanged)
- ❌ Loading screen logic (works for both)
- ❌ Web build (completely unchanged)

---

## Benefits

### For Users

| User Type | Mode | Experience |
|-----------|------|------------|
| **Premium Desktop** | Embedded (default) | Zero-click startup, instant FEAGI |
| **Developer** | Remote (via Settings) | Connect to shared/remote FEAGI |
| **Web** | Remote (only option) | Existing behavior (unchanged) |

### For Development

- ✅ Minimal code changes
- ✅ Existing web flow untouched
- ✅ Existing remote flow untouched
- ✅ Only adds embedded path (new capability)

---

## My Recommendation

**Implement exactly as you described:**

1. **Early detection** ✅ (FeagiModeDetector - already done)
2. **Desktop default** → Embedded FEAGI (auto-launch)
3. **Settings option** → Switch to remote mode
4. **HTML5** → Remote only (existing behavior)
5. **No splash screens** → Fast, seamless startup

**This gives you:**
- Zero-click desktop experience (embedded)
- Full flexibility for power users (Settings)
- Web builds completely unchanged
- Professional UX (no annoying prompts)

---

**Should I proceed with implementing the BrainVisualizer.gd changes to auto-launch embedded FEAGI on desktop?** 🚀

