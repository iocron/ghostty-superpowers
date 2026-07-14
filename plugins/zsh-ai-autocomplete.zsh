#!/usr/bin/env zsh

GHOSTTY_SUPERPOWERS="${GHOSTTY_SUPERPOWERS:-${HOME}/.ghostty-superpowers}"

# Feature: echo 123 # change the echo string to hello world → echo "hello world"

# Check if ollama is available
LLM_SKIP_FILE="/tmp/.ghostty_llm_skip"
if ! command -v ollama >/dev/null 2>&1; then
  if [[ ! -f "$LLM_SKIP_FILE" ]]; then
    echo "⚠ ollama not found. Skipping LLM completion module." >&2
    echo "  Install it from https://ollama.com to enable AI autocompletion." >&2
    touch "$LLM_SKIP_FILE"
  fi
  return 0
fi

# Load .env
ENV_FILE="${ENV_FILE:-$GHOSTTY_SUPERPOWERS/.env}"
if [[ -f "$ENV_FILE" ]]; then
  source "$ENV_FILE"
fi

# LLM - Default Settings
# Use the MLX-optimized model fallback only on macOS; plain model elsewhere.
if [[ "$(uname -s)" == "Darwin" ]]; then
  GHOSTTY_SUPERPOWERS_OLLAMA_MODEL="${GHOSTTY_SUPERPOWERS_OLLAMA_MODEL:-gemma4:e2b-mlx}"
else
  GHOSTTY_SUPERPOWERS_OLLAMA_MODEL="${GHOSTTY_SUPERPOWERS_OLLAMA_MODEL:-gemma4:e2b}"
fi

# Check if the required ollama model is installed
LLM_MODEL_SKIP_FILE="/tmp/.ghostty_llm_model_skip"
if ! ollama show "$GHOSTTY_SUPERPOWERS_OLLAMA_MODEL" >/dev/null 2>&1; then
  if [[ ! -f "$LLM_MODEL_SKIP_FILE" ]]; then
    echo "⚠ ollama model '$GHOSTTY_SUPERPOWERS_OLLAMA_MODEL' not found. Skipping LLM completion module." >&2
    echo "  Run 'ollama pull $GHOSTTY_SUPERPOWERS_OLLAMA_MODEL' to enable AI autocompletion." >&2
    touch "$LLM_MODEL_SKIP_FILE"
  fi
  return 0
fi

# LLM - Safety Guardrails
readonly LLM_TRIGGER_REGEX='^#[[:space:]]*([^#].*)$'
readonly LLM_SAFETY_REGEX=$(cat <<'EOF' | tr -d '\n'
(
(^|[[:space:]]|\|)[[:space:]]*sh([[:space:]]|$)|
bash[[:space:]]|
chmod([[:space:]]+-R)?([[:space:]]+777)?|
curl[[:space:]]|
eval[[:space:]]|
fish[[:space:]]|
npx[[:space:]]|
rm[[:space:]]*-r|
root|
source[[:space:]]|
sudo|
wget[[:space:]]|
zsh[[:space:]]
)
EOF
)

