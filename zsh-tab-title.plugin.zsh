#!/bin/bash

# Set terminal window and tab/icon title
#
# usage: title short_tab_title long_window_title
#
# See: http://www.faqs.org/docs/Linux-mini/Xterm-Title.html#ss3.1
# Fully supports screen, hyper, iterm, wezterm, and probably most modern xterm and rxvt
# (In screen, only short_tab_title is used)
#
# Enhanced WezTerm support with OSC 1337 user vars and OSC 7 working directory
# For SSH sessions, ensure this plugin is installed on remote hosts for best experience
#
# Debug: Set ZSH_TAB_TITLE_DEBUG=true to see what's happening
# Example: export ZSH_TAB_TITLE_DEBUG=true
function title {
  emulate -L zsh
  setopt prompt_subst
  
  [[ "$EMACS" == *term* ]] && return

  tabTitle="$1"
  termTitle="$2"

  if [[ "$ZSH_TAB_TITLE_DEBUG" == "true" ]]; then
    echo "[DEBUG] title() called - tabTitle='$tabTitle', termTitle='$termTitle'"
    echo "[DEBUG] TERM_PROGRAM='$TERM_PROGRAM', TERM='$TERM'"
  fi

  if [[ "$TERM_PROGRAM" == "iTerm.app" ]]; then
    print -Pn "\e]2;$termTitle:q\a" # set window name
    print -Pn "\e]1;$tabTitle:q\a" # set tab name
  elif [[ "$TERM_PROGRAM" == "Hyper" ]]; then
    print -Pn "\e]1;$termTitle:q\a" # set tab name
    print -Pn "\e]2;$tabTitle:q\a" # set window name
  elif [[ "$TERM_PROGRAM" == "WezTerm" ]]; then
    print -Pn "\e]2;$termTitle:q\a" # set window name
    print -Pn "\e]1;$tabTitle:q\a" # set tab name
  else
    if [[ "$ZSH_TAB_TITLE_DEBUG" == "true" ]]; then
      echo "[DEBUG] Using fallback title setting for TERM='$TERM'"
    fi
    case "$TERM" in
      xterm-kitty)
        print -Pn "\e]1;$termTitle:q\a" # set window name
        print -Pn "\e]2;$tabTitle:q\a" # set tab name
      ;;

      wezterm)
        print -Pn "\e]2;$termTitle:q\a" # set window name
        print -Pn "\e]1;$tabTitle:q\a" # set tab name
      ;;

      cygwin|xterm*|putty*|rxvt*|ansi|${~ZSH_TAB_TITLE_ADDITIONAL_TERMS})
        print -Pn "\e]2;$termTitle:q\a" # set window name
        print -Pn "\e]1;$tabTitle:q\a" # set tab name
      ;;

      screen*|tmux*)
        print -Pn "\ek$tabTitle:q\e\\" # set screen hardstatus
      ;;
    esac
  fi
}

