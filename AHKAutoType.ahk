#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; TRAY MENU & GLOBAL SETTINGS
; ==============================================================================
global isTyping := false
TraySetIcon("shell32.dll", 70) ; Set a keyboard-like icon (optional)

; Custom Tray Menu
A_TrayMenu.Delete() ; Clear standard menu
A_TrayMenu.Add("Settings", ShowGui)
; FIX 1: Wrapped ExitApp in a lambda to ignore menu parameters
A_TrayMenu.Add("Exit", (*) => ExitApp())
A_TrayMenu.Default := "Settings" ; Double-click tray icon to open settings
A_TrayMenu.ClickCount := 1

; ==============================================================================
; GUI SETUP
; ==============================================================================
MyGui := Gui(, "Advanced Human Typer v3")
MyGui.Opt("+AlwaysOnTop")
MyGui.SetFont("s9", "Segoe UI")
MyGui.OnEvent("Close", (*) => MyGui.Hide()) ; Minimize to tray on close

; --- Speed & Flow Group ---
MyGui.Add("GroupBox", "x10 y10 w280 h110", "Speed & Flow")

MyGui.Add("Text", "x25 y35", "Target Speed (WPM):")
MyGui.Add("Slider", "x140 y32 w130 h25 vWPM Range10-200 TickInterval10 ToolTip", 90)

MyGui.Add("Text", "x25 y70", "Speed Variance (ms):")
MyGui.Add("Slider", "x140 y67 w130 h25 vVariance Range0-100 TickInterval10 ToolTip", 40)
MyGui.SetFont("s8 cGray")
MyGui.Add("Text", "x35 y90", "(Jitter between keys)")
MyGui.SetFont("s9 cDefault")

; --- Errors & Realism Group ---
MyGui.Add("GroupBox", "x10 y130 w280 h180", "Errors & Distractions")

MyGui.Add("Text", "x25 y155", "Error Rate (%):")
MyGui.Add("Slider", "x140 y152 w130 h25 vErrorRate Range0-20 TickInterval1 ToolTip", 3)

MyGui.Add("Text", "x25 y190", "Distraction Chance (%):")
MyGui.Add("Slider", "x160 y187 w110 h25 vDistractionChance Range0-5 TickInterval1 ToolTip", 1)
MyGui.SetFont("s8 cGray")
MyGui.Add("Text", "x35 y210", "(Stops for 2-10s randomly)")
MyGui.SetFont("s9 cDefault")

MyGui.Add("Checkbox", "x25 y240 vDoubleSpace", "Writer's Block (Thinking Pauses)")
MyGui.Add("Checkbox", "x25 y265 vCountdown Checked", "3-Second Start Delay")

; --- Controls Group ---
MyGui.Add("Button", "x10 y320 w135 h40", "Start Typing (F8)").OnEvent("Click", StartTyping)
MyGui.Add("Button", "x155 y320 w135 h40", "Stop (Esc)").OnEvent("Click", StopTyping)

MyGui.Show("w300 h375")

; ==============================================================================
; HOTKEYS
; ==============================================================================
F8::StartTyping()
Esc::StopTyping()

; ==============================================================================
; MAIN FUNCTIONS
; ==============================================================================

ShowGui(*) {
    MyGui.Show()
}

