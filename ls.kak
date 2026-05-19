provide-module ls %{
  declare-option -hidden str _ls_current_dir "."
  declare-option -hidden str _ls_cmd \
    "echo '../'; printf '%%s\n' ""$(basename ""$(pwd)"")/""; ls --group-directories-first -1 -A -L -p | sed -E 's|^|  |'"
  declare-option -hidden str _ls_jump_client "lsjumpclient"
  declare-option -hidden str _ls_client "lsclient"
  declare-option -hidden str-list _ls_selected_filepaths
  declare-option -hidden str _ls_selected_indicator "\+"
  declare-option -hidden str _ls_selected_filepaths_sep ":__:"
  declare-option -hidden int _ls_selected_count
  declare-option -hidden str-list _ls_copied_filepaths
  declare-option -hidden str _ls_copied_action
  declare-option -hidden int _ls_copied_count
  declare-option -hidden str _ls_copied_indicator "\*"
  declare-option -hidden str _ls_hline_face "default,default+@SecondarySelection"

  define-command -hidden _ls-assert-buffer %{
    evaluate-commands %sh{
      if [ ! "$kak_bufname" = "*ls*" ]; then
        echo "fail 'Not in "*ls*" buffer'"
      fi
    }
  }

  define-command -hidden _ls-hline %{
    set-face window PrimaryCursor %opt{_ls_hline_face}
    set-face window PrimaryCursorEol %opt{_ls_hline_face}
    try %{ remove-highlighter window/hlline }
    try %{ add-highlighter window/hlline line %val{cursor_line} %opt{_ls_hline_face} }
  }

  define-command -hidden _ls-redraw-impl -params ..1 %{
    _ls-assert-buffer
    evaluate-commands -save-regs 'c' %sh{
      if [ -n "$1" ]; then
        kak_opt__ls_current_dir="$1"
        echo "set-option window _ls_current_dir '$1'"
      fi
      cd "$kak_opt__ls_current_dir"

      ui="$(eval "$kak_opt__ls_cmd")"

      if [ -n "$kak_opt__ls_copied_filepaths" ]; then
        array="$kak_opt__ls_copied_filepaths"
        while [ -n "$array" ]; do
          path="${array%%$kak_opt__ls_selected_filepaths_sep*}"

          [ "$path" = "$array" ] && break
          if [ "$kak_opt__ls_current_dir" = "$(dirname "$path")" ]; then
            ui="$(printf '%s' "$ui" | sed -E "s|^.(.+$(basename "$path"))|$kak_opt__ls_copied_indicator\1|")"
          fi

          array="${array#*:__:}"
        done
      fi

      if [ -n "$kak_opt__ls_selected_filepaths" ]; then
        array="$kak_opt__ls_selected_filepaths"
        while [ -n "$array" ]; do
          path="${array%%$kak_opt__ls_selected_filepaths_sep*}"

          [ "$path" = "$array" ] && break
          if [ "$kak_opt__ls_current_dir" = "$(dirname "$path")" ]; then
            ui="$(printf '%s' "$ui" | sed -E "s|^.(.+$(basename "$path"))|$kak_opt__ls_selected_indicator\1|")"
          fi

          array="${array#*:__:}"
        done
      fi

      echo "set-register c '$ui'"
      echo "execute-keys '%%<dquote>cR:select $kak_selection_desc<ret>'"
    }
    _ls-hline
  }

  define-command ls-redraw -docstring 'Redraw the filebrowser' %{
    _ls-redraw-impl
  }

  define-command -hidden _ls-enable-impl -params 1 %{
      edit -scratch -debug "*ls*"
      set-option window filetype ls
      rename-client "%opt{_ls_client}"
      execute-keys "gg"
      _ls-redraw-impl %arg{1}
  }

  define-command ls-enable -docstring 'Open the filebrowser' %{
    try %{
      ls-disable
    }
    set-option global _ls_jump_client "%val{client}"
    evaluate-commands %sh{
      dir=
      [ -f "$kak_buffile" ] && dir="$(dirname "$kak_buffile")" || dir="$PWD"
      if [ -n "$TMUX" ]; then
        tmux split-window -l "20%" -h -b "kak -c $kak_session -e '_ls-enable-impl %{$dir}'" > /dev/null
      else
        echo "new '_ls-enable-impl %{$dir}'"
      fi
    }
  }

  define-command ls-disable -docstring 'Close the filebrowser' %{
    try %{ delete-buffer "*ls*" } catch %{ fail }
    try %{ evaluate-commands -client %opt{_ls_client} quit }
  }

  define-command ls-toggle -docstring 'Toggle visibility of filebrowser' %{
    try %{
      ls-disable
    } catch %{
      ls-enable
    }
  }

  define-command ls-open -docstring 'Open a file' %{
    _ls-assert-buffer
    evaluate-commands %sh{
      open(){
        local filepath="$1"

        if [ -d "$filepath" ]; then
          cd "$filepath"
          echo "set-option window _ls_current_dir \"$PWD\""
          echo "execute-keys gg"
        elif [ -f "$filepath" ]; then
          filepath="$kak_opt__ls_current_dir/$filepath"

          if [ -n "$(echo "$kak_client_list" | grep -o "$kak_opt__ls_jump_client")" ]; then
            echo "evaluate-commands -client $kak_opt__ls_jump_client %{ edit -existing "$filepath" }" | kak -p $kak_session
            if [ -n "$TMUX" ]; then
              echo "focus $kak_opt__ls_jump_client"
            fi
          else
            cmd="kak -c $kak_session -e 'edit -existing "$filepath"; rename-client "$kak_opt__ls_jump_client"'"
            if [ -n "$TMUX" ]; then
              tmux split-window -c "$dir" -l "80%" -h "$cmd" > /dev/null
            elif [ -n "$kak_opt_termcmd" ]; then
              $kak_opt_termcmd "cd $dir; $cmd"
            elif [ -n "$TERMINAL" ]; then
              $TERMINAL -e sh -c "cd $dir; $cmd" || $TERMINAL -x sh -c "cd $dir; $cmd" || $TERMINAL sh -c "cd $dir; $cmd"
            else
              echo "fail 'No defined method to run program'"
            fi
          fi
        fi
      }

      cd "$kak_opt__ls_current_dir"
      ui="$(eval "$kak_opt__ls_cmd")"
      current_file="$(echo "$ui" | head -$kak_cursor_line | tail -1 | grep -Po "[\.\w-].*")"

      open "$current_file"
    }
    ls-redraw
  }

  define-command ls-create -docstring 'Create a file' %{
    _ls-assert-buffer
    evaluate-commands %{
      prompt "Create:" %{
        evaluate-commands %sh{
          cd "$kak_opt__ls_current_dir"
          if [ -n "$(echo "$kak_text" | grep '.*/')" ]; then
            mkdir -p "$kak_text"
          else
            DIR_PATH=$(dirname "$kak_text")
            mkdir -p "$DIR_PATH"
            touch "$kak_text"
          fi
        }
        ls-redraw
      }
    }
  }

  define-command ls-delete -docstring 'Delete a file' %{
    _ls-assert-buffer
    prompt %sh{
      count=$kak_opt__ls_selected_count
      [ $count -eq 0 ] && count=1
      files="$([ $count -gt 1 ] && echo 'files' || echo 'file')"
      printf "Delete %s? [y/n]:" "$count $files"
    } \
    %{
      evaluate-commands %sh{
        if [ ! "$kak_text" = "y" ] || [ ! "$kak_text" = "Y"]; then
          exit
        fi

        remove_file() {
          if [ -x "$(command -v trash-put)" ]; then
            trash-put "$1"
          else
            rm -rf "$1"
          fi
        }

        if [ -n "$kak_opt__ls_selected_filepaths" ]; then
          array="$kak_opt__ls_selected_filepaths"
          while [ -n "$array" ]; do
            path="${array%%$kak_opt__ls_selected_filepaths_sep*}"

            [ "$path" = "$array" ] && break

            remove_file "$path"

            array="${array#*:__:}"
          done
        else
          cd "$kak_opt__ls_current_dir"
          ui="$(eval "$kak_opt__ls_cmd")"

          current_file="$(echo "$ui" | head -$kak_cursor_line | tail -1 | grep -Po "[\.\w-].*")"

          if [ "$current_file" = "../" ] || [ "$current_file" = "./" ]; then
            echo "fail 'Cannot delete ./ or ../'"
            exit
          fi

          remove_file "$kak_opt__ls_current_dir/$current_file"
        fi
      }
      ls-clear
      ls-redraw
    }
  }

  define-command ls-toggle-select %{
    _ls-assert-buffer
    evaluate-commands %sh{
      cd "$kak_opt__ls_current_dir"
      ui="$(eval "$kak_opt__ls_cmd")"
      current_file="$(echo "$ui" | head -$kak_cursor_line | tail -1 | grep -Po "[\.\w-].*")"

      if [ "$current_file" = "../" ] || [ "$current_file" = "./" ]; then
        echo "fail 'Cannot select ./ or ../'"
        exit
      fi

      current_file="$kak_opt__ls_current_dir/$current_file"

      SEP="$kak_opt__ls_selected_filepaths_sep"

      paths="$kak_opt__ls_selected_filepaths"
      if printf '%s' "$paths" | grep -q "$current_file$SEP"; then
        paths="$(echo "$paths" | sed "s|$current_file$SEP||")"
      else
        paths="$current_file${SEP}$paths"
      fi

      echo "set-option window _ls_selected_filepaths '$paths'"
      count="$(printf '%s' "$paths" | sed "s|$SEP|\n|g" | wc -l)"
      files="$([ $count -gt 1 ] && echo 'files' || echo 'file')"
      if [ $count -gt 0 ]; then
        echo "set-option window modelinefmt '$count $files selected'"
        echo "set-option window _ls_selected_count $count"
      else
        echo "set-option window modelinefmt ''"
        echo "set-option window _ls_selected_count 0"
      fi
    }
    ls-redraw
  }

  define-command -hidden _ls-get-copy-cut-path -params 1 %{
    evaluate-commands %sh{
      cd "$kak_opt__ls_current_dir"
      ui="$(eval "$kak_opt__ls_cmd")"
      current_file="$(echo "$ui" | head -$kak_cursor_line | tail -1 | grep -Po "[\.\w-].*")"

      if [ "$current_file" = "../" ] || [ "$current_file" = "./" ]; then
        echo "fail 'Cannot copy ./ or ../'"
        exit
      fi

      if [ -n "$kak_opt__ls_selected_filepaths" ]; then
        echo "set-option window _ls_copied_filepaths '$kak_opt__ls_selected_filepaths'"
        echo "set-option window _ls_copied_count $kak_opt__ls_selected_count"
        echo "set-option window _ls_selected_filepaths ''"
        echo "set-option window _ls_selected_count 0"
      else
        echo "set-option window _ls_copied_filepaths '$kak_opt__ls_current_dir/${current_file}$kak_opt__ls_selected_filepaths_sep'"
        echo "set-option window _ls_copied_count 1"
      fi
      echo "set-option window _ls_copied_action '$1'"
    }
    ls-redraw
  }

  define-command ls-copy -docstring 'Copy a file to be pasted later' %{
    _ls-assert-buffer
    _ls-get-copy-cut-path "copy"
    set-option window modelinefmt %sh{
      files="$([ $kak_opt__ls_copied_count -gt 1 ] && echo 'files' || echo 'file')"
      printf "%s copied" "$kak_opt__ls_copied_count $files"
    }
  }

  define-command ls-cut -docstring 'Cut a file to be pasted later' %{
    _ls-assert-buffer
    _ls-get-copy-cut-path "cut"
    # set-option window modelinefmt "Cut %opt{_ls_copied_count} file(s)"
    set-option window modelinefmt %sh{
      files="$([ $kak_opt__ls_copied_count -gt 1 ] && echo 'files' || echo 'file')"
      printf "%s cut" "$kak_opt__ls_copied_count $files"
    }
  }

  define-command ls-paste -docstring 'Paste a file that was copied or cut' %{
    _ls-assert-buffer
    evaluate-commands %sh{
      [ -z "$kak_opt__ls_copied_filepaths" ] && exit

      cd "$kak_opt__ls_current_dir"
      ui="$(eval "$kak_opt__ls_cmd")"

      copy() {
        local src="$1"
        local dest="$2"
        if [ -d "$src" ]; then
          cp -r "$src" "$dest"
        else
          cp "$src" "$dest"
        fi
      }

      array="$kak_opt__ls_copied_filepaths"
      while [ -n "$array" ]; do
        path="${array%%$kak_opt__ls_selected_filepaths_sep*}"

        [ "$path" = "$array" ] && break

        array="${array#*:__:}"

        name="$(basename "$path")"

        case "$name" in
          *.*)
            extension="${name##*.}"
            base="${name%.*}"
            ;;
          *)
            extension=""
            base="$name"
            ;;
        esac

        new_name="$name"
        i=0

        while [ -e "$new_name" ]; do
          i=$((i+1))
          if [ -z "$extension" ]; then
            new_name="$base-$i"
          else
            new_name="$base-$i.$extension"
          fi
        done

        dest="$kak_opt__ls_current_dir/$new_name"

        if [ "$path" = "$kak_opt__ls_current_dir/" ]; then
          echo "fail 'Cannot copy/move into self'"
          exit
        fi

        if [ "$kak_opt__ls_copied_action" = "copy" ]; then
          copy "$path" "$dest"
        elif [ "$kak_opt__ls_copied_action" = "cut" ]; then
          mv "$path" "$dest"
        fi
        if [ $? -ne 0 ]; then
          echo "fail 'Failed to paste file'"
          exit
        fi
      done
    }
    ls-clear
    ls-redraw
  }

  define-command ls-clear -docstring 'Clear selections if they exist' %{
    _ls-assert-buffer
    set-option window _ls_selected_filepaths ''
    set-option window _ls_selected_count 0
    set-option window _ls_copied_filepaths ''
    set-option window _ls_copied_count 0
    set-option window _ls_copied_action ''
    set-option window modelinefmt ''
    ls-redraw
  }

  define-command ls-rename -docstring 'Rename a file' %{
    _ls-assert-buffer
    evaluate-commands %sh{
      cd "$kak_opt__ls_current_dir"
      ui="$(eval "$kak_opt__ls_cmd")"
      current_file="$(echo "$ui" | head -$kak_cursor_line | tail -1 | grep -Po "[\.\w-].*")"

      if [ "$current_file" = "../" ] || [ "$current_file" = "./" ]; then
        echo "fail 'Cannot rename ./ or ../'"
        exit
      fi
      echo "set-register f '$current_file'"
    }
    evaluate-commands -save-regs 'f' %{
      prompt -init "%reg{f}" "Rename:" %{
        evaluate-commands %sh{
        cd "$kak_opt__ls_current_dir"
          mv "$kak_reg_f" "$kak_text"
          [ $? -ne 0 ] && echo "fail 'Could not rename file'"
        }
        ls-redraw
      }
    }
  }

  define-command -hidden _ls-cd-impl -params 2 %{
    evaluate-commands %sh{
      cd "$kak_opt__ls_current_dir"

      dir="$1"
      ret_dir="$2"

      echo "change-directory '$ret_dir'"

      cd "$dir"

      # Doing this as to not need to check that `$dir` is a link
      if [ $? -ne 0 ]; then
        echo "fail '`$dir` is not a directory'"
        exit
      fi

      echo "set-option window _ls_current_dir '$PWD'"
    }
    ls-redraw
  }

  define-command -hidden _ls-cd-prompt -params 1 %{
    prompt -on-abort 'change-directory %arg{1}' -menu -file-completion "Directory:" %{
      _ls-cd-impl "%val{text}" "%arg{1}"
    }
  }

  define-command ls-cd -params ..1 \
  -docstring 'ls-cd: [<directory>]: Change <directory> of filebrowser. if <directory> is provided, cd there or open prompt' \
  %{
    _ls-assert-buffer
    evaluate-commands -save-regs 'd' %{
      set-register d %sh{pwd}
      change-directory %opt{_ls_current_dir}
      evaluate-commands %sh{
        if [ -n "$1" ]; then
          echo "_ls-cd-impl '$1' '$kak_reg_d'"
        else
          echo "_ls-cd-prompt '$kak_reg_d'"
        fi
      }
    }
  }

  define-command ls-run -params .. \
  -docstring 'ls-run [<command>]: Run <command> in current ls directory. if <command> is provided, run it or open prompt' \
  %{
    _ls-assert-buffer
    evaluate-commands -save-regs 'd' %{
      set-register d %sh{pwd}
      change-directory %opt{_ls_current_dir}
      evaluate-commands %sh{
        if [ -n "$1" ]; then
          $@ > /dev/null
          printf 'change-directory "%s"\n' "$kak_reg_d"
          printf "ls-redraw\n"
        else
          printf 'prompt -shell-completion "Command:" %%{
            nop %%sh{
              eval "$kak_text"
            }
            change-directory "%s"
            ls-redraw
          }\n' "$kak_reg_d"
        fi
      }
    }
  }

  define-command ls-copy-path %{
    evaluate-commands %sh{
      cd "$kak_opt__ls_current_dir"
      ui="$(eval "$kak_opt__ls_cmd")"
      current_file="$(echo "$ui" | head -$kak_cursor_line | tail -1 | grep -Po "[\.\w-].*")"

      echo "set-register dquote '$kak_opt__ls_current_dir/$current_file'"
    }
  }

  define-command ls-copy-name %{
    evaluate-commands %sh{
      cd "$kak_opt__ls_current_dir"
      ui="$(eval "$kak_opt__ls_cmd")"
      current_file="$(echo "$ui" | head -$kak_cursor_line | tail -1 | grep -Po "[\.\w-].*")"

      echo "set-register dquote '$current_file'"
    }
  }

  define-command ls-copy-directory %{
    evaluate-commands %sh{
      echo "set-register dquote '$kak_opt__ls_current_dir'"
    }
  }

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

    evaluate-commands %sh{
      echo "add-highlighter -override window/ regex '^($kak_opt__ls_copied_indicator)' 1:red"
      echo "add-highlighter -override window/ regex '^($kak_opt__ls_selected_indicator)' 1:cyan"
    }

    hook window RawKey .* %{
      _ls-hline
    }
  }

  hook global ClientClose %opt{_ls_client} %{
    try %{ ls-disable }
  }
}

require-module ls
