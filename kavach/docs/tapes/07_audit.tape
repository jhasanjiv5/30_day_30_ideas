Output "/tmp/vhs_07_audit.gif"
Set Shell "bash"
Set FontSize 14
Set Width 1150
Set Height 640
Set Theme "Catppuccin Mocha"
Set Padding 20

Hide
Type `export DEMO_DIR=$(mktemp -d) && export HOME=$DEMO_DIR && export KAVACH_HOME=$DEMO_DIR/.kavach && mkdir -p $DEMO_DIR/.ssh && touch $DEMO_DIR/.ssh/id_ed25519 && chmod 644 $DEMO_DIR/.ssh/id_ed25519 && printf '{"mcpServers":{"unreviewed-srv":{"command":"node"}}}\n' > $DEMO_DIR/.mcp.json && cd $DEMO_DIR && clear`
Enter
Sleep 400ms
Show

Type "kavach audit"
Enter
Sleep 900ms
Screenshot "docs/frames/07_audit.png"
Sleep 300ms

Hide
Type "rm -rf $DEMO_DIR"
Enter