function setTerminalTitleInIdle {

  if [[ "$ZSH_TAB_TITLE_DISABLE_AUTO_TITLE" == true ]]; then
    return
  fi

  if [[ "$ZSH_TAB_TITLE_ONLY_FOLDER" == true ]]; then
    ZSH_THEME_TERM_TAB_TITLE_IDLE=${PWD##*/}
  else
    ZSH_THEME_TERM_TAB_TITLE_IDLE="%20<..<%~%<<" #15 char left truncated PWD
  fi

  if [[ "$ZSH_TAB_TITLE_DEFAULT_DISABLE_PREFIX" == true ]]; then
  ZSH_TAB_TITLE_PREFIX=""
  elif [[ -z "$ZSH_TAB_TITLE_PREFIX" ]]; then
    ZSH_TAB_TITLE_PREFIX="%n@%m:"
  fi

  ZSH_THEME_TERM_TITLE_IDLE="$ZSH_TAB_TITLE_PREFIX %~ $ZSH_TAB_TITLE_SUFFIX"

  title "$ZSH_THEME_TERM_TAB_TITLE_IDLE" "$ZSH_THEME_TERM_TITLE_IDLE"
  
  # WezTerm-specific: Set OSC 1337 user vars for better integration
  # Check multiple ways to detect WezTerm, or assume WezTerm in SSH sessions
  local is_wezterm=false
  
  if [[ "$TERM_PROGRAM" == "WezTerm" ]] || [[ "$WEZTERM_PANE" != "" ]] || [[ "$TERM_PROGRAM_VERSION" =~ "wezterm" ]]; then
    is_wezterm=true
  elif [[ "$SSH_CONNECTION" != "" ]] && [[ "$ZSH_TAB_TITLE_ASSUME_WEZTERM_SSH" == "true" ]]; then
    # Assume WezTerm in SSH sessions if explicitly enabled
    is_wezterm=true
  fi
  
  if [[ "$is_wezterm" == "true" ]]; then
    if [[ "$ZSH_TAB_TITLE_DEBUG" == "true" ]]; then
      echo "[DEBUG] WezTerm detected/assumed - setting OSC sequences"
      echo "[DEBUG] TERM_PROGRAM=$TERM_PROGRAM, WEZTERM_PANE=$WEZTERM_PANE, SSH_CONNECTION=$SSH_CONNECTION"
      echo "[DEBUG] HOST=$HOST, PWD=$PWD"
    fi
    printf "\033]1337;SetUserVar=WEZTERM_PROG=%s\033\\" "$(echo -n "zsh" | base64)"
    printf "\033]1337;SetUserVar=WEZTERM_USER=%s\033\\" "$(echo -n "$USER" | base64)"
    printf "\033]1337;SetUserVar=WEZTERM_HOST=%s\033\\" "$(echo -n "$HOST" | base64)"
    # Set current working directory with OSC 7
    printf "\033]7;file://%s%s\033\\" "$HOST" "$PWD"
  elif [[ "$ZSH_TAB_TITLE_DEBUG" == "true" ]]; then
    echo "[DEBUG] WezTerm not detected - TERM_PROGRAM=$TERM_PROGRAM, WEZTERM_PANE=$WEZTERM_PANE, SSH_CONNECTION=$SSH_CONNECTION"
  fi
}

# Runs before showing the prompt
function omz_termsupport_precmd {
  emulate -L zsh

  setTerminalTitleInIdle
}

# Runs before executing the command
function omz_termsupport_preexec {
  emulate -L zsh
  setopt extended_glob

  if [[ "$ZSH_TAB_TITLE_DISABLE_AUTO_TITLE" == true ]]; then
    return
  fi

  if [[ "$ZSH_TAB_TITLE_ENABLE_FULL_COMMAND" == true ]]; then
  	  # full command
	  local CMD=${1:gs/%/%%}
    local LINE=${2:gs/%/%%}
  else
	  # cmd name only, or if this is sudo or ssh, the next cmd
	  local CMD=${1[(wr)^(*=*|sudo|ssh|mosh|rake|-*)]:gs/%/%%}
    local LINE=${2[(wr)^(*=*|sudo|ssh|mosh|rake|-*)]:gs/%/%%}
  fi

  if [[ "$ZSH_TAB_TITLE_CONCAT_FOLDER_PROCESS" == true ]]; then
    title "${PWD##*/}:%100>...>$LINE%<<" "${PWD##*/}:${CMD}"
  else
    title "%100>...>$LINE%<<" "$CMD"
  fi
  
  # WezTerm-specific: Update user vars when executing commands
  # Check multiple ways to detect WezTerm, or assume WezTerm in SSH sessions
  local is_wezterm=false
  
  if [[ "$TERM_PROGRAM" == "WezTerm" ]] || [[ "$WEZTERM_PANE" != "" ]] || [[ "$TERM_PROGRAM_VERSION" =~ "wezterm" ]]; then
    is_wezterm=true
  elif [[ "$SSH_CONNECTION" != "" ]] && [[ "$ZSH_TAB_TITLE_ASSUME_WEZTERM_SSH" == "true" ]]; then
    # Assume WezTerm in SSH sessions if explicitly enabled
    is_wezterm=true
  fi
  
  if [[ "$is_wezterm" == "true" ]]; then
    printf "\033]1337;SetUserVar=WEZTERM_PROG=%s\033\\" "$(echo -n "$CMD" | base64)"
    # Update current working directory with OSC 7
    printf "\033]7;file://%s%s\033\\" "$HOST" "$PWD"
  fi
}

# Execute the first time, so it show correctly on terminal load
setTerminalTitleInIdle

autoload -U add-zsh-hook
add-zsh-hook precmd omz_termsupport_precmd
add-zsh-hook preexec omz_termsupport_preexec
