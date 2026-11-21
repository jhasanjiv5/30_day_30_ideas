Output "/tmp/vhs_04_block_secret.gif"
Set Shell "bash"
Set FontSize 14
Set Width 1150
Set Height 520
Set Theme "Catppuccin Mocha"
Set Padding 20

Hide
Type "export KAVACH_HOME=$(mktemp -d) && clear"
Enter
Sleep 300ms
Show

Type `echo '{"hook_event_name":"UserPromptSubmit","prompt":"Deploy with AKIAIOSFODNN7EXAMPLE"}' | kavach hook UserPromptSubmit | jq .`
Enter
Sleep 900ms
Screenshot "docs/frames/04_block_secret.png"
Sleep 300ms

Hide
Type "rm -rf $KAVACH_HOME"
Enter
