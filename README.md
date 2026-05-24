# ls.kak
Another filebrowser plugin for kakoune

https://github.com/user-attachments/assets/df0a21fe-69d5-43b4-b3ce-3462b3395a81

## Dependencies
- [tmux](https://github.com/tmux/tmux/) (optional)

## Installation
Copy [ls.kak](./ls.kak) into your autoload directory

## Usage
Run either `:ls-open` or `:ls-toggle` to get started

## Suggested Hook
```kak
hook global WinSetOption filetype=ls %{
  try %{ remove-highlighter window/wrap }
  map window normal <ret> ":ls-open<ret>"
  map window normal l ":ls-open<ret>"
  map window normal h ":ls-cd ..<ret>"
  map window normal a ":ls-create<ret>"
  map window normal d ":ls-delete<ret>"
  map window normal y ":ls-copy<ret>"
  map window normal x ":ls-cut<ret>"
  map window normal p ":ls-paste<ret>"
  map window normal r ":ls-rename<ret>"
  map window normal <tab> ":ls-cd<ret>"
  map window normal <esc> ":ls-clear<ret>"
  map window normal s ":ls-toggle-select<ret>"

  try %{ declare-user-mode ls-copy-info } # Copy focused file's info to default yank/paste register
  map window normal c ":enter-user-mode ls-copy-info<ret>"
  map window ls-copy-info p ":ls-copy-path<ret>"
  map window ls-copy-info n ":ls-copy-name<ret>"
  map window ls-copy-info d ":ls-copy-directory<ret>"
}
```

## Note

This configuration has been set on the ls buffer to prevent accidental changes to the buffer
The buffer is the source of truth so if anything changes it outside of the ls commands, unwanted actions may be performed to your file system

```kak
hook global WinSetOption filetype=ls %{
  set-option window modelinefmt ''

  map window normal i ":nop<ret>"
  map window normal I ":nop<ret>"
  map window normal a ":nop<ret>"
  map window normal A ":nop<ret>"
  map window normal o ":nop<ret>"
  map window normal O ":nop<ret>"
  map window normal c ":nop<ret>"
  map window normal d ":nop<ret>"
  map window normal u ":nop<ret>"
  map window normal <a-d> ":nop<ret>"
  map window normal <a-c> ":nop<ret>"
  map window normal x ":nop<ret>"
  map window normal y ":nop<ret>"
  map window normal p ":nop<ret>"
  map window normal r ":nop<ret>"
  map window normal R ":nop<ret>"
}
```

## References
- [kaktree](https://github.com/andreyorst/kaktree/tree/master)
- [ptfm](https://gitlab.com/lisael/ptfm)

