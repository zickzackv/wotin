package main

import "core:fmt"
import "core:os"

COMPLETION_BASH :: `# wotin bash completion
# Usage: source <(wotin completion bash)
_wotin_completion() {
    local cur prev words
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    local commands="start stop status current cancel restart frames log report aggregate projects tags remove change edit rename add import completion version help"
    local time_flags="--today --yesterday --week --month --year --from --to"
    local output_flags="--json --csv"

    case "${prev}" in
        wotin)
            COMPREPLY=($(compgen -W "${commands}" -- "${cur}"))
            return ;;
        log|report|aggregate)
            COMPREPLY=($(compgen -W "${time_flags} ${output_flags}" -- "${cur}"))
            return ;;
        completion)
            COMPREPLY=($(compgen -W "bash zsh fish" -- "${cur}"))
            return ;;
        rename)
            COMPREPLY=($(compgen -W "project tag" -- "${cur}"))
            return ;;
    esac

    COMPREPLY=($(compgen -W "${commands}" -- "${cur}"))
}
complete -F _wotin_completion wotin
`

COMPLETION_ZSH :: `# wotin zsh completion
# Usage: source <(wotin completion zsh)
_wotin() {
    local -a commands time_flags output_flags
    commands=(
        'start:Start tracking time'
        'stop:Stop current activity'
        'status:Show currently running activity'
        'current:Alias for status'
        'cancel:Delete current activity without saving'
        'restart:Restart last stopped activity'
        'frames:List all frame IDs'
        'log:Detailed activity list'
        'report:Aggregated time report'
        'aggregate:Daily breakdown per project'
        'projects:List all projects'
        'tags:List all tags'
        'remove:Delete an entry by frame ID'
        'change:Change project and/or tags of an entry'
        'edit:Edit entry in $EDITOR'
        'rename:Rename a project or tag everywhere'
        'add:Manually add a past activity'
        'import:Import from Watson frames file'
        'completion:Generate shell completion script'
        'version:Show version'
        'help:Show help'
    )
    time_flags=(--today --yesterday --week --month --year --from --to)
    output_flags=(--json --csv)

    case $words[2] in
        log|report|aggregate)
            _arguments '*: :(${time_flags[@]} ${output_flags[@]})'
            return ;;
        completion)
            _arguments '*: :(bash zsh fish)'
            return ;;
        rename)
            _arguments '*: :(project tag)'
            return ;;
    esac

    _describe 'command' commands
}
compdef _wotin wotin
`

COMPLETION_FISH :: `# wotin fish completion
# Usage: wotin completion fish | source

set -l commands start stop status current cancel restart frames log report aggregate projects tags remove change edit rename add import completion version help
set -l time_flags --today --yesterday --week --month --year --from --to
set -l output_flags --json --csv

complete -c wotin -f -n "not __fish_seen_subcommand_from $commands" -a "$commands"

for cmd in log report aggregate
    complete -c wotin -n "__fish_seen_subcommand_from $cmd" -a "$time_flags $output_flags"
end

complete -c wotin -n "__fish_seen_subcommand_from completion" -a "bash zsh fish"
complete -c wotin -n "__fish_seen_subcommand_from rename" -a "project tag"
`

print_completion :: proc(shell: string) {
	switch shell {
	case "bash":
		fmt.print(COMPLETION_BASH)
	case "zsh":
		fmt.print(COMPLETION_ZSH)
	case "fish":
		fmt.print(COMPLETION_FISH)
	case:
		fmt.fprintf(os.stderr, "Error: unknown shell '%s', use bash, zsh, or fish\n", shell)
		os.exit(1)
	}
}
