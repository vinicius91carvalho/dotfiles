# macOS keyboard shortcuts (System Settings > Keyboard > Keyboard Shortcuts).
#
# Captured verbatim from this machine's com.apple.symbolichotkeys plist on
# 2026-08-03. Each numeric key is an Apple "symbolic hot key" id; there is no
# public list of them, so the comments below are best-effort labels.
#
# `parameters` is [ ascii keyCode modifierMask ]. Modifier mask bits:
#   Shift 131072 | Control 262144 | Option 524288 | Command 1048576 | Fn 8388608
#
# To re-capture after changing shortcuts in System Settings, see README.md.
{
  system.defaults.CustomUserPreferences."com.apple.symbolichotkeys" = {
    AppleSymbolicHotKeys = {
      # Zoom: toggle
      "15" = {
        enabled = false;
      };
      # Zoom: zoom in
      "16" = {
        enabled = false;
      };
      # Zoom: zoom out
      "17" = {
        enabled = false;
      };
      # Zoom: toggle image smoothing
      "18" = {
        enabled = false;
      };
      # Zoom: scroll-wheel zoom
      "19" = {
        enabled = false;
      };
      # Zoom: focus follows keyboard
      "20" = {
        enabled = false;
      };
      # Contrast: increase
      "21" = {
        enabled = false;
      };
      # Contrast: decrease
      "22" = {
        enabled = false;
      };
      # Invert colours
      "23" = {
        enabled = false;
      };
      # Zoom: toggle full / picture-in-picture
      "24" = {
        enabled = false;
      };
      # Accessibility: toggle VoiceOver
      "25" = {
        enabled = false;
      };
      # Accessibility: show Accessibility controls
      "26" = {
        enabled = false;
      };
      # Screenshot: save screen to file
      "28" = {
        enabled = false;
        value = {
          parameters = [
            51
            20
            1179648
          ];
          type = "standard";
        };
      };
      # Screenshot: copy screen to clipboard
      "29" = {
        enabled = false;
        value = {
          parameters = [
            51
            20
            1441792
          ];
          type = "standard";
        };
      };
      # Screenshot: save selection to file
      "30" = {
        enabled = false;
        value = {
          parameters = [
            52
            21
            1179648
          ];
          type = "standard";
        };
      };
      # Screenshot: copy selection to clipboard
      "31" = {
        enabled = false;
        value = {
          parameters = [
            52
            21
            1441792
          ];
          type = "standard";
        };
      };
      # Select previous input source
      "60" = {
        enabled = false;
        value = {
          parameters = [
            32
            49
            262144
          ];
          type = "standard";
        };
      };
      # Select next input source
      "61" = {
        enabled = false;
        value = {
          parameters = [
            32
            49
            786432
          ];
          type = "standard";
        };
      };
      # Move left a space
      "79" = {
        enabled = true;
        value = {
          parameters = [
            65535
            123
            8650752
          ];
          type = "standard";
        };
      };
      # Move right a space
      "80" = {
        enabled = true;
        value = {
          parameters = [
            65535
            123
            8781824
          ];
          type = "standard";
        };
      };
      # Move up a space
      "81" = {
        enabled = true;
        value = {
          parameters = [
            65535
            124
            8650752
          ];
          type = "standard";
        };
      };
      # Move down a space
      "82" = {
        enabled = true;
        value = {
          parameters = [
            65535
            124
            8781824
          ];
          type = "standard";
        };
      };
      # Switch to Desktop 1
      "118" = {
        enabled = true;
        value = {
          parameters = [
            65535
            18
            262144
          ];
          type = "standard";
        };
      };
      # Dictation / press-modifier shortcut
      "164" = {
        enabled = true;
        value = {
          parameters = [
            8388608
            4286578687
          ];
          type = "modifier";
        };
      };
      # Spotlight / assistant
      "176" = {
        enabled = true;
        value = {
          parameters = [
            32
            54
            1048592
          ];
          type = "SAE1.0";
        };
      };
      # Finder: new window with search
      "184" = {
        enabled = false;
        value = {
          parameters = [
            53
            23
            1179648
          ];
          type = "standard";
        };
      };
    };
  };
}