# Unified function for LLM responses
# Mode: "generate" (default) - generates a command from prompt
# Mode: "modify" - modifies a command based on instruction
get_llm_response() {
  local prompt="$1"
  local mode="${2:-generate}"

  # Sanitize prompt
  prompt=$(echo "$prompt" | sed 's/[[:space:]]*$//' | sed 's/^[[:space:]]*#[[:space:]]*//')

  if [[ -z "$prompt" ]]; then
    return 1
  fi

  # Construct prompt based on mode
  local secure_prompt
  if [[ "$mode" == "modify" ]]; then
    secure_prompt="Modify this command according to the instruction. $prompt. Return ONLY the modified command, no explanations, no markdown, no extra text."
  else
    secure_prompt="You are running on $(uname -s)/$(uname -m). Return ONLY a single executable terminal command, no explanations, no markdown, no extra text, that accomplishes this task as a single command: $prompt"
  fi

  # Call Ollama
  local response
  response=$(ollama run "$GHOSTTY_SUPERPOWERS_OLLAMA_MODEL" --nowordwrap --think=false "$secure_prompt" 2>/dev/null)

  # Sanitize response - extract command from markdown code blocks
  # Remove markdown code block markers and extract actual command
  response=$(echo "$response" | sed 's/```[a-z]*//g' | sed 's/```//g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  
  # Handle quotes properly to prevent xargs errors
  if [[ -n "$response" ]]; then
    # Remove outer quotes if they match
    if [[ ${#response} -gt 1 ]]; then
      first_char="${response:0:1}"
      last_char="${response: -1}"
      if [[ "$first_char" == "$last_char" ]] && [[ "$first_char" =~ [\'\"] ]]; then
        response="${response:1:${#response}-2}"
      fi
    fi
    # Trim whitespace
    response=$(echo "$response" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  fi
  
  # Final safety check to clean up any problematic characters
  response=$(printf "%s" "$response" | LC_ALL=C tr -d '\000-\010\013\014\016-\037\177')

  # Security check
  if [[ "$response" =~ $LLM_SAFETY_REGEX ]]; then
    echo "# $response"
    return 1
  fi

  echo "$response"
}

# Process LLM response or fallback action
_llm_handle_buffer() {
  # Pattern 1: # command completion (new command generation)
  # Only trigger if BUFFER starts with exactly one #, not ## or ###
  # Explicitly check that BUFFER starts with # but not ##
  if [[ "$BUFFER" =~ ^# ]] && [[ ! "$BUFFER" =~ ^## ]] && [[ "$BUFFER" =~ $LLM_TRIGGER_REGEX ]]; then
    local prompt="${match[1]}"

    if [[ -n "$prompt" ]]; then
      local completion
      completion=$(get_llm_response "$prompt")

      if [[ -n "$completion" ]]; then
        BUFFER="$completion"
        CURSOR=${#BUFFER}
      fi
      return
    fi
  fi

  # Pattern 2: <command>#<instruction> or <command> # <instruction> - modify command based on instruction
  # Only trigger if BUFFER contains exactly one # separating command and instruction
  if [[ "$BUFFER" =~ '^(.*)#[[:space:]]*(.+)$' ]] && [[ ! "$BUFFER" =~ '##' ]] && [[ ! "${match[1]}" =~ '#$' ]]; then
    local command_to_modify="${match[1]}"
    local instruction="${match[2]}"
    command_to_modify=$(echo "$command_to_modify" | sed 's/[[:space:]]*$//')

    if [[ -n "$command_to_modify" ]] && [[ -n "$instruction" ]]; then
      local modified_command
      modified_command=$(get_llm_response "Command: $command_to_modify. Instruction: $instruction" "modify")

      if [[ -n "$modified_command" ]]; then
        BUFFER="$modified_command"
        CURSOR=${#BUFFER}
      fi
      return
    fi
  fi

  # No LLM pattern matched, call fallback widget
  zle "$@"
}

# Tab widget: complete with LLM or fallback to normal completion
llm_tab_widget() {
  _llm_handle_buffer expand-or-complete
}

# Enter widget: complete with LLM or fallback to accept-line
llm_enter_widget() {
  _llm_handle_buffer accept-line
}

# Register the widgets
zle -N llm_tab_widget
zle -N llm_enter_widget

# Bind Keys to custom Widgets
bindkey '^I' llm_tab_widget
bindkey '^M' llm_enter_widget

# Show a short usage hint once
LLM_HINT_SKIP_FILE="/tmp/.ghostty_llm_hint_skip"
if [[ ! -f "$LLM_HINT_SKIP_FILE" ]]; then
  echo "✓ AI completion ready (model: $GHOSTTY_SUPERPOWERS_OLLAMA_MODEL)." >&2
  echo "  Type '# describe a command' then Tab/Enter to generate, or '<command> # instruction' to modify." >&2
  touch "$LLM_HINT_SKIP_FILE"
fi