StartTyping(*) {
    global isTyping
    
    if (isTyping)
        return

    savedObj := MyGui.Submit(false) ; Get current settings without hiding
    textToType := A_Clipboard
    
    if (textToType = "") {
        MsgBox("Clipboard is empty!", "Error", "Icon!")
        return
    }

    ; --- Countdown Feature ---
    if (savedObj.Countdown) {
        Loop 3 {
            ToolTip("Starting in " . (4 - A_Index) . "...")
            SoundBeep(400, 150)
            Sleep(850)
        }
        ToolTip("Go!")
        Sleep(300)
        ToolTip()
    }

    isTyping := true
    totalChars := StrLen(textToType)
    
    ; Calculate base delay (ms per character)
    targetDelay := 60000 / (savedObj.WPM * 5)

    ; FIX 2: Initialize variable outside loop so it exists for the first check
    percentComplete := 0 

    Loop Parse, textToType {
        if (!isTyping) {
            ToolTip()
            break
        }

        char := A_LoopField
        currentIndex := A_Index

        ; --- Progress Tooltip ---
        if (Mod(currentIndex, 10) == 0 || currentIndex == totalChars) {
            percentComplete := Round((currentIndex / totalChars) * 100)
            ToolTip("Typing: " percentComplete "%`n[Esc] to Stop")
        }
        
        ; --- Warm-Up Curve ---
        currentBaseDelay := targetDelay
        if (currentIndex < 15) {
            factor := 2.0 - (currentIndex / 15) 
            currentBaseDelay := targetDelay * factor
        }

        ; --- 1. Distraction Logic ---
        if (savedObj.DistractionChance > 0 && Random(1, 1000) <= (savedObj.DistractionChance * 10)) {
             ToolTip("Distracted... (Paused)")
             Sleep(Random(2000, 8000))
             ToolTip("Typing: " percentComplete "%") ; Now safe to use
        }

        ; --- 2. Advanced Error Simulation ---
        if (savedObj.ErrorRate > 0 && Random(1, 100) <= savedObj.ErrorRate && RegExMatch(char, "\w")) {
            PerformHumanError(char)
        }

        ; --- 3. Type Correct Character ---
        SendText(char)

        ; --- 4. Rhythm & Jitter ---
        sleepTime := currentBaseDelay + Random(-savedObj.Variance, savedObj.Variance)
        if (sleepTime < 10) 
            sleepTime := 10

        ; Punctuation Pauses
        if (char ~= "[.?!]") {
            sleepTime += Random(300, 600)
        }
        else if (char ~= "[,;]") {
            sleepTime += Random(100, 200)
        }
        else if (char = "`n") {
            sleepTime += Random(300, 500)
        }
        
        ; Writer's Block (Micro pauses)
        if (savedObj.DoubleSpace && Random(1, 200) == 1) {
            sleepTime += Random(600, 1500)
        }

        Sleep(sleepTime)
    }

    isTyping := false
    ToolTip("Done!")
    SetTimer () => ToolTip(), -2000
    SoundBeep(600, 150)
}

StopTyping(*) {
    global isTyping
    if (isTyping) {
        isTyping := false
        ToolTip("Stopped!")
        SetTimer () => ToolTip(), -1000
    }
}

; ==============================================================================
; HELPER FUNCTIONS
; ==============================================================================

PerformHumanError(targetChar) {
    if (!isTyping) 
        return

    neighbor := GetNeighborKey(targetChar)
    errorType := Random(1, 100)

    ; 30% chance of fat finger (hit both), 70% chance of just wrong key
    if (errorType < 30) {
        SendText(neighbor)
        Sleep(Random(20, 60))
        SendText(targetChar)
        Sleep(Random(350, 700)) ; Realization
        SendInput("{Backspace}")
        Sleep(Random(80, 150))
        SendInput("{Backspace}")
        Sleep(Random(100, 200))
    } 
    else {
        SendText(neighbor)
        Sleep(Random(250, 550)) ; Realization
        SendInput("{Backspace}")
        Sleep(Random(50, 150))
    }
}

GetNeighborKey(char) {
    static neighbors := Map(
        "q", "wa", "w", "qes", "e", "wrd", "r", "etf", "t", "ryg", "y", "tuh", "u", "yij", "i", "uok", "o", "ipl", "p", "o",
        "a", "qwsz", "s", "awedxz", "d", "serfcx", "f", "drtgv", "g", "ftyhb", "h", "gyujn", "j", "huikm", "k", "jiol", "l", "kop",
        "z", "asx", "x", "zsdc", "c", "xdfv", "v", "cfgb", "b", "vghn", "n", "bhjm", "m", "njk"
    )
    
    lowerChar := StrLower(char)
    
    if (neighbors.Has(lowerChar)) {
        options := neighbors[lowerChar]
        randomIdx := Random(1, StrLen(options))
        nearKey := SubStr(options, randomIdx, 1)
        
        if IsUpper(char)
            return StrUpper(nearKey)
        return nearKey
    }
    return "a" 
}
