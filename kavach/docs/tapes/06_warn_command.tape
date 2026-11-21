Output "/tmp/vhs_06_warn_command.gif"
Set Shell "bash"
Set FontSize 14
Set Width 1150
Set Height 540
Set Theme "Catppuccin Mocha"
Set Padding 20

Hide
Type "export KAVACH_HOME=$(mktemp -d) && clear"
Enter
Sleep 300ms
Show

Type `echo '{"hook_event_name":"PreToolUse","tool_name":"mcp__unknown_db__query","mcp_server":{"name":"unknown_db","source":"project"},"tool_input":{"sql":"SELECT 1"}}' | kavach hook PreToolUse | jq .`
Enter
Sleep 900ms
Screenshot "docs/frames/06_warn_command.png"
Sleep 300ms

Hide
Type "rm -rf $KAVACH_HOME"
Enter
