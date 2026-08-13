# assets

Runtime files the executable loads from its own folder at startup. They are
kept under version control here and copied into `bin/` by
`tools/copy-assets.bat`.

Expected layout after the copy:

    bin/
      DelphiLoop.exe
      dlogo.png
      prompt_executor.md
      prompt_reviewer.md
      prompt_refine.md
      styles/
        Win10ModernDark.style

`Engine.Prompts` falls back to the constants in `Engine.Consts` when a prompt
file is missing, so the application still runs with an empty `assets` folder -
it just loses the ability to edit prompts without recompiling.
